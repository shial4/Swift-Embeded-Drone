import RP2040

struct Program {
  func run() {
    let board = RP2040()

    let led = Led(board: board, pin: .d22)
    var motor = Motor(board: board, in1: .d19, in2: .d18, pwmHz: 400)
    var servoL = Servo(board: board, pin: .d2)
    var servoR = Servo(board: board, pin: .d3)
    // var btn14 = Button(board: board, pin: .d14)
    // var btn15 = Button(board: board, pin: .d15)
    var irReceiver = IRReceiver(board: board, pin: .d13)

    var rollCmd = 0      // -100…+100
    var throttleCmd = 20  // 0…100
    var engineEnabled = false

    let stepPerFrame: Int = 12  // how fast command ramps while holding a button
    let autoCenterPerFrame: Int = 6  // how fast it recenters when no button is held

    led.blink(board, 3, onUS: 300_000, offUS: 150_000)

    var nextServoL: UInt64 = board.now
    var nextServoR: UInt64 = nextServoL
    var nextMotor: UInt64 = nextServoL

    while true {
      let now = board.now
      // let lPressed = btn14.isPressed(board: board)
      // let rPressed = btn15.isPressed(board: board)

      // if lPressed && rPressed {
      //   if !engineEnabled { engineEnabled = true }
      //   throttleCmd = (throttleCmd + 5).clamp(lo: 0, hi: 100)
      // } else if lPressed && !rPressed {
      //   rollCmd = (rollCmd - stepPerFrame).clamp(lo: -100, hi: 100)
      //   hadRollInput = true
      // } else if rPressed && !lPressed {
      //   rollCmd = (rollCmd + stepPerFrame).clamp(lo: -100, hi: 100)
      //   hadRollInput = true
      // }

      if let action = irReceiver.poll(board: board) {
        switch action {
        case .powerToggle:
          engineEnabled.toggle()
          if !engineEnabled {
            throttleCmd = 0
            motor.setThrottle(0)
          } else {
            throttleCmd = 20
            motor.setThrottle(20)
          }
        case .volumeUp:
          throttleCmd = (throttleCmd + 5).clamp(lo: 0, hi: 100)
        case .volumeDown:
          throttleCmd = (throttleCmd - 5).clamp(lo: 0, hi: 100)
        case .rollLeft:
          rollCmd = (rollCmd - stepPerFrame).clamp(lo: -100, hi: 100)
        case .rollRight:
          rollCmd = (rollCmd + stepPerFrame).clamp(lo: -100, hi: 100)
        case .noseUp:
          break
        case .noseDown:
          break
        case .select, .numeric, .raw:
          break
        }
      }

      let appliedThrottle = engineEnabled ? throttleCmd : 0
      motor.setThrottle(appliedThrottle)
      if !engineEnabled { throttleCmd = 0 }

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
