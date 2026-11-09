///|
test "plain JSON explicit projection and collisions" {
  let v = read("{:port 8080 :enabled true :hosts [\"a\" \"b\"]}")
  let j = to_plain_json(v, keyword_keys=true)
  assert_true(from_plain_json(j) is Mapping(_))
  assert_eq(
    write(from_plain_json(Json::array([Json::number(2.5), Json::null()]))),
    "[2.5 nil]",
  )
  for
    value in [
      v,
      read("{:x 1 \"x\" 2}"),
      read("9007199254740992"),
      read("1M"),
      read("#{1}"),
    ] {
    let bad = try {
      let _ = to_plain_json(value)
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  let collision = try {
    let _ = to_plain_json(read("{:x 1 \"x\" 2}"), keyword_keys=true)
    false
  } catch {
    _ => true
  }
  assert_true(collision)
}
