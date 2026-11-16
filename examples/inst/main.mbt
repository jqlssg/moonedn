///|
fn main raise {
  let utc = @edn.read("#inst \"1990-12-31T23:59:60Z\"")
  let shifted = @edn.read("#inst \"1990-12-31T15:59:60-08:00\"")
  assert_true(@edn.equivalent(utc, shifted))
  assert_false(
    @edn.equivalent(utc, @edn.read("#inst \"1991-01-01T00:00:00Z\"")),
  )
  let unknown = @edn.read("#inst \"2000-01-01T00:00:00-00:00\"")
  let transported = @edn.from_tagged_json(@edn.to_tagged_json(unknown))
  assert_eq(@edn.write(transported), @edn.write(unknown))
  assert_true(
    @edn.equivalent(unknown, @edn.read("#inst \"2000-01-01T00:00:00Z\"")),
  )
  let zero = @edn.read("#inst \"0000-02-29t00:00:00z\"")
  assert_eq(@edn.write(zero), "#inst \"0000-02-29t00:00:00z\"")
  println(@edn.write(utc))
  println(@edn.write(transported))
  println(@edn.write(zero))
}
