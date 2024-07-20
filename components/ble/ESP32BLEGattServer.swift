final class ESP32BLEGattServer {

    private typealias CGattsEventHandler = @convention(c) (esp_gatts_cb_event_t, esp_gatt_if_t, UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) -> Void
    private typealias CGapEventHandler = @convention(c) (esp_gap_ble_cb_event_t, UnsafeMutablePointer<esp_ble_gap_cb_param_t>?) -> Void

    typealias GattsEventHandler = (esp_gatts_cb_event_t, esp_gatt_if_t, UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) -> Void
    typealias GapEventHandler = (esp_gap_ble_cb_event_t, UnsafeMutablePointer<esp_ble_gap_cb_param_t>?) -> Void

    private final class BLESingleton {
        static let shared = BLESingleton()

        var gattsEventHandler: GattsEventHandler?
        var gapEventHandler: GapEventHandler?

        init() { }
    }

    private struct CharacteristicHandle {
        let valueHandle: Int
        let descriptorHandle: Int?
    }

    private enum BLEDescriptorStatus: UInt8 {
        case undefined = 0
        case notify = 0x01
        case indication = 0x02
    }

    private var adv_data: esp_ble_adv_data_t
    private var scan_rsp_data: esp_ble_adv_data_t
    private var adv_service_uuid128: [UInt8] = [
        /* LSB <--------------------------------------------------------------------------------> MSB */
        //first uuid, 16bit, [12],[13] is the value
        0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80, 0x00, 0x10, 0x00, 0x00, 0xEE, 0x00, 0x00, 0x00,
        //second uuid, 32bit, [12], [13], [14], [15] is the value
        0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80, 0x00, 0x10, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00,
    ]
    private var characteristicAttributeValue: esp_attr_value_t
    private var characteristicValue:[UInt8] = [0x11, 0x22, 0x33]
    private var advertisementParameters: esp_ble_adv_params_t
    private var advertisementState: UInt8 = 0
    private var mainGattsIF: esp_gatt_if_t?
    private var connectionID: UInt16?

    /// Main profile for this controller.
    private let profile: BLEProfile

    /// The handles assigned to the BLE Profile.
    private var handles = [UInt16]()

    init(profile: BLEProfile) {
        self.profile = profile
        self.adv_data = esp_ble_adv_data_t(
            set_scan_rsp: false,
            include_name: true,
            include_txpower: false,
            min_interval: 0x0006,
            max_interval: 0x0010,
            appearance: 0,
            manufacturer_len: 0,
            p_manufacturer_data: nil,
            service_data_len: 0,
            p_service_data: nil,
            service_uuid_len: 32,
            p_service_uuid: nil,
            flag: UInt8(ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT)
        )
        self.scan_rsp_data = esp_ble_adv_data_t(
            set_scan_rsp: true,
            include_name: true,
            include_txpower: true,
            min_interval: 0x0006,
            max_interval: 0x0010,
            appearance: 0,
            manufacturer_len: 0,
            p_manufacturer_data: nil,
            service_data_len: 0,
            p_service_data: nil,
            service_uuid_len: 32,
            p_service_uuid: nil,
            flag: UInt8(ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT)
        )
        self.characteristicAttributeValue = esp_attr_value_t(
            attr_max_len: 0x40,
            attr_len: 3,
            attr_value: nil
        )
        self.advertisementParameters = adv_params_wo_peer_address(
            0x20,
            0x40,
            ADV_TYPE_IND,
            BLE_ADDR_TYPE_PUBLIC,
            ADV_CHNL_ALL,
            ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY
        )

        adv_service_uuid128.withUnsafeMutableBufferPointer { buffer in
            self.adv_data.p_service_uuid = buffer.baseAddress
            self.scan_rsp_data.p_service_uuid = buffer.baseAddress
        }
        characteristicValue.withUnsafeMutableBufferPointer { buffer in
            self.characteristicAttributeValue.attr_value = buffer.baseAddress
        }

        BLESingleton.shared.gattsEventHandler = { (event, gattsIF, param) in
            self.handleMainGattsEvent(event: event, gattsIF: gattsIF, param: param)
        }
        BLESingleton.shared.gapEventHandler = { (event, param) in
            self.handleGapEvent(event: event, param: param)
        }

        // TODO: handle errors.
        var error = nvs_flash_init()
        printErrorIfNeeded(error, title: "NVS FLASH ERROR")

        // error = esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT)
        // printErrorIfNeeded(error, title: "esp_bt_controller_mem_release ERROR")

        var defaultConfiguration = buildDefaultBTControllerConfiguration()
        error = esp_bt_controller_init(&defaultConfiguration)
        printErrorIfNeeded(error, title: "BT INIT ERROR")

        error = esp_bt_controller_enable(ESP_BT_MODE_BLE)
        printErrorIfNeeded(error, title: "BT ENABLE ERROR")

        error = esp_bluedroid_init()
        printErrorIfNeeded(error, title: "Bluedroid init ERROR")

        error = esp_bluedroid_enable()
        printErrorIfNeeded(error, title: "Bluedroid enable ERROR")

        error = esp_ble_gatts_register_callback({ (event, gattsIF, param) in
            // Call the singleton as capturing objects is not allowed on c closures.
            BLESingleton.shared.gattsEventHandler?(event, gattsIF, param)
        })
        printErrorIfNeeded(error, title: "BT GATTS Register callback ERROR")

        error = esp_ble_gap_register_callback({ (event, param) in
            // Call the singleton as capturing objects is not allowed on c closures.
            BLESingleton.shared.gapEventHandler?(event, param)
        })
        printErrorIfNeeded(error, title: "BT GAP register callback ERROR")

        error = esp_ble_gatts_app_register(0)
        printErrorIfNeeded(error, title: "BT Gatts app register ERROR")

        error = esp_ble_gatt_set_local_mtu(500)
        printErrorIfNeeded(error, title: "BT set MTU ERROR")
    }

    func updateValue(_ value: [UInt8], for characteristicUUID: BLEUUID, at serviceUUID: BLEUUID) {
        guard !handles.isEmpty, let characteristicHandle = handle(for: characteristicUUID, at: serviceUUID) else { return }

        let validHandle = handles[characteristicHandle.valueHandle]
        var data = value
        let length = data.count
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        dataPointer.initialize(from: &data, count: length)

        var error = esp_ble_gatts_set_attr_value(validHandle, UInt16(length), dataPointer)
        printErrorIfNeeded(error, title: "esp_ble_gatts_set_attr_value error")

        guard let mainGattsIF, let connectionID else { return }
        guard let descriptorHandle = characteristicHandle.descriptorHandle else { return }
        guard .notify == notifyIndicationStatus(for: handles[descriptorHandle]) else { return }

        let needConfirmation = false // false for notification, true for indication
        error = esp_ble_gatts_send_indicate(
            mainGattsIF, 
            connectionID, 
            validHandle, 
            UInt16(length), 
            dataPointer, 
            needConfirmation
        )
        printErrorIfNeeded(error, title: "esp_ble_gatts_send_indicate error")
    }

    // MARK - Private.

    /// Get the notify/indication status by reading the value of a descriptor handle.
    private func notifyIndicationStatus(for descriptorHandle: UInt16) -> BLEDescriptorStatus {
        let expectedLength = 2 // The descriptor's length is always 2.
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedLength)
        let status = swift_esp_ble_gatts_get_attr_value(descriptorHandle, UInt16(expectedLength), dataPointer)
        if status != ESP_GATT_OK {
            print("Error swift_esp_ble_gatts_get_attr_value")
            return BLEDescriptorStatus.undefined
        }
        return BLEDescriptorStatus(rawValue: dataPointer[0]) ?? BLEDescriptorStatus.undefined
    }

    /// Get the handle for a given characteristic and service.
    private func handle(for characteristicUUID: BLEUUID, at serviceUUID: BLEUUID) -> CharacteristicHandle? {
        var handleIndex = 0
        for service in profile.services {
            guard service.uuid == serviceUUID else {
                handleIndex += service.handlesCount
                continue
            }
            handleIndex += 1
            for characteristic in service.characteristics {
                guard characteristic.uuid == characteristicUUID else {
                    handleIndex += characteristic.handlesCount
                    continue
                }
                if characteristic.descriptor == nil {
                    return CharacteristicHandle(valueHandle: handleIndex + 1, descriptorHandle: nil)
                } else {
                    return CharacteristicHandle(valueHandle: handleIndex + 1, descriptorHandle: handleIndex + 2)
                }
            }
        }
        return nil
    }

    private func handleGapEvent(
        event: esp_gap_ble_cb_event_t, 
        param: UnsafeMutablePointer<esp_ble_gap_cb_param_t>?
    ) {
        switch event {
            case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
                handleAdvertisementDataSetComplete()
            case ESP_GAP_BLE_SCAN_RSP_DATA_SET_COMPLETE_EVT:
                handleScanRSPDataSetComplete()
            case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
                handleAdvertisementStartComplete(param: param)
            case ESP_GAP_BLE_ADV_STOP_COMPLETE_EVT:
                handleAdvertisementStopComplete(param: param)
            case ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT:
                handleUpdateConnectionParameters(param: param)
            default: break
        }
    }

    private func handleAdvertisementDataSetComplete() {
        advertisementState &= (~1)
        if advertisementState == 0 {
            startAdvertising()
        }
    }

    private func handleScanRSPDataSetComplete() {
        advertisementState &= (~2)
        if advertisementState == 0 {
            startAdvertising()
        }
    }

    private func handleAdvertisementStartComplete(param: UnsafeMutablePointer<esp_ble_gap_cb_param_t>?) {
        let advertisementStartCompleteEvent = read_ble_adv_start_cmpl_evt_param(param)
        if advertisementStartCompleteEvent.status != ESP_BT_STATUS_SUCCESS {
            print("Advertising start failed")
        }
    }

    private func handleAdvertisementStopComplete(param: UnsafeMutablePointer<esp_ble_gap_cb_param_t>?) {
        let advertisementStopCompleteEvent = read_ble_adv_stop_cmpl_evt_param(param)
        if advertisementStopCompleteEvent.status != ESP_BT_STATUS_SUCCESS {
            print("Advertising stop failed")
        } else {
            print("Stop advertisement was successful")
        }
    }

    private func handleUpdateConnectionParameters(param: UnsafeMutablePointer<esp_ble_gap_cb_param_t>?) {
        let event = read_ble_update_conn_params_evt_param(param)
        print("Updated connection parameters \(event.status.rawValue), \(event.min_int), \(event.max_int), \(event.conn_int), \(event.latency), \(event.timeout)")
    }

    private func handleMainGattsEvent(
        event: esp_gatts_cb_event_t, 
        gattsIF: esp_gatt_if_t, 
        param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?
    ) {
        switch event {
            case ESP_GATTS_REG_EVT:
                handleReadRegisterEvent(gattsIF: gattsIF, param: param)
            case ESP_GATTS_READ_EVT:
                handleReadEvent(gattsIF: gattsIF, param: param)
            case ESP_GATTS_WRITE_EVT:
                handleWriteEvent(gattsIF: gattsIF, param: param)
            case ESP_GATTS_EXEC_WRITE_EVT:
                handleExecWriteEvent(gattsIF: gattsIF, param: param)
            case ESP_GATTS_MTU_EVT:
                handleMTUEvent(param: param)
            case ESP_GATTS_START_EVT:
                handleStartEvent(param: param)
            case ESP_GATTS_CONNECT_EVT:
                handleConnectEvent(param: param)
            case ESP_GATTS_DISCONNECT_EVT:
                handleDisconnectEvent(param: param)
            case ESP_GATTS_CREAT_ATTR_TAB_EVT:
                handleCreateAttributeTableEvent(param: param)
            case ESP_GATTS_CONF_EVT:
                handleConfEvent(param: param)
            default: break
        }
    }

    private func handleReadRegisterEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("Register Event")
        let registerEvent = read_reg_evt_param(param)
        if registerEvent.status != ESP_GATT_OK {
            print("App registration failed with status \(registerEvent.status)")
            return
        }

        mainGattsIF = gattsIF

        // TODO: handle error.
        var error = safe_swift_esp_ble_gap_set_device_name()
        printErrorIfNeeded(error, title: "set device name ERROR")

        withUnsafeMutablePointer(to: &adv_data) { pointer in
            error = esp_ble_gap_config_adv_data(pointer);
        }
        printErrorIfNeeded(error, title: "esp_ble_gap_config_adv_data 1 ERROR")
        advertisementState |= 1

        withUnsafeMutablePointer(to: &scan_rsp_data) { pointer in
            error = esp_ble_gap_config_adv_data(pointer);
        }
        printErrorIfNeeded(error, title: "esp_ble_gap_config_adv_data 2 error")
        advertisementState |= 2

        var databaseElements = profile.services[0].databaseElements
        let databaseElementsLength = UInt16(databaseElements.count)
        databaseElements.withUnsafeMutableBufferPointer { buffer in
            error = esp_ble_gatts_create_attr_tab(buffer.baseAddress, gattsIF, databaseElementsLength, 0);
        }
        printErrorIfNeeded(error, title: "esp_ble_gatts_create_attr_tab error")
    }

    private func handleReadEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let readEvent = read_read_evt_param(param)
        print("Read event \(readEvent.conn_id), handle: \(readEvent.handle)")
    }

    private func handleWriteEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let writeEvent = read_write_evt_param(param)
        print("Write event. Handle: \(writeEvent.handle). Length: \(writeEvent.len). ConnectionID: \(writeEvent.conn_id)")

        if !writeEvent.is_prep {
            if writeEvent.len == 2 {
                let descriptorValue = UInt16(writeEvent.value[1] << 8) | UInt16(writeEvent.value[0])
                if descriptorValue == 0x0001 {
                    print("Notify enabled on handle: \(writeEvent.handle)")

                    let cccdHandle = writeEvent.handle
                    var cccdData: [UInt8] = [1, 0]
                    let cccdDataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
                    cccdDataPointer.initialize(from: &cccdData, count: 2)
                    let error = esp_ble_gatts_set_attr_value(cccdHandle, 2, cccdDataPointer)
                    printErrorIfNeeded(error, title: "esp_ble_gatts_set_attr_value error")
                } else if descriptorValue == 0x0001 {
                    print("Indicate enabled")
                }
            }
        }

        if writeEvent.need_rsp {
            let error = esp_ble_gatts_send_response(gattsIF, writeEvent.conn_id, writeEvent.trans_id, ESP_GATT_OK, nil)
            printErrorIfNeeded(error, title: "esp_ble_gatts_send_response error")
        }
    }

    private func handleExecWriteEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("GATTS EXEC WRITE Event")
        // TODO: update
        // let writeEvent = read_write_evt_param(param)
        // esp_ble_gatts_send_response(gattsIF, writeEvent.conn_id, writeEvent.trans_id, ESP_GATT_OK, nil)
    }

    private func handleMTUEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let mtu = read_mtu_evt_param(param)
        print("MTU \(mtu.mtu)")
    }

    private func handleStartEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("Service start event")
    }

    private func handleConnectEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("Connection event")
        let connectionEvent = read_connect_evt_param(param)
        var connectionParameters = esp_ble_conn_update_params_t(
            bda: connectionEvent.remote_bda,
            min_int: 0x10,
            max_int: 0x20,
            latency: 0,
            timeout: 400
        )
        esp_ble_gap_update_conn_params(&connectionParameters)
        connectionID = connectionEvent.conn_id
    }

    private func handleDisconnectEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let disconnectEvent = read_disconnect_evt_param(param)
        print("Disconnect reason: \(disconnectEvent.reason.rawValue)")

        connectionID = nil
        mainGattsIF = nil

        startAdvertising()
    }

    private func handleCreateAttributeTableEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        // The event contains esp_gatt_status_t: status, esp_bt_uuid_t: svc_uuid,
        // uint8_t: svc_inst_id, uint16_t: num_handle, uint16_t *handles
        let createAttributeEvent = read_add_attr_tab_evt_param(param)
        if createAttributeEvent.status != ESP_GATT_OK {
            print("Create Attribute Table failed with status \(createAttributeEvent.status)")
            return
        }
        print("CreateAttributeEvent \(createAttributeEvent.num_handle)")

        var handleIndex = 0
        for service in profile.services {
            let serviceHandle = UInt16(createAttributeEvent.handles[handleIndex])
            handleIndex += service.handlesCount

            let error = esp_ble_gatts_start_service(serviceHandle)
            printErrorIfNeeded(error, title: "esp_ble_gatts_start_service error")
        }

        handles.removeAll()
        let bufferPointer = UnsafeBufferPointer(start: createAttributeEvent.handles, count: Int(createAttributeEvent.num_handle))
        handles.append(contentsOf: Array(bufferPointer))
    }

    private func handleConfEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let confEvent = read_conf_evt_param(param)
        print("Conf status: \(confEvent.status), handle: \(confEvent.handle)")
        if confEvent.status != ESP_GATT_OK {
            print("Conference error \(confEvent.status.rawValue)")
        }
    }

    private func printErrorIfNeeded(_ error: esp_err_t, title: String) {
        guard error != ESP_OK else { return }
        print("\(title) \(error)")
    }

    private func startAdvertising() {
        esp_ble_gap_start_advertising(&advertisementParameters)
    }

}

