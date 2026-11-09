///|
fn json_pair(kind : String, payload : Json) -> Json {
  Json::array([Json::string(kind), payload])
}

///|
fn encode_json(
  value : Value,
  work : Work,
  depth : Int32,
) -> Json raise EdnError {
  work.tick(depth)
  match value {
    Nil => Json::array([Json::string("nil")])
    Bool(x) => json_pair("boolean", Json::boolean(x))
    Integer(x) => json_pair("integer", Json::string(x))
    BigInteger(x) => json_pair("big-integer", Json::string(x))
    Decimal(x) => json_pair("decimal", Json::string(x))
    Float(x) => json_pair("float", Json::string(float_text(x)))
    Text(x) => json_pair("string", Json::string(x))
    Character(x) => json_pair("character", Json::string(x.to_string()))
    Symbol(x) => json_pair("symbol", Json::string(x))
    Keyword(x) => json_pair("keyword", Json::string(x))
    List(items) | Vector(items) | Set(items) =>
      json_pair(
        value.kind(),
        Json::array(items.map(item => encode_json(item, work, depth + 1))),
      )
    Mapping(entries) =>
      json_pair(
        "map",
        Json::array(
          entries.map(entry => {
            let (key, item) = entry
            Json::array([
              encode_json(key, work, depth + 1),
              encode_json(item, work, depth + 1),
            ])
          }),
        ),
      )
    Tagged(name, child) =>
      Json::array([
        Json::string("tagged"),
        Json::string(name),
        encode_json(child, work, depth + 1),
      ])
  }
}

///|
fn json_string(json : Json) -> String raise EdnError {
  guard json is Json::String(s) else {
    raise Invalid("tagged JSON string required")
  }
  s
}

///|
fn json_array(json : Json) -> Array[Json] raise EdnError {
  guard json is Json::Array(items) else {
    raise Invalid("tagged JSON array required")
  }
  items
}

///|
fn decode_json(json : Json, work : Work, depth : Int32) -> Value raise EdnError {
  work.tick(depth)
  let xs = json_array(json)
  guard !xs.is_empty() else { raise Invalid("empty tagged JSON node") }
  let kind = json_string(xs[0])
  if kind == "nil" {
    guard xs.length() == 1 else { raise Invalid("nil JSON arity") }
    return Nil
  }
  if kind == "tagged" {
    guard xs.length() == 3 else { raise Invalid("tagged JSON arity") }
    return Tagged(json_string(xs[1]), decode_json(xs[2], work, depth + 1))
  }
  guard xs.length() == 2 else { raise Invalid("tagged JSON arity") }
  let payload = xs[1]
  match kind {
    "boolean" => {
      guard payload is Json::True || payload is Json::False else {
        raise Invalid("boolean JSON payload")
      }
      Bool(payload is Json::True)
    }
    "integer" => Integer(json_string(payload))
    "big-integer" => BigInteger(json_string(payload))
    "decimal" => Decimal(json_string(payload))
    "float" => {
      let v = parse_number(json_string(payload))
      guard v is Float(_) else {
        raise Invalid("float JSON payload must have floating grammar")
      }
      v
    }
    "string" => Text(json_string(payload))
    "symbol" => Symbol(json_string(payload))
    "keyword" => Keyword(json_string(payload))
    "character" => {
      let chars = json_string(payload).to_array()
      guard chars.length() == 1 else {
        raise Invalid("character JSON payload requires one scalar")
      }
      Character(chars[0])
    }
    "list" | "vector" | "set" => {
      let items = json_array(payload)
      guard items.length() <= work.limits.container else {
        raise Limit("JSON collection")
      }
      let values = items.map(item => decode_json(item, work, depth + 1))
      match kind {
        "list" => List(values)
        "vector" => Vector(values)
        _ => Set(values)
      }
    }
    "map" => {
      let entries = json_array(payload)
      guard entries.length() <= work.limits.container else {
        raise Limit("JSON map")
      }
      Mapping(
        entries.map(entry => {
          let pair = json_array(entry)
          guard pair.length() == 2 else {
            raise Invalid("JSON map entry arity")
          }
          (
            decode_json(pair[0], work, depth + 1),
            decode_json(pair[1], work, depth + 1),
          )
        }),
      )
    }
    _ => raise Invalid("unknown tagged JSON kind")
  }
}

///|
/// Lossless v1 transport: [kind,payload], with string-valued numbers, pair maps,
/// explicit list/vector kinds, and ["tagged",name,child] for extension elements.
pub fn to_tagged_json(
  value : Value,
  limits~ : Limits = Limits::default(),
) -> Json raise EdnError {
  validate_value(value, limits~)
  let json = encode_json(value, Work::new(limits), 0)
  guard json.stringify().length() <= limits.input else {
    raise Limit("JSON output units")
  }
  json
}

///|
pub fn from_tagged_json(
  json : Json,
  limits~ : Limits = Limits::default(),
) -> Value raise EdnError {
  let value = decode_json(json, Work::new(limits), 0)
  validate_value(value, limits~)
  value
}
