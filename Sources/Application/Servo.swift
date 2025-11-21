import RP2040

struct Servo<Pin: DigitalPin> {
  let pin: Pin

  // SG90 tuning (drop-in)
  private let frameUS = 20_000  // 50 Hz
  private let minUS          = 600      // many SG90s don’t like <600
  private let maxUS          = 2400     // try 2500 only if no buzz/stall
  private let rollMaxDeg     = 70       // commanded max (pilot input)
  private let hardLimit   = 85       // absolute clamp; protects horns/links
  private let slewDegPerSec  = 360      // ~1.0s for 0→360°, ~0.5s for 0→180°
  private let slewPerFrame   = 7  // ≈7 deg/frame @50 fps
  
  private var pinHigh = false
  private var position = 0  // current position in degrees

  init(board: RP2040, pin: Pin) {
    self.pin = pin
    board.setMode(.output, pin: pin)
    board.digitalWrite(pin: pin, false)
  }

  private func surfaceTarget(
    isLeft: Bool, 
    rollCmd: Int, 
    rollMaxDeg: Int, 
    trimL: Int = 0, 
    trimR: Int = 0, 
    hardLimit: Int 
    ) -> Int { 
      let deg = (isLeft ? rollCmd : -rollCmd) * rollMaxDeg / 100 
      let withTrim = deg + (isLeft ? trimL : trimR) 
      return withTrim.clamp(lo: -hardLimit, hi: hardLimit) 
    }

  /// Non-blocking: toggle pin edge and return **delta µs** until next call.
  mutating func updateElevon(board: RP2040, rollCmd: Int, isLeft: Bool) -> Int {
    let target = surfaceTarget(
      isLeft: isLeft, 
      rollCmd: rollCmd, 
      rollMaxDeg: rollMaxDeg, 
      trimL: 0, 
      trimR: 0, 
      hardLimit: hardLimit
      )
    let pos = position.stepToward(target, step: slewPerFrame) 
    position = pos
    let us = pos.usForAngle(minUS: minUS, maxUS: maxUS)

    // compute pulse width for the *next* frame start; slew once per frame
    if !pinHigh {
      // beginning of a new frame → slew toward target and start HIGH phase
      board.digitalWrite(pin: pin, true)
      pinHigh = true
      return us                  // stay HIGH for pulse width
    } else {
      // end of pulse → go LOW for the remainder of the frame
      board.digitalWrite(pin: pin, false)
      pinHigh = false
      let low = frameUS - us
      // ensure we never return 0 (avoids immediate retrigger)
      return low > 0 ? low : 1
    }
  }
}

// MARK: - Servo Math Helpers

extension Int {
  @inline(__always)
  func clamp(lo: Int, hi: Int) -> Int { Swift.max(lo, Swift.min(hi, self)) }
  @inline(__always)
  func usForAngle(minUS: Int, maxUS: Int) -> Int {
    // Map -90…+90 around neutral to 0…180
    let pseudo = (90 + self).clamp(lo: 0, hi: 180)
    return minUS + (maxUS - minUS) * pseudo / 180
  }
  @inline(__always)
  func stepToward(_ tgt: Int, step: Int) -> Int {
    self < tgt ? Swift.min(self + step, tgt) : (self > tgt ? Swift.max(self - step, tgt) : self)
  }
}