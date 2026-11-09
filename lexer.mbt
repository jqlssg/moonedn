///|
pub(all) enum Token {
  Atom(String)
  Quoted(String)
  CharLiteral(Char)
  Open(Char)
  Close(Char)
  SetOpen
  Discard
  Tag(String)
}

///|
pub(all) struct SpannedToken {
  token : Token
  start : Int32
  end : Int32
}

///|
fn separator(c : Char) -> Bool {
  c.is_whitespace() || c == ',' || "()[]{}\";\\".contains_char(c)
}

///|
fn Reader::skip_space(self : Reader) -> Unit {
  while self.pos < self.chars.length() {
    let c = self.chars[self.pos]
    if c == ';' {
      while self.pos < self.chars.length() &&
            self.chars[self.pos] != '\n' &&
            self.chars[self.pos] != '\r' {
        self.pos += 1
      }
    } else if c.is_whitespace() || c == ',' {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
fn Reader::hex4(self : Reader) -> Int32 raise EdnError {
  let mut n = 0
  for _ in 0..<4 {
    guard self.pos < self.chars.length() else {
      raise Syntax(self.pos, "incomplete Unicode escape")
    }
    let c = self.chars[self.pos]
    self.pos += 1
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      raise Syntax(self.pos - 1, "invalid hexadecimal digit")
    }
    n = n * 16 + digit
  }
  n
}

///|
fn Reader::quoted(self : Reader, start : Int32) -> String raise EdnError {
  let out = StringBuilder()
  while self.pos < self.chars.length() {
    guard self.pos - start <= self.limits.token else {
      raise Limit("string token")
    }
    let c = self.chars[self.pos]
    self.pos += 1
    if c == '"' {
      return out.to_string()
    }
    if c != '\\' {
      out.write_char(c)
      continue
    }
    guard self.pos < self.chars.length() else {
      raise Syntax(self.pos, "unfinished escape")
    }
    let escape = self.chars[self.pos]
    self.pos += 1
    match escape {
      'n' => out.write_char('\n')
      'r' => out.write_char('\r')
      't' => out.write_char('\t')
      'b' => out.write_char('\b')
      'f' => out.write_char('\u{000c}')
      '"' => out.write_char('"')
      '\\' => out.write_char('\\')
      'u' => {
        let high = self.hex4()
        if high >= 0xD800 && high <= 0xDBFF {
          guard self.pos + 1 < self.chars.length() &&
            self.chars[self.pos] == '\\' &&
            self.chars[self.pos + 1] == 'u' else {
            raise Syntax(self.pos, "high surrogate needs a low surrogate")
          }
          self.pos += 2
          let low = self.hex4()
          guard low >= 0xDC00 && low <= 0xDFFF else {
            raise Syntax(self.pos, "invalid low surrogate")
          }
          out.write_char(
            (0x10000 + (high - 0xD800) * 1024 + low - 0xDC00).unsafe_to_char(),
          )
        } else {
          guard high < 0xDC00 || high > 0xDFFF else {
            raise Syntax(self.pos, "unpaired low surrogate")
          }
          out.write_char(high.unsafe_to_char())
        }
      }
      _ => raise Syntax(self.pos - 1, "unsupported string escape")
    }
  }
  raise Syntax(start, "unterminated string")
}

///|
fn Reader::word(self : Reader, start : Int32) -> String raise EdnError {
  while self.pos < self.chars.length() && !separator(self.chars[self.pos]) {
    self.pos += 1
    guard self.pos - start <= self.limits.token else {
      raise Limit("token length")
    }
  }
  chars_slice(self.chars, start, self.pos)
}

///|
fn Reader::character(self : Reader) -> Char raise EdnError {
  guard self.pos < self.chars.length() && !self.chars[self.pos].is_whitespace() else {
    raise Syntax(self.pos, "character expected")
  }
  let start = self.pos
  let c = self.chars[self.pos]
  self.pos += 1
  // A single delimiter is itself a character, e.g. backslash followed by ].
  if separator(c) {
    return c
  }
  let text = self.word(start)
  match text {
    "newline" => '\n'
    "return" => '\r'
    "space" => ' '
    "tab" => '\t'
    _ => {
      let xs = text.to_array()
      if xs.length() == 1 {
        return xs[0]
      }
      guard xs.length() == 5 && xs[0] == 'u' else {
        raise Syntax(start, "invalid character name")
      }
      let saved = self.pos
      self.pos = start + 1
      let n = self.hex4()
      self.pos = saved
      guard n < 0xD800 || n > 0xDFFF else {
        raise Syntax(start, "surrogate is not a character")
      }
      n.unsafe_to_char()
    }
  }
}

///|
/// Low-level tokenization for editors. Do not mix token and value reading on one reader.
pub fn Reader::next_token(self : Reader) -> SpannedToken? raise EdnError {
  self.skip_space()
  if self.pos == self.chars.length() {
    return None
  }
  let start = self.pos
  let c = self.chars[self.pos]
  self.pos += 1
  let token = match c {
    '(' | '[' | '{' => Open(c)
    ')' | ']' | '}' => Close(c)
    '"' => Quoted(self.quoted(start))
    '\\' => CharLiteral(self.character())
    '#' => {
      guard self.pos < self.chars.length() else {
        raise Syntax(start, "unfinished dispatch")
      }
      match self.chars[self.pos] {
        '{' => {
          self.pos += 1
          SetOpen
        }
        '_' => {
          self.pos += 1
          Discard
        }
        _ => {
          let name = self.word(self.pos)
          guard valid_tag(name) else { raise Syntax(start, "invalid tag") }
          Tag(name)
        }
      }
    }
    _ => Atom(self.word(start))
  }
  guard self.pos - start <= self.limits.token else {
    raise Limit("token length")
  }
  Some({ token, start, end: self.pos, })
}
