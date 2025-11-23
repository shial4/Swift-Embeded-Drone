# rpi-pico-drone

Based on the Raspberry Pi Pico LED blink example from https://github.com/swiftlang/swift-embedded-examples and extended into a tiny elevon (flying wing) controller written in Embedded Swift. The original LED demo is still present as a startup heartbeat, but the firmware now drives a motor, two elevon servos, and basic inputs.

![Pico drone breadboard setup](Resources/IMB_f1WaZe.PNG)

## Hardware & Components
- Raspberry Pi Pico (non-W recommended)
- L9110S motor driver wired to GPIO 18/19 for throttle PWM and direction
- Two SG90-compatible servos on GPIO 2 and GPIO 3 (elevon left/right)
- Two momentary buttons on GPIO 14 and GPIO 15 (roll left/right + throttle ramp when both held)
- Optional IR receiver on GPIO 13 (wired as a pull-up input placeholder)
- Onboard/green LED on GPIO 22 for boot heartbeat
- Airframe based on the “K+ 3D Printed Flying wing FPV Drone” model

The Pico is built around the dual-core RP2040 MCU and exposes 26 usable GPIO pins (3.3 V only) on its 40-pin header. Power rails (VBUS, VSYS, 3V3, GND) and the SWD pads sit on the same edge, making it easy to feed the H-bridge and servos while keeping logic pins isolated. The diagram below labels every pin; the connections above land on the left header near the USB socket for short, low-noise runs to the motor driver and servos.

![Pico drone breadboard setup](Resources/raspberrypipicopinout.png.jpeg)

## Architecture
- **Runtime loop**: `Program.run()` sets up peripherals, blinks the LED, then enters a scheduler-like loop that services servos and motor in a non-blocking fashion. Each device returns the microseconds until its next edge; the loop sleeps until the earliest deadline to keep timing stable without interrupts.
- **Inputs**: `Button` wraps GPIO with pull-ups to read active-low momentary switches. `IRReceiver` mirrors the same pattern for an IR input.
- **Motor control**: `Motor` drives an L9110S H-bridge with simple PWM and coast/off phases to keep noise down. Throttle is signed (-100…100) for direction support and is serviced at `pwmHz` (default 400 Hz here).
- **Servo control**: `Servo` emits 50 Hz frames with slew limiting and angle clamps. `updateElevon` maps roll command to left/right elevons, keeping mechanical limits in check.
- **Command shaping**: Buttons ramp `rollCmd` up/down and auto-center when released. Holding both buttons ramps throttle up; releasing drops back to zero and idles the motor.

Simple wiring diagram
```
                     ┌──────────────────────┐
                     │   4×AA BATTERY PACK  │
                     │       ~6.0 V         │
                     └───────┬───────┬──────┘
                             │       │
                           (+)       (-)
                             │       │
         +-------------------+       +-----------------------------+
         |                                                 GND BUS |
         v                                                         v

 ┌──────────────────────────────────────────────────────────────────────────┐
 │                               Raspberry Pi Pico                          │
 │                                                                          │
 │   VSYS  ◄────────────────────────────── +6V                               │
 │   GND   ◄────────────────────────────── GND                               │
 │                                                                          │
 │   GP22 ───────────────► LED (anode)                                      │
 │                    LED cathode ───────► GND                               │
 │                                                                          │
 │   GP13 ───────────────► IR Receiver OUT                                   │
 │   3V3  ───────────────► IR Receiver VCC                                   │
 │   GND  ───────────────► IR Receiver GND                                   │
 │                                                                          │
 │   GP2  ───────────────► Servo L signal                                    │
 │   GP3  ───────────────► Servo R signal                                    │
 │                                                                          │
 │   GP19 ───────────────► L9110S IN1                                        │
 │   GP18 ───────────────► L9110S IN2                                        │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘


                 +6V BUS ──────────────────────────────────────+
                 │                                             │
                 v                                             v

        ┌───────────────┐                            ┌─────────────────┐
        │   SERVO L     │                            │    SERVO R      │
        │   SG90        │                            │    SG90         │
        │  V+ ◄─────────┴──────────────► +6V         │  V+ ◄──────────────► +6V
        │  GND◄────────────────────────► GND         │  GND◄────────────────► GND
        │  SIG◄────────────── GP2                   │  SIG◄────────────── GP3
        └───────────────┘                            └─────────────────┘


                          L9110S MOTOR DRIVER MODULE

                  +6V ───────────────► MOTOR POWER VCC
                  GND ───────────────► MOTOR POWER GND

      GP19 ─────────► IN1     OUT1 ──────────────► Motor +
      GP18 ─────────► IN2     OUT2 ──────────────► Motor –
```

Here is a minimal “quick map” of the setup.

