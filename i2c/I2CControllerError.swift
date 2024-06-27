enum I2CControllerError: Error {
    case invalidLength
    case invalidArgument
    case fail
    case invalidState
    case timeout
    case undefined(Int32)
}
