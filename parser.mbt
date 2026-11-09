///|
fn Reader::parse_token(
  self : Reader,
  span : SpannedToken,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  work.tick(depth)
  match span.token {
    Atom(text) =>
      parse_atom(text) catch {
        Invalid(message) => raise Syntax(span.start, message)
        e => raise e
      }
    Quoted(text) => Text(text)
    CharLiteral(c) => Character(c)
    Close(_) => raise Syntax(span.start, "unexpected closing delimiter")
    Discard => {
      // A discard consumes one *value*. Nested discards still count towards work.
      let _ = self.required(work, depth + 1)
      self.required(work, depth + 1)
    }
    Tag(name) => {
      let value = self.required(work, depth + 1)
      validate_tag(name, value)
      Tagged(name, value)
    }
    Open(c) => self.collection(c, work, depth)
    SetOpen => self.collection('#', work, depth)
  }
}

///|
fn Reader::required(
  self : Reader,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  let token = self.next_token()
  guard token is Some(span) else { raise Syntax(self.pos, "value expected") }
  self.parse_token(span, work, depth)
}

///|
fn Reader::collection(
  self : Reader,
  open : Char,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  let close = match open {
    '(' => ')'
    '[' => ']'
    _ => '}'
  }
  let values : Array[Value] = []
  while true {
    let token = self.next_token()
    guard token is Some(span) else {
      raise Syntax(self.pos, "unterminated collection")
    }
    match span.token {
      Close(c) => {
        guard c == close else {
          raise Syntax(span.start, "mismatched closing delimiter")
        }
        break
      }
      Discard => {
        work.tick(depth + 1)
        let _ = self.required(work, depth + 1)
        continue
      }
      _ => ()
    }
    // Check before appending, including the second half of every map pair.
    let max_items = if open == '{' {
      self.limits.container * 2
    } else {
      self.limits.container
    }
    guard values.length() < max_items else { raise Limit("collection length") }
    values.push(self.parse_token(span, work, depth + 1))
  }
  match open {
    '(' => List(values)
    '[' => Vector(values)
    '#' => {
      for i in 0..<values.length() {
        for j in 0..<i {
          guard !equal_inner(values[i], values[j], work, depth + 1) else {
            raise Syntax(self.pos, "duplicate set element")
          }
        }
      }
      Set(values)
    }
    _ => {
      guard values.length() % 2 == 0 else {
        raise Syntax(self.pos, "map needs an even number of values")
      }
      let pairs : Array[(Value, Value)] = []
      let mut i = 0
      while i < values.length() {
        for (key, _) in pairs {
          guard !equal_inner(key, values[i], work, depth + 1) else {
            raise Syntax(self.pos, "duplicate map key")
          }
        }
        pairs.push((values[i], values[i + 1]))
        i += 2
      }
      Mapping(pairs)
    }
  }
}

///|
/// Reads the next value, skipping discards. The document-wide budget persists
/// across calls; after a syntax/resource error the reader is poisoned.
pub fn Reader::read_next(self : Reader) -> Value? raise EdnError {
  guard !self.failed else {
    raise Invalid("reader has failed; create a new reader")
  }
  errdefer {
    self.failed = true
  }
  let work = Work::new(self.limits)
  work.visited = self.nodes
  while true {
    let token = self.next_token()
    guard token is Some(span) else {
      self.nodes = work.visited
      return None
    }
    if span.token is Discard {
      work.tick(0)
      let _ = self.required(work, 1)
      continue
    }
    let value = self.parse_token(span, work, 0)
    self.nodes = work.visited
    return Some(value)
  } nobreak {
    None
  }
}

///|
pub fn read(
  source : String,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  let reader = Reader::new(source, limits~)
  guard reader.read_next() is Some(value) else {
    raise Syntax(reader.offset(), "one value expected")
  }
  guard reader.read_next() is None else {
    raise Syntax(reader.offset(), "trailing value")
  }
  value
}

///|
pub fn read_all(
  source : String,
  limits~ : Limits = Limits::default(),
) -> Array[Value] raise EdnError {
  let reader = Reader::new(source, limits~)
  let result : Array[Value] = []
  while reader.read_next() is Some(value) {
    result.push(value)
  }
  result
}
