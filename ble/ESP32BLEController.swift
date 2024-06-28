
struct GattsProfile {
    let gattsEventHandler: ESP32BLEController.GattsEventHandler
    let gattsIF: UInt16
    var serviceHandle: UInt16
    let serviceID: esp_gatt_srvc_id_t
    let charHandle: UInt16
    let charUUID: esp_bt_uuid_t
    let descrUUID: esp_bt_uuid_t
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

    init(
        profile: GattsProfile
    ) { 
        BLESingleton.shared.gattsEventHandler = { (event, gattsIF, param) in
            
        }
        BLESingleton.shared.gapEventHandler = { (event, param) in
            
        }

        // TODO: handle errors.
        var defaultConfiguration = buildDefaultBTControllerConfiguration()
        _ = esp_bt_controller_init(&defaultConfiguration)

        _ = esp_bt_controller_enable(ESP_BT_MODE_BLE)

        _ = esp_bluedroid_init()

        _ = esp_bluedroid_enable()

        _ = esp_ble_gatts_register_callback({ (event, gattsIF, param) in
            // Call the singleton as capturing objects is not allowed on c closures.
            BLESingleton.shared.gattsEventHandler?(event, gattsIF, param)
        })

        _ = esp_ble_gap_register_callback({ (event, param) in
            // Call the singleton as capturing objects is not allowed on c closures.
            BLESingleton.shared.gapEventHandler?(event, param)
        })

        _ = esp_ble_gatts_app_register(0)

        _ = esp_ble_gatt_set_local_mtu(500)
    }

}