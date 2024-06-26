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

    func readRawData(
        deviceAddress: UInt8, 
        registerAddress: UInt8, 
        length: Int,
        timeout: UInt32
    ) throws (I2CControllerError) -> [UInt8] {
        guard length > 0 else { throw I2CControllerError.invalidLength }
        var data = Array(repeating: UInt8(0xFF), count: length)
        let registerAddressArray = [registerAddress]
        let result = i2c_master_write_read_device(
            masterPort,
            deviceAddress,
            registerAddressArray,
            1,
            &data,
            length,
            timeout
        );
        guard let controllerError = I2CControllerError(result) else { return data }
        throw controllerError
    }

    func writeRawData(
        _ data: [UInt8],
        deviceAddress: UInt8, 
        registerAddress: UInt8, 
        timeout: UInt32
    ) throws (I2CControllerError) {
        guard !data.isEmpty else { throw I2CControllerError.invalidLength }
        var rawData = [registerAddress]
        rawData.append(contentsOf: data)
        let length = rawData.count
        let result = i2c_master_write_to_device(
            masterPort, 
            deviceAddress, 
            rawData, 
            length, 
            timeout
        )
        guard let controllerError = I2CControllerError(result) else { return }
        throw controllerError
    }
}

extension I2CControllerError {
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