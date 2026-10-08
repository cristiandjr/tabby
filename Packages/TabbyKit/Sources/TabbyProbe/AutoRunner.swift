import AppKit
import TabbyKit

struct AutoReport: Codable {
    struct Cycle: Codable {
        var index: Int
        var openedBy: String
        var openMs: Double?
        var closeMs: Double?
    }

    struct Attempt: Codable {
        var index: Int
        var strategy: String
        var targetApp: String
        var sameAppWindows: Int
        var tabsSent: Int
        var tabsReceived: Int
        var selectionCorrect: Bool
        var thumbnailFound: Bool
        var overlayAboveMissionControl: Bool?
        var returnReceived: Bool
        var exactWindow: Bool
        var rightApp: Bool
        var missionControlClosedMs: Double?
        var stayedOpen: Bool
        var detail: [String: String]
    }

    var tool = "tabby-probe auto 0.4"
    var startedAt = Date()
    var finishedAt: Date?
    var macOS = SystemStatus.macOSVersion
    var accessibility = SystemStatus.accessibilityTrusted
    var postEvents = SystemStatus.postEventAccess
    var privateWindowAPI = PrivateAXBridge.isAvailable
    var windowApps: [String] = []
    var windowManagerPID: Int32?
    var registrations: [String: [String: String]] = [:]
    var notificationCounts: [String: Int] = [:]
    var notificationLog: [String] = []
    var cycles: [Cycle] = []
    var thumbnails: [String] = []
    var thumbnailMatches = ""
    var missionControlWindows: [String] = []
    var overlayAbove: Bool?
    var attempts: [Attempt] = []
    var tapTimeouts = 0
    var verdicts: [String: String] = [:]
}

@MainActor
final class AutoRunner {
    private static let sniffedNotifications = [
        "AXCreated",
        "AXUIElementDestroyed",
        "AXFocusedUIElementChanged",
        "AXSelectedChildrenChanged",
        "AXLayoutChanged",
        "AXWindowCreated",
    ]

    private let outputDirectory: URL
    private let interceptor = KeyboardInterceptor()
    private let provider = WindowProvider()
    private let overlay = SelectionOverlay()
    private let dockObserver = MissionControlObserver()
    private let windowManagerObserver = MissionControlObserver()
    private let dockSniffer = AXNotificationObserver()
    private let windowManagerSniffer = AXNotificationObserver()
    private let startedAt = ContinuousClock().now
    private var report = AutoReport()

    private var engine: NavigationEngine?
    private var sessionWindows: [CGWindowID: MissionWindow] = [:]
    private var thumbnails: [CGWindowID: MissionControlThumbnail] = [:]
    private var tabsReceived = 0
    private var returnReceived = false
    private var requestedStrategy: ActivationStrategy = .accessibility
    private var usedStrategy: ActivationStrategy = .accessibility
    private var activationDetail: [String: String] = [:]
    private var activationStarted: ContinuousClock.Instant?

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func run() async -> Int32 {
        say("tabby-probe auto · \(SystemStatus.macOSVersion)")
        guard preflight() else { return 2 }
        AX.setGlobalTimeout(0.3)
        startNotifications()
        interceptor.onAction = { [weak self] key in
            self?.handleKey(key)
        }
        guard interceptor.install() else {
            say("Could not install the keyboard tap.")
            return 2
        }
        let originalApp = NSWorkspace.shared.frontmostApplication
        _ = await closeMissionControl()
        let windows = provider.snapshot()
        report.windowApps = windows.map(\.appName)
        say("Windows: \(windows.count) · \(windows.map(\.appName).joined(separator: ", "))")
        guard windows.count >= 2 else {
            say("At least 2 windows are needed.")
            finish()
            return 1
        }
        await detectionCycles(5)
        await explore()
        await demo(9)
        originalApp?.activate(options: [])
        finish()
        return 0
    }

