struct BLEProfile {
    let services: [BLEService]
}

struct BLEService {
    let uuid: BLEUUID
    let characteristics: [BLECharacteristic]
}

struct BLECharacteristic {
    let uuid: BLEUUID
    let dataLength: UInt16
    let descriptionUUID: BLEUUID
    let descriptionDataLength: UInt16
}

struct BLEUUID {
    enum BLEUUIDSize {
        case sixteenBits
        case thirtyTwoBits
    }

    let uuid: [UInt8]
    let length: BLEUUIDSize

    init(uuid16: UInt16) {
        self.uuid = [
            UInt8(uuid16 & 0xFF00 << 8),
            UInt8(uuid16 & 0xFF),
        ]
        self.length = .sixteenBits
    }

    init(uuid32: UInt32) {
        self.uuid = [
            UInt8(uuid32 & 0xFF000000 << 24),
            UInt8(uuid32 & 0xFF0000 << 16),
            UInt8(uuid32 & 0xFF00 << 8),
            UInt8(uuid32 & 0xFF),        
        ]
        self.length = .thirtyTwoBits
    }

    var uuid16: UInt16 {
        return (UInt16(uuid[1]) & 0xFF00 << 8) | (UInt16(uuid[0]) & 0xFF)
    }

    var uuid32: UInt32 {
        var rawUUID: UInt32 = (UInt32(uuid[1]) & 0xFF00 << 8) | (UInt32(uuid[0]) & 0xFF)
        guard length == .thirtyTwoBits else { return rawUUID }
        rawUUID |= (UInt32(uuid[3]) & 0xFF000000 << 24) | (UInt32(uuid[2]) & 0xFF0000)
        return rawUUID
    }
}

extension BLEUUID {
    var esp32UUID: esp_bt_uuid_t {
        switch length {
            case .sixteenBits:
                return esp_bt_uuid_t(
                    len: 2, 
                    uuid: esp_bt_uuid_t.__Unnamed_union_uuid(uuid16: uuid16)
                )
            case .thirtyTwoBits:
                return esp_bt_uuid_t(
                    len: 4, 
                    uuid: esp_bt_uuid_t.__Unnamed_union_uuid(uuid32: uuid32)
                )
        }
    }
}