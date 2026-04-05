import Foundation

struct KeywordInterpreter: CommandInterpreter {

    private static let defaultThrottle: Float = 0.4

    func interpret(_ text: String) -> AgentAction {
        let command = text.trimmingCharacters(in: .whitespaces).lowercased()
        switch command {
        case "/forward":
            return .move(direction: .forward, throttle: Self.defaultThrottle)
        case "/backward":
            return .move(direction: .backward, throttle: Self.defaultThrottle)
        case "/left":
            return .move(direction: .left, throttle: Self.defaultThrottle)
        case "/right":
            return .move(direction: .right, throttle: Self.defaultThrottle)
        case "/stop":
            return .stop
        case "/status":
            return .queryStatus
        default:
            return .unknown(raw: text)
        }
    }
}
