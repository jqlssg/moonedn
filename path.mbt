///|
pub(all) enum Segment {
  Index(Int32)
  Key(Value)
  TaggedValue
}

///|
pub type Path = Array[Segment]

///|
fn child_at(
  value : Value,
  segment : Segment,
  work : Work,
  depth : Int32,
) -> Value? raise EdnError {
  work.tick(depth)
  match (value, segment) {
    (List(items), Index(index)) | (Vector(items), Index(index)) =>
      if index < 0 || index >= items.length() {
        None
      } else {
        Some(items[index])
      }
    (Mapping(entries), Key(key)) => {
      for (candidate, item) in entries {
        if equal_inner(candidate, key, work, depth + 1) {
          return Some(item)
        }
      }
      None
    }
    (Tagged(_, child), TaggedValue) => Some(child)
    _ => raise PathError("segment does not apply to this value kind")
  }
}

///|
/// Returns an independent subtree. A missing key/index is None, a segment-kind
/// mismatch is an error. Nil is a present value and remains Some(Nil).
pub fn lookup(
  value : Value,
  path : Path,
  limits~ : Limits = Limits::default(),
) -> Value? raise EdnError {
  limits.validate()
  guard path.length() <= limits.depth else { raise Limit("path depth") }
  validate_value(value, limits~)
  let work = Work::new(limits)
  let mut current = value
  for i in 0..<path.length() {
    match child_at(current, path[i], work, i) {
      Some(child) => current = child
      None => return None
    }
  }
  Some(clone_inner(current, work, 0))
}

///|
pub fn require_at(
  value : Value,
  path : Path,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  guard lookup(value, path, limits~) is Some(found) else {
    raise PathError("path not found")
  }
  found
}

///|
/// One component per sequence index, map key or tagged payload. Map keys may be
/// arbitrary EDN values; no lossy string path syntax is involved.
pub fn contains_path(
  value : Value,
  path : Path,
  limits~ : Limits = Limits::default(),
) -> Bool raise EdnError {
  lookup(value, path, limits~) is Some(_)
}
