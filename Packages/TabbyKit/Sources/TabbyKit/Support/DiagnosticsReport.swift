public struct DiagnosticsReport: Equatable, Sendable {
    public struct Display: Equatable, Sendable {
        public var width: Int
        public var height: Int
        public var scale: Double

        public init(width: Int, height: Int, scale: Double) {
            self.width = width
            self.height = height
            self.scale = scale
        }
    }

    public struct Session: Equatable, Sendable {
        public var windows: Int
        public var thumbnails: Int
        public var activation: ActivationResult?
        public var move: SpaceMoveResult?

        public init(windows: Int, thumbnails: Int, activation: ActivationResult? = nil, move: SpaceMoveResult? = nil) {
            self.windows = windows
            self.thumbnails = thumbnails
            self.activation = activation
            self.move = move
        }
    }

    public var appVersion: String
    public var build: String
    public var macOS: String
    public var architecture: String
    public var displays: [Display]
    public var accessibility: Bool
    public var screenRecording: Bool
    public var postEvents: Bool
    public var listenEvents: Bool
    public var secureInput: Bool
    public var privateWindowAPI: Bool
    public var enabled: Bool
    public var running: Bool
    public var keyboardTap: Bool
    public var tapTimeouts: Int
    public var shortcuts: [String]
    public var liftSetting: Bool
    public var reduceMotion: Bool
    public var translocated: Bool
    public var launchAtLogin: String
    public var updateCheck: Bool
    public var availableUpdate: String?
    public var lastSession: Session?

    public init(
        appVersion: String, build: String, macOS: String, architecture: String, displays: [Display],
        accessibility: Bool, screenRecording: Bool, postEvents: Bool, listenEvents: Bool, secureInput: Bool,
        privateWindowAPI: Bool, enabled: Bool, running: Bool, keyboardTap: Bool, tapTimeouts: Int,
        shortcuts: [String], liftSetting: Bool, reduceMotion: Bool, translocated: Bool, launchAtLogin: String,
        updateCheck: Bool = true, availableUpdate: String? = nil, lastSession: Session?
    ) {
        self.appVersion = appVersion
        self.build = build
        self.macOS = macOS
        self.architecture = architecture
        self.displays = displays
        self.accessibility = accessibility
        self.screenRecording = screenRecording
        self.postEvents = postEvents
        self.listenEvents = listenEvents
        self.secureInput = secureInput
        self.privateWindowAPI = privateWindowAPI
        self.enabled = enabled
        self.running = running
        self.keyboardTap = keyboardTap
        self.tapTimeouts = tapTimeouts
        self.shortcuts = shortcuts
        self.liftSetting = liftSetting
        self.reduceMotion = reduceMotion
        self.translocated = translocated
        self.launchAtLogin = launchAtLogin
        self.updateCheck = updateCheck
        self.availableUpdate = availableUpdate
        self.lastSession = lastSession
    }

    public var capabilityLevel: Int? {
        guard accessibility else { return 0 }
        guard let lastSession else { return nil }
        return lastSession.thumbnails > 0 ? 3 : 2
    }

    public var text: String {
        var lines: [String] = []
        lines.append("Tabby \(appVersion) (\(build))")
        lines.append("macOS \(macOS) · \(architecture)")
        lines.append("Displays: \(displayList)")
        lines.append("")
        lines.append(permissionsLine)
        lines.append(systemLine)
        lines.append(stateLine)
        lines.append("Shortcuts: \(shortcuts.joined(separator: " · "))")
        lines.append(liftLine)
        lines.append("Translocated: \(Self.yes(translocated)) · Launch at login: \(launchAtLogin)")
        lines.append("Update check: \(Self.onOff(updateCheck)) · new version: \(availableUpdate ?? "none")")
        lines.append("Capability level: \(capabilityDescription)")
        if let lastSession {
            lines.append("Last session: \(lastSession.windows) windows · \(lastSession.thumbnails) thumbnails matched")
            if let activation = lastSession.activation {
                let exactness: String = activation.exact ? "exact" : "not exact"
                let milliseconds: Int = Int(activation.elapsed / .milliseconds(1))
                lines.append("Last activation: \(exactness) · \(activation.strategy.rawValue) · \(milliseconds) ms")
            }
            if let move = lastSession.move {
                lines.append("Last move: \(String(describing: move))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private var displayList: String {
        guard !displays.isEmpty else { return "none" }
        let names: [String] = displays.map { display in
            "\(display.width)×\(display.height) @\(Self.format(display.scale))x"
        }
        return names.joined(separator: ", ")
    }

    private var permissionsLine: String {
        let accessibilityText: String = Self.yes(accessibility)
        let recordingText: String = Self.yes(screenRecording)
        let postText: String = Self.yes(postEvents)
        let listenText: String = Self.yes(listenEvents)
        return "Accessibility: \(accessibilityText) · Screen Recording: \(recordingText) · Post events: \(postText) · Input Monitoring: \(listenText)"
    }

    private var systemLine: String {
        let secureText: String = Self.onOff(secureInput)
        let apiText: String = privateWindowAPI ? "available" : "missing"
        return "Secure Input: \(secureText) · _AXUIElementGetWindow: \(apiText)"
    }

    private var stateLine: String {
        let enabledText: String = enabled ? "enabled" : "paused"
        let runningText: String = Self.yes(running)
        let tapText: String = keyboardTap ? "installed" : "not installed"
        return "Tabby: \(enabledText) · running: \(runningText) · keyboard tap: \(tapText) · tap timeouts: \(tapTimeouts)"
    }

    private var liftLine: String {
        let settingText: String = Self.onOff(liftSetting)
        let activeText: String = Self.yes(liftSetting && screenRecording && !reduceMotion)
        let motionText: String = Self.yes(reduceMotion)
        return "Lift effect: \(settingText) · active: \(activeText) · reduce motion: \(motionText)"
    }

    private var capabilityDescription: String {
        guard let level = capabilityLevel else { return "unknown, open Mission Control once" }
        return "\(level) (\(Self.levelName(level)))"
    }

    private static func onOff(_ value: Bool) -> String {
        value ? "on" : "off"
    }

    private static func yes(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func format(_ scale: Double) -> String {
        scale == scale.rounded() ? String(Int(scale)) : String(scale)
    }

    private static func levelName(_ level: Int) -> String {
        switch level {
        case 0: "no permission"
        case 1: "shortcut fallback"
        case 2: "HUD only"
        default: "full"
        }
    }
}
