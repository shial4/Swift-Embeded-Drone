# rpi-pico-drone

Based on the Raspberry Pi Pico LED blink example from https://github.com/swiftlang/swift-embedded-examples and extended into a tiny elevon (flying wing) controller written in Embedded Swift. The original LED demo is still present as a startup heartbeat, but the firmware now drives a motor, two elevon servos, and basic inputs.

<img src="https://github.com/swiftlang/swift-embedded-examples/assets/1186214/f2c45c18-f9a4-48b4-a941-1298ecc942cb">

## Hardware & Components
- Raspberry Pi Pico (non-W recommended)
- L9110S motor driver wired to GPIO 18/19 for throttle PWM and direction
- Two SG90-compatible servos on GPIO 2 and GPIO 3 (elevon left/right)
- Two momentary buttons on GPIO 14 and GPIO 15 (roll left/right + throttle ramp when both held)
- Optional IR receiver on GPIO 13 (wired as a pull-up input placeholder)
- Onboard/green LED on GPIO 22 for boot heartbeat

## Architecture
- **Runtime loop**: `Program.run()` sets up peripherals, blinks the LED, then enters a scheduler-like loop that services servos and motor in a non-blocking fashion. Each device returns the microseconds until its next edge; the loop sleeps until the earliest deadline to keep timing stable without interrupts.
- **Inputs**: `Button` wraps GPIO with pull-ups to read active-low momentary switches. `IRReceiver` mirrors the same pattern for an IR input.
- **Motor control**: `Motor` drives an L9110S H-bridge with simple PWM and coast/off phases to keep noise down. Throttle is signed (-100…100) for direction support and is serviced at `pwmHz` (default 400 Hz here).
- **Servo control**: `Servo` emits 50 Hz frames with slew limiting and angle clamps. `updateElevon` maps roll command to left/right elevons, keeping mechanical limits in check.
- **Command shaping**: Buttons ramp `rollCmd` up/down and auto-center when released. Holding both buttons ramps throttle up; releasing drops back to zero and idles the motor.

## RP2040 HAL and Support changes
- Added GPIO read/write support in `Sources/RP2040/HAL/Digital.swift`, including `digitalRead`, `digitalWrite`, pin mode selection (input with pull-ups/downs and multiple drive strengths), and bulk byte writes. This extends the original blink-only sample to two-way pin access needed for buttons and H-bridge control.
- Support files (`Sources/Support/Support.c`, `Sources/Support/crt0.S`) remain close to the upstream example but are wired to set up the vector table, stack, and reset handler for this binary so the new HAL calls can run from cold boot.

## Build and flash
- Put the Pico in USB Mass Storage firmware upload mode (hold BOOTSEL while plugging in, or erase existing firmware).
- Install a recent nightly Swift toolchain with Embedded Swift support.
- Build and copy the UF2 to the Pico:

``` console
$ make
$ cp .build/Application.uf2 /Volumes/RP2040
```

After reset, the LED blinks three times, then the loop begins servicing inputs, servos, and motor.

## Credits
- Swift Embedded examples team for the base RP2040 sample and startup/runtime scaffolding.
- Embedded Swift community and toolchain contributors for making bare-metal Swift on Pico possible.
