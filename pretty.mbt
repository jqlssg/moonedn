///|
pub(all) struct Layout {
  width : Int32
  indent : Int32
}

///|
pub fn Layout::default() -> Layout {
  { width: 80, indent: 2, }
}

///|
fn newline_indent(
  out : Output,
  level : Int32,
  layout : Layout,
) -> Unit raise EdnError {
  out.put("\n")
  for _ in 0..<(level * layout.indent) {
    out.put(" ")
  }
}

///|
fn pretty_inner(
  value : Value,
  out : Output,
  work : Work,
  level : Int32,
  layout : Layout,
) -> Unit raise EdnError {
  work.tick(level)
  let compact = render_inner(value, work, level, false)
  if compact.length() + level * layout.indent <= layout.width {
    out.put(compact)
    return
  }
  match value {
    List(items) | Vector(items) | Set(items) => {
      let (open, close) = match value {
        List(_) => ("(", ")")
        Vector(_) => ("[", "]")
        _ => ("#{", "}")
      }
      out.put(open)
      for item in items {
        newline_indent(out, level + 1, layout)
        pretty_inner(item, out, work, level + 1, layout)
      }
      if !items.is_empty() {
        newline_indent(out, level, layout)
      }
      out.put(close)
    }
    Mapping(entries) => {
      out.put("{")
      for (key, item) in entries {
        newline_indent(out, level + 1, layout)
        pretty_inner(key, out, work, level + 1, layout)
        out.put(" ")
        pretty_inner(item, out, work, level + 1, layout)
      }
      if !entries.is_empty() {
        newline_indent(out, level, layout)
      }
      out.put("}")
    }
    Tagged(name, child) => {
      out.put("#" + name)
      newline_indent(out, level + 1, layout)
      pretty_inner(child, out, work, level + 1, layout)
    }
    _ => out.put(compact)
  }
}

///|
/// Width is a preferred line width; long indivisible scalars are never split.
/// Comments and original whitespace are intentionally not preserved.
pub fn pretty(
  value : Value,
  layout~ : Layout = Layout::default(),
  limits~ : Limits = Limits::default(),
) -> String raise EdnError {
  guard layout.width >= 16 &&
    layout.width <= 240 &&
    layout.indent >= 1 &&
    layout.indent <= 8 else {
    raise Invalid("layout range")
  }
  validate_value(value, limits~)
  let out = Output::new(limits.input)
  pretty_inner(value, out, Work::new(limits), 0, layout)
  out.builder.to_string()
}
