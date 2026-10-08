public protocol SessionClock: Sendable {
    var now: ContinuousClock.Instant { get }
    func sleep(for duration: Duration, tolerance: Duration?) async
}

extension SessionClock {
    public func sleep(for duration: Duration) async {
        await sleep(for: duration, tolerance: nil)
    }
}

public struct SystemClock: SessionClock {
    public init() {}

    public var now: ContinuousClock.Instant {
        ContinuousClock().now
    }

    public func sleep(for duration: Duration, tolerance: Duration?) async {
        try? await Task.sleep(for: duration, tolerance: tolerance)
    }
}
