import CoreGraphics
import Foundation
import TabbyKit

struct ProbeReport: Codable {
    struct Screen: Codable {
        var name: String
        var frame: CGRect
        var scale: Double
    }

    struct Permissions: Codable {
        var accessibility = SystemStatus.accessibilityTrusted
        var inputMonitoring = SystemStatus.listenEventAccess
        var postEvents = SystemStatus.postEventAccess
        var secureInput = SystemStatus.secureInputEnabled
    }

    struct WindowSummary: Codable {
        var count = 0
        var apps: [String] = []
        var diagnostics = WindowProvider.Diagnostics()
        var missingFromReference = 0
        var newComparedToReference = 0
        var snapshotMs: Double?

        init() {}

        init(windows: [MissionWindow], diagnostics: WindowProvider.Diagnostics, reference: Set<CGWindowID>?, snapshotMs: Double) {
            count = windows.count
            apps = windows.map(\.appName)
            self.diagnostics = diagnostics
            self.snapshotMs = snapshotMs
            if let reference {
                let ids = Set(windows.map(\.id))
                missingFromReference = reference.subtracting(ids).count
                newComparedToReference = ids.subtracting(reference).count
            }
        }
    }

    struct Event: Codable {
        var name: String
        var atMs: Double
        var phase: String
    }

    struct Trigger: Codable {
        var keyCode: Int
        var modifiers: String
        var latencyMs: Double
    }

    struct DockTree: Codable {
        var label: String
        var file: String
        var nodes: Int
        var pressable: Int
        var withFrame: Int
        var readMs: Double
    }

    struct Session: Codable {
        var index: Int
        var windows: Int
        var snapshotMs: Double
        var thumbnailsFound = 0
        var thumbnailSearchMs: Double?
        var secureInput: Bool
        var keys: [String: Int] = [:]
        var endReason: String?
    }

    struct Attempt: Codable {
        var index: Int
        var strategy: String
        var targetApp: String
        var exactWindow: Bool
        var rightApp: Bool
        var missionControlExitMs: Double?
        var missionControlStayedOpen: Bool
        var detail: [String: String]
    }

    var tool = "tabby-probe 0.1"
    var startedAt = Date()
    var finishedAt: Date?
    var macOS = SystemStatus.macOSVersion
    var permissions = Permissions()
    var privateWindowAPI = PrivateAXBridge.isAvailable
    var screens: [Screen] = []
    var observerRegistration: [String: String] = [:]
    var tapInstalled = false
    var tapDisabledBySystem = 0
    var windowsBefore = WindowSummary()
    var windowsDuringMissionControl = WindowSummary()
    var events: [Event] = []
    var triggers: [Trigger] = []
    var dockTrees: [DockTree] = []
    var nativeKeys: [String: String] = [:]
    var sessions: [Session] = []
    var attempts: [Attempt] = []
    var answers: [String: String] = [:]
    var verdicts: [String: String] = [:]
}

