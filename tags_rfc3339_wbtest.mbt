///|
test "RFC3339 required time values and leap identity" {
  let leap = read("#inst \"1990-12-31T23:59:60Z\"")
  assert_true(equivalent(leap, read("#inst \"1990-12-31T15:59:60-08:00\"")))
  assert_true(equivalent(leap, read("#inst \"1991-01-01T05:29:60+05:30\"")))
  assert_false(equivalent(leap, read("#inst \"1990-12-31T23:59:59Z\"")))
  assert_false(equivalent(leap, read("#inst \"1991-01-01T00:00:00Z\"")))
  assert_true(
    equivalent(
      read("#inst \"2000-01-01T00:00:00-00:00\""),
      read("#inst \"2000-01-01T00:00:00Z\""),
    ),
  )
  assert_eq(
    write(read("#inst \"0000-02-29t00:00:00z\"")),
    "#inst \"0000-02-29t00:00:00z\"",
  )
}

///|
test "RFC3339 unknown local offset metadata and precise fractions" {
  for
    s in [
      "2000-01-01T00:00:00-00:00", "0000-02-29t00:00:00z", "9999-12-31T23:59:59.000000000000000001Z",
      "2016-12-31T23:59:60.000000000000000001-00:00",
    ] {
    let value = Tagged("inst", Text(s))
    assert_eq(write(read(write(value))), write(value))
    assert_eq(write(from_tagged_json(to_tagged_json(value))), write(value))
    assert_eq(write(read(pretty(value))), write(value))
  }
  assert_eq(instant_key("0000-01-01T00:00:00Z"), (-62167219200L, ""))
  assert_eq(instant_key("0001-01-01T00:00:00Z"), (-62135596800L, ""))
  assert_eq(
    instant_key("0000-03-01T00:00:00Z").0 -
    instant_key("0000-02-28T00:00:00Z").0,
    172800L,
  )
  assert_eq(instant_key("9999-12-31T23:59:59-23:59"), (253402387139L, ""))
  assert_eq(instant_key("0000-01-01T00:00:00+23:59"), (-62167305540L, ""))
  assert_true(
    equivalent(
      read("#inst \"2016-12-31t23:59:60.1200z\""),
      read("#inst \"2017-01-01T00:59:60.12+01:00\""),
    ),
  )
  assert_false(
    equivalent(
      read("#inst \"2016-12-31T23:59:60.12Z\""),
      read("#inst \"2016-12-31T23:59:60.1201Z\""),
    ),
  )
}

///|
test "RFC3339 rejects calendar errors and unannounced leap seconds" {
  for
    text in [
      "1900-02-29T00:00:00Z", "0001-02-29T00:00:00Z", "2000-01-01T00:00:60Z", "2016-12-30T23:59:60Z",
      "2016-12-31T22:59:60Z", "2016-12-31T23:59:60+01:00", "2017-01-01T00:00:60Z",
      "2026-12-31T23:59:60Z", "2016-12-31T23:59:61Z", "2016-12-31T24:00:00Z", "2016-12-31T23:59:59+24:00",
      "2016-12-31T23:59:59+00:60", "2016-12-31", "2016-12-31T23:59:59", "2016-12-31T23:59:59.Z",
      "2016-12-31T23:59:59,1Z", "2016-12-31T23:59:59Zx", "10000-01-01T00:00:00Z",
      "-001-01-01T00:00:00Z",
    ] {
    let rejected = try {
      let _ = instant_key(text)
      false
    } catch {
      Invalid(_) => true
      _ => false
    }
    assert_true(rejected, msg=text)
  }
}

///|
test "RFC3339 tag equality governs collection keys and duplicate validation" {
  let map = read(
    "{#inst \"1990-12-31T23:59:60Z\" :leap #inst \"1991-01-01T00:00:00Z\" :next}",
  )
  assert_true(
    require_at(map, [Key(read("#inst \"1991-01-01T05:29:60+05:30\""))])
    is Keyword("leap"),
  )
  for
    source in [
      "#{#inst \"1990-12-31T23:59:60Z\" #inst \"1990-12-31T15:59:60-08:00\"}", "{#inst \"2000-01-01T00:00:00-00:00\" 1 #inst \"2000-01-01T00:00:00Z\" 2}",
    ] {
    let rejected = try {
      let _ = read(source)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let distinct = read(
    "#{#inst \"2016-12-31T23:59:59.5Z\" #inst \"2016-12-31T23:59:60.5Z\" #inst \"2017-01-01T00:00:00.5Z\"}",
  )
  assert_true(equivalent(distinct, from_tagged_json(to_tagged_json(distinct))))
  let invalid = Tagged("inst", Text("2016-12-30T23:59:60Z"))
  let rejected = try {
    let _ = write(invalid)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "RFC3339 negative leap rule with synthetic adjustment only" {
  assert_eq(adjusted_instant_key(100L, "12", 58, -1), (100L, "12"))
  for second in [59, 60] {
    let rejected = try {
      let _ = adjusted_instant_key(101L, "", second, -1)
      false
    } catch {
      Invalid(_) => true
      _ => false
    }
    assert_true(rejected)
  }
  assert_eq(adjusted_instant_key(101L, "", 59, 0), (101L, ""))
}
