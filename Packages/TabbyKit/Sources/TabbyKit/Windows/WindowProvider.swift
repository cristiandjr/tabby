import AppKit
import ApplicationServices

@MainActor
public final class WindowProvider {
    public struct Diagnostics: Codable, Sendable {
        public var candidates = 0
        public var matchedByPrivateAPI = 0
        public var matchedByFrame = 0
        public var matchedByCache = 0
        public var unmatched = 0
        public var excludedBySubrole = 0
        public var excludedMinimized = 0
        public var excludedSystem = 0
        public var excludedOffScreen = 0
        public var unmatchedWindows: [String] = []

        public init() {}
    }

    public static let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
        "com.apple.Spotlight",
        "com.apple.screencaptureui",
    ]

    public private(set) var lastDiagnostics = Diagnostics()
    private let log = Log.logger("windows")
    private var elements: [CGWindowID: AXUIElement] = [:]
    private var systemProcesses: [pid_t: Bool] = [:]

    public init() {}

    public func element(for id: CGWindowID) -> AXUIElement? {
        elements[id]
    }

    public func snapshot() -> [MissionWindow] {
        var diagnostics = Diagnostics()
        let records = WindowFilter.candidates(CGWindowSource.onScreen(), excluding: [ProcessInfo.processInfo.processIdentifier])
        var axWindowsByPID: [pid_t: [AXUIElement]] = [:]
        var usedIndices: [pid_t: Set<Int>] = [:]
        var found: [CGWindowID: AXUIElement] = [:]
        var windows: [MissionWindow] = []

        for record in records {
            let app = NSRunningApplication(processIdentifier: record.pid)
            if let bundleID = app?.bundleIdentifier, Self.excludedBundleIDs.contains(bundleID) {
                diagnostics.excludedSystem += 1
                continue
            }
            if app?.activationPolicy == .prohibited {
                diagnostics.excludedSystem += 1
                continue
            }
            guard let display = Self.displayID(for: record.bounds) else {
                diagnostics.excludedOffScreen += 1
                continue
            }
            diagnostics.candidates += 1
            let axWindows = axWindows(for: record.pid, cache: &axWindowsByPID)
            var used = usedIndices[record.pid] ?? []
            let element: AXUIElement
            if let index = matchIndex(for: record, in: axWindows, excluding: used, diagnostics: &diagnostics) {
                used.insert(index)
                usedIndices[record.pid] = used
                element = axWindows[index]
            } else if let known = elements[record.id] {
                // After a desktop switch inside Mission Control, apps list their windows again only ~0.9 s later.
                diagnostics.matchedByCache += 1
                element = known
            } else {
                diagnostics.unmatched += 1
                diagnostics.unmatchedWindows.append("\(record.ownerName) \(Int(record.bounds.width))x\(Int(record.bounds.height))")
                continue
            }
            if AX.bool(element, kAXMinimizedAttribute) == true {
                diagnostics.excludedMinimized += 1
                continue
            }
            if let subrole = AX.string(element, kAXSubroleAttribute),
               subrole != kAXStandardWindowSubrole,
               subrole != kAXDialogSubrole {
                diagnostics.excludedBySubrole += 1
                continue
            }
            found[record.id] = element
            windows.append(MissionWindow(
                id: record.id,
                pid: record.pid,
                bundleID: app?.bundleIdentifier,
                appName: app?.localizedName ?? record.ownerName,
                title: AX.string(element, kAXTitleAttribute),
                frame: record.bounds,
                displayID: display,
                zIndex: windows.count
            ))
        }
        let alive = CGWindowSource.existingIDs()
        elements = elements.merging(found) { _, new in new }.filter { alive.contains($0.key) }
        lastDiagnostics = diagnostics
        log.info("snapshot: \(windows.count) windows · candidates \(diagnostics.candidates) · private API \(diagnostics.matchedByPrivateAPI) · by frame \(diagnostics.matchedByFrame) · cached \(diagnostics.matchedByCache) · unmatched \(diagnostics.unmatched) · off-screen \(diagnostics.excludedOffScreen) · minimized \(diagnostics.excludedMinimized) · subrole \(diagnostics.excludedBySubrole) · system \(diagnostics.excludedSystem)")
        return windows
    }

    public func visibleWindowIDs(on display: CGDirectDisplayID) -> Set<CGWindowID> {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let records = CGWindowSource.onScreen().filter { record in
            record.layer == 0 && record.alpha > 0.01 && record.pid != ownPID
                && !isSystemProcess(record.pid)
                && Self.displayID(for: record.bounds) == display
        }
        return Set(records.map(\.id))
    }

    private func isSystemProcess(_ pid: pid_t) -> Bool {
        if let known = systemProcesses[pid] { return known }
        let app = NSRunningApplication(processIdentifier: pid)
        let system = app.map { $0.activationPolicy == .prohibited || Self.excludedBundleIDs.contains($0.bundleIdentifier ?? "") } ?? false
        systemProcesses[pid] = system
        return system
    }

    private func axWindows(for pid: pid_t, cache: inout [pid_t: [AXUIElement]]) -> [AXUIElement] {
        if let cached = cache[pid] { return cached }
        let list = AX.elements(AX.application(pid), kAXWindowsAttribute)
        cache[pid] = list
        return list
    }

    private func matchIndex(
        for record: CGWindowRecord,
        in axWindows: [AXUIElement],
        excluding used: Set<Int>,
        diagnostics: inout Diagnostics
    ) -> Int? {
        if PrivateAXBridge.isAvailable,
           let index = axWindows.indices.first(where: { !used.contains($0) && PrivateAXBridge.windowID(of: axWindows[$0]) == record.id }) {
            diagnostics.matchedByPrivateAPI += 1
            return index
        }
        let index = axWindows.indices.first { candidate in
            guard !used.contains(candidate), let frame = AX.frame(axWindows[candidate]) else { return false }
            return abs(frame.minX - record.bounds.minX) <= 2
                && abs(frame.minY - record.bounds.minY) <= 2
                && abs(frame.width - record.bounds.width) <= 2
                && abs(frame.height - record.bounds.height) <= 2
        }
        if index != nil { diagnostics.matchedByFrame += 1 }
        return index
    }

    // A window that touches no display belongs nowhere: parked off-screen, or passing by while Mission Control slides desktops.
    static func displayID(for frame: CGRect) -> CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetDisplaysWithRect(frame, 8, &displays, &count) == .success, count > 0 else { return nil }
        return display(for: frame, among: displays.prefix(Int(count)).map { ($0, CGDisplayBounds($0)) })
    }

    static func display(for frame: CGRect, among displays: [(id: CGDirectDisplayID, bounds: CGRect)]) -> CGDirectDisplayID? {
        func overlap(_ bounds: CGRect) -> CGFloat {
            let shared = bounds.intersection(frame)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        return displays.filter { overlap($0.bounds) > 0 }.max { overlap($0.bounds) < overlap($1.bounds) }?.id
    }
}
