///|
pub(all) struct Statistics {
  nodes : Int32
  max_depth : Int32
  text_units : Int32
  collections : Int32
  map_entries : Int32
  tagged : Int32
  kinds : Map[String, Int32]
}

///|
priv struct Inspection {
  mut max_depth : Int32
  mut text_units : Int32
  mut collections : Int32
  mut map_entries : Int32
  mut tagged : Int32
  kinds : Map[String, Int32]
}

///|
fn inspect_inner(
  value : Value,
  state : Inspection,
  work : Work,
  depth : Int32,
) -> Unit raise EdnError {
  work.tick(depth)
  state.max_depth = if depth > state.max_depth {
    depth
  } else {
    state.max_depth
  }
  let kind = value.kind()
  state.kinds[kind] = state.kinds.get(kind).unwrap_or(0) + 1
  match value {
    Text(s)
    | Integer(s)
    | BigInteger(s)
    | Decimal(s)
    | Keyword(s)
    | Symbol(s) => state.text_units += s.length()
    Tagged(name, child) => {
      state.tagged += 1
      state.text_units += name.length()
      inspect_inner(child, state, work, depth + 1)
    }
    List(items) | Vector(items) | Set(items) => {
      state.collections += 1
      for item in items {
        inspect_inner(item, state, work, depth + 1)
      }
    }
    Mapping(entries) => {
      state.collections += 1
      state.map_entries += entries.length()
      for (key, item) in entries {
        inspect_inner(key, state, work, depth + 1)
        inspect_inner(item, state, work, depth + 1)
      }
    }
    _ => ()
  }
}

///|
/// Counts both map keys and values. Root depth is zero. Each occurrence counts
/// once even when a caller has shared the same underlying array in two places.
pub fn inspect_value(
  value : Value,
  limits~ : Limits = Limits::default(),
) -> Statistics raise EdnError {
  validate_value(value, limits~)
  let work = Work::new(limits)
  let state : Inspection = {
    max_depth: 0,
    text_units: 0,
    collections: 0,
    map_entries: 0,
    tagged: 0,
    kinds: Map([]),
  }
  inspect_inner(value, state, work, 0)
  {
    nodes: work.visited,
    max_depth: state.max_depth,
    text_units: state.text_units,
    collections: state.collections,
    map_entries: state.map_entries,
    tagged: state.tagged,
    kinds: state.kinds,
  }
}

///|
pub(all) struct Diagnostic {
  message : String
  offset : Int32?
  line : Int32?
  column : Int32?
  excerpt : String
}

///|
/// Converts typed errors to a bounded editor-friendly diagnostic. Offsets and
/// columns count Unicode scalars; an invalid supplied offset has no location.
pub fn diagnose(
  source : String,
  error : EdnError,
  context~ : Int32 = 40,
) -> Diagnostic raise EdnError {
  guard context >= 0 && context <= 200 else {
    raise Invalid("diagnostic context range")
  }
  let (offset, message) = match error {
    Syntax(pos, message) => (Some(pos), message)
    Limit(message) => (None, "resource limit: " + message)
    Invalid(message) => (None, "invalid value: " + message)
    PathError(message) => (None, "path: " + message)
  }
  if offset is Some(pos) {
    let reader = Reader::new(source)
    if pos >= 0 && pos <= reader.source_length() {
      let (line, column) = reader.location(pos)
      let start = if pos > context { pos - context } else { 0 }
      let end = if pos + context < reader.source_length() {
        pos + context
      } else {
        reader.source_length()
      }
      return {
        message,
        offset,
        line: Some(line),
        column: Some(column),
        excerpt: chars_slice(reader.chars, start, end),
      }
    }
  }
  { message, offset: None, line: None, column: None, excerpt: "", }
}
