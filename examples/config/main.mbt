///|
fn main raise {
  let config = @edn.read(
    "{:service {:host \"localhost\" :port 8080} :features [:reader :writer]}",
  )
  let changed = @edn.transact(config, [
    @edn.Check(
      [@edn.Key(@edn.Keyword("service")), @edn.Key(@edn.Keyword("port"))],
      @edn.Integer("8080"),
    ),
    @edn.Replace(
      [@edn.Key(@edn.Keyword("service")), @edn.Key(@edn.Keyword("port"))],
      @edn.Integer("9090"),
    ),
    @edn.Insert(
      [@edn.Key(@edn.Keyword("features"))],
      2,
      @edn.Keyword("editing"),
    ),
  ])
  let port = @edn.require_at(changed, [
    @edn.Key(@edn.Keyword("service")),
    @edn.Key(@edn.Keyword("port")),
  ])
  assert_true(port is @edn.Integer("9090"))
  assert_true(
    @edn.require_at(config, [
      @edn.Key(@edn.Keyword("service")),
      @edn.Key(@edn.Keyword("port")),
    ])
    is @edn.Integer("8080"),
  )
  println(@edn.pretty(changed, layout={ width: 40, indent: 2, }))
}
