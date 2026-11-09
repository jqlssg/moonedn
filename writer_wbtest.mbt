///|
test "compact round trips and deterministic ordering" {
  for
    text in [
      "nil", "[1 2N 1.5 0M :x foo \\newline]", "{[1] #{a b} :t #app/x true}", "\"a\\n\\u0001🙂\"",
      "#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\"",
    ] {
    let value = read(text)
    assert_true(equivalent(value, read(write(value))), msg=text)
  }
  assert_eq(write(read("{:b 2 :a 1}"), canonical=true), "{:a 1 :b 2}")
  assert_eq(write(read("#{b a}"), canonical=true), "#{a b}")
  assert_eq(write(Float(1.0)), "1.0")
  let bad = try {
    let _ = write(Text("x"), limits={ ..Limits::default(), input: 2, })
    false
  } catch {
    Limit(_) => true
    _ => false
  }
  assert_true(bad)
}
