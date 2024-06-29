
struct GattsProfile {
    let gattsEventHandler: ESP32BLEController.GattsEventHandler
    var gattsIF: UInt16
    var serviceHandle: UInt16
    var serviceID: esp_gatt_srvc_id_t
    var charHandle: UInt16
    var charUUID: esp_bt_uuid_t
    var descrUUID: esp_bt_uuid_t
}

final class ESP32BLEController {

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

    private var profile: GattsProfile
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

    init(profile: GattsProfile) { 
        
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
                handleExecWriteEvent(gattsIF: gattsIF, param: param)
            case ESP_GATTS_MTU_EVT:
                handleMTUEvent(param: param)
            case ESP_GATTS_CREATE_EVT:
                handleCreateEvent(param: param)
            case ESP_GATTS_ADD_CHAR_EVT:
                handleAddCharEvent(param: param)
            case ESP_GATTS_START_EVT:
                handleStartEvent(param: param)
            case ESP_GATTS_CONNECT_EVT:
                handleConnectEvent(param: param)
            case ESP_GATTS_DISCONNECT_EVT:
                handleDisconnectEvent(param: param)
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

        profile.serviceID.is_primary = true
        profile.serviceID.id.inst_id = 0x00
        profile.serviceID.id.uuid.len = UInt16(ESP_UUID_LEN_16)
        profile.serviceID.id.uuid.uuid.uuid16 = 0x00FF

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

        var serviceID = profile.serviceID
        withUnsafeMutablePointer(to: &serviceID) { pointer in
            error = esp_ble_gatts_create_service(gattsIF, pointer, 4)
        }
        printErrorIfNeeded(error, title: "esp_ble_gatts_create_service error")
    }

    private func handleReadEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let readEvent = read_read_evt_param(param)
        print("Read event \(readEvent.conn_id)")
        var responseValue = safe_build_esp_gatt_value_t()
        responseValue.handle = readEvent.handle
        responseValue.len = 4
        update_gatt_value(&responseValue, 0, 0)
        update_gatt_value(&responseValue, 1, 1)
        update_gatt_value(&responseValue, 2, 2)
        update_gatt_value(&responseValue, 3, 3)
        var response = esp_gatt_rsp_t(attr_value: responseValue)
        withUnsafeMutablePointer(to: &response) { pointer in
            esp_ble_gatts_send_response(gattsIF, readEvent.conn_id, readEvent.trans_id, ESP_GATT_OK, pointer)
        }
    }

    private func handleWriteEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {

    }

    private func handleExecWriteEvent(gattsIF: esp_gatt_if_t, param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("GATTS EXEC WRITE Event")
        let writeEvent = read_write_evt_param(param)
        esp_ble_gatts_send_response(gattsIF, writeEvent.conn_id, writeEvent.trans_id, ESP_GATT_OK, nil)
    }

    private func handleMTUEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let mtu = read_mtu_evt_param(param)
        print("MTU \(mtu.mtu)")
    }

    private func handleCreateEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("Create Event")

        let createEvent = read_create_evt_param(param)
        profile.serviceHandle = createEvent.service_handle
        profile.charUUID.len = UInt16(ESP_UUID_LEN_16)
        profile.charUUID.uuid.uuid16 = 0xFF01

        esp_ble_gatts_start_service(profile.serviceHandle)

        var error = ESP_OK
        withUnsafeMutablePointer(to: &profile.charUUID) { charUUIDPointer in
            withUnsafeMutablePointer(to: &characteristicAttributeValue) { characteristicAttributeValuePointer in
                error = esp_ble_gatts_add_char(
                    profile.serviceHandle,
                    charUUIDPointer,
                    UInt16(ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE),
                    UInt8(ESP_GATT_CHAR_PROP_BIT_READ | ESP_GATT_CHAR_PROP_BIT_WRITE | ESP_GATT_CHAR_PROP_BIT_NOTIFY),
                    characteristicAttributeValuePointer,
                    nil
                )
            }
        }
        printErrorIfNeeded(error, title: "esp_ble_gatts_start_service error")

    }

    private func handleAddCharEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        print("Add characteristic event")

        let addCharacteristicEvent = read_add_char_evt_param(param)
        profile.charHandle = addCharacteristicEvent.attr_handle
        profile.descrUUID.len = UInt16(ESP_UUID_LEN_16)
        profile.descrUUID.uuid.uuid16 = UInt16(ESP_GATT_UUID_CHAR_CLIENT_CONFIG)

        var error = swift_temp_esp_ble_gatts_get_attr_value(addCharacteristicEvent.attr_handle)
        printErrorIfNeeded(error, title: "swift_temp_esp_ble_gatts_get_attr_value error")

        withUnsafeMutablePointer(to: &profile.descrUUID) { pointer in
            error = esp_ble_gatts_add_char_descr(
                profile.serviceHandle,
                pointer,
                UInt16(ESP_GATT_PERM_READ | ESP_GATT_PERM_WRITE),
                nil,
                nil
            )
        }
        printErrorIfNeeded(error, title: "esp_ble_gatts_add_char_descr error")
    }

    private func handleAddCharDescriptionEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        
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
        withUnsafeMutablePointer(to: &connectionParameters) { pointer in
            esp_ble_gap_update_conn_params(pointer)
        }
    }

    private func handleDisconnectEvent(param: UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) {
        let disconnectEvent = read_disconnect_evt_param(param)
        print("Disconnect reason: \(disconnectEvent.reason.rawValue)")
        startAdvertising()
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
        withUnsafeMutablePointer(to: &advertisementParameters) { pointer in
            esp_ble_gap_start_advertising(pointer)
        }
    }

}