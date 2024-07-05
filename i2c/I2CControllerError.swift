enum I2CControllerError: Error {
    case invalidLength
    case invalidArgument
    case fail
    case invalidState
    case timeout
    case undefined(Int32)

    var description: String {
        switch self {
            case .invalidLength: return "invalidLength"
            case .invalidArgument: return "invalidArgument"
            case .fail: return "fail"
            case .invalidState: return "invalidState"
            case .timeout: return "timeout"
            case .undefined: return "Undefined"
        }
    }
}
