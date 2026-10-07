import AppKit
import ApplicationServices

@MainActor
public final class WindowProvider {
    public struct Diagnostics: Codable, Sendable {
        public var candidates = 0
        public var matchedByPrivateAPI = 0
        public var matchedByFrame = 0
        public var unmatched = 0
        public var excludedBySubrole = 0
        public var excludedMinimized = 0
        public var excludedSystem = 0

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
    private var elements: [CGWindowID: AXUIElement] = [:]

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
            diagnostics.candidates += 1
            let axWindows = axWindows(for: record.pid, cache: &axWindowsByPID)
            var used = usedIndices[record.pid] ?? []
            guard let index = matchIndex(for: record, in: axWindows, excluding: used, diagnostics: &diagnostics) else {
                diagnostics.unmatched += 1
                continue
            }
            used.insert(index)
            usedIndices[record.pid] = used
            let element = axWindows[index]
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
                displayID: Self.displayID(for: record.bounds),
                zIndex: windows.count
            ))
        }
        elements = found
        lastDiagnostics = diagnostics
        return windows
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

    private static func displayID(for frame: CGRect) -> CGDirectDisplayID {
        var display: CGDirectDisplayID = 0
        var count: UInt32 = 0
        CGGetDisplaysWithPoint(CGPoint(x: frame.midX, y: frame.midY), 1, &display, &count)
        return count > 0 ? display : CGMainDisplayID()
    }
}
