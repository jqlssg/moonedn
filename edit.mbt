///|
pub(all) enum Edit {
  Replace(Path, Value)
  Put(Path, Value, Value)
  Insert(Path, Int32, Value)
  Remove(Path)
  Check(Path, Value)
}

///|
fn rewrite_at(
  value : Value,
  path : Path,
  offset : Int32,
  change : (Value) -> Value raise EdnError,
  work : Work,
) -> Value raise EdnError {
  work.tick(offset)
  if offset == path.length() {
    return change(value)
  }
  match (value, path[offset]) {
    (List(items), Index(index)) | (Vector(items), Index(index)) => {
      guard index >= 0 && index < items.length() else {
        raise PathError("sequence index not found")
      }
      let result = items.copy()
      result[index] = rewrite_at(items[index], path, offset + 1, change, work)
      if value is List(_) {
        List(result)
      } else {
        Vector(result)
      }
    }
    (Mapping(entries), Key(key)) => {
      let result = entries.copy()
      for i in 0..<entries.length() {
        let (candidate, child) = entries[i]
        if equal_inner(candidate, key, work, offset + 1) {
          result[i] = (
            candidate,
            rewrite_at(child, path, offset + 1, change, work),
          )
          return Mapping(result)
        }
      }
      raise PathError("map key not found")
    }
    (Tagged(name, child), TaggedValue) =>
      Tagged(name, rewrite_at(child, path, offset + 1, change, work))
    _ => raise PathError("segment does not apply to value")
  }
}

///|
fn put_entry(
  value : Value,
  key : Value,
  item : Value,
  work : Work,
) -> Value raise EdnError {
  guard value is Mapping(entries) else {
    raise PathError("put target must be a map")
  }
  let result = entries.copy()
  for i in 0..<entries.length() {
    let (candidate, _) = entries[i]
    if equal_inner(candidate, key, work, 0) {
      result[i] = (candidate, item)
      return Mapping(result)
    }
  }
  guard result.length() < work.limits.container else {
    raise Limit("map length")
  }
  result.push((key, item))
  Mapping(result)
}

///|
fn insert_item(
  value : Value,
  index : Int32,
  item : Value,
  work : Work,
) -> Value raise EdnError {
  let items = match value {
    List(items) | Vector(items) => items
    _ => raise PathError("insert target must be a sequence")
  }
  guard index >= 0 && index <= items.length() else {
    raise PathError("insert index")
  }
  guard items.length() < work.limits.container else {
    raise Limit("sequence length")
  }
  let result = items.copy()
  result.insert(index, item)
  if value is List(_) {
    List(result)
  } else {
    Vector(result)
  }
}

///|
fn remove_child(
  value : Value,
  segment : Segment,
  work : Work,
) -> Value raise EdnError {
  match (value, segment) {
    (List(items), Index(index)) | (Vector(items), Index(index)) => {
      guard index >= 0 && index < items.length() else {
        raise PathError("remove index")
      }
      let result = items.copy()
      let _ = result.remove(index)
      if value is List(_) {
        List(result)
      } else {
        Vector(result)
      }
    }
    (Mapping(entries), Key(key)) => {
      let result = entries.copy()
      for i in 0..<entries.length() {
        let (candidate, _) = entries[i]
        if equal_inner(candidate, key, work, 0) {
          let _ = result.remove(i)
          return Mapping(result)
        }
      }
      raise PathError("remove key not found")
    }
    _ => raise PathError("remove requires a sequence index or map key")
  }
}

///|
fn apply_one(value : Value, edit : Edit, work : Work) -> Value raise EdnError {
  let path = match edit {
    Replace(p, _) | Put(p, _, _) | Insert(p, _, _) | Remove(p) | Check(p, _) =>
      p
  }
  guard path.length() <= work.limits.depth else {
    raise Limit("edit path depth")
  }
  match edit {
    Replace(_, item) => {
      let item = clone_inner(item, work, 0)
      rewrite_at(value, path, 0, _ => item, work)
    }
    Put(_, key, item) => {
      let key = clone_inner(key, work, 0)
      let item = clone_inner(item, work, 0)
      rewrite_at(
        value,
        path,
        0,
        target => put_entry(target, key, item, work),
        work,
      )
    }
    Insert(_, index, item) => {
      let item = clone_inner(item, work, 0)
      rewrite_at(
        value,
        path,
        0,
        target => insert_item(target, index, item, work),
        work,
      )
    }
    Remove(_) => {
      guard !path.is_empty() else {
        raise PathError("cannot remove document root")
      }
      let parent = path[0:path.length() - 1].to_owned()
      rewrite_at(
        value,
        parent,
        0,
        target => remove_child(target, path[path.length() - 1], work),
        work,
      )
    }
    Check(_, expected) =>
      rewrite_at(
        value,
        path,
        0,
        target => {
          guard equal_inner(target, expected, work, 0) else {
            raise PathError("transaction precondition failed")
          }
          target
        },
        work,
      )
  }
}

///|
/// Applies edits sequentially against a detached snapshot. Any failure returns
/// an error; no partial result escapes and caller-owned inputs remain unchanged.
pub fn transact(
  value : Value,
  edits : Array[Edit],
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  guard edits.length() <= limits.container else { raise Limit("edit count") }
  let work = Work::new(limits)
  let mut result = clone_inner(value, work, 0)
  for edit in edits {
    result = apply_one(result, edit, work)
  }
  validate_value(result, limits~)
  result
}
