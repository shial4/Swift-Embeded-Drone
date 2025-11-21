//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension RP2040 {
  enum PinDirection {
    case input
    case output
  }

  func setDirection(_ pin: some DigitalPin, _ direction: PinDirection) {
    switch direction {
    case .output:
      hardware.sio.enableOutput(1 << pin.rawValue)
    case .input:
      hardware.sio.disableOutput(1 << pin.rawValue)
    }
  }

  func put(_ pin: some DigitalPin, _ value: Bool) {
    switch value {
    case true:
      hardware.sio.setOutput(1 << pin.rawValue)
    case false:
      hardware.sio.clearOutput(1 << pin.rawValue)
    }
  }

  public func write(
    _ byte: UInt8,
    to pins: (
      some DigitalPin, some DigitalPin, some DigitalPin, some DigitalPin,
      some DigitalPin, some DigitalPin, some DigitalPin, some DigitalPin
    )
  ) {
    var set = UInt32(0)
    var clear = UInt32(0)

    if byte & (1 << 0) != 0 {
      set |= 1 << pins.0.rawValue
    } else {
      clear |= 1 << pins.0.rawValue
    }
    if byte & (1 << 1) != 0 {
      set |= 1 << pins.1.rawValue
    } else {
      clear |= 1 << pins.1.rawValue
    }
    if byte & (1 << 2) != 0 {
      set |= 1 << pins.2.rawValue
    } else {
      clear |= 1 << pins.2.rawValue
    }
    if byte & (1 << 3) != 0 {
      set |= 1 << pins.3.rawValue
    } else {
      clear |= 1 << pins.3.rawValue
    }
    if byte & (1 << 4) != 0 {
      set |= 1 << pins.4.rawValue
    } else {
      clear |= 1 << pins.4.rawValue
    }
    if byte & (1 << 5) != 0 {
      set |= 1 << pins.5.rawValue
    } else {
      clear |= 1 << pins.5.rawValue
    }
    if byte & (1 << 6) != 0 {
      set |= 1 << pins.6.rawValue
    } else {
      clear |= 1 << pins.6.rawValue
    }
    if byte & (1 << 7) != 0 {
      set |= 1 << pins.7.rawValue
    } else {
      clear |= 1 << pins.7.rawValue
    }
    hardware.sio.setOutput(set)
    hardware.sio.clearOutput(clear)
  }

  func setFunction(
    _ pin: some DigitalPin,
    _ function: RP2040Hardware.IOBank.GPIOControl.Projection.FuncSel
  ) {
    hardware.ioBank0.gpioControl[pin.rawValue].modify {
      $0.functionSelection = function
    }
  }

  func initialize(_ pin: some DigitalPin) {
    setDirection(pin, .input)
    put(pin, false)
    setFunction(pin, .sio0)
  }

  public func setMode(_ mode: PinMode, pin: some DigitalPin) {
    let idx = pin.rawValue

    hardware.ioBank0.gpioControl[pin.rawValue].modify {
      $0.functionSelection = .sio0
    }

  switch mode {
  case .input:
    hardware.padsBank0.gpio[idx].modify {
      $0.pullUpEnable = false
      $0.pullDownEnable = false
      $0.inputEnable = true
      $0.outputDisable = true
      $0.schmittTriggerEnable = true
      $0.slewRateControl = .slow
    }
    setDirection(pin, .input)

  case .inputPullup:
    hardware.padsBank0.gpio[idx].modify {
      $0.pullUpEnable = true
      $0.pullDownEnable = false
      $0.inputEnable = true
      $0.outputDisable = true
      $0.schmittTriggerEnable = true
      $0.slewRateControl = .slow
    }
    setDirection(pin, .input)

  case .inputPulldown:
    hardware.padsBank0.gpio[idx].modify {
      $0.pullUpEnable = false
      $0.pullDownEnable = true
      $0.inputEnable = true
      $0.outputDisable = true
      $0.schmittTriggerEnable = true
      $0.slewRateControl = .slow
    }
    setDirection(pin, .input)

  case .output2mA, .output4mA, .output8mA, .output12mA:
    let drive: RP2040Hardware.PadsBank.GPIO.Projection.DriveStrength =
      (mode == .output2mA) ? .level2mA :
      (mode == .output4mA) ? .level4mA :
      (mode == .output8mA) ? .level8mA : .level12mA

    hardware.padsBank0.gpio[idx].modify {
      $0.pullUpEnable = false
      $0.pullDownEnable = false
      $0.inputEnable = true
      $0.outputDisable = false
      $0.driveStrength = drive
      $0.schmittTriggerEnable = true
      $0.slewRateControl = .slow
    }
    setDirection(pin, .output)
  }
    // switch mode {
    // case .output4mA:
    //   initialize(pin)
    //   hardware.padsBank0.gpio[pin.rawValue].modify {
    //     $0.driveStrength = .level4mA
    //   }
    //   setDirection(pin, .output)
    // default:
    //   break
    // }
  }

  public func digitalWrite(pin: some DigitalPin, _ value: Bool) {
    put(pin, value)
  }

  /// Reads the logic level from a GPIO pin.
  /// Returns `true` if the pin is HIGH, `false` if LOW.
  public func digitalRead(pin: some DigitalPin) -> Bool {
    let g = hardware.sio.gpioIn
    return ((g >> pin.rawValue) & 1) != 0
  }
}
