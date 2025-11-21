// IR receiver module

import RP2040

struct IRReceiver<Pin: DigitalPin> {
    let pin: Pin

    init(board: RP2040, pin: Pin) {
        self.pin = pin
        board.setMode(.inputPullup, pin: pin)
    }

    func isPressed(board: RP2040) -> Bool {
        return !board.digitalRead(pin: pin)
    }
}
