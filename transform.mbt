///|
fn transform_inner(
  value : Value,
  visit : (Value) -> Value raise EdnError,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  work.tick(depth)
  let rebuilt = match value {
    List(items) =>
      List(items.map(item => transform_inner(item, visit, work, depth + 1)))
    Vector(items) =>
      Vector(items.map(item => transform_inner(item, visit, work, depth + 1)))
    Set(items) =>
      Set(items.map(item => transform_inner(item, visit, work, depth + 1)))
    Mapping(entries) =>
      Mapping(
        entries.map(entry => {
          let (key, item) = entry
          (
            transform_inner(key, visit, work, depth + 1),
            transform_inner(item, visit, work, depth + 1),
          )
        }),
      )
    Tagged(name, child) =>
      Tagged(name, transform_inner(child, visit, work, depth + 1))
    _ => value
  }
  visit(rebuilt)
}

///|
/// Post-order transform over a detached input tree, including map keys and tag
/// payloads. Each original node is visited exactly once. Callback results are
/// not revisited. The final result is validated and detached from callback arrays.
/// Resource budgets cover library traversal, not arbitrary callback computation.
pub fn transform(
  value : Value,
  visit : (Value) -> Value raise EdnError,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  let input = clone_value(value, limits~)
  let result = transform_inner(input, visit, Work::new(limits), 0)
  clone_value(result, limits~)
}

///|
/// Resolve all occurrences of one tag after parsing. Parsing/discard never
/// executes callbacks. Unknown tags and unrelated built-ins remain unchanged.
pub fn resolve_tag(
  value : Value,
  name : String,
  handler : (Value) -> Value raise EdnError,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  guard valid_tag(name) else { raise Invalid("tag handler name") }
  transform(
    value,
    node => {
      match node {
        Tagged(tag, child) => if tag == name { handler(child) } else { node }
        _ => node
      }
    },
    limits~,
  )
}
