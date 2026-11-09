///|
test "acceptance invalid constructed values cannot bypass public equality" {
  let bad = try {
    let _ = equivalent(Set([Nil, Nil]), Set([Nil, Bool(true)]))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad)
}

///|
test "acceptance character scalar validity" {
  let bad = try {
    validate_value(Character((0xD800).unsafe_to_char()))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad)
}

///|
test "acceptance plain JSON range is symmetric" {
  let bad = try {
    let _ = to_plain_json(Float(1.0e20))
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad)
}
