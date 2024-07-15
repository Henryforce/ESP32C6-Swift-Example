struct BLEProfile {
    let services: [BLEService]
}

struct BLEService {
    let uuid: BLEUUID
    let primary: Bool
    let characteristics: [BLECharacteristic]
}

struct BLECharacteristic {
    let uuid: BLEUUID
    let dataLength: UInt16
    let permissions: BLECharacteristicPermissions
    let properties: BLECharacteristicProperties
    let description: BLECharacteristicDescription
}

struct BLECharacteristicDescription {
    let uuid: BLEUUID
    let permissions: BLECharacteristicPermissions
}

// TODO: add support for 128 bits UUID.
struct BLEUUID: Equatable, Hashable {
    enum BLEUUIDSize: Equatable, Hashable {
        case sixteenBits
        case thirtyTwoBits

        var rawLength: UInt16 {
            switch self {
                case .sixteenBits: UInt16(ESP_UUID_LEN_16)
                case .thirtyTwoBits: UInt16(ESP_UUID_LEN_32)
            }
        }
    }

    /// UUID stored as bytes ordered from LSB to MSB.
    let uuid: [UInt8]
    let length: BLEUUIDSize

    init(uuid16: UInt16) {
        // Bytes need to be stored from LSB to MSB.
        self.uuid = [
            UInt8(uuid16 & 0xFF),
            UInt8((uuid16 & 0xFF00) >> 8),
        ]
        self.length = .sixteenBits
    }

    init(uuid32: UInt32) {
        // Bytes need to be stored from LSB to MSB.
        self.uuid = [
            UInt8(uuid32 & 0xFF),       
            UInt8((uuid32 & 0xFF00) >> 8),
            UInt8((uuid32 & 0xFF0000) >> 16), 
            UInt8((uuid32 & 0xFF000000) >> 24),
        ]
        self.length = .thirtyTwoBits
    }

    /// Returns the two LSBs of the UUID.
    var uuid16: UInt16 {
        guard uuid.count >= 2 else { return 0 }
        return (UInt16(uuid[1]) << 8) | UInt16(uuid[0])
    }

    /// Returns the four LSBs of the UUID.
    var uuid32: UInt32 {
        guard uuid.count >= 4 else { return UInt32(uuid16) }
        var rawUUID = (UInt32(uuid[3]) << 24) | (UInt32(uuid[2]) << 16)
        rawUUID |= (UInt32(uuid[1]) << 8) | UInt32(uuid[0])
        return rawUUID
    }
}

struct BLECharacteristicPermissions: OptionSet {
    let rawValue: Int

    static let read = BLECharacteristicPermissions(rawValue: 1 << 0)
    static let write = BLECharacteristicPermissions(rawValue: 1 << 1)
}

struct BLECharacteristicProperties: OptionSet {
    let rawValue: Int

    static let read = BLECharacteristicProperties(rawValue: 1 << 0)
    static let write = BLECharacteristicProperties(rawValue: 1 << 1)
    static let notify = BLECharacteristicProperties(rawValue: 1 << 2)
}
