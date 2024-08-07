
final class AHT20Impl<I: I2CController, T: TaskDelayController>: AHT20 {
    private let i2CController: I
    private let taskDelayController: T

    init(i2CController: I, taskDelayController: T) {
        self.i2CController = i2CController
        self.taskDelayController = taskDelayController
    }

    func setup() throws(AHT20Error) {
        taskDelayController.delay(milliseconds: 21)

        try run(command: .softReset)

        taskDelayController.delay(milliseconds: 21)

        try run(command: .initialize)

        taskDelayController.delay(milliseconds: 75)

        // First data check.
        print("Read AHT20 data")
        _ = try readData(polling: true)

        print("Verify calibration")
        try verifyCalibration()
    }

    func readData(polling: Bool) throws(AHT20Error) -> AHT20Data {
        if polling {
            try requestMeasurement()
            try waitForReadyStatus()
        }

        // Data is returned as follows (blocks of 1 byte):
        // [Status] [Humidity MSB] [Humidity] [Humidity LSB | Temp MSB] [Temp] [Temp LSB]
        let rawData = try readI2CData(readLength: Constants.measurementLength)

        var rawHumidity = UInt32(rawData[1])
        rawHumidity <<= 8
        rawHumidity |= UInt32(rawData[2])
        rawHumidity <<= 4
        rawHumidity |= UInt32(rawData[3]) >> 4
        let humidity: Double = Double(rawHumidity) * 100.0 / Constants.dataDenonimator

        var rawTemperature = UInt32(rawData[3]) & 0x0F
        rawTemperature <<= 8
        rawTemperature |= UInt32(rawData[4])
        rawTemperature <<= 8
        rawTemperature |= UInt32(rawData[5])
        let temperature: Double = (Double(rawTemperature) * 200.0 / Constants.dataDenonimator) - 50.0

        return AHT20Data(temperature: temperature, humidity: humidity)
    }

    func requestMeasurement() throws(AHT20Error) {
        try run(command: .trigger)
    }

    func isReady() throws(AHT20Error) -> Bool {
        let status = try readStatus()
        return !status.contains(.busy)
    }

    private func readStatus() throws(AHT20Error) -> AHT20Status {
        let rawData = try readI2CData(writeData: [0x71], readLength: Constants.statusLength)
        return AHT20Status(rawValue: Int(rawData[0]))
    }

    private func waitForReadyStatus() throws(AHT20Error) {
        while(true) {
            // TODO: handle a maximum number of retries.
            taskDelayController.delay(milliseconds: 10)
            if try isReady() {
                break
            }
        }
    }

    private func verifyCalibration() throws(AHT20Error) {
        let status = try readStatus()
        if !status.contains(.calibrated) {
            throw AHT20Error.calibrationFailed
        }
    }

    private func readI2CData(writeData: [UInt8] = [], readLength: Int) throws(AHT20Error) -> [UInt8] {
        do {
            return try i2CController.writeReadRawData(
                writeData,
                deviceAddress: Constants.deviceAddress, 
                length: readLength,
                timeout: 10
            )
        } catch (let error) {
            throw AHT20Error.I2CReadError(error)
        }
    }

    private func run(command: AHT20Command) throws(AHT20Error) {
        do {
            try i2CController.writeRawData(
                command.writeData,
                deviceAddress: Constants.deviceAddress, 
                timeout: 10
            )
        } catch (let error) {
            throw AHT20Error.I2CReadError(error)
        }
    }
}

fileprivate enum Constants {
    static let deviceAddress: UInt8 = 0x38
    static let measurementAddress: UInt8 = 0xAC
    static let statusLength: Int = 1
    static let measurementLength: Int = 6
    static let dataDenonimator: Double = 1048576 // 2^20.
}

fileprivate enum AHT20Command {
    case initialize
    case softReset
    case calibrate
    case trigger

    var writeData: [UInt8] {
        switch self {
            case .initialize: return [0xBE, 0x08, 0x00]
            case .softReset: return [0xBA]
            case .calibrate: return [0xE1, 0x08, 0x00]
            case .trigger: return [0xAC, 0x33, 0x00]
        }
    }
}

fileprivate struct AHT20Status: OptionSet {
    let rawValue: Int

    static let calibrated = AHT20Status(rawValue: 1 << 3)
    static let busy = AHT20Status(rawValue: 1 << 7)
}