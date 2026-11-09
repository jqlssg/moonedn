///|
test "tokens and Unicode escapes" {
  let r = Reader::new(
    "; comment\n\"a\\n\\uD83D\\uDE42\" \\space \\] #foo/x #_ #{",
  )
  assert_true(r.next_token() is Some({ token: Quoted("a\n🙂"), .. }))
  assert_true(r.next_token() is Some({ token: CharLiteral(' '), .. }))
  assert_true(r.next_token() is Some({ token: CharLiteral(']'), .. }))
  assert_true(r.next_token() is Some({ token: Tag("foo/x"), .. }))
  assert_true(r.next_token() is Some({ token: Discard, .. }))
  assert_true(r.next_token() is Some({ token: SetOpen, .. }))
  assert_true(r.next_token() is None)
  for
    source in [
      "\"\\uD800\"", "\"\\uDC00\"", "\\uD800", "\\wat", "#", "#1x", "\"\\q\"",
    ] {
    let bad = try {
      let _ = Reader::new(source).next_token()
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=source)
  }
}