fileprivate extension BLECharacteristicPermissions {
    var esp32Permissions: UInt16 {
        var value: UInt16 = 0
        if contains(.read) {
            value |= UInt16(ESP_GATT_PERM_READ)
        }
        if contains(.write) {
            value |= UInt16(ESP_GATT_PERM_WRITE)
        }
        return value
    }
}

fileprivate extension BLECharacteristicProperties {
    var esp32Properties: UInt8 {
        var value: UInt8 = 0
        if contains(.read) {
            value |= UInt8(ESP_GATT_CHAR_PROP_BIT_READ)
        }
        if contains(.write) {
            value |= UInt8(ESP_GATT_CHAR_PROP_BIT_WRITE)
        }
        if contains(.notify) {
            value |= UInt8(ESP_GATT_CHAR_PROP_BIT_NOTIFY)
        }
        return value
    }
}

fileprivate extension BLEService {
    var handlesCount: Int {
        var count = 0
        for characteristic in characteristics {
            count += characteristic.handlesCount
        }
        return count
    }

    var databaseElements: [esp_gatts_attr_db_t] {
        var elements = [esp_gatts_attr_db_t]()

        elements.append(databaseElementDeclaration)

        for characteristic in characteristics {
            elements.append(characteristic.databaseElementDeclaration)
            elements.append(characteristic.databaseElementValue)
            if let descriptor = characteristic.descriptor {
                elements.append(descriptor.databaseElementDescriptor)
            }
        }

        return elements
    }

    var databaseElementDeclaration: esp_gatts_attr_db_t {
        let control = esp_attr_control_t(auto_rsp: UInt8(ESP_GATT_AUTO_RSP))

        // Bytes need to be stored from LSB to MSB.
        var primaryUUIDBytes: [UInt8] = [
            UInt8(ESP_GATT_UUID_PRI_SERVICE & 0xFF),
            UInt8((ESP_GATT_UUID_PRI_SERVICE >> 8) & 0xFF),
        ]
        let primaryUUIDUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
        primaryUUIDUnsafePointer.initialize(from: &primaryUUIDBytes, count: 2)

        var uuidBytes = uuid.uuid
        let uuidBytesCount = uuidBytes.count
        let uuidUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidBytesCount)
        uuidUnsafePointer.initialize(from: &uuidBytes, count: uuidBytesCount)

        let description = esp_attr_desc_t(
            uuid_length: UInt16(ESP_UUID_LEN_16),
            uuid_p: primaryUUIDUnsafePointer,
            perm: UInt16(ESP_GATT_PERM_READ),
            max_length: 2,
            length: UInt16(uuidBytesCount),
            value: uuidUnsafePointer
        )

        return esp_gatts_attr_db_t(attr_control: control, att_desc: description)
    }
}

