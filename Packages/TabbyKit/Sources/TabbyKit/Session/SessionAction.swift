public enum SessionAction: Hashable, Codable, Sendable {
    case next
    case previous
    case activate

    public var repeatsWhenHeld: Bool {
        self != .activate
    }
}
