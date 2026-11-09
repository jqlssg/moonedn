///|
fn chars_slice(xs : Array[Char], start : Int32, end : Int32) -> String {
  String::from_array(xs[start:end])
}

///|
/// Parses the EDN decimal grammar without routing large integers through Double.
pub fn parse_number(text : String) -> Value raise EdnError {
  let xs = text.to_array()
  guard xs.length() > 0 && xs.length() <= 65536 else {
    raise Invalid("empty or oversized number")
  }
  let mut end = xs.length()
  let suffix = if xs[end - 1] == 'N' || xs[end - 1] == 'M' {
    end -= 1
    xs[end]
  } else {
    ' '
  }
  let mut pos = 0
  let negative = if pos < end && (xs[pos] == '-' || xs[pos] == '+') {
    pos += 1
    xs[0] == '-'
  } else {
    false
  }
  let start = pos
  while pos < end && xs[pos].is_ascii_digit() {
    pos += 1
  }
  guard pos > start else { raise Invalid("number needs integer digits") }
  if pos - start > 1 && xs[start] == '0' {
    raise Invalid("leading zero in number")
  }
  let integer_end = pos
  let mut fractional = false
  if pos < end && xs[pos] == '.' {
    fractional = true
    pos += 1
    let fraction_start = pos
    while pos < end && xs[pos].is_ascii_digit() {
      pos += 1
    }
    guard pos > fraction_start else { raise Invalid("fraction needs digits") }
  }
  let mut exponent = false
  if pos < end && (xs[pos] == 'e' || xs[pos] == 'E') {
    exponent = true
    pos += 1
    if pos < end && (xs[pos] == '+' || xs[pos] == '-') {
      pos += 1
    }
    let exp_start = pos
    let mut exp_value = 0
    while pos < end && xs[pos].is_ascii_digit() {
      exp_value = exp_value * 10 + xs[pos].to_int() - 48
      guard exp_value <= 1000000 else {
        raise Limit("decimal exponent exceeds 1000000")
      }
      pos += 1
    }
    guard pos > exp_start else { raise Invalid("exponent needs digits") }
  }
  guard pos == end else { raise Invalid("unexpected number suffix") }
  let body = chars_slice(xs, 0, end)
  if suffix == 'N' {
    guard !fractional && !exponent else { raise Invalid("N requires integer") }
    let digits = chars_slice(xs, start, integer_end)
    return BigInteger(
      if negative && digits != "0" {
        "-" + digits
      } else {
        digits
      },
    )
  }
  if suffix == 'M' {
    return Decimal(body)
  }
  if fractional || exponent {
    let f = @string.parse_double(body) catch {
      _ => raise Invalid("invalid double")
    }
    guard !f.is_inf() && !f.is_nan() else { raise Invalid("nonfinite double") }
    return Float(f)
  }
  let number = @string.parse_int64(body) catch {
    _ => raise Invalid("integer exceeds signed 64-bit; use N")
  }
  Integer(number.to_string())
}

///|
/// Exact decimal magnitude: coefficient * 10^exponent, without expansion.
pub fn decimal_key(text : String) -> String raise EdnError {
  guard parse_number(text + "M") is Decimal(_) else {
    raise Invalid("not decimal")
  }
  let xs = text.to_array()
  let negative = xs[0] == '-'
  let mut pos = if xs[0] == '-' || xs[0] == '+' { 1 } else { 0 }
  let digits : Array[Char] = []
  let mut after_dot = false
  let mut scale = 0
  while pos < xs.length() && xs[pos] != 'e' && xs[pos] != 'E' {
    if xs[pos] == '.' {
      after_dot = true
    } else {
      digits.push(xs[pos])
      if after_dot {
        scale += 1
      }
    }
    pos += 1
  }
  let mut exponent = 0
  if pos < xs.length() {
    let s = chars_slice(xs, pos + 1, xs.length())
    exponent = @string.parse_int(s) catch {
      _ => raise Invalid("decimal exponent")
    }
  }
  exponent -= scale
  let mut first = 0
  let mut last = digits.length()
  while first < last && digits[first] == '0' {
    first += 1
  }
  if first == last {
    return "0e0"
  }
  while last > first && digits[last - 1] == '0' {
    last -= 1
    exponent += 1
  }
  (if negative { "-" } else { "" }) +
  chars_slice(digits, first, last) +
  "e" +
  exponent.to_string()
}
