import RP2040

struct Program {
  func run() {
    let board = RP2040()

    let led = Led(board: board, pin: .d22)
    var motor = Motor(board: board, in1: .d19, in2: .d18, pwmHz: 400)
    var servoL = Servo(board: board, pin: .d2)
    var servoR = Servo(board: board, pin: .d3)
    var btn14 = Button(board: board, pin: .d14)
    var btn15 = Button(board: board, pin: .d15)
    var irReceiver = IRReceiver(board: board, pin: .d13)

    var rollCmd = 0  // -100…+100
    var throttle = 0           // 0…100

    let stepPerFrame: Int = 12  // how fast command ramps while holding a button
    let autoCenterPerFrame: Int = 6  // how fast it recenters when no button is held

    led.blink(board, 3, onUS: 300_000, offUS: 150_000)

    var nextServoL: UInt64 = board.now
    var nextServoR: UInt64 = nextServoL
    var nextMotor: UInt64 = nextServoL

    while true {
      let now = board.now
      let lPressed = btn14.isPressed(board: board)
      let rPressed = btn15.isPressed(board: board)

      if lPressed && rPressed {
        throttle = (throttle + 5).clamp(lo: -100, hi: 100)   // ramp up; change sign to ramp down
        motor.setThrottle(throttle)
      } else if lPressed && !rPressed {
        rollCmd = (rollCmd - stepPerFrame).clamp(lo: -100, hi: 100)
      } else if rPressed && !lPressed {
        rollCmd = (rollCmd + stepPerFrame).clamp(lo: -100, hi: 100)
      } else {
        if rollCmd > 0 {
          rollCmd = max(0, rollCmd - autoCenterPerFrame)
        } else if rollCmd < 0 {
          rollCmd = min(0, rollCmd + autoCenterPerFrame)
        }
        throttle = 0
        motor.setThrottle(throttle)
      }

      if now >= nextServoL {
        let d = servoL.updateElevon(board: board, rollCmd: rollCmd, isLeft: true)
        nextServoL &+= UInt64(d)
      }
      if now >= nextServoR {
        let d = servoR.updateElevon(board: board, rollCmd: rollCmd, isLeft: false)
        nextServoR &+= UInt64(d)
      }
      if now >= nextMotor {
        let d = motor.service(board: board, nowUS: now)
        nextMotor &+= UInt64(d)
      }

      let next = min(nextMotor, min(nextServoL, nextServoR))
      if next > now { board.sleep(forMicroseconds: next - now) }
    }
  }
}
