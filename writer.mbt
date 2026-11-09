///|
priv struct Output {
  builder : StringBuilder
  limit : Int32
  mut size : Int32
}

///|
fn Output::new(limit : Int32) -> Output {
  { builder: StringBuilder(), limit, size: 0, }
}

///|
fn Output::put(self : Output, text : String) -> Unit raise EdnError {
  guard text.length() <= self.limit - self.size else {
    raise Limit("output units")
  }
  self.size += text.length()
  self.builder.write_string(text)
}

///|
fn Output::char(self : Output, c : Char) -> Unit raise EdnError {
  self.put(c.to_string())
}

///|
fn quoted_output(text : String, out : Output) -> Unit raise EdnError {
  out.put("\"")
  for c in text {
    match c {
      '"' => out.put("\\\"")
      '\\' => out.put("\\\\")
      '\n' => out.put("\\n")
      '\r' => out.put("\\r")
      '\t' => out.put("\\t")
      '\b' => out.put("\\b")
      '\u{000c}' => out.put("\\f")
      _ =>
        if c.to_int() < 32 {
          let n = c.to_int()
          let digits = "0123456789abcdef".to_array()
          out.put("\\u00")
          out.char(digits[n / 16])
          out.char(digits[n % 16])
        } else {
          out.char(c)
        }
    }
  }
  out.put("\"")
}

///|
fn float_text(x : Double) -> String {
  let text = x.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    text + ".0"
  }
}

///|
fn write_items(
  items : Array[Value],
  out : Output,
  work : Work,
  depth : Int32,
  canonical : Bool,
) -> Unit raise EdnError {
  for i in 0..<items.length() {
    if i > 0 {
      out.put(" ")
    }
    write_inner(items[i], out, work, depth + 1, canonical)
  }
}

///|
fn render_inner(
  value : Value,
  work : Work,
  depth : Int32,
  canonical : Bool,
) -> String raise EdnError {
  let out = Output::new(work.limits.input)
  write_inner(value, out, work, depth, canonical)
  out.builder.to_string()
}

///|
fn write_inner(
  value : Value,
  out : Output,
  work : Work,
  depth : Int32,
  canonical : Bool,
) -> Unit raise EdnError {
  work.tick(depth)
  match value {
    Nil => out.put("nil")
    Bool(x) => out.put(if x { "true" } else { "false" })
    Integer(x) => out.put(x)
    BigInteger(x) => {
      out.put(x)
      out.put("N")
    }
    Decimal(x) => {
      out.put(x)
      out.put("M")
    }
    Float(x) => out.put(float_text(x))
    Text(x) => quoted_output(x, out)
    Symbol(x) => out.put(x)
    Keyword(x) => {
      out.put(":")
      out.put(x)
    }
    Character(c) => {
      out.put("\\")
      match c {
        ' ' => out.put("space")
        '\n' => out.put("newline")
        '\r' => out.put("return")
        '\t' => out.put("tab")
        _ =>
          if c.is_whitespace() || c.is_control() {
            let n = c.to_int()
            let hex = "0123456789abcdef".to_array()
            out.put("u")
            for shift in [12, 8, 4, 0] {
              out.char(hex[(n >> shift) & 15])
            }
          } else {
            out.char(c)
          }
      }
    }
    Tagged(name, child) => {
      out.put("#")
      out.put(name)
      out.put(" ")
      write_inner(child, out, work, depth + 1, canonical)
    }
    List(items) => {
      out.put("(")
      write_items(items, out, work, depth, canonical)
      out.put(")")
    }
    Vector(items) => {
      out.put("[")
      write_items(items, out, work, depth, canonical)
      out.put("]")
    }
    Set(items) => {
      out.put("#{")
      if canonical {
        let rendered = items.map(item => {
          render_inner(item, work, depth + 1, true)
        })
        rendered.sort()
        for i in 0..<rendered.length() {
          if i > 0 {
            out.put(" ")
          }
          out.put(rendered[i])
        }
      } else {
        write_items(items, out, work, depth, false)
      }
      out.put("}")
    }
    Mapping(entries) => {
      out.put("{")
      if canonical {
        let rendered = entries.map(entry => {
          let (key, item) = entry
          render_inner(key, work, depth + 1, true) +
          " " +
          render_inner(item, work, depth + 1, true)
        })
        rendered.sort()
        for i in 0..<rendered.length() {
          if i > 0 {
            out.put(" ")
          }
          out.put(rendered[i])
        }
      } else {
        for i in 0..<entries.length() {
          if i > 0 {
            out.put(" ")
          }
          let (key, item) = entries[i]
          write_inner(key, out, work, depth + 1, false)
          out.put(" ")
          write_inner(item, out, work, depth + 1, false)
        }
      }
      out.put("}")
    }
  }
}

///|
/// Deterministic compact EDN for a given representation. canonical=true sorts
/// map entries and set elements by serialized text; this is not an EDN hash.
pub fn write(
  value : Value,
  canonical~ : Bool = false,
  limits~ : Limits = Limits::default(),
) -> String raise EdnError {
  validate_value(value, limits~)
  render_inner(value, Work::new(limits), 0, canonical)
}
