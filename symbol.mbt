///|
fn symbol_part(text : String) -> Bool {
  let xs = text.to_array()
  if xs.is_empty() || xs[0].is_ascii_digit() || xs[0] == ':' || xs[0] == '#' {
    return false
  }
  if xs.length() > 1 &&
    (xs[0] == '+' || xs[0] == '-' || xs[0] == '.') &&
    xs[1].is_ascii_digit() {
    return false
  }
  for c in xs {
    let ascii_ok = c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      ".*+!-_?$%&=<>:#".contains_char(c)
    let unicode_ok = c.to_int() > 127 && !c.is_whitespace() && !c.is_control()
    if !ascii_ok && !unicode_ok {
      return false
    }
  }
  true
}

///|
/// The slash alone is a symbol. Otherwise a single slash divides two names.
pub fn valid_symbol(text : String) -> Bool {
  if text == "/" {
    return true
  }
  let parts = text.split("/").map(x => x.to_owned()).to_array()
  (parts.length() == 1 && symbol_part(parts[0])) ||
  (parts.length() == 2 && symbol_part(parts[0]) && symbol_part(parts[1]))
}

///|
pub fn valid_tag(text : String) -> Bool {
  if !valid_symbol(text) || text == "/" {
    return false
  }
  let c = text.to_array()[0]
  c.is_ascii_alphabetic() || (c.to_int() > 127 && !c.is_numeric())
}

///|
pub fn parse_atom(text : String) -> Value raise EdnError {
  match text {
    "nil" => return Nil
    "true" => return Bool(true)
    "false" => return Bool(false)
    _ => ()
  }
  let xs = text.to_array()
  guard !xs.is_empty() else { raise Invalid("empty token") }
  let numeric = xs[0].is_ascii_digit() ||
    (
      xs.length() > 1 &&
      (xs[0] == '+' || xs[0] == '-' || xs[0] == '.') &&
      xs[1].is_ascii_digit()
    )
  if numeric {
    return parse_number(text)
  }
  if xs[0] == ':' {
    let name = chars_slice(xs, 1, xs.length())
    guard name != "/" && valid_symbol(name) else {
      raise Invalid("invalid keyword")
    }
    return Keyword(name)
  }
  guard valid_symbol(text) else { raise Invalid("invalid symbol") }
  Symbol(text)
}
