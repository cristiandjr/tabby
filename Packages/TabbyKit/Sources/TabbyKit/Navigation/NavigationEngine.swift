import CoreGraphics

public struct NavigationEngine: Sendable {
    public private(set) var windowIDs: [CGWindowID]
    public private(set) var selectedID: CGWindowID?

    public init(windowIDs: [CGWindowID], initialIndex: Int = 1) {
        self.windowIDs = windowIDs
        selectedID = windowIDs.isEmpty ? nil : windowIDs[min(max(initialIndex, 0), windowIDs.count - 1)]
    }

    public var selectedIndex: Int? {
        selectedID.flatMap { windowIDs.firstIndex(of: $0) }
    }

    public mutating func next() {
        move(by: 1)
    }

    public mutating func previous() {
        move(by: -1)
    }

    public mutating func update(windowIDs newIDs: [CGWindowID]) {
        let previousIndex = selectedIndex
        windowIDs = newIDs
        guard !newIDs.isEmpty else {
            selectedID = nil
            return
        }
        if let selectedID, newIDs.contains(selectedID) { return }
        selectedID = newIDs[min(previousIndex ?? 0, newIDs.count - 1)]
    }

    private mutating func move(by offset: Int) {
        guard !windowIDs.isEmpty else { return }
        let count = windowIDs.count
        let current = selectedIndex ?? 0
        selectedID = windowIDs[((current + offset) % count + count) % count]
    }
}
