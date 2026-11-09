///|
test "post-order transform validates keys and detaches callback output" {
  let original = read("{:x [#app/env \"HOST\" #_#app/env \"SECRET\"]}")
  let mut calls = 0
  let result = resolve_tag(original, "app/env", value => {
    calls += 1
    guard value is Text("HOST") else { raise Invalid("unexpected lookup") }
    Text("localhost")
  })
  assert_eq(calls, 1)
  assert_eq(write(result), "{:x [\"localhost\"]}")
  assert_eq(write(original), "{:x [#app/env \"HOST\"]}")
  let bad = try {
    let _ = transform(read("#{1 2}"), node => {
      match node {
        Integer(_) => Integer("0")
        _ => node
      }
    })
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(bad)
  let external : Array[Value] = [Nil]
  let detached = transform(Nil, _ => Vector(external))
  external[0] = Bool(true)
  assert_eq(write(detached), "[nil]")
}
