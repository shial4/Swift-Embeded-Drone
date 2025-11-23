import RP2040

struct IRReceiver<Pin: DigitalPin> {
  enum Key: UInt8 {
    case power    = 0x45
    case up       = 0x40
    case down     = 0x19
    case left     = 0x07
    case right    = 0x09
    case ok       = 0x15
    case back     = 0x44
    case volDown  = 0x0D
    case volUp    = 0x0C
    case menu     = 0x47
    case home     = 0x46
    case mouse    = 0x43
  }

  enum Action {
    case noseUp
    case noseDown
    case rollLeft
    case rollRight
    case volumeUp
    case volumeDown
    case powerToggle
    case select
    case numeric(Int)
    case raw(UInt8)
  }

  let pin: Pin

  private let sampleUS: UInt64 = 60
  private let startLowTicks = 200
  private let startHighTicks = 80
  private let lowTicksPerBit = 15
  private let highTicksPerBit = 40

  init(board: RP2040, pin: Pin) {
    self.pin = pin
    board.setMode(.inputPullup, pin: pin)
  }

  /// Polls the IR receiver; returns an action if a full NEC frame was captured.
  mutating func poll(board: RP2040) -> Action? {
    guard let code = decode(board: board) else { return nil }
    return actionFor(code: code)
  }

  private func decode(board: RP2040) -> UInt8? {
    guard !board.digitalRead(pin: pin) else { return nil }

    var count = 0
    while !board.digitalRead(pin: pin) && count < startLowTicks {
      count &+= 1
      board.sleep(forMicroseconds: sampleUS)
    }
    if count >= startLowTicks { return nil }

    count = 0
    while board.digitalRead(pin: pin) && count < startHighTicks {
      count &+= 1
      board.sleep(forMicroseconds: sampleUS)
    }
    if count >= startHighTicks { return nil }

    var d0: UInt8 = 0
    var d1: UInt8 = 0
    var d2: UInt8 = 0
    var d3: UInt8 = 0
    var idx = 0
    var bit: UInt8 = 0

    for _ in 0..<32 {
      count = 0
      while !board.digitalRead(pin: pin) && count < lowTicksPerBit {
        count &+= 1
        board.sleep(forMicroseconds: sampleUS)
      }

      count = 0
      while board.digitalRead(pin: pin) && count < highTicksPerBit {
        count &+= 1
        board.sleep(forMicroseconds: sampleUS)
      }

      if count > 8 {
        switch idx {
        case 0: d0 |= UInt8(1) << bit
        case 1: d1 |= UInt8(1) << bit
        case 2: d2 |= UInt8(1) << bit
        default: d3 |= UInt8(1) << bit
        }
      }

      if bit == 7 {
        bit = 0
        idx += 1
      } else {
        bit &+= 1
      }
    }

    let check: UInt8 = 0xFF
    guard d0 &+ d1 == check, d2 &+ d3 == check else { return nil }
    return d2
  }

  private func actionFor(code: UInt8) -> Action {
    guard let key = Key(rawValue: code) else {
        return .raw(code)
    }
    switch key {
    case .power:    return .powerToggle
    case .up:       return .noseUp
    case .down:     return .noseDown
    case .left:     return .rollLeft
    case .right:    return .rollRight
    case .volUp:    return .volumeUp
    case .volDown:  return .volumeDown
    case .ok:       return .select
    default:
        return .raw(code)
    }
  }
}
