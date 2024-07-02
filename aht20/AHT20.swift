
enum AHT20Error: Error {
    case calibrationFailed
    case I2CReadError(I2CControllerError)
    case I2CWriteError(I2CControllerError)
}

struct AHT20Data {
    /// Temperature in celsius degrees.
    let temperature: Double

    /// Relative humidity percentage, values are within 0 to 100.
    let humidity: Double
}

protocol AHT20 {
    /// Soft-reset the sensor and wait for it to be calibrated.
    func setup() throws(AHT20Error)

    /// This method will request to read the AHT20 data. If polling is true,
    /// then this method will wait until the sensor has valid data. According
    /// to the datasheet, this might take around 80ms. If polling is false,
    /// then call this method only after calling isReady() to avoid unwanted
    /// behaviors.
    func readData(polling: Bool) throws(AHT20Error) -> AHT20Data

    /// Method that sends a command for the sensor to start measuring. Use this
    /// method along isReady() if you want to avoid polling inside readData().
    func requestMeasurement() throws(AHT20Error)

    /// Whether or not the sensor data is ready to be read. Use this
    /// method along requestMeasurement() if you want to avoid polling inside
    /// readData().
    func isReady() throws(AHT20Error) -> Bool
}