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
    public var lastSession: Session?

    public init(
        appVersion: String, build: String, macOS: String, architecture: String, displays: [Display],
        accessibility: Bool, screenRecording: Bool, postEvents: Bool, listenEvents: Bool, secureInput: Bool,
        privateWindowAPI: Bool, enabled: Bool, running: Bool, keyboardTap: Bool, tapTimeouts: Int,
        shortcuts: [String], liftSetting: Bool, reduceMotion: Bool, translocated: Bool, launchAtLogin: String,
        lastSession: Session?
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
        self.lastSession = lastSession
    }

    public var capabilityLevel: Int? {
        guard accessibility else { return 0 }
        guard let lastSession else { return nil }
        return lastSession.thumbnails > 0 ? 3 : 2
    }

    public var text: String {
        var lines = [
            "Tabby \(appVersion) (\(build))",
            "macOS \(macOS) · \(architecture)",
            "Displays: " + (displays.isEmpty ? "none" : displays.map { "\($0.width)×\($0.height) @\(Self.format($0.scale))x" }.joined(separator: ", ")),
            "",
            "Accessibility: \(Self.yes(accessibility)) · Screen Recording: \(Self.yes(screenRecording)) · Post events: \(Self.yes(postEvents)) · Input Monitoring: \(Self.yes(listenEvents))",
            "Secure Input: \(secureInput ? "on" : "off") · _AXUIElementGetWindow: \(privateWindowAPI ? "available" : "missing")",
            "Tabby: \(enabled ? "enabled" : "paused") · running: \(Self.yes(running)) · keyboard tap: \(keyboardTap ? "installed" : "not installed") · tap timeouts: \(tapTimeouts)",
            "Shortcuts: " + shortcuts.joined(separator: " · "),
            "Lift effect: \(liftSetting ? "on" : "off") · active: \(Self.yes(liftSetting && screenRecording && !reduceMotion)) · reduce motion: \(Self.yes(reduceMotion))",
            "Translocated: \(Self.yes(translocated)) · Launch at login: \(launchAtLogin)",
            "Capability level: " + (capabilityLevel.map { "\($0) (\(Self.levelName($0)))" } ?? "unknown, open Mission Control once"),
        ]
        if let lastSession {
            lines.append("Last session: \(lastSession.windows) windows · \(lastSession.thumbnails) thumbnails matched")
            if let activation = lastSession.activation {
                lines.append("Last activation: \(activation.exact ? "exact" : "not exact") · \(activation.strategy.rawValue) · \(Int(activation.elapsed / .milliseconds(1))) ms")
            }
            if let move = lastSession.move {
                lines.append("Last move: \(String(describing: move))")
            }
        }
        return lines.joined(separator: "\n")
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
