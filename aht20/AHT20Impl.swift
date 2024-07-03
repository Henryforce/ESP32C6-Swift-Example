
fileprivate enum Constants {
    static let deviceAddress: UInt8 = 0x38
    static let measurementAddress: UInt8 = 0xAC
    static let measurementLength: Int = 6
}

fileprivate enum AHT20Command: UInt8 {
    case softReset = 0xBA
    case calibrate = 0xE1

    var data: [UInt8] {
        switch self {
            case .softResetCommand: return []
            case .calibrate: return [0x08, 0x00]
        }
    }
}

final class AHT20Impl<T: I2CController>: AHT20 {
    func setup() throws(AHT20Error) {
        // TODO: delay for at least 20 ms
        try run(command: .softReset)
        // TODO: delay for at least 20 ms
    }

    func readData(polling: Bool) throws(AHT20Error) -> AHT20Data {
        return AHT20Data(
            temperature: 0.0,
            humidity: 0.0
        )
    }

    func requestMeasurement() throws(AHT20Error) {

    }

    func isReady() throws(AHT20Error) -> Bool {
        return false
    }

    private func readI2CData() throws(LTR390Error) -> [UInt8] {
        // TODO: this method is not correct, in order to read it must first write..
        // do {
        //     return try i2CController.readRawData(
        //         deviceAddress: Constants.deviceAddress, 
        //         registerAddress: Constants.measurementAddress, 
        //         length: Constants.measurementLength,
        //         timeout: 10
        //     )
        // } catch (let error) {
        //     throw AHT20Error.I2CReadError(error)
        // }
        return []
    }

    private func run(command: AHT20Command) throws(LTR390Error) {
        // do {
        //     try i2CController.writeRawData(
        //         command.data,
        //         deviceAddress: Constants.deviceAddress, 
        //         registerAddress: command.rawValue, 
        //         timeout: 10
        //     )
        // } catch (let error) {
        //     throw LTR390Error.I2CReadError(error)
        // }
    }
}