    private func preflight() -> Bool {
        var ready = true
        if !AX.isTrusted {
            AX.requestTrust()
            say("Accessibility permission is missing for the app that launched the probe.")
            ready = false
        }
        if !SystemStatus.postEventAccess {
            _ = CGRequestPostEventAccess()
            say("Permission to post keyboard events is missing.")
            ready = false
        }
        return ready
    }

    private func startNotifications() {
        dockObserver.onEvent = { [weak self] event, instant in
            self?.logNotification(source: "dock", name: event.rawValue, element: nil, at: instant)
        }
        report.registrations["dock-expose"] = names(dockObserver.start())
        if let pid = DockAccessibility.pid {
            dockSniffer.onNotification = { [weak self] name, element, instant in
                self?.logNotification(source: "dock", name: name, element: element, at: instant)
            }
            report.registrations["dock"] = dockSniffer.start(pid: pid, notifications: Self.sniffedNotifications)
        }
        guard let pid = MissionControlAccessibility.windowManagerPID else { return }
        report.windowManagerPID = pid
        windowManagerObserver.onEvent = { [weak self] event, instant in
            self?.logNotification(source: "wm", name: event.rawValue, element: nil, at: instant)
        }
        report.registrations["wm-expose"] = names(windowManagerObserver.start(pid: pid))
        windowManagerSniffer.onNotification = { [weak self] name, element, instant in
            self?.logNotification(source: "wm", name: name, element: element, at: instant)
        }
        report.registrations["wm"] = windowManagerSniffer.start(pid: pid, notifications: Self.sniffedNotifications)
    }

    private func names(_ registration: [MissionControlEvent: AXError]?) -> [String: String] {
        (registration ?? [:]).reduce(into: [:]) { result, item in
            result[item.key.rawValue] = item.value.name
        }
    }

    private func logNotification(source: String, name: String, element: AXUIElement?, at instant: ContinuousClock.Instant) {
        let key = "\(source):\(name)"
        report.notificationCounts[key, default: 0] += 1
        guard report.notificationLog.count < 300 else { return }
        let detail = element.map { element in
            (AX.string(element, kAXRoleAttribute) ?? "?") + (AX.string(element, "AXIdentifier").map { ":\($0)" } ?? "")
        } ?? ""
        report.notificationLog.append("\(Int(milliseconds(from: startedAt, to: instant))) \(key) \(detail)")
    }

