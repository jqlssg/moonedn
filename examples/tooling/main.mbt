///|
fn main raise {
  let reader = @edn.Reader::new(
    "; events\n#app/event {:kind :start :seq 1}\n#_[:ignored] #app/event {:kind :stop :seq 2}",
  )
  let mut count = 0
  while reader.read_next() is Some(event) {
    let payload = @edn.resolve_tag(event, "app/event", value => value)
    let stats = @edn.inspect_value(payload)
    assert_eq(stats.map_entries, 2)
    println(@edn.pretty(payload))
    count += 1
  }
  assert_eq(count, 2)
  let invalid = "{:x [1 2}"
  try {
    let _ = @edn.read(invalid)
  } catch {
    error => {
      let diagnostic = @edn.diagnose(invalid, error)
      assert_eq(diagnostic.line, Some(1))
      println(diagnostic.message)
    }
  }
  println("events=" + count.to_string())
}
