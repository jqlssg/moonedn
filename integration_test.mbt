///|
test "public application workflows" {
  let config = @moonedn.read("{:env #app/env \"HOST\" :port 8080}")
  let resolved = @moonedn.resolve_tag(config, "app/env", v => {
    match v {
      @moonedn.Text("HOST") => @moonedn.Text("localhost")
      _ => raise @moonedn.Invalid("unknown environment key")
    }
  })
  let updated = @moonedn.transact(resolved, [
    @moonedn.Put([], @moonedn.Keyword("port"), @moonedn.Integer("9090")),
  ])
  assert_eq(@moonedn.write(updated), "{:env \"localhost\" :port 9090}")
  assert_true(
    @moonedn.equivalent(
      updated,
      @moonedn.from_tagged_json(@moonedn.to_tagged_json(updated)),
    ),
  )
}
