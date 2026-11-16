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
// UTC transitions from IERS Bulletin C 72 (July 2026), Leap_Second.dat.
// A positive event inserts :60 immediately before this ordinary UTC second.
// Keep changes and the independent IERS comparison in tools in sync.
fn utc_leap_adjustment(boundary : Int64) -> Int32 {
  let transitions : Array[(Int64, Int32)] = [
    (78796800L, 1),
    (94694400L, 1),
    (126230400L, 1),
    (157766400L, 1),
    (189302400L, 1),
    (220924800L, 1),
    (252460800L, 1),
    (283996800L, 1),
    (315532800L, 1),
    (362793600L, 1),
    (394329600L, 1),
    (425865600L, 1),
    (489024000L, 1),
    (567993600L, 1),
    (631152000L, 1),
    (662688000L, 1),
    (709948800L, 1),
    (741484800L, 1),
    (773020800L, 1),
    (820454400L, 1),
    (867715200L, 1),
    (915148800L, 1),
    (1136073600L, 1),
    (1230768000L, 1),
    (1341100800L, 1),
    (1435708800L, 1),
    (1483228800L, 1),
  ]
  for event in transitions {
    if event.0 == boundary {
      return event.1
    }
  }
  0
}

///|
/// Exact equality key for RFC3339 timestamps, not an elapsed-time API.
/// Ordinary seconds retain their POSIX second and trimmed fractional digits.
/// A leap second uses the preceding POSIX second and "leap:" + fraction, so it
/// never aliases either adjacent ordinary second. The original tagged string
/// retains offset metadata, including the unknown-local-offset marker -00:00.
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
  guard month >= 1 && month <= 12 && hour < 24 && minute < 60 && second <= 60 else {
    raise Invalid("instant field range")
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
    (h * 60 + m) * (if xs[pos] == '-' { -1 } else { 1 })
  }
  // Count days from 0000-01-01 with nonnegative divisions (year 0000 is leap).
  let mut days = year * 365 +
    (year + 3) / 4 -
    (year + 99) / 100 +
    (year + 399) / 400
  for i in 0..<(month - 1) {
    days += month_days[i]
  }
  days += day - 1
  let seconds = (days - 719528).to_int64() * 86400L +
    (hour * 3600 +
    minute * 60 +
    (if second == 60 { 59 } else { second }) -
    offset * 60).to_int64()
  adjusted_instant_key(
    seconds,
    fraction,
    second,
    utc_leap_adjustment(seconds + 1L),
  )
}

///|
// Kept separate so negative-leap rules can be tested without inventing a UTC event.
fn adjusted_instant_key(
  seconds : Int64,
  fraction : String,
  second : Int32,
  adjustment : Int32,
) -> (Int64, String) raise EdnError {
  if second == 60 {
    guard adjustment == 1 else {
      raise Invalid("second 60 requires an announced UTC leap second")
    }
    (seconds, "leap:" + fraction)
  } else {
    guard second != 59 || adjustment != -1 else {
      raise Invalid("second omitted by a negative UTC leap second")
    }
    (seconds, fraction)
  }
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
