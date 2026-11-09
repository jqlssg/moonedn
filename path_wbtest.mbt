///|
test "typed paths and presence distinct from nil" {
  let value = read("{:a [nil #app/x {:k 42}] [1 2] :complex}")
  assert_true(lookup(value, [Key(Keyword("a")), Index(0)]) is Some(Nil))
  assert_true(lookup(value, [Key(Keyword("missing"))]) is None)
  assert_true(
    require_at(value, [
      Key(Keyword("a")),
      Index(1),
      TaggedValue,
      Key(Keyword("k")),
    ])
    is Integer("42"),
  )
  assert_true(
    require_at(value, [Key(List([Integer("1"), Integer("2")]))])
    is Keyword("complex"),
  )
  let bad = try {
    let _ = lookup(value, [Index(0)])
    false
  } catch {
    PathError(_) => true
    _ => false
  }
  assert_true(bad)
}
