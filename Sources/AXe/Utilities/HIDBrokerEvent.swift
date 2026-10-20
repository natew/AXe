import Foundation
import FBSimulatorControl

// the wire representation covers every native event without changing its timing or transport.
indirect enum HIDBrokerEvent: Codable {
    case touch(Int32, Double, Double)
    case button(Int32, Int32)
    case keyboard(Int32, UInt32)
    case twoFingerTouch(Int32, CGPoint, CGPoint)
    case delay(TimeInterval)
    case deviceOrientation(Int32)
    case shake
    case toggleInCallStatusBar
    case lockDevice
    case composite([HIDBrokerEvent])

    init(_ event: FBSimulatorHIDEvent) throws {
        switch event {
        case let .touch(direction, x, y): self = .touch(direction.rawValue, x, y)
        case let .button(direction, button): self = .button(direction.rawValue, button.rawValue)
        case let .keyboard(direction, keyCode): self = .keyboard(direction.rawValue, keyCode)
        case let .twoFingerTouch(direction, finger1, finger2):
            self = .twoFingerTouch(direction.rawValue, finger1, finger2)
        case let .delay(duration): self = .delay(duration)
        case let .deviceOrientation(orientation): self = .deviceOrientation(orientation.rawValue)
        case .shake: self = .shake
        case .toggleInCallStatusBar: self = .toggleInCallStatusBar
        case .lockDevice: self = .lockDevice
        case let .composite(events): self = .composite(try events.map(Self.init))
        @unknown default: throw CLIError(errorDescription: "Unsupported HID event.")
        }
    }

    var durationBudget: TimeInterval {
        get throws {
            switch self {
            case let .delay(seconds):
                guard seconds.isFinite, seconds >= 0, seconds <= 86_400 else {
                    throw CLIError(errorDescription: "Invalid HID delay.")
                }
                return seconds
            case .keyboard: return 0.1
            case let .composite(events): return try events.reduce(0) { try $0 + $1.durationBudget }
            default: return 0
            }
        }
    }

    func nativeEvent() throws -> FBSimulatorHIDEvent {
        func direction(_ raw: Int32) throws -> FBSimulatorHIDDirection {
            guard let value = FBSimulatorHIDDirection(rawValue: raw) else {
                throw CLIError(errorDescription: "Invalid HID direction.")
            }
            return value
        }
        switch self {
        case let .touch(raw, x, y): return .touch(direction: try direction(raw), x: x, y: y)
        case let .button(raw, button):
            guard let value = FBSimulatorHIDButton(rawValue: button) else {
                throw CLIError(errorDescription: "Invalid HID button.")
            }
            return .button(direction: try direction(raw), button: value)
        case let .keyboard(raw, keyCode): return .keyboard(direction: try direction(raw), keyCode: keyCode)
        case let .twoFingerTouch(raw, finger1, finger2):
            return .twoFingerTouch(direction: try direction(raw), finger1: finger1, finger2: finger2)
        case let .delay(duration): return .delay(duration)
        case let .deviceOrientation(raw):
            guard let value = FBSimulatorHIDDeviceOrientation(rawValue: raw) else {
                throw CLIError(errorDescription: "Invalid HID orientation.")
            }
            return .deviceOrientation(value)
        case .shake: return .shake
        case .toggleInCallStatusBar: return .toggleInCallStatusBar
        case .lockDevice: return .lockDevice
        case let .composite(events): return .composite(try events.map { try $0.nativeEvent() })
        }
    }
}
