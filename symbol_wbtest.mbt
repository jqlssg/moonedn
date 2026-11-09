///|
test "symbols keywords and reserved atoms" {
  for s in ["abc", "ns/name", "/", "+", "-", ".", "a:b#c", "中文/名字"] {
    assert_true(valid_symbol(s), msg=s)
  }
  for s in ["", "12", "a/", "/a", "a/b/c", "a/2x", "::x", "@x", "a b", "a'b"] {
    assert_false(valid_symbol(s), msg=s)
  }
  assert_true(parse_atom(":db/id") is Keyword("db/id"))
  assert_true(parse_atom("nil") is Nil)
  assert_false(valid_tag("+tag"))
  assert_true(valid_tag("org.example/Thing"))
}
