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

import Support

extension RP2040 {
  public var now: UInt64 {
    var high = hardware.timer.awh
    var low: UInt32
    repeat {
      low = hardware.timer.awl
      let nextHigh = hardware.timer.awh
      if high == nextHigh {
        break
      }
      high = nextHigh
    } while true
    return UInt64(high) << 32 | UInt64(low)
  }

  public func sleep(forMicroseconds microseconds: UInt64) {
    let start = now
    let deadline = start + microseconds

    let highDeadline = UInt32(deadline >> 32)
    let lowDeadline = UInt32(deadline & UInt64(UInt32.max))
    var high = hardware.timer.awh

    while high < highDeadline {
      high = hardware.timer.awh
    }

    while high == highDeadline && hardware.timer.awl < lowDeadline {
      high = hardware.timer.awh
    }
  }

  public func sleep(forMilliseconds ms: Int) {
    if ms > 0 { sleep(forMicroseconds: UInt64(ms) * 1_000) }
  }

  public func sleep(for duration: Duration) {
    let (seconds, attoseconds) = duration.components
    let microseconds = attoseconds / 1_000_000_000_000 + seconds * 1_000_000
    if microseconds > 0 {
      sleep(forMicroseconds: UInt64(microseconds))
    }
  }
}
