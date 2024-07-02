final class ESP32I2CController: I2CController {
    
    let masterPort: i2c_port_t
    let masterFrequency: UInt32
    let sdaPin: Int32
    let sclPin: Int32
    let enableSDAPullup: Bool
    let enableSCLPullup: Bool
    let masterRXBufferLength: Int
    let masterTXBufferLength: Int

    init(
        masterPort: i2c_port_t,
        masterFrequency: UInt32 = 400000,
        sdaPin: Int32,
        sclPin: Int32,
        enableSDAPullup: Bool = true,
        enableSCLPullup: Bool = true,
        masterRXBufferLength: Int = 0,
        masterTXBufferLength: Int = 0
    ) {
        self.masterPort = masterPort
        self.masterFrequency = masterFrequency
        self.sdaPin = sdaPin
        self.sclPin = sclPin
        self.enableSDAPullup = enableSDAPullup
        self.enableSCLPullup = enableSCLPullup
        self.masterRXBufferLength = masterRXBufferLength
        self.masterTXBufferLength = masterTXBufferLength
    }

    func setup() throws (I2CControllerError) {
        var configuration = i2c_config_t()
        configuration.mode = I2C_MODE_MASTER
        configuration.sda_io_num = sdaPin
        configuration.scl_io_num = sclPin
        configuration.sda_pullup_en = enableSDAPullup
        configuration.scl_pullup_en = enableSCLPullup
        configuration.master.clk_speed = masterFrequency

        i2c_param_config(masterPort, &configuration);

        let result = i2c_driver_install(
            masterPort,
            configuration.mode, 
            masterRXBufferLength, 
            masterTXBufferLength, 
            0 // intr_alloc_flags
        )
        guard let controllerError = I2CControllerError(result) else { return }
        throw controllerError
    }

    func writeReadRawData(
        _ writeData: [UInt8],
        deviceAddress: UInt8,  
        length: Int,
        timeout: UInt32
    ) throws (I2CControllerError) -> [UInt8] {
        guard writeData.count > 0, length > 0 else { throw I2CControllerError.invalidLength }
        var readData = Array(repeating: UInt8(0x00), count: length)
        let result = i2c_master_write_read_device(
            masterPort,
            deviceAddress,
            writeData,
            writeData.count,
            &readData,
            length,
            timeout
        )
        if let controllerError = I2CControllerError(result) {
            throw controllerError
        }
        return readData
    }

    func writeRawData(
        _ data: [UInt8],
        deviceAddress: UInt8,  
        timeout: UInt32
    ) throws (I2CControllerError) {
        guard !data.isEmpty else { throw I2CControllerError.invalidLength }
        let length = data.count
        let result = i2c_master_write_to_device(
            masterPort, 
            deviceAddress, 
            data, 
            length, 
            timeout
        )
        if let controllerError = I2CControllerError(result) { 
            throw controllerError
        }
    }
}

fileprivate extension I2CControllerError {
    init?(_ error: esp_err_t) {
        guard error != ESP_OK else { return nil }
        switch error {
            case ESP_ERR_INVALID_ARG:
                self = .invalidArgument
            case ESP_FAIL: 
                self = .fail
            case ESP_ERR_INVALID_STATE:
                self = .invalidState
            case ESP_ERR_TIMEOUT: 
                self = .timeout
            default:
                self = .undefined(error)
        }
    }
}