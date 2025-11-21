import RP2040

/// L9110S: two inputs per motor (IN1/IN2). 
/// Forward:  IN1=HIGH, IN2=LOW
/// Reverse:  IN1=LOW,  IN2=HIGH
/// Coast:    IN1=LOW,  IN2=LOW
/// Brake:    IN1=HIGH, IN2=HIGH  (optional; we use coast when PWM is off)
struct Motor<IN1: DigitalPin, IN2: DigitalPin> {
  let in1: IN1
  let in2: IN2
  let pwmHz: Int

  private let periodUS: Int
  private var dutyUS: Int = 0              // 0…periodUS
  private var forward = true
  private var highPhase = false            // are we in the HIGH (drive) portion?

  init(board: RP2040, in1: IN1, in2: IN2, pwmHz: Int = 1000) {
    self.in1 = in1
    self.in2 = in2
    self.pwmHz = pwmHz
    self.periodUS = 1_000_000 / pwmHz
    board.setMode(.output, pin: in1)
    board.setMode(.output, pin: in2)
    // idle coast
    board.digitalWrite(pin: in1, false)
    board.digitalWrite(pin: in2, false)
    setThrottle(0)
  }

  /// -100…100: sign = direction, magnitude = duty
  mutating func setThrottle(_ percent: Int) {
    let p = percent < -100 ? -100 : (percent > 100 ? 100 : percent)
    forward = (p >= 0)
    let mag = p < 0 ? -p : p
    dutyUS = periodUS * mag / 100
    // If we hit 0% while in drive phase, next service() will drop to coast.
  }

  /// Non-blocking. Flips outputs and returns **delta µs** until next call.
  mutating func service(board: RP2040, nowUS: UInt64) -> UInt32 {
    // 0% → coast whole period
    if dutyUS == 0 {
      if highPhase {
        // ensure we’re not driving
        board.digitalWrite(pin: in1, false)
        board.digitalWrite(pin: in2, false)
        highPhase = false
      }
      return UInt32(periodUS)
    }

    // 100% → drive constantly in chosen direction, schedule next period
    if dutyUS >= periodUS {
      if forward {
        board.digitalWrite(pin: in1, true)
        board.digitalWrite(pin: in2, false)
      } else {
        board.digitalWrite(pin: in1, false)
        board.digitalWrite(pin: in2, true)
      }
      highPhase = true
      return UInt32(periodUS)
    }

    // Normal PWM: drive for duty, then coast for remainder (quiet, safe)
    if !highPhase {
      // HIGH (drive) phase
      if forward {
        board.digitalWrite(pin: in1, true)
        board.digitalWrite(pin: in2, false)
      } else {
        board.digitalWrite(pin: in1, false)
        board.digitalWrite(pin: in2, true)
      }
      highPhase = true
      return UInt32(dutyUS)
    } else {
      // LOW (coast) phase
      board.digitalWrite(pin: in1, false)
      board.digitalWrite(pin: in2, false)
      highPhase = false
      let off = periodUS - dutyUS
      return UInt32(off > 0 ? off : 1)
    }
  }
}
