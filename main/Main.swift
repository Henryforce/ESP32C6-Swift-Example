// Main.

var bleController: ESP32BLEController?
var globalAmbientLight: UInt32 = 0
var globalUVIndex: UInt32 = 0
var globalTemperature: Int32 = 0
var globalHumidity: UInt32 = 0

@_cdecl("app_main")
func app_main() {
  print("🏎️   Hello, Embedded Swift Example!")

  let bleProfile = BLEProfile(
    services: [
      BLEService(
        uuid: .weatherNode,
        primary: true,
        characteristics: [
          .ambientLight,
          .uvIndex,
          .temperature,
          .humidity,
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

  let readEventHandler: BLEReadEventHandler = { characteristic in
    if characteristic.uuid == .ambientLight {
      return globalAmbientLight.toUInt8Array()
    } else if characteristic.uuid == .uvIndex {
      return globalUVIndex.toUInt8Array()
    } else if characteristic.uuid == .humidity {
      return globalHumidity.toUInt8Array()
    } else if characteristic.uuid == .temperature {
      return globalTemperature.toUInt8Array()
    }
    return [0, 0, 0, 0]
  }

  // Start the BLE operation.  
  bleController = ESP32BLEController(
    profile: bleProfile,
    readEventHandler: readEventHandler
  )

  while (true) {
    do {
      try ltr390.setupInALSMode()
      
      taskDelayController.delay(milliseconds: 1500)
      
      let luminosity = try ltr390.readLuminosity()
      globalAmbientLight = UInt32(luminosity)
      print("Luminosity: \(globalAmbientLight)")

      try ltr390.setupInUVMode()
      taskDelayController.delay(milliseconds: 1500)
      let uvIndex = try ltr390.readUVIndex()
      globalUVIndex = UInt32(uvIndex)
      print("UVIndex: \(globalUVIndex)")
    } catch {
      print("LTR390 Error")
    }

    do {
      let aht20Data = try aht20.readData(polling: true)
      globalTemperature = Int32(aht20Data.temperature)
      globalHumidity = UInt32(aht20Data.humidity)
      print("Temperature: \(globalTemperature)")
      print("Humidity: \(globalHumidity)")
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

fileprivate extension UInt32 {
  func toUInt8Array() -> [UInt8] {
    let value = self
    return [
        UInt8(value >> 24),
        UInt8((value & 0xFF0000) >> 16),
        UInt8((value & 0xFF00) >> 8),
        UInt8(value & 0xFF),
    ]
  }
}

fileprivate extension Int32 {
  func toUInt8Array() -> [UInt8] {
    let value = self
    return [
        UInt8(value >> 24),
        UInt8((value & 0xFF0000) >> 16),
        UInt8((value & 0xFF00) >> 8),
        UInt8(value & 0xFF),
    ]
  }
}