enum LTR390Mode: UInt8 {
    case ALS = 0
    case UV
}

enum LTR390Gain: UInt8 {
    case one = 0
    case three
    case six
    case nine
    case eighteen
}

enum LTR390Resolution: UInt8 {
    case twentyBit = 0
    case nineteenBit
    case eighteenBit
    case seventeenBit
    case sixteenBit
    case thirteenBit

    var integrationFactor: Double {
        switch self {
            case .twentyBit: return 4.0
            case .nineteenBit: return 2.0
            case .eighteenBit: return 1.0
            case .seventeenBit: return 0.5
            case .sixteenBit: return 0.25
            case .thirteenBit: return 0.125 // This is actually a bit undefined...
        }
    }
}

enum LTR390MeasurementRate: UInt8 {
    case twentyFiveMs = 0
    case fiftyMs
    case oneHundredMs
    case twoHundredMs
    case fiveHundredMs
    case oneSecond
    case twoSeconds
}

protocol LTR390 {
    func readUVIndex() throws(LTR390Error) -> Double
    func readLuminosity() throws(LTR390Error) -> Double
    
    func readMode() throws(LTR390Error) -> LTR390Mode
    func writeMode(_ mode: LTR390Mode, enableLightSensor: Bool) throws(LTR390Error)

    func readGain() throws(LTR390Error) -> LTR390Gain
    func writeGain(_ gain: LTR390Gain) throws(LTR390Error)

    func readResolution() throws(LTR390Error) -> LTR390Resolution
    func writeResolution(_ resolution: LTR390Resolution) throws(LTR390Error)

    func readMeasurementRate() throws(LTR390Error) -> LTR390MeasurementRate
    func writeMeasurementRate(_ measurementRate: LTR390MeasurementRate) throws(LTR390Error)
}

/// https://esphome.io/components/sensor/ltr390.html
final class LTR390Impl<T: I2CController>: LTR390 {
    private let deviceAddress: UInt8 = 0x53
    private let uvSensitivity = 2300.0
    private let i2CController: T

    private var latestMode = LTR390Mode.UV
    private var latestLightSensorEnabledStatus = false
    private var latestGain = LTR390Gain.one
    private var latestResolution = LTR390Resolution.twentyBit
    private var latestMeasurementRate = LTR390MeasurementRate.twentyFiveMs

    init(i2CController: T) {
        self.i2CController = i2CController
    }

    func readUVIndex() throws(LTR390Error) -> Double {
        let rawData = try readI2CData(at: .uvData)
        let uvIndexInt = (UInt32(rawData[2]) << 16) | (UInt32(rawData[1]) << 8) | UInt32(rawData[0])
        return Double(uvIndexInt) / uvSensitivity
    }
    func readLuminosity() throws(LTR390Error) -> Double {
        let rawData = try readI2CData(at: .alsData)
        let alsDataInt = (UInt32(rawData[2]) << 16) | (UInt32(rawData[1]) << 8) | UInt32(rawData[0])
        return (0.6 * Double(alsDataInt)) / (Double(latestGain.rawValue) * latestResolution.integrationFactor)
    }
    
    func readMode() throws(LTR390Error) -> LTR390Mode {
        let rawData = try readI2CData(at: .mainControl)
        let shiftedData = (rawData[0] & 0x08) >> 3
        guard let validMode = LTR390Mode(rawValue: shiftedData) else { throw LTR390Error.invalidData }
        self.latestMode = validMode
        return validMode
    }
    func writeMode(_ mode: LTR390Mode, enableLightSensor: Bool) throws(LTR390Error) {
        let mainControlData = (mode.rawValue << 3) | (enableLightSensor ? 0x2 : 0x0)
        try writeI2CData([mainControlData], at: .mainControl)
        self.latestMode = mode
        self.latestLightSensorEnabledStatus = enableLightSensor
    }

    func readGain() throws(LTR390Error) -> LTR390Gain {
        let rawData = try readI2CData(at: .gain)
        guard let validGain = LTR390Gain(rawValue: rawData[0]) else { throw LTR390Error.invalidData }
        self.latestGain = validGain
        return validGain
    }
    func writeGain(_ gain: LTR390Gain) throws(LTR390Error) {
        try writeI2CData([gain.rawValue], at: .gain)
        self.latestGain = gain
    }

    func readResolution() throws(LTR390Error) -> LTR390Resolution {
        let rawData = try readI2CData(at: .measurementResolution)
        let shiftedData = (rawData[0] & 0x70) >> 4
        guard let validResolution = LTR390Resolution(rawValue: shiftedData) else {
            throw LTR390Error.invalidData
        }
        self.latestResolution = validResolution
        return validResolution
    }
    func writeResolution(_ resolution: LTR390Resolution) throws(LTR390Error) {
        let measurementResolutionData = (resolution.rawValue << 4) | latestMeasurementRate.rawValue
        try writeI2CData([measurementResolutionData], at: .measurementResolution)
        self.latestResolution = resolution
    }

    func readMeasurementRate() throws(LTR390Error) -> LTR390MeasurementRate {
        let rawData = try readI2CData(at: .measurementResolution)
        guard let validMeasurementRate = LTR390MeasurementRate(rawValue: rawData[0] & 0x0F) else {
            throw LTR390Error.invalidData
        }
        self.latestMeasurementRate = validMeasurementRate
        return validMeasurementRate
    }
    func writeMeasurementRate(_ measurementRate: LTR390MeasurementRate) throws(LTR390Error) {
        let measurementResolutionData = (latestResolution.rawValue << 4) | measurementRate.rawValue
        try writeI2CData([measurementResolutionData], at: .measurementResolution)
        self.latestMeasurementRate = measurementRate
    }

    private func readI2CData(at register: LTR390Register) throws(LTR390Error) -> [UInt8] {
        do {
            return try i2CController.readRawData(
                deviceAddress: deviceAddress, 
                registerAddress: register.address, 
                length: register.length,
                timeout: 10
            )
        } catch (let error) {
            throw LTR390Error.I2CReadError(error)
        }
    }

    private func writeI2CData(
        _ data:[UInt8],
        at register: LTR390Register
    ) throws(LTR390Error) {
        guard data.count == register.length else { throw LTR390Error.invalidDataLength }
        do {
            try i2CController.writeRawData(
                data,
                deviceAddress: deviceAddress, 
                registerAddress: register.address, 
                timeout: 10
            )
        } catch (let error) {
            throw LTR390Error.I2CReadError(error)
        }
    }
}

enum LTR390Error: Error {
    case invalidData
    case invalidDataLength
    case I2CReadError(I2CControllerError)
    case I2CWriteError(I2CControllerError)
}

enum LTR390Register {
    case mainControl
    case measurementResolution
    case gain
    case alsData
    case uvData

    var address: UInt8 {
        switch self {
            case .mainControl: return 0x00
            case .measurementResolution: return 0x04
            case .gain: return 0x05
            case .alsData: return 0x0D // 0x0D, 0x0E, 0x0F
            case .uvData: return 0x10 // 0x10, 0x11, 0x12
        }
    }

    var length: Int {
        switch self {
            case .mainControl, .measurementResolution, .gain:
                return 1
            case .alsData, .uvData:
                return 3
        }
    }
}