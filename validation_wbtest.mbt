///|
test "manual values and detached arrays" {
  let a : Array[Value] = [Text("a")]
  let v = clone_value(Vector(a))
  a[0] = Nil
  assert_true(v is Vector(xs) && xs[0] is Text("a"))
  for
    value in [
      Integer("+1"),
      BigInteger("01"),
      Symbol("nil"),
      Keyword("/"),
      Set([Nil, Nil]),
      Mapping([(Nil, Nil), (Nil, Bool(true))]),
    ] {
    let bad = try {
      validate_value(value)
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  let cyclic : Array[Value] = []
  cyclic.push(Vector(cyclic))
  let bad = try {
    validate_value(Vector(cyclic), limits={ ..Limits::default(), depth: 5, })
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(bad)
  let keyword_bad = try {
    let _ = read(":/")
    false
  } catch {
    _ => true
  }
  assert_true(keyword_bad)
}
