///|
test "scalar source positions and input limits" {
  let r = Reader::new("a🙂\r\n中")
  assert_eq(r.source_length(), 5)
  assert_eq(r.offset(), 0)
  assert_eq(r.location(4), (2, 1))
  assert_eq(r.location(2), (1, 3))
  assert_eq(r.budgets().depth, 128)
  let bad = try {
    let _ = Reader::new("🙂", limits={ ..Limits::default(), input: 1, })
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
