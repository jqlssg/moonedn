///|
test "statistics and structured error diagnostics" {
  let stats = inspect_value(read("{:x [1 #app/x true]}"))
  assert_eq(stats.nodes, 6)
  assert_eq(stats.collections, 2)
  assert_eq(stats.map_entries, 1)
  assert_eq(stats.tagged, 1)
  assert_eq(stats.max_depth, 3)
  assert_eq(stats.kinds.get("integer"), Some(1))
  let d = diagnose("[🙂\n}", Syntax(3, "unexpected delimiter"), context=2)
  assert_eq(d.line, Some(2))
  assert_eq(d.column, Some(1))
  assert_true(d.excerpt.contains("}"))
  assert_true(diagnose("", Limit("nodes")).line is None)
}
