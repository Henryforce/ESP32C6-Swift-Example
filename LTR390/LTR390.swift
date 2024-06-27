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
