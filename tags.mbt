///|
fn decimal_digits(
  xs : Array[Char],
  start : Int32,
  end : Int32,
) -> Int32 raise EdnError {
  guard start < end && end <= xs.length() else {
    raise Invalid("date field length")
  }
  let mut result = 0
  for i in start..<end {
    guard xs[i].is_ascii_digit() else { raise Invalid("date field digits") }
    result = result * 10 + xs[i].to_int() - 48
  }
  result
}

///|
fn leap_year(year : Int32) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
/// Validates the supported RFC3339 profile and returns exact epoch seconds plus
/// a fractional digit string. Leap seconds and unknown -00:00 offsets are rejected.
pub fn instant_key(text : String) -> (Int64, String) raise EdnError {
  let xs = text.to_array()
  guard xs.length() >= 20 && xs.length() <= 65536 else {
    raise Invalid("instant length")
  }
  guard xs[4] == '-' &&
    xs[7] == '-' &&
    (xs[10] == 'T' || xs[10] == 't') &&
    xs[13] == ':' &&
    xs[16] == ':' else {
    raise Invalid("instant requires RFC3339 date and time")
  }
  let year = decimal_digits(xs, 0, 4)
  let month = decimal_digits(xs, 5, 7)
  let day = decimal_digits(xs, 8, 10)
  let hour = decimal_digits(xs, 11, 13)
  let minute = decimal_digits(xs, 14, 16)
  let second = decimal_digits(xs, 17, 19)
  guard year >= 1 &&
    month >= 1 &&
    month <= 12 &&
    hour < 24 &&
    minute < 60 &&
    second < 60 else {
    raise Invalid("instant field range; leap seconds unsupported")
  }
  let month_days = [
    31,
    if leap_year(year) {
      29
    } else {
      28
    },
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ]
  guard day >= 1 && day <= month_days[month - 1] else {
    raise Invalid("invalid calendar day")
  }
  let mut pos = 19
  let mut fraction = ""
  if xs[pos] == '.' {
    pos += 1
    let start = pos
    while pos < xs.length() && xs[pos].is_ascii_digit() {
      pos += 1
    }
    guard pos > start else { raise Invalid("instant fraction needs digits") }
    let mut last = pos
    while last > start && xs[last - 1] == '0' {
      last -= 1
    }
    fraction = chars_slice(xs, start, last)
  }
  guard pos < xs.length() else { raise Invalid("instant timezone required") }
  let offset = if xs[pos] == 'Z' || xs[pos] == 'z' {
    guard pos + 1 == xs.length() else { raise Invalid("trailing instant text") }
    0
  } else {
    guard (xs[pos] == '+' || xs[pos] == '-') &&
      pos + 6 == xs.length() &&
      xs[pos + 3] == ':' else {
      raise Invalid("invalid instant timezone")
    }
    let h = decimal_digits(xs, pos + 1, pos + 3)
    let m = decimal_digits(xs, pos + 4, pos + 6)
    guard h < 24 && m < 60 else { raise Invalid("timezone range") }
    guard xs[pos] != '-' || h != 0 || m != 0 else {
      raise Invalid("unknown local offset -00:00 unsupported")
    }
    (h * 60 + m) * (if xs[pos] == '-' { -1 } else { 1 })
  }
  let y = year - 1
  let mut days = y * 365 + y / 4 - y / 100 + y / 400
  for i in 0..<(month - 1) {
    days += month_days[i]
  }
  days += day - 1
  let seconds = (days - 719162).to_int64() * 86400L +
    (hour * 3600 + minute * 60 + second - offset * 60).to_int64()
  (seconds, fraction)
}

///|
pub fn uuid_key(text : String) -> String raise EdnError {
  let xs = text.to_array()
  guard xs.length() == 36 else { raise Invalid("UUID must have 36 characters") }
  let out = StringBuilder()
  for i in 0..<36 {
    let c = xs[i]
    if i == 8 || i == 13 || i == 18 || i == 23 {
      guard c == '-' else { raise Invalid("UUID separator") }
      out.write_char(c)
    } else {
      guard c.is_ascii_digit() ||
        (c >= 'a' && c <= 'f') ||
        (c >= 'A' && c <= 'F') else {
        raise Invalid("UUID hexadecimal digit")
      }
      out.write_char(
        if c >= 'A' && c <= 'F' {
          (c.to_int() + 32).unsafe_to_char()
        } else {
          c
        },
      )
    }
  }
  out.to_string()
}

///|
fn validate_tag(name : String, value : Value) -> Unit raise EdnError {
  guard valid_tag(name) else { raise Invalid("invalid tag name") }
  if name == "uuid" {
    guard value is Text(text) else { raise Invalid("uuid tag requires string") }
    let _ = uuid_key(text)
  } else if name == "inst" {
    guard value is Text(text) else { raise Invalid("inst tag requires string") }
    let _ = instant_key(text)
  }
}