extension ProbeReport {
    static func verdicts(for report: ProbeReport) -> [String: String] {
        var verdicts: [String: String] = [:]
        let opens = report.events.filter { $0.phase == "detection" && $0.name == MissionControlEvent.showAllWindows.rawValue }.count
        let exits = report.events.filter { $0.phase == "detection" && $0.name == MissionControlEvent.exit.rawValue }.count
        let registered = report.observerRegistration[MissionControlEvent.showAllWindows.rawValue] == "success"
            && report.observerRegistration[MissionControlEvent.exit.rawValue] == "success"
        verdicts["H1 detection"] = registered && opens >= 4 && exits >= opens ? "pass (\(opens) opens)" : (opens > 0 ? "partial (\(opens) opens, \(exits) exits)" : "fail")

        let before = report.windowsBefore
        let during = report.windowsDuringMissionControl
        verdicts["H2 window list"] = before.count > 0 && during.count == before.count && during.missingFromReference == 0
            ? "pass" : (during.count > 0 ? "review (\(before.count) before, \(during.count) during)" : "unknown")

        let thumbnails = report.sessions.map(\.thumbnailsFound).max() ?? 0
        let pressable = report.dockTrees.map(\.pressable).max() ?? 0
        verdicts["H3 thumbnails"] = thumbnails > 0 ? "pass (\(thumbnails) matched)" : (pressable > 0 ? "review (\(pressable) pressable)" : "fail")

        verdicts["H4 thumbnail action"] = rate(of: .dockThumbnail, in: report.attempts)
        verdicts["H5 accessibility activation"] = rate(of: .accessibility, in: report.attempts)
        verdicts["H5 running application"] = rate(of: .runningApplication, in: report.attempts)

        verdicts["H6 overlay"] = "hud=\(report.answers["sawHUD"] ?? "unknown"), highlight=\(report.answers["sawHighlight"] ?? "untested"), aligned=\(report.answers["highlightAligned"] ?? "untested")"

        let keys = report.sessions.reduce(0) { $0 + $1.keys.values.reduce(0, +) }
        let nativeReaction = report.answers["missionControlReactedToTab"]
        verdicts["H7 keyboard"] = report.tapInstalled && keys > 0 && nativeReaction == "no"
            ? "pass (\(keys) keys)" : (report.tapInstalled ? "review (\(keys) keys, native=\(nativeReaction ?? "unknown"))" : "fail")

        let diagnostics = before.diagnostics
        verdicts["H8 window id"] = report.privateWindowAPI && diagnostics.candidates > 0 && diagnostics.matchedByPrivateAPI == diagnostics.candidates
            ? "pass" : (report.privateWindowAPI ? "partial (\(diagnostics.matchedByPrivateAPI)/\(diagnostics.candidates))" : "fail")

        verdicts["H9 move to desktop"] = "pending"
        verdicts["H0 native keys"] = report.nativeKeys.isEmpty ? "unknown" : report.nativeKeys.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        return verdicts
    }

    private static func rate(of strategy: ActivationStrategy, in attempts: [Attempt]) -> String {
        let matching = attempts.filter { $0.strategy == strategy.rawValue }
        guard !matching.isEmpty else { return "untested" }
        return "\(matching.filter(\.exactWindow).count)/\(matching.count) exact"
    }

    func markdownSummary() -> String {
        var lines = [
            "# tabby-probe · \(ISO8601DateFormatter().string(from: startedAt))",
            "",
            "- macOS: \(macOS)",
            "- Accessibility: \(permissions.accessibility) · Input Monitoring: \(permissions.inputMonitoring) · Secure input: \(permissions.secureInput)",
            "- _AXUIElementGetWindow: \(privateWindowAPI) · Keyboard tap: \(tapInstalled) · Tap disabled by system: \(tapDisabledBySystem)",
            "",
            "| Hypothesis | Result |",
            "|---|---|",
        ]
        for key in verdicts.keys.sorted() {
            lines.append("| \(key) | \(verdicts[key] ?? "") |")
        }
        if !triggers.isEmpty {
            lines.append("")
            lines.append("Open latency from key press (ms): " + triggers.map { String(Int($0.latencyMs)) }.joined(separator: ", "))
        }
        if !attempts.isEmpty {
            lines.append("")
            lines.append("| # | Strategy | App | Exact window | Mission Control closed |")
            lines.append("|---|---|---|---|---|")
            for attempt in attempts {
                let closed = attempt.missionControlExitMs.map { "\(Int($0)) ms" } ?? (attempt.missionControlStayedOpen ? "stayed open" : "—")
                lines.append("| \(attempt.index) | \(attempt.strategy) | \(attempt.targetApp) | \(attempt.exactWindow ? "yes" : "no") | \(closed) |")
            }
        }
        return lines.joined(separator: "\n")
    }
}
