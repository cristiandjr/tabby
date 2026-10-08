struct MissionControlDetector {
    enum Change: Equatable {
        case opened
        case closed
    }

    static let closedReadingsToConfirm = 2

    private(set) var isOpen = false
    private var closedReadings = 0

    mutating func feed(_ reading: Bool?) -> Change? {
        guard let reading else { return nil }
        if reading {
            closedReadings = 0
            guard !isOpen else { return nil }
            isOpen = true
            return .opened
        }
        guard isOpen else { return nil }
        closedReadings += 1
        guard closedReadings >= Self.closedReadingsToConfirm else { return nil }
        reset()
        return .closed
    }

    mutating func reset() {
        isOpen = false
        closedReadings = 0
    }
}
