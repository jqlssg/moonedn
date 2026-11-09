///|
test "lossless JSON transport and malformed schema" {
  let value = read(
    "{:x (1 123456789012345678901234567890N 1.2300M) [true] #{\\space #app/id :v}}",
  )
  let encoded = to_tagged_json(value)
  let decoded = from_tagged_json(encoded)
  assert_eq(write(decoded), write(value))
  assert_true(equivalent(value, decoded))
  for
    j in [
      Json::array([]),
      Json::array([Json::string("nil"), Json::null()]),
      Json::array([Json::string("float"), Json::string("1")]),
      Json::array([Json::string("character"), Json::string("ab")]),
    ] {
    let bad = try {
      let _ = from_tagged_json(j)
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
}