fileprivate extension BLECharacteristic {
    var handlesCount: Int {
        if descriptor != nil {
            return 3
        }
        return 2
    }

    var databaseElementDeclaration: esp_gatts_attr_db_t {
        let control = esp_attr_control_t(auto_rsp: UInt8(ESP_GATT_AUTO_RSP))

        // Bytes need to be stored from LSB to MSB.
        var uuidBytes: [UInt8] = [
            UInt8(ESP_GATT_UUID_CHAR_DECLARE & 0xFF),
            UInt8((ESP_GATT_UUID_CHAR_DECLARE >> 8) & 0xFF),
        ]
        let uuidUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
        uuidUnsafePointer.initialize(from: &uuidBytes, count: 2)

        var valueBytes: [UInt8] = [UInt8(properties.esp32Properties)]
        let valueUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        valueUnsafePointer.initialize(from: &valueBytes, count: 1)

        let description = esp_attr_desc_t(
            uuid_length: UInt16(ESP_UUID_LEN_16),
            uuid_p: uuidUnsafePointer,
            perm: UInt16(ESP_GATT_PERM_READ),
            max_length: 1,
            length: 1,
            value: valueUnsafePointer
        )

        return esp_gatts_attr_db_t(attr_control: control, att_desc: description)
    }

    var databaseElementValue: esp_gatts_attr_db_t {
        let control = esp_attr_control_t(auto_rsp: UInt8(ESP_GATT_AUTO_RSP))
        
        var uuidBytes = uuid.uuid
        let uuidBytesCount = uuidBytes.count
        let uuidUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidBytesCount)
        uuidUnsafePointer.initialize(from: &uuidBytes, count: uuidBytesCount)

        var valueBytes: [UInt8] = Array(repeating:0, count:4)
        let valueUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(dataLength))
        valueUnsafePointer.initialize(from: &valueBytes, count: Int(dataLength))

        let description = esp_attr_desc_t(
            uuid_length: uuid.length.rawLength,
            uuid_p: uuidUnsafePointer,
            perm: UInt16(permissions.esp32Permissions),
            max_length: 500, // TODO: check about this max value.
            length: dataLength,
            value: valueUnsafePointer
        )

        return esp_gatts_attr_db_t(attr_control: control, att_desc: description)
    }
}

fileprivate extension BLECharacteristicDescriptor {
    var databaseElementDescriptor: esp_gatts_attr_db_t {
        let control = esp_attr_control_t(auto_rsp: UInt8(ESP_GATT_AUTO_RSP))
        
        // Bytes need to be stored from LSB to MSB.
        var uuidBytes = uuid.uuid
        let uuidBytesCount = uuidBytes.count
        let uuidUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: uuidBytesCount)
        uuidUnsafePointer.initialize(from: &uuidBytes, count: uuidBytesCount)

        var valueBytes: [UInt8] = [0, 0]
        let valueUnsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
        valueUnsafePointer.initialize(from: &valueBytes, count: 2)

        let description = esp_attr_desc_t(
            uuid_length: UInt16(uuidBytesCount),
            uuid_p: uuidUnsafePointer,
            perm: UInt16(permissions.esp32Permissions),
            max_length: 2,
            length: 2,
            value: valueUnsafePointer
        )

        return esp_gatts_attr_db_t(attr_control: control, att_desc: description)
    }
}

extension BLEUUID {
    /// Use this UUID as the default description UUID for a characteristic.
    static let clientConfiguration = BLEUUID(uuid16: UInt16(ESP_GATT_UUID_CHAR_CLIENT_CONFIG))
}
