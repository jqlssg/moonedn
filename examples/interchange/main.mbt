///|
fn main raise {
  let message = @edn.read(
    "{:id 123456789012345678901234567890N :amount 12.3400M :route (service/send) [1 2] #app/result #{:ok :cached}}",
  )
  let transport = @edn.to_tagged_json(message)
  let restored = @edn.from_tagged_json(transport)
  assert_eq(@edn.write(restored), @edn.write(message))
  println(transport.stringify())
  println(@edn.write(restored, canonical=true))
  let ordinary = @edn.to_plain_json(
    @edn.read("{:status \"ok\" :retries 3}"),
    keyword_keys=true,
  )
  println(ordinary.stringify())
}
