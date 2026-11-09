///|
/// EDN values. Integer/BigInteger contain normalized decimal digits, Decimal
/// contains an exact decimal literal without its M suffix. Arrays are owned by
/// callers; use clone_value before exposing a separately editable value.
pub(all) enum Value {
  Nil
  Bool(Bool)
  Integer(String)
  BigInteger(String)
  Float(Double)
  Decimal(String)
  Text(String)
  Character(Char)
  Symbol(String)
  Keyword(String)
  List(Array[Value])
  Vector(Array[Value])
  Mapping(Array[(Value, Value)])
  Set(Array[Value])
  Tagged(String, Value)
}

///|
pub(all) suberror EdnError {
  Syntax(Int32, String)
  Limit(String)
  Invalid(String)
  PathError(String)
}

///|
/// Resource budgets apply to one document/operation, not process-global state.
pub(all) struct Limits {
  input : Int32
  depth : Int32
  nodes : Int32
  token : Int32
  container : Int32
}

///|
pub fn Limits::default() -> Limits {
  { input: 1000000, depth: 128, nodes: 100000, token: 65536, container: 10000, }
}

///|
pub fn Limits::validate(limits : Limits) -> Unit raise EdnError {
  if limits.input < 0 ||
    limits.depth < 1 ||
    limits.depth > 256 ||
    limits.nodes < 1 ||
    limits.token < 1 ||
    limits.container < 0 ||
    limits.container > 1000000000 {
    raise Invalid("invalid budgets; depth must be in 1..256")
  }
}

///|
pub fn Value::kind(self : Value) -> String {
  match self {
    Nil => "nil"
    Bool(_) => "boolean"
    Integer(_) => "integer"
    BigInteger(_) => "big-integer"
    Float(_) => "float"
    Decimal(_) => "decimal"
    Text(_) => "string"
    Character(_) => "character"
    Symbol(_) => "symbol"
    Keyword(_) => "keyword"
    List(_) => "list"
    Vector(_) => "vector"
    Mapping(_) => "map"
    Set(_) => "set"
    Tagged(_, _) => "tagged"
  }
}
