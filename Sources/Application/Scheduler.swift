
struct Scheduler {
  var nextDueUS: UInt64 = 0
  let run: (_ nowUS: UInt64) -> UInt64
}