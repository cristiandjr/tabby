public enum SessionAction: Hashable, Codable, Sendable {
    case next
    case previous
    case activate
    case moveToDesktop(Int)

    public var repeatsWhenHeld: Bool {
        switch self {
        case .next, .previous:
            true
        case .activate, .moveToDesktop:
            false
        }
    }
}
