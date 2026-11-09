///|
test "2000 numeric tree round trips across text JSON and identity edits" {
  for i in 0..<2000 {
    let value : Value = Mapping([
      (Keyword("n"), Integer((i - 1000).to_string())),
      (
        Vector([Integer(i.to_string())]),
        List([
          Float(i.to_double() / 7.0),
          Decimal(i.to_string() + ".2300"),
          BigInteger((i + 1).to_string() + "00000000000000000000"),
          Character('🙂'),
        ]),
      ),
    ])
    assert_true(equivalent(value, read(write(value))), msg=i.to_string())
    assert_eq(write(from_tagged_json(to_tagged_json(value))), write(value))
    assert_eq(write(transact(value, [])), write(value))
  }
}

///|
test "malformed forms and unsupported Clojure reader macros" {
  for
    s in [
      "+01", "0x10", "1/2", "2r10", "1.", ".2", "1e", "1e+", "1e1000001M", "1.2N",
      "NaN", "##Inf", "'x", "@x", "^meta x", "~x", "`x", "#\"regex\"", "#:ns{:x 1}",
      "#?x", "{:a 1 :a 2}", "#{[1] (1)}", "#_#_", "[\\ ]", "[\\u00gg]", "[1", "{1 2 3}",
    ] {
    // NaN is a legal symbol; it is never interpreted as a non-finite number.
    if s == "NaN" {
      assert_true(read(s) is Symbol("NaN"))
      continue
    }
    let bad = try {
      let _ = read(s)
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=s)
  }
}

///|
test "every input budget is enforced at the public entrypoint" {
  let base = Limits::default()
  for
    (source, limits) in [
      ("[1 2]", { ..base, container: 1, }),
      ("\"abcdef\"", { ..base, token: 4, }),
      ("[1 2]", { ..base, nodes: 2, }),
      ("[1]", { ..base, input: 2, }),
      ("[[1]]", { ..base, depth: 1, }),
      ("[#_1 #_2 #_3]", { ..base, nodes: 3, }),
    ] {
    let bad = try {
      let _ = read(source, limits~)
      false
    } catch {
      Limit(_) => true
      _ => false
    }
    assert_true(bad, msg=source)
  }
  for
    s in [
      "{#inst \"2000-01-01T00:00:00Z\" 1 #inst \"2000-01-01T01:00:00+01:00\" 2}",
      "#{1.0M 1.00M}",
    ] {
    let bad = try {
      let _ = read(s)
      false
    } catch {
      _ => true
    }
    assert_true(bad, msg=s)
  }
}
