// Main.

var bleController: ESP32BLEController?
var globalLuminosity: UInt32 = 0

@_cdecl("app_main")
func app_main() {
  print("🏎️   Hello, Embedded Swift Example!")

  let bleProfile = BLEProfile(
    services: [
      BLEService(
        uuid: BLEUUID(uuid16: 0x00FF),
        primary: true,
        characteristics: [
          BLECharacteristic(
            uuid: BLEUUID(uuid16: 0xFF01),
            dataLength: 4,
            permissions: [.read, .write],
            properties: [.read, .write, .notify],
            description: BLECharacteristicDescription(
              uuid: .clientConfiguration,
              permissions: [.read, .write]
            )
          )
        ]
      )
    ]
  )

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
    print("LTR390 Setup error: \(error)")
    return
  }

  let taskDelayController = ESP32TaskDelayController()
  let aht20 = AHT20Impl(
    i2CController: i2CController,
    taskDelayController: taskDelayController
  )
  do {
    try aht20.setup()
  } catch (let error) {
    print("AHT20 Setup error: \(error)")
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

  // Start the BLE operation.  
  bleController = ESP32BLEController(
    profile: bleProfile,
    readEventHandler: readEventHandler
  )

  while (true) {
    do {
      // try ltr390.setupInALSMode()
      
      taskDelayController.delay(milliseconds: 1500)
      
      let luminosity = try ltr390.readLuminosity()
      globalLuminosity = UInt32(luminosity)
      print("Luminosity: \(globalLuminosity)")

      // try ltr390.setupInUVMode()
      // vTaskDelay(150)
      // taskDelayController.delay(milliseconds: 1500)
      // let uvIndex = try ltr390.readUVIndex()
      // print("UVIndex: \(Int(uvIndex))")
    } catch {
      print("LTR390 Error")
    }

    do {
      let aht20Data = try aht20.readData(polling: true)
      print("Temperature: \(UInt32(aht20Data.temperature))")
      print("Humidity: \(UInt32(aht20Data.humidity))")
    } catch {
      print("AHT20 Error")
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

extension BLEUUID {
  /// The characteristic UUID used for the luminosity.
  static let luminosity = BLEUUID(uuid16: 0x00FF)
}