// Main.

var bleController: ESP32BLEController?
var globalLuminosity: UInt32 = 0

@_cdecl("app_main")
func app_main() {
  print("🏎️   Hello, Embedded Swift!")

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
    try ltr390.setupInALSMode()
  } catch (let error) {
    print("Error \(error)")
    return
  }

  let readEventHandler: BLEReadEventHandler = {
    let luminosity = globalLuminosity
    return [
        0,
        UInt8((luminosity & 0xFF0000) >> 16),
        UInt8((luminosity & 0xFF00) >> 8),
        UInt8(luminosity & 0xFF),
    ]
  }
  // TODO: clean up this ble init.
  let uuid = esp_bt_uuid_t(len: 2, uuid: esp_bt_uuid_t.__Unnamed_union_uuid(uuid16: 0x00FF))
  let id = esp_gatt_id_t(uuid: uuid, inst_id: 0)
  let serviceID = esp_gatt_srvc_id_t(id: id, is_primary: true)
  let profile = GattsProfile(
    gattsIF: UInt16(ESP_GATT_IF_NONE), // Initial is always ESP_GATT_IF_NONE
    serviceHandle: 0, // It will be later updated.
    serviceID: serviceID,
    charHandle: 0, // It will be later updated.
    charUUID: esp_bt_uuid_t(len: 2, uuid: esp_bt_uuid_t.__Unnamed_union_uuid(uuid16: 0xFF01)),
    descrUUID: esp_bt_uuid_t(len: 2, uuid: esp_bt_uuid_t.__Unnamed_union_uuid(uuid16: UInt16(ESP_GATT_UUID_CHAR_CLIENT_CONFIG)))
  )
  bleController = ESP32BLEController(
    profile: profile,
    readEventHandler: readEventHandler
  )

  while (true) {
    do {
      // try ltr390.setupInALSMode()
      vTaskDelay(150)
      // globalLuminosity = try ltr390.readRawLuminosity() 
      let luminosity = try ltr390.readLuminosity()
      globalLuminosity = UInt32(luminosity)
      print("Luminosity: \(globalLuminosity)")

      // try ltr390.setupInUVMode()
      // vTaskDelay(150)
      // let uvIndex = try ltr390.readUVIndex()
      // print("UVIndex: \(Int(uvIndex))")
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
