final class ESP32TaskDelayController: TaskDelayController {
    private let tickPeriod: UInt32

    init() {
        self.tickPeriod = delayPortTickPeriodMs()
    }

    func delay(milliseconds: UInt32) {
        vTaskDelay(milliseconds / tickPeriod)
    }
}