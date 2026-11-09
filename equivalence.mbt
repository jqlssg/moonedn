///|
priv struct Work {
  limits : Limits
  mut visited : Int32
}

///|
fn Work::new(limits : Limits) -> Work raise EdnError {
  limits.validate()
  { limits, visited: 0, }
}

///|
fn Work::tick(self : Work, depth : Int32) -> Unit raise EdnError {
  guard depth <= self.limits.depth else { raise Limit("operation depth") }
  self.visited += 1
  guard self.visited <= self.limits.nodes else { raise Limit("operation work") }
}

///|
fn seq_equal(
  a : Array[Value],
  b : Array[Value],
  work : Work,
  depth : Int32,
) -> Bool raise EdnError {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !equal_inner(a[i], b[i], work, depth + 1) {
      return false
    }
  }
  true
}

///|
fn equal_inner(
  a : Value,
  b : Value,
  work : Work,
  depth : Int32,
) -> Bool raise EdnError {
  work.tick(depth)
  match (a, b) {
    (Nil, Nil) => true
    (Bool(x), Bool(y)) => x == y
    (Integer(x), Integer(y)) => x == y
    (BigInteger(x), BigInteger(y)) => x == y
    (Float(x), Float(y)) => x == y
    (Decimal(x), Decimal(y)) => decimal_key(x) == decimal_key(y)
    (Text(x), Text(y)) => x == y
    (Character(x), Character(y)) => x == y
    (Symbol(x), Symbol(y)) => x == y
    (Keyword(x), Keyword(y)) => x == y
    (List(x), List(y))
    | (List(x), Vector(y))
    | (Vector(x), List(y))
    | (Vector(x), Vector(y)) => seq_equal(x, y, work, depth)
    (Mapping(x), Mapping(y)) => {
      if x.length() != y.length() {
        return false
      }
      for (key, value) in x {
        let mut found = false
        for (other, target) in y {
          if equal_inner(key, other, work, depth + 1) {
            if !equal_inner(value, target, work, depth + 1) {
              return false
            }
            found = true
            break
          }
        }
        if !found {
          return false
        }
      }
      true
    }
    (Set(x), Set(y)) => {
      if x.length() != y.length() {
        return false
      }
      for item in x {
        let mut found = false
        for other in y {
          if equal_inner(item, other, work, depth + 1) {
            found = true
            break
          }
        }
        if !found {
          return false
        }
      }
      true
    }
    (Tagged(x, v), Tagged(y, w)) => {
      if x != y {
        return false
      }
      match (x, v, w) {
        ("inst", Text(s), Text(t)) => instant_key(s) == instant_key(t)
        ("uuid", Text(s), Text(t)) => uuid_key(s) == uuid_key(t)
        _ => equal_inner(v, w, work, depth + 1)
      }
    }
    _ => false
  }
}

///|
/// EDN collection equality ignores map/set order and treats lists as sequences.
/// Numeric precision is significant: 1, 1N, 1.0 and 1M are distinct categories.
/// The work budget bounds quadratic comparisons for arbitrary collection keys.
pub fn equivalent(
  a : Value,
  b : Value,
  limits~ : Limits = Limits::default(),
) -> Bool raise EdnError {
  equal_inner(a, b, Work::new(limits), 0)
}