```
Pico Pins (left side):                        Pico Pins (right side):
1   GP0                                        40  VBUS
2   GP1                                        39  VSYS      ← Battery + (4×AA)
3   GND        ← common GND                    38  GND       ← common GND
4   GP2        ← Servo L signal                37  3V3       ← IR Receiver VCC
5   GP3        ← Servo R signal                36  3V3_EN
6   GP4                                        35  ADC_VREF
7   GP5                                        34  GP28
8   GND        ← can use (servo/IR/motor GND)  33  GND       ← common GND
9   GP6                                        32  GP27
10  GP7                                        31  GP26
11  GP8                                        30  RUN
12  GP9                                        29  GP22
13  AGND      ← safe GND                       28  GND       ← common GND
14  GP10                                       27  GP21
15  GP11                                       26  GP20
16  GP12                                       25  GP19      ← Motor IN1 (L9110S IN1)
17  GP13      ← IR Receiver OUT                24  GP18      ← Motor IN2 (L9110S IN2)
18  GND       ← common GND                     23  GND       ← common GND
19  GP14                                       22  GP17
20  GP15                                       21  GP16
```

## RP2040 HAL and Support changes
- GPIO writes now map each bit to the intended pin (bit 3 no longer toggles pin 0), fixing incorrect patterns when writing full bytes to multiple pins. See `Sources/RP2040/HAL/Digital.swift` (`write(_:to:)`).
- `setMode` configures pads for inputs (with optional pull-up/down) and outputs with selectable drive strengths, ensuring pins are in a safe state before use. The new cases set pulls, input/output enables, slew rate, and drive strength in `Sources/RP2040/HAL/Digital.swift`.
- Added `digitalRead` and the underlying SIO `gpioIn` accessor so firmware can read GPIO logic levels instead of only driving them. References: `Sources/RP2040/HAL/Digital.swift` and `Sources/RP2040/Hardware/SIO.swift`.
- The monotonic timer (`now`) is public and `sleep(forMilliseconds:)` now delegates to the microsecond sleep helper for more accurate, timer-based delays. See `Sources/RP2040/HAL/Time.swift`.
- Support files (`Sources/Support/Support.c`, `Sources/Support/crt0.S`) remain close to the upstream example but set up the vector table, stack, and reset handler for this binary so the new HAL calls can run from cold boot.

## Tools and toolsets
- **Toolset JSONs (`Tools/Toolsets/*.json`)** describe the extra compiler and linker flags needed for each MCU/format. Swift does not yet ship presets for these bare-metal targets, so the JSON tells `swift build --toolset …` which CPU, segments, entry point, and linker behavior to use. The Makefile points at `Tools/Toolsets/pico.json` by default.
- **Selecting a toolset**: use `make TOOLSET=Tools/Toolsets/pico2.json build` to swap to another preset, or call Swift directly: `swift build --configuration release --triple armv6m-apple-none-macho --toolset Tools/Toolsets/pico.json`.
- **Available presets**: `pico.json` (RP2040 Mach-O with explicit segments), `pico2.json` (RP2040 Mach-O with slightly different layout), `rpi-5-elf.json` (Pi 5 ELF using `linkerscript.ld`), `stm32f74x*.json` (STM32F7 variants). Use the one that matches your board/format.
- **Conversion helpers (`Tools/*.py`)**: `macho2uf2.py` (used in the Makefile) turns the Swift-produced Mach-O into a UF2 for drag-and-drop flashing; `macho2bin.py` emits a raw binary; `elf2hex.py` produces Intel HEX. `Tools/SVDs/` holds vendor SVDs for other targets (not required for the Pico build).


## Swift Setup 

- Navigate to the repo root.
- Install and select the `main-snapshot` toolchain with [Swiftly](https://github.com/swiftlang/swiftly).

``` console
swiftly install main-snapshot
swiftly use main-snapshot
```

This creates a `.swift-version` file so `swift build` picks the right toolchain. Verify with:
``` console
swift --version
```
You should see something similar:
```
% swift --version                                                            
Apple Swift version 6.3-dev (LLVM 5f3d4bf88611f07, Swift cf535d8b998d09b)
Target: arm64-apple-macosx15.0
```

## Build and flash
- Put the Pico in USB Mass Storage firmware upload mode (hold BOOTSEL while plugging in, or erase existing firmware).
- Install a recent nightly Swift toolchain with Embedded Swift support.
- Build and copy the UF2 to the Pico:

``` console
$ make clean && make      
$ cp .build/armv6m-apple-none-macho/release/Application.uf2 /Volumes/RPI-RP2/
```

After reset, the LED blinks three times, then the loop begins servicing inputs, servos, and motor.

## Credits
- Swift Embedded examples team for the base RP2040 sample and startup/runtime scaffolding.
- Embedded Swift community and toolchain contributors for making bare-metal Swift on Pico possible.
