// Main.

// typealias GattsEventHandler = @convention(c) (esp_gatts_cb_event_t, esp_gatt_if_t, UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) -> Void
// typealias FakeEventHandler = (esp_gatts_cb_event_t, esp_gatt_if_t, UnsafeMutablePointer<esp_ble_gatts_cb_param_t>?) -> Void

// final class BLESingleton {
//   static let shared = BLESingleton()

//   var callback: FakeEventHandler?

//   init() { }
// }

@_cdecl("app_main")
func app_main() {
  print("🏎️   Hello, Embedded Swift!")

  // _ = esp_bt_controller_enable(ESP_BT_MODE_BLE)
  // BLESingleton.shared.callback = { (event, gatts_if, param) in
  // }
  // let gatts_event_handler: GattsEventHandler = { (event, gatts_if, param) in
  //   BLESingleton.shared.callback?(event, gatts_if, param)
  // }
  // _ = esp_ble_gatts_register_callback(gatts_event_handler)

  // let deleteMe = DeleteMe()
  let i2CController = ESP32I2CController(
    masterPort: I2C_NUM_0,
    sdaPin: 6,
    sclPin: 7
  )
  do {
    try i2CController.setup()
  } catch {
    print("I2C Setup Error: \(error)")
    return
  }

  let ltr390 = LTR390Impl(i2CController: i2CController)
  do {
    try ltr390.setup()
  } catch (let error) {
    print("Error \(error)")
  }

  while (true) {
    do {
      try ltr390.setupInALSMode()
      vTaskDelay(150)
      let luminosity = try ltr390.readLuminosity()
      print("Luminosity: \(Int(luminosity))")

      try ltr390.setupInUVMode()
      vTaskDelay(150)
      let uvIndex = try ltr390.readUVIndex()
      print("UVIndex: \(Int(uvIndex))")
    } catch {
      print("LTR390 Read Error: \(error)")
    }
  }
}

extension LTR390 {
  func setup() throws(LTR390Error) {
    try writeGain(.eighteen)
    print("Gain: \(try readGain().rawValue)")

    try writeResolution(.twentyBit)
    print("Resolution: \(try readResolution().rawValue)")
  }

  func setupInUVMode() throws(LTR390Error) {
    try writeMode(.UV, enableLightSensor: true)
    // print("Mode: \(try readMode().rawValue)")
  }

  func setupInALSMode() throws(LTR390Error) {
    try writeMode(.ALS, enableLightSensor: true)
    // print("Mode: \(try readMode().rawValue)")
  }
}
