import RP2040

struct Led<Pin: DigitalPin> {
    let pin: Pin

    init(board: RP2040, pin: Pin) {
        self.pin = pin
        board.setMode(.output, pin: pin)
    }

    func blink(_ board: RP2040, _ n: Int, onUS: UInt64 = 150_000, offUS: UInt64 = 150_000) {
        for _ in 0..<n { 
            board.digitalWrite(pin: pin, true) 
            board.sleep(forMicroseconds: onUS)
            board.digitalWrite(pin: pin, false)
            board.sleep(forMicroseconds: offUS) 
        }
    }
}