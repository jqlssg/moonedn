///|
test "value types and default limits" {
  assert_eq(Value::Integer("42").kind(), "integer")
  assert_eq(Value::Vector([]).kind(), "vector")
  Limits::default().validate()
  let bad = try {
    ({ ..Limits::default(), depth: 0, } : Limits).validate()
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
