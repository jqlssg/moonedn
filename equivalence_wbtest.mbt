///|
test "collection equality and numeric precision" {
  assert_true(equivalent(List([Integer("1")]), Vector([Integer("1")])))
  assert_false(equivalent(Integer("1"), BigInteger("1")))
  assert_true(equivalent(Decimal("100.00"), Decimal("1e2")))
  assert_true(equivalent(Set([Bool(true), Nil]), Set([Nil, Bool(true)])))
  assert_true(
    equivalent(
      Mapping([(Keyword("x"), Nil), (Integer("1"), Bool(true))]),
      Mapping([(Integer("1"), Bool(true)), (Keyword("x"), Nil)]),
    ),
  )
  let bad = try {
    let _ = equivalent(Vector([Nil]), Vector([Nil]), limits={
      ..Limits::default(),
      nodes: 1,
    })
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
