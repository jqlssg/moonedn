///|
test "exact built-in tag semantics" {
  assert_eq(instant_key("1970-01-01T00:00:00Z"), (0L, ""))
  assert_eq(
    instant_key("2000-02-29T12:30:00.1200+02:00"),
    instant_key("2000-02-29T10:30:00.12Z"),
  )
  assert_true(
    equivalent(
      read("#inst \"1985-04-12T23:20:50.52Z\""),
      read("#inst \"1985-04-13T00:20:50.520+01:00\""),
    ),
  )
  assert_true(
    equivalent(
      read("#uuid \"F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6\""),
      read("#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\""),
    ),
  )
  for
    s in [
      "#uuid 1", "#uuid \"no\"", "#inst \"2023-02-29T00:00:00Z\"", "#inst \"2000-01-01T00:00:60Z\"",
      "#inst \"2000-01-01T00:00:00-00:00\"",
    ] {
    let bad = try {
      let _ = read(s)
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=s)
  }
}
