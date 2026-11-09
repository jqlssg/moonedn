///|
/// A pull reader owns its source. Positions are Unicode scalar offsets.
/// Limits.input is measured in UTF-16 units to bound allocation before decoding.
pub struct Reader {
  priv chars : Array[Char]
  priv limits : Limits
  priv mut pos : Int32
  priv mut nodes : Int32
  priv mut failed : Bool
}

///|
pub fn Reader::new(
  source : String,
  limits~ : Limits = Limits::default(),
) -> Reader raise EdnError {
  limits.validate()
  guard source.length() <= limits.input else { raise Limit("input units") }
  { chars: source.to_array(), limits, pos: 0, nodes: 0, failed: false, }
}

///|
pub fn Reader::offset(self : Reader) -> Int32 {
  self.pos
}

///|
pub fn Reader::source_length(self : Reader) -> Int32 {
  self.chars.length()
}

///|
pub fn Reader::budgets(self : Reader) -> Limits {
  self.limits
}

///|
/// Returns one-based line and column. CRLF is one logical newline.
pub fn Reader::location(
  self : Reader,
  offset : Int32,
) -> (Int32, Int32) raise EdnError {
  guard offset >= 0 && offset <= self.chars.length() else {
    raise Invalid("source offset")
  }
  let mut line = 1
  let mut column = 1
  for i in 0..<offset {
    let c = self.chars[i]
    if c == '\r' {
      line += 1
      column = 1
    } else if c == '\n' {
      if i == 0 || self.chars[i - 1] != '\r' {
        line += 1
      }
      column = 1
    } else {
      column += 1
    }
  }
  (line, column)
}
