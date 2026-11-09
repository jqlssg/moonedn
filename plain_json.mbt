///|
fn plain_encode(
  value : Value,
  keyword_keys : Bool,
  work : Work,
  depth : Int32,
) -> Json raise EdnError {
  work.tick(depth)
  match value {
    Nil => Json::null()
    Bool(x) => Json::boolean(x)
    Text(x) => Json::string(x)
    Float(x) => {
      guard x >= -9007199254740991.0 && x <= 9007199254740991.0 else {
        raise Invalid("float outside interoperable JSON range")
      }
      Json::number(x)
    }
    Integer(x) => {
      let n = @string.parse_int64(x) catch { _ => raise Invalid("integer") }
      guard n >= -9007199254740991L && n <= 9007199254740991L else {
        raise Invalid("integer outside interoperable JSON range")
      }
      Json::number(n.to_double())
    }
    List(items) | Vector(items) =>
      Json::array(
        items.map(item => plain_encode(item, keyword_keys, work, depth + 1)),
      )
    Mapping(entries) => {
      let result : Map[String, Json] = Map([])
      for (key, item) in entries {
        let name = match key {
          Text(s) => s
          Keyword(s) => {
            guard keyword_keys else {
              raise Invalid("keyword keys need explicit projection")
            }
            s
          }
          _ => raise Invalid("plain JSON map keys must be strings")
        }
        guard !result.contains(name) else {
          raise Invalid("plain JSON key collision")
        }
        result[name] = plain_encode(item, keyword_keys, work, depth + 1)
      }
      Json::object(result)
    }
    _ =>
      raise Invalid(
        "EDN type has no safe plain JSON projection; use tagged JSON",
      )
  }
}

///|
/// Projects lists/vectors to arrays. Keyword map keys require explicit opt-in;
/// collisions, sets, tags, symbols, characters, big and exact decimals fail.
pub fn to_plain_json(
  value : Value,
  keyword_keys~ : Bool = false,
  limits~ : Limits = Limits::default(),
) -> Json raise EdnError {
  validate_value(value, limits~)
  let json = plain_encode(value, keyword_keys, Work::new(limits), 0)
  guard json.stringify().length() <= limits.input else {
    raise Limit("JSON output units")
  }
  json
}

///|
fn plain_decode(
  json : Json,
  work : Work,
  depth : Int32,
) -> Value raise EdnError {
  work.tick(depth)
  match json {
    Null => Nil
    True => Bool(true)
    False => Bool(false)
    String(s) => {
      check_text(s, work)
      Text(s)
    }
    Number(n, ..) => {
      guard !n.is_inf() && !n.is_nan() else {
        raise Invalid("non-finite JSON number")
      }
      guard n >= -9007199254740991.0 && n <= 9007199254740991.0 else {
        raise Invalid("JSON number outside interoperable range")
      }
      let integer = n.to_int64()
      if integer.to_double() == n {
        Integer(integer.to_string())
      } else {
        Float(n)
      }
    }
    Array(items) => {
      guard items.length() <= work.limits.container else {
        raise Limit("JSON collection")
      }
      Vector(items.map(item => plain_decode(item, work, depth + 1)))
    }
    Object(items) => {
      guard items.length() <= work.limits.container else {
        raise Limit("JSON map")
      }
      let keys = items.keys().to_array()
      keys.sort()
      let entries : Array[(Value, Value)] = []
      for key in keys {
        check_text(key, work)
        work.tick(depth + 1)
        guard items.get(key) is Some(item) else {
          raise Invalid("JSON object changed during traversal")
        }
        entries.push((Text(key), plain_decode(item, work, depth + 1)))
      }
      Mapping(entries)
    }
  }
}

///|
/// Imports a binary64 JSON DOM. Integral safe numbers become Integer, arrays
/// become Vector, object keys become Text. Exact source spelling is not retained.
pub fn from_plain_json(
  json : Json,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  plain_decode(json, Work::new(limits), 0)
}
