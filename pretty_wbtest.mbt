///|
test "pretty layout preserves data and is stable" {
  let value = read(
    "{:server {:host \"localhost\" :port 8080} :features [:reader :writer :editing]}",
  )
  let formatted = pretty(value, layout={ width: 24, indent: 2, })
  assert_true(formatted.contains("\n"))
  assert_true(equivalent(value, read(formatted)))
  assert_eq(
    pretty(read(formatted), layout={ width: 24, indent: 2, }),
    formatted,
  )
  assert_eq(pretty(read("[1 2]")), "[1 2]")
}
