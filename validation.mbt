///|
fn check_text(text : String, work : Work) -> Unit raise EdnError {
  guard text.length() <= work.limits.token else {
    raise Limit("value text length")
  }
  work.units += text.length()
  guard work.units <= work.limits.input else {
    raise Limit("aggregate text units")
  }
}

///|
fn clone_inner(
  value : Value,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  work.tick(depth)
  match value {
    Nil | Bool(_) | Character(_) => value
    Float(x) => {
      guard !x.is_inf() && !x.is_nan() else {
        raise Invalid("non-finite float")
      }
      value
    }
    Text(s) => {
      check_text(s, work)
      value
    }
    Integer(s) => {
      check_text(s, work)
      guard parse_number(s) is Integer(t) && s == t else {
        raise Invalid("integer must be normalized signed 64-bit digits")
      }
      value
    }
    BigInteger(s) => {
      check_text(s, work)
      guard parse_number(s + "N") is BigInteger(t) && s == t else {
        raise Invalid("big integer must be normalized digits")
      }
      value
    }
    Decimal(s) => {
      check_text(s, work)
      guard parse_number(s + "M") is Decimal(_) else {
        raise Invalid("decimal literal")
      }
      value
    }
    Symbol(s) => {
      check_text(s, work)
      guard parse_atom(s) is Symbol(_) else {
        raise Invalid("reserved or numeric symbol")
      }
      value
    }
    Keyword(s) => {
      check_text(s, work)
      guard s != "/" && valid_symbol(s) else {
        raise Invalid("invalid keyword")
      }
      value
    }
    Tagged(name, child) => {
      check_text(name, work)
      validate_tag(name, child)
      Tagged(name, clone_inner(child, work, depth + 1))
    }
    List(items) | Vector(items) | Set(items) => {
      guard items.length() <= work.limits.container else {
        raise Limit("collection length")
      }
      let result : Array[Value] = []
      for item in items {
        result.push(clone_inner(item, work, depth + 1))
      }
      match value {
        List(_) => List(result)
        Vector(_) => Vector(result)
        _ => {
          for i in 0..<result.length() {
            for j in 0..<i {
              guard !equal_inner(result[i], result[j], work, depth + 1) else {
                raise Invalid("duplicate set element")
              }
            }
          }
          Set(result)
        }
      }
    }
    Mapping(entries) => {
      guard entries.length() <= work.limits.container else {
        raise Limit("map length")
      }
      let result : Array[(Value, Value)] = []
      for (key, item) in entries {
        let key = clone_inner(key, work, depth + 1)
        let item = clone_inner(item, work, depth + 1)
        for (old, _) in result {
          guard !equal_inner(key, old, work, depth + 1) else {
            raise Invalid("duplicate map key")
          }
        }
        result.push((key, item))
      }
      Mapping(result)
    }
  }
}

///|
/// Validates manually constructed values; rejects cycles through the depth
/// budget. The returned value has independent arrays at every nesting level.
pub fn clone_value(
  value : Value,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  clone_inner(value, Work::new(limits), 0)
}

///|
pub fn validate_value(
  value : Value,
  limits~ : Limits = Limits::default(),
) -> Unit raise EdnError {
  let _ = clone_value(value, limits~)
}
