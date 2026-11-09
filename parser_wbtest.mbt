///|
test "collections tags discards and stream reading" {
  let v = read(
    "{:a [1 #_2 3], (true nil) #{:x :y}, :tag #app/Thing {:ok true}}",
  )
  assert_true(v is Mapping(p) && p.length() == 3)
  assert_eq(read_all("#_1 2 #_#_3 4 5").length(), 2)
  assert_true(read("#_0 [#_1]") is Vector(a) && a.is_empty())
  assert_true(read("(1 2)") is List(_))
  for
    source in [
      "", "1 2", "[1}", "[", "{:a}", "#{1 1}", "{[1] :a (1) :b}", "#tag", "#_", "#_1",
      "::x", "01",
    ] {
    let bad = try {
      let _ = read(source)
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=source)
  }
}

///|
test "reader budgets and failure state" {
  let r = Reader::new("1 2 3", limits={ ..Limits::default(), nodes: 2, })
  assert_true(r.read_next() is Some(Integer("1")))
  assert_true(r.read_next() is Some(Integer("2")))
  let bad = try {
    let _ = r.read_next()
    false
  } catch {
    _ => true
  }
  assert_true(bad)
  let poisoned = try {
    let _ = r.read_next()
    false
  } catch {
    Invalid(_) => true
    _ => false
  }
  assert_true(poisoned)
  for source in ["[[[[1]]]]", "#_#_#_#_1 2 3 4"] {
    let bad = try {
      let _ = read(source, limits={ ..Limits::default(), depth: 2, })
      false
    } catch {
      Limit(_) => true
      _ => false
    }
    assert_true(bad, msg=source)
  }
}