    private var isMissionControlOpen: Bool {
        DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature())
    }

    private func openMissionControl() async -> (ms: Double?, by: String) {
        let started = ContinuousClock().now
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
        if await waitUntil(timeout: .seconds(2), { self.isMissionControlOpen }) {
            return (milliseconds(from: started, to: ContinuousClock().now), "app")
        }
        let retried = ContinuousClock().now
        WindowActivator.postKey(126, flags: .maskControl)
        if await waitUntil(timeout: .seconds(2), { self.isMissionControlOpen }) {
            return (milliseconds(from: retried, to: ContinuousClock().now), "shortcut")
        }
        return (nil, "failed")
    }

    private func closeMissionControl() async -> Double? {
        guard isMissionControlOpen else { return nil }
        let started = ContinuousClock().now
        WindowActivator.postKey(KeyCode.escape)
        return await waitUntil(timeout: .seconds(2), { !self.isMissionControlOpen })
            ? milliseconds(from: started, to: ContinuousClock().now)
            : nil
    }

    private func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func detectionCycles(_ count: Int) async {
        say("— Detection: opening and closing Mission Control \(count) times")
        for index in 1...count {
            let open = await openMissionControl()
            try? await Task.sleep(for: .milliseconds(700))
            let close = await closeMissionControl()
            report.cycles.append(.init(index: index, openedBy: open.by, openMs: open.ms, closeMs: close))
            say("  \(index). opened by \(open.by) in \(format(open.ms)) · closed in \(format(close))")
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func explore() async {
        say("— Exploring Mission Control")
        guard await openMissionControl().ms != nil else {
            say("  Mission Control did not open")
            return
        }
        try? await Task.sleep(for: .milliseconds(700))
        if let tree = MissionControlAccessibility.tree() {
            try? DockAccessibility.render(tree).write(
                to: outputDirectory.appendingPathComponent("windowmanager-tree.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        let windows = provider.snapshot()
        let found = MissionControlAccessibility.thumbnails()
        report.thumbnails = found.map { thumbnail in
            "\(thumbnail.info.bundleID ?? "?") space=\(thumbnail.info.spaceID ?? "?") \"\(thumbnail.info.title ?? "")\" \(describe(thumbnail.info.frame))"
        }
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: found.map(\.info))
        report.thumbnailMatches = "\(matches.count)/\(windows.count)"
        say("  Thumbnails: \(found.count) · matched to windows: \(matches.count)/\(windows.count)")
        if let window = windows.first(where: { matches[$0.id] != nil }), let index = matches[window.id] {
            overlay.showHighlight(globalRect: found[index].info.frame)
            overlay.showHUD(text: "Tabby · \(window.appName)", near: found[index].info.frame)
            try? await Task.sleep(for: .milliseconds(300))
            report.overlayAbove = overlayIsAboveMissionControl()
            report.missionControlWindows = missionControlWindowDescriptions()
            say("  Overlay above Mission Control: \(report.overlayAbove.map { String($0) } ?? "unknown")")
            try? await Task.sleep(for: .milliseconds(600))
            overlay.hide()
        }
        _ = await closeMissionControl()
        try? await Task.sleep(for: .milliseconds(500))
    }

    private func demo(_ count: Int) async {
        say("— Demo: Tab + Return inside Mission Control (\(count) attempts)")
        let strategies: [ActivationStrategy] = [.dockThumbnail, .accessibility, .runningApplication]
        for index in 0..<count {
            guard await openMissionControl().ms != nil else {
                say("  \(index + 1). Mission Control did not open")
                continue
            }
            try? await Task.sleep(for: .milliseconds(500))
            startSession()
            guard let ids = engine?.windowIDs, ids.count >= 2 else {
                endSession()
                _ = await closeMissionControl()
                continue
            }
            let targetIndex = (index % (ids.count - 1)) + 1
            let target = ids[targetIndex]
            let tabs = (targetIndex - 1 + ids.count) % ids.count
            for _ in 0..<tabs where interceptor.mode == .intercept {
                WindowActivator.postKey(KeyCode.tab)
                try? await Task.sleep(for: .milliseconds(120))
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard let window = sessionWindows[target] else {
                endSession()
                _ = await closeMissionControl()
                continue
            }
            let selectionCorrect = engine?.selectedID == target
            let overlayAbove = overlayIsAboveMissionControl()
            let sameApp = sessionWindows.values.filter { $0.bundleID == window.bundleID }.count
            let thumbnailFound = thumbnails[target] != nil
            let received = tabsReceived
            requestedStrategy = strategies[index % strategies.count]
            returnReceived = false
            activationStarted = nil
            activationDetail = [:]
            if interceptor.mode == .intercept {
                WindowActivator.postKey(KeyCode.returnKey)
            }
            let closed = await waitUntil(timeout: .milliseconds(1500), { !self.isMissionControlOpen })
            let closedMs = closed ? activationStarted.map { milliseconds(from: $0, to: ContinuousClock().now) } : nil
            try? await Task.sleep(for: .milliseconds(450))
            let focused = WindowActivator.focusedWindow()
            let stayedOpen = isMissionControlOpen
            if stayedOpen {
                _ = await closeMissionControl()
            }
            endSession()
            let attempt = AutoReport.Attempt(
                index: index + 1,
                strategy: returnReceived ? usedStrategy.rawValue : "none",
                targetApp: window.appName,
                sameAppWindows: sameApp,
                tabsSent: tabs,
                tabsReceived: received,
                selectionCorrect: selectionCorrect,
                thumbnailFound: thumbnailFound,
                overlayAboveMissionControl: overlayAbove,
                returnReceived: returnReceived,
                exactWindow: focused?.windowID == target,
                rightApp: focused?.pid == window.pid,
                missionControlClosedMs: closedMs,
                stayedOpen: stayedOpen,
                detail: activationDetail
            )
            report.attempts.append(attempt)
            say("  \(index + 1). \(attempt.strategy) → \(window.appName) (\(sameApp) of that app) · tabs \(received)/\(tabs) · selection \(selectionCorrect ? "ok" : "WRONG") · thumbnail \(thumbnailFound ? "yes" : "no") · exact window \(attempt.exactWindow ? "yes" : "NO") · closed in \(format(closedMs))")
            try? await Task.sleep(for: .milliseconds(600))
        }
    }

    private func startSession() {
        let windows = provider.snapshot()
        sessionWindows = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        engine = NavigationEngine(windowIDs: windows.map(\.id))
        let found = MissionControlAccessibility.thumbnails()
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: found.map(\.info))
        thumbnails = matches.reduce(into: [:]) { result, item in
            result[item.key] = found[item.value]
        }
        tabsReceived = 0
        interceptor.setMode(.intercept)
        render()
    }

    private func endSession() {
        interceptor.setMode(.off)
        overlay.hide()
        engine = nil
        sessionWindows = [:]
        thumbnails = [:]
    }

    private func render() {
        guard let engine, let id = engine.selectedID, let window = sessionWindows[id] else { return }
        let position = (engine.selectedIndex ?? 0) + 1
        let frame = thumbnails[id]?.info.frame
        overlay.showHighlight(globalRect: frame)
        overlay.showHUD(text: "\(window.appName)  ·  \(position)/\(engine.windowIDs.count)", near: frame ?? window.frame)
    }

    private func handleKey(_ key: SessionAction) {
        guard engine != nil else { return }
        switch key {
        case .next:
            engine?.next()
            tabsReceived += 1
            render()
        case .previous:
            engine?.previous()
            render()
        case .activate:
            returnReceived = true
            activate()
        case .moveToDesktop:
            break
        }
    }

    private func activate() {
        guard let engine, let id = engine.selectedID, let window = sessionWindows[id] else { return }
        interceptor.setMode(.off)
        overlay.hide()
        activationStarted = ContinuousClock().now
        var strategy = requestedStrategy
        var detail: [String: String] = [:]
        if strategy == .dockThumbnail, let thumbnail = thumbnails[id] {
            detail["press"] = WindowActivator.pressThumbnail(thumbnail.element).name
        } else {
            if strategy == .dockThumbnail {
                strategy = .accessibility
                detail["fallback"] = "noThumbnail"
            }
            if strategy == .accessibility, let element = provider.element(for: id) {
                detail.merge(WindowActivator.activateWithAccessibility(pid: window.pid, window: element)) { _, new in new }
            }
            if strategy == .runningApplication {
                detail.merge(WindowActivator.activateWithRunningApplication(pid: window.pid, window: provider.element(for: id))) { _, new in new }
            }
        }
        usedStrategy = strategy
        activationDetail = detail
    }

    private func overlayIsAboveMissionControl() -> Bool? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ours = Set(overlay.visibleWindowNumbers)
        let missionControlPIDs = Set([DockAccessibility.pid, MissionControlAccessibility.windowManagerPID].compactMap { $0 })
        var ourIndex: Int?
        var theirIndex: Int?
        for (index, info) in list.enumerated() {
            let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1
            let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if ourIndex == nil, ours.contains(number) { ourIndex = index }
            if theirIndex == nil, missionControlPIDs.contains(pid), layer > 0 { theirIndex = index }
        }
        guard let ourIndex, let theirIndex else { return nil }
        return ourIndex < theirIndex
    }

    private func missionControlWindowDescriptions() -> [String] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let ours = Set(overlay.visibleWindowNumbers)
        let missionControlPIDs = Set([DockAccessibility.pid, MissionControlAccessibility.windowManagerPID].compactMap { $0 })
        return list.enumerated().compactMap { index, info in
            let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1
            let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1
            guard ours.contains(number) || missionControlPIDs.contains(pid) else { return nil }
            let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            return "#\(index) \(ours.contains(number) ? "Tabby" : owner) layer=\(layer)"
        }
    }

    private func finish() {
        dockObserver.stop()
        windowManagerObserver.stop()
        dockSniffer.stop()
        windowManagerSniffer.stop()
        interceptor.setMode(.off)
        report.tapTimeouts = interceptor.timeoutCount
        interceptor.uninstall()
        overlay.hide()
        report.finishedAt = Date()
        report.verdicts = verdicts()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            try? data.write(to: outputDirectory.appendingPathComponent("auto-report.json"))
        }
        let summary = report.verdicts.keys.sorted().map { "| \($0) | \(report.verdicts[$0] ?? "") |" }
        let text = (["| Hypothesis | Result |", "|---|---|"] + summary).joined(separator: "\n")
        try? text.write(to: outputDirectory.appendingPathComponent("auto-summary.md"), atomically: true, encoding: .utf8)
        say("")
        say(text)
        say("")
        say("Results: \(outputDirectory.path)")
    }

    private func verdicts() -> [String: String] {
        var verdicts: [String: String] = [:]
        let opened = report.cycles.filter { $0.openMs != nil }
        let closed = report.cycles.filter { $0.closeMs != nil }
        verdicts["H1 detection (mc group)"] = "\(opened.count)/\(report.cycles.count) opens, \(closed.count)/\(report.cycles.count) closes · open \(format(median(opened.compactMap(\.openMs)))) after the launch request · close \(format(median(closed.compactMap(\.closeMs))))"
        let notified = report.notificationCounts.filter { $0.key.contains("AXExpose") }
        verdicts["H1 AXExpose notifications"] = notified.isEmpty ? "silent (Dock and WindowManager)" : notified.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        verdicts["H3 thumbnails"] = "\(report.thumbnails.count) found · matched \(report.thumbnailMatches)"
        for strategy in ActivationStrategy.allCases {
            let attempts = report.attempts.filter { $0.strategy == strategy.rawValue }
            guard !attempts.isEmpty else { continue }
            let exact = attempts.filter(\.exactWindow).count
            let closedTimes = attempts.compactMap(\.missionControlClosedMs)
            verdicts["H4/H5 \(strategy.rawValue)"] = "\(exact)/\(attempts.count) exact window · closed \(format(median(closedTimes)))"
        }
        let attempts = report.attempts
        verdicts["H6 overlay above Mission Control"] = report.overlayAbove.map { String($0) } ?? "unknown"
        let tabsOK = attempts.filter { $0.tabsReceived == $0.tabsSent }.count
        let selectionOK = attempts.filter(\.selectionCorrect).count
        let returnOK = attempts.filter(\.returnReceived).count
        verdicts["H7 keyboard"] = "tabs intercepted \(tabsOK)/\(attempts.count) · selection \(selectionOK)/\(attempts.count) · return intercepted \(returnOK)/\(attempts.count) · tap timeouts \(report.tapTimeouts)"
        verdicts["H8 window id"] = report.privateWindowAPI ? "available" : "missing"
        return verdicts
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.sorted()[values.count / 2]
    }

    private func format(_ value: Double?) -> String {
        value.map { "\(Int($0)) ms" } ?? "—"
    }

    private func describe(_ frame: CGRect) -> String {
        "(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))"
    }

    private func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
        let components = (end - start).components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }

    private func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}
