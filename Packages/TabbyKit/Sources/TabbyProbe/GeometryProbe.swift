import AppKit
import TabbyKit

@MainActor
enum GeometryProbe {
    static func run() async -> Int32 {
        guard AX.isTrusted else {
            AX.requestTrust()
            say("Accessibility permission is missing.")
            return 2
        }
        AX.setGlobalTimeout(0.3)
        let clock = ContinuousClock()
        if isOpen {
            WindowActivator.postKey(KeyCode.escape)
            try? await Task.sleep(for: .milliseconds(800))
        }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
        let requested = clock.now
        while clock.now - requested < .seconds(3), !isOpen {
            try? await Task.sleep(for: .milliseconds(5))
        }
        guard isOpen else {
            say("Mission Control did not open.")
            return 1
        }
        let opened = clock.now
        var samples: [(ms: Int, thumbnails: [ThumbnailInfo])] = []
        for target in [0, 40, 80, 120, 180, 250, 350, 500, 700, 1000] {
            while clock.now - opened < .milliseconds(target) {
                try? await Task.sleep(for: .milliseconds(5))
            }
            samples.append((target, MissionControlAccessibility.thumbnails().map(\.info)))
        }
        let windows = WindowProvider().snapshot()
        let latest = samples.last?.thumbnails ?? []
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: latest)
        say("window vs thumbnail aspect ratio:")
        for window in windows {
            guard let index = matches[window.id] else {
                say("    \(window.appName): no thumbnail")
                continue
            }
            let thumbnail = latest[index].frame
            let windowRatio = window.frame.width / max(window.frame.height, 1)
            let thumbnailRatio = thumbnail.width / max(thumbnail.height, 1)
            let scale = thumbnail.width / max(window.frame.width, 1)
            say(String(format: "    %@: window %.0fx%.0f (%.3f) · thumbnail %.0fx%.0f (%.3f) · scale %.3f", window.appName, window.frame.width, window.frame.height, windowRatio, thumbnail.width, thumbnail.height, thumbnailRatio, scale))
        }
        if let first = latest.first {
            let overlay = SelectionOverlay()
            overlay.showHighlight(globalRect: first.frame)
            try? await Task.sleep(for: .milliseconds(200))
            say("overlay panels vs screens:")
            for (index, line) in overlay.panelDiagnostics().enumerated() {
                say("    \(index): \(line)")
            }
            overlay.hide()
        }
        WindowActivator.postKey(KeyCode.escape)
        var keys: [String] = []
        for sample in samples {
            for info in sample.thumbnails where !keys.contains(key(info)) {
                keys.append(key(info))
            }
        }
        say("thumbnails per sample: " + samples.map { "\($0.ms)ms=\($0.thumbnails.count)" }.joined(separator: " "))
        for name in keys {
            say(name)
            var previous: CGRect?
            for sample in samples {
                guard let frame = sample.thumbnails.first(where: { key($0) == name })?.frame else {
                    say("    \(sample.ms) ms: missing")
                    continue
                }
                let moved = previous.map { $0 != frame } ?? false
                say("    \(sample.ms) ms: (\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))\(moved ? "  ← moved" : "")")
                previous = frame
            }
        }
        return 0
    }

    private static var isOpen: Bool {
        DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature())
    }

    private static func key(_ info: ThumbnailInfo) -> String {
        "\(info.bundleID ?? "?") · \(info.title ?? "")"
    }

    private static func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}
