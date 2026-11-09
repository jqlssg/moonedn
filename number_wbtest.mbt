///|
test "precise numeric grammar and boundaries" {
  assert_true(parse_number("-0") is Integer("0"))
  assert_true(parse_number("9223372036854775807") is Integer(_))
  assert_true(parse_number("999999999999999999999N") is BigInteger(_))
  assert_true(parse_number("1e2") is Float(100.0))
  assert_eq(decimal_key("100.00"), decimal_key("1e2"))
  for
    s in [
      "01", "-01", ".3", "1.", "1e", "1.5N", "9223372036854775808", "1e9999", "1e1000001M",
    ] {
    let bad = try {
      let _ = parse_number(s)
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=s)
  }
}
