extension BLEUUID {
    // Services.
    static let weatherNode = BLEUUID(uuid16: 0x00FF)
    // Characteristics.
    static let ambientLight = BLEUUID(uuid16: 0xFF01)
    static let uvIndex = BLEUUID(uuid16: 0xFF02)
    static let temperature = BLEUUID(uuid16: 0xFF03)
    static let humidity = BLEUUID(uuid16: 0xFF04)
}

extension BLECharacteristic {
    static let ambientLight = baseCharacteristic(uuid: .ambientLight)
    static let uvIndex = baseCharacteristic(uuid: .uvIndex)
    static let temperature = baseCharacteristic(uuid: .temperature)
    static let humidity = baseCharacteristic(uuid: .humidity)

    private static func baseCharacteristic(uuid: BLEUUID) -> BLECharacteristic {
        return BLECharacteristic(
            uuid: uuid,
            dataLength: 4,
            permissions: [.read, .write],
            properties: [.read, .write, .notify],
            description: BLECharacteristicDescription(
                uuid: .clientConfiguration,
                permissions: [.read, .write]
            )
        )
    }
}
