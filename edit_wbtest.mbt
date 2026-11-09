///|
test "atomic edits leave inputs unchanged" {
  let source = read("{:hosts [\"a\" \"b\"] :port 8080}")
  let result = transact(source, [
    Check([Key(Keyword("port"))], Integer("8080")),
    Replace([Key(Keyword("port"))], Integer("9090")),
    Insert([Key(Keyword("hosts"))], 1, Text("new")),
    Remove([Key(Keyword("hosts")), Index(0)]),
    Put([], Keyword("enabled"), Bool(true)),
  ])
  assert_eq(write(result), "{:hosts [\"new\" \"b\"] :port 9090 :enabled true}")
  assert_eq(write(source), "{:hosts [\"a\" \"b\"] :port 8080}")
  let before = write(source)
  let failed = try {
    let _ = transact(source, [
      Replace([Key(Keyword("port"))], Nil),
      Remove([Key(Keyword("missing"))]),
    ])
    false
  } catch {
    PathError(_) => true
    _ => false
  }
  assert_true(failed)
  assert_eq(write(source), before)
  let collision = try {
    let _ = transact(read("#{[1] [2]}"), [
      Replace([], Set([Integer("1"), Integer("1")])),
    ])
    false
  } catch {
    _ => true
  }
  assert_true(collision)
}
