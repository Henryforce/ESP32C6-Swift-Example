// Datasheet available in:
// https://esphome.io/components/sensor/ltr390.html

fileprivate enum Constants {
    static let deviceAddress: UInt8 = 0x53
    static let uvSensitivity: Double = 2300.0
}

final class LTR390Impl<T: I2CController>: LTR390 {
    private let i2CController: T

    private var latestMode = LTR390Mode.UV
    private var latestLightSensorEnabledStatus = false
    private var latestGain = LTR390Gain.one
    private var latestResolution = LTR390Resolution.twentyBit
    private var latestMeasurementRate = LTR390MeasurementRate.twentyFiveMs

    init(i2CController: T) {
        self.i2CController = i2CController
    }

    func readRawUVIndex() throws(LTR390Error) -> UInt32 {
        let rawData = try readI2CData(at: .uvData)
        return (UInt32(rawData[2]) << 16) | (UInt32(rawData[1]) << 8) | UInt32(rawData[0])
    }
    func readUVIndex() throws(LTR390Error) -> Double {
        let uvIndexInt = try readRawUVIndex()
        return Double(uvIndexInt) / Constants.uvSensitivity
    }

    func readRawLuminosity() throws(LTR390Error) -> UInt32 {
        let rawData = try readI2CData(at: .alsData)
        return (UInt32(rawData[2]) << 16) | (UInt32(rawData[1]) << 8) | UInt32(rawData[0])
    }
    func readLuminosity() throws(LTR390Error) -> Double {
        let alsDataInt = try readRawLuminosity()
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
        try writeI2CData([LTR390Register.mainControl.address, mainControlData])
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
        try writeI2CData([LTR390Register.gain.address, gain.rawValue])
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
        try writeI2CData([LTR390Register.measurementResolution.address, measurementResolutionData])
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
        try writeI2CData([LTR390Register.measurementResolution.address, measurementResolutionData])
        self.latestMeasurementRate = measurementRate
    }

    private func readI2CData(at register: LTR390Register) throws(LTR390Error) -> [UInt8] {
        do {
            return try i2CController.writeReadRawData(
                [register.address],
                deviceAddress: Constants.deviceAddress,
                length: register.length,
                timeout: 10
            )
        } catch (let error) {
            throw LTR390Error.I2CReadError(error)
        }
    }

    private func writeI2CData(_ data:[UInt8]) throws(LTR390Error) {
        do {
            try i2CController.writeRawData(
                data,
                deviceAddress: Constants.deviceAddress,
                timeout: 10
            )
        } catch (let error) {
            throw LTR390Error.I2CReadError(error)
        }
    }
}