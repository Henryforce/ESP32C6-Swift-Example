protocol I2CController {
    func setup() throws (I2CControllerError)

    func writeReadRawData(
        _ writeData: [UInt8],
        deviceAddress: UInt8, 
        length: Int,
        timeout: UInt32
    ) throws (I2CControllerError) -> [UInt8]

    func writeRawData(
        _ data: [UInt8],
        deviceAddress: UInt8,
        timeout: UInt32
    ) throws (I2CControllerError)
}
