import AppKit
import OSLog
import TabbyKit

enum ProbeCommand: String {
    case run
    case auto
    case demo
    case geometry
    case drive
    case sniff
    case outline
    case check
    case dump
}

@MainActor
final class ProbeRunner {
    private enum Phase: String {
        case idle
        case detection
        case nativeKeys
        case demo
    }

    private struct PendingActivation {
        let target: MissionWindow
        let strategy: ActivationStrategy
        let startedAt: ContinuousClock.Instant
        let detail: [String: String]
        var exitAfterMs: Double?
    }

    private let console = Console()
    private let log = Log.logger("probe", subsystem: "io.github.cristiandjr.tabby.spike")
    private static let dockNotifications = [
        "AXCreated",
        "AXUIElementDestroyed",
        "AXLayoutChanged",
        "AXFocusedUIElementChanged",
        "AXSelectedChildrenChanged",
        "AXValueChanged",
        "AXTitleChanged",
        "AXWindowCreated",
        "AXMoved",
        "AXResized",
    ]

    private let observer = MissionControlObserver()
    private let dockSniffer = AXNotificationObserver()
    private let interceptor = KeyboardInterceptor()
    private let provider = WindowProvider()
    private let overlay = SelectionOverlay()
    private let outputDirectory: URL
    private let startedAt: ContinuousClock.Instant

    private var report = ProbeReport()
    private var phase: Phase = .idle
    private var missionControlOpen = false
    private var notificationsSeen = false
    private var dockSignature: [String] = []
    private var pollTask: Task<Void, Never>?
    private var dockNotificationsLogged = 0
    private var lastKeyDown: (code: UInt16, modifiers: ModifierSet, at: ContinuousClock.Instant)?
    private var dumpedDuringDetection = false
    private var referenceWindowIDs: Set<CGWindowID> = []

    private var engine: NavigationEngine?
    private var sessionWindows: [CGWindowID: MissionWindow] = [:]
    private var thumbnails: [CGWindowID: MissionControlThumbnail] = [:]
    private var sessionKeys: [String: Int] = [:]
    private var pending: PendingActivation?
    private var attemptCounter = 0

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
        self.startedAt = ContinuousClock().now
    }

    func run(_ command: ProbeCommand) async -> Int32 {
        switch command {
        case .check:
            printEnvironment()
            return 0
        case .dump:
            return await dumpOnly()
        case .run:
            return await guided()
        case .auto:
            return await AutoRunner(outputDirectory: outputDirectory).run()
        case .demo:
            return await DemoRunner(selfTest: CommandLine.arguments.contains("--selftest")).run()
        case .geometry:
            return await GeometryProbe.run()
        case .drive:
            return await DriveProbe.run()
        case .sniff:
            return await NotificationSniffer.run()
        case .outline:
            return await OutlineProbe.run()
        }
    }

    private func printEnvironment() {
        console.say("tabby-probe · \(SystemStatus.macOSVersion)")
        console.say("Accessibility: \(SystemStatus.accessibilityTrusted)")
        console.say("Input Monitoring: \(SystemStatus.listenEventAccess)")
        console.say("Post events: \(SystemStatus.postEventAccess)")
        console.say("Secure input: \(SystemStatus.secureInputEnabled)")
        console.say("Dock pid: \(DockAccessibility.pid.map { String($0) } ?? "-")")
        console.say("Dock top level: \(DockAccessibility.topLevelSignature().joined(separator: ", "))")
        console.say("_AXUIElementGetWindow: \(PrivateAXBridge.isAvailable)")
        for screen in NSScreen.screens {
            console.say("Screen: \(screen.localizedName) \(NSStringFromRect(screen.frame)) @\(screen.backingScaleFactor)x")
        }
    }

    private func guided() async -> Int32 {
        console.title("Tabby probe · Spike 0")
        console.say(t("Guided test, about 10 minutes. Results stay on this Mac:", "Prueba guiada de unos 10 minutos. Los resultados quedan en esta Mac:"))
        console.say("  \(outputDirectory.path)")
        console.say(t(
            "\"Return\" is the ↩ key (Enter). Ctrl+C stops the probe at any time.",
            "\"Enter\" es la tecla ↩ (Intro / Return). Ctrl+C corta el probe en cualquier momento."
        ))
        guard ensureAccessibility() else { return 2 }
        AX.setGlobalTimeout(0.3)
        report.screens = NSScreen.screens.map {
            ProbeReport.Screen(name: $0.localizedName, frame: $0.frame, scale: Double($0.backingScaleFactor))
        }
        startObserving()
        await stepWindows()
        startDockPolling()
        await stepDetection()
        await stepGuidedDump()
        await stepNativeKeys()
        await stepDemo()
        finish()
        return 0
    }

    private func ensureAccessibility() -> Bool {
        guard !AX.isTrusted else { return true }
        AX.requestTrust()
        console.say()
        console.say(t(
            """
            Terminal does not have Accessibility permission yet.
              1. System Settings → Privacy & Security → Accessibility
              2. Turn on Terminal
              3. Run the probe again (if it still fails, quit Terminal with ⌘Q and reopen it)
            """,
            """
            Terminal todavía no tiene permiso de Accesibilidad.
              1. Configuración del Sistema → Privacidad y seguridad → Accesibilidad
              2. Activá Terminal
              3. Volvé a correr el probe (si sigue fallando, cerrá Terminal con ⌘Q y abrila de nuevo)
            """
        ))
        return false
    }

    private func startObserving() {
        observer.onEvent = { [weak self] event, instant in
            self?.handle(event, at: instant)
        }
        let registration = observer.start() ?? [:]
        report.observerRegistration = Dictionary(uniqueKeysWithValues: registration.map { ($0.key.rawValue, $0.value.name) })
        if registration.isEmpty {
            report.observerRegistration["observer"] = "failed"
        }
        dockSniffer.onNotification = { [weak self] name, element, instant in
            self?.recordDockNotification(name, element: element, at: instant)
        }
        if let pid = DockAccessibility.pid {
            report.dockNotificationRegistration = dockSniffer.start(pid: pid, notifications: Self.dockNotifications)
        }
        interceptor.onKey = { [weak self] key in
            self?.handleKey(key)
        }
        interceptor.onKeyDown = { [weak self] code, modifiers, instant in
            self?.lastKeyDown = (code, modifiers, instant)
        }
        report.tapInstalled = interceptor.install()
        let registrationText = report.observerRegistration.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        console.say(t("Mission Control observer: ", "Observador de Mission Control: ") + registrationText)
        console.say(t("Keyboard tap installed: ", "Tap de teclado instalado: ") + (report.tapInstalled ? "✅" : "❌"))
    }

    private func startDockPolling() {
        dockSignature = DockAccessibility.topLevelSignature()
        report.dockBaseline = dockSignature
        report.dockWindowsBaseline = dockWindowsDescription()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.pollDock()
            }
        }
    }

    private func pollDock() {
        let signature = DockAccessibility.topLevelSignature()
        guard signature != dockSignature else { return }
        let wasOpen = DockAccessibility.isMissionControlOpen(dockSignature)
        let isOpen = DockAccessibility.isMissionControlOpen(signature)
        dockSignature = signature
        let now = ContinuousClock().now
        let name = isOpen == wasOpen ? "dockTreeChanged" : (isOpen ? "missionControlGroupAppeared" : "missionControlGroupRemoved")
        report.events.append(.init(
            name: name,
            atMs: milliseconds(from: startedAt, to: now),
            phase: phase.rawValue,
            detail: signature.joined(separator: ", ")
        ))
        guard isOpen != wasOpen else {
            console.say("  · " + t("Dock tree changed (not Mission Control): ", "Cambió el árbol del Dock (no es Mission Control): ") + signature.joined(separator: ", "))
            return
        }
        guard !notificationsSeen else { return }
        if isOpen {
            missionControlOpen = true
            console.say("  ● " + t("Mission Control opened", "Mission Control abierto"))
            missionControlOpened(at: now, detectedBy: "dockTree")
        } else {
            missionControlOpen = false
            console.say("  ○ " + t("Mission Control closed", "Mission Control cerrado"))
            missionControlClosed(at: now)
        }
    }

    private func recordDockNotification(_ name: String, element: AXUIElement, at instant: ContinuousClock.Instant) {
        report.dockNotificationCounts[name, default: 0] += 1
        guard dockNotificationsLogged < 400 else { return }
        dockNotificationsLogged += 1
        let role = AX.string(element, kAXRoleAttribute) ?? "?"
        let identifier = AX.string(element, "AXIdentifier").map { ":\($0)" } ?? ""
        report.events.append(.init(
            name: "dock:\(name)",
            atMs: milliseconds(from: startedAt, to: instant),
            phase: phase.rawValue,
            detail: role + identifier
        ))
    }

    private func dockWindowsDescription() -> [String] {
        guard let pid = DockAccessibility.pid else { return [] }
        return CGWindowSource.onScreen().filter { $0.pid == pid }.map { record in
            "layer=\(record.layer) (\(Int(record.bounds.minX)),\(Int(record.bounds.minY)) \(Int(record.bounds.width))x\(Int(record.bounds.height))) alpha=\(record.alpha)"
        }
    }

    private func stepWindows() async {
        console.title(t("Step 1/5 · Windows", "Paso 1/5 · Ventanas"))
        console.say(t(
            "Open several windows. Ideally: 2 overlapping Finder windows, a browser, 2 Terminal windows and VS Code.",
            "Abrí varias ventanas. Ideal: 2 ventanas de Finder superpuestas, un navegador, 2 ventanas de Terminal y VS Code."
        ))
        await console.waitForReturn(t("When they are open, press Return (↩) here.", "Cuando estén abiertas, presioná Enter (↩) acá."))
        let started = ContinuousClock().now
        let windows = provider.snapshot()
        let elapsed = milliseconds(from: started, to: ContinuousClock().now)
        referenceWindowIDs = Set(windows.map(\.id))
        report.windowsBefore = .init(windows: windows, diagnostics: provider.lastDiagnostics, reference: nil, snapshotMs: elapsed)
        for window in windows.prefix(15) {
            console.say("  \(window.zIndex + 1). \(window.appName) — \(window.title ?? "—")")
        }
        let diagnostics = provider.lastDiagnostics
        console.say(t(
            "Windows: \(windows.count) · matched with _AXUIElementGetWindow: \(diagnostics.matchedByPrivateAPI) · by frame: \(diagnostics.matchedByFrame) · window-server only: \(diagnostics.unmatched) · \(Int(elapsed)) ms",
            "Ventanas: \(windows.count) · emparejadas con _AXUIElementGetWindow: \(diagnostics.matchedByPrivateAPI) · por frame: \(diagnostics.matchedByFrame) · solo del WindowServer: \(diagnostics.unmatched) · \(Int(elapsed)) ms"
        ))
    }

    private func stepDetection() async {
        phase = .detection
        console.title(t("Step 2/5 · Detection", "Paso 2/5 · Detección"))
        console.say(t(
            """
            Open and close Mission Control at least 4 times, with a different method each time if you can:
              • your keyboard shortcut (for example ⌃↑)
              • the Mission Control key (F3)
              • the trackpad gesture
              • a hot corner, if you use one
            Close it with Esc, a click or the gesture. Each detection is printed here.
            """,
            """
            Abrí y cerrá Mission Control al menos 4 veces, con un método distinto cada vez si podés:
              • tu atajo de teclado (por ejemplo ⌃↑)
              • la tecla Mission Control (F3)
              • el gesto del trackpad
              • una esquina activa, si usás
            Cerralo con Esc, un clic o el gesto. Cada detección aparece acá.
            """
        ))
        interceptor.setMode(.observe)
        await console.waitForReturn(t("When you are done, press Return (↩) here.", "Cuando termines, presioná Enter (↩) acá."))
        interceptor.setMode(.off)
        phase = .idle
        let notified = report.events.filter { $0.phase == Phase.detection.rawValue && $0.name == MissionControlEvent.showAllWindows.rawValue }.count
        let dockChanges = report.events.filter { $0.phase == Phase.detection.rawValue && $0.name == "dockTreeExpanded" }.count
        console.say(t(
            "Openings detected · notifications: \(notified) · Dock tree: \(dockChanges)",
            "Aperturas detectadas · notificaciones: \(notified) · árbol del Dock: \(dockChanges)"
        ))
    }

    private func stepGuidedDump() async {
        console.title(t("Step 3/5 · Dock snapshot", "Paso 3/5 · Foto del Dock"))
        console.say(t(
            "After you press Return (↩), open Mission Control and leave it open, without moving the mouse, until you see \"Saved\" (about 10 seconds).",
            "Después de presionar Enter (↩), abrí Mission Control y dejalo abierto, sin mover el mouse, hasta que aparezca \"Guardado\" (unos 10 segundos)."
        ))
        await console.waitForReturn(t("Press Return (↩) to start the countdown.", "Presioná Enter (↩) para empezar la cuenta regresiva."))
        for remaining in stride(from: 5, through: 1, by: -1) {
            console.say("  \(remaining)…")
            try? await Task.sleep(for: .seconds(1))
        }
        saveDockTree(label: "guided")
        captureWindowsDuringMissionControl()
        report.dockWindowsDuringMissionControl = dockWindowsDescription()
        await exploreMissionControl()
        console.say(t("Saved. You can close Mission Control now.", "Guardado. Ya podés cerrar Mission Control."))
        try? await Task.sleep(for: .seconds(2))
    }

    private func exploreMissionControl() async {
        var lines = ["# Mission Control exploration", ""]
        guard let pid = DockAccessibility.pid, let group = DockAccessibility.missionControlElement() else {
            lines.append("Mission Control group not found. Was Mission Control open?")
            writeExploration(lines)
            console.say("    " + t("Mission Control was not open during the snapshot.", "Mission Control no estaba abierto durante la foto."))
            return
        }
        lines.append("## Group attributes")
        lines += AX.attributeNames(group).sorted().map { "- \($0) = \(AX.describe(AX.raw(group, $0)))" }
        lines.append("")
        lines.append("## Parameterized attributes: " + AX.parameterizedAttributeNames(group).joined(separator: ", "))
        lines.append("## Actions: " + AX.actions(group).joined(separator: ", "))

        var counts: [String: Int] = [:]
        for attribute in ["AXChildren", "AXChildrenInNavigationOrder", "AXVisibleChildren", "AXContents", "AXRows", "AXSelectedChildren"] {
            counts[attribute] = AX.elements(group, attribute).count
        }

        let application = AX.application(pid)
        let enhancedBefore = AX.bool(application, "AXEnhancedUserInterface")
        let enhancedResult = AX.set(application, "AXEnhancedUserInterface", kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(400))
        if let enhancedGroup = DockAccessibility.missionControlElement() {
            let children = AX.elements(enhancedGroup, kAXChildrenAttribute)
            counts["AXChildren (AXEnhancedUserInterface)"] = children.count
            if !children.isEmpty {
                lines.append("")
                lines.append("## Subtree with AXEnhancedUserInterface")
                lines.append(DockAccessibility.render(DockAccessibility.subtree(of: enhancedGroup)))
            }
        }
        AX.set(application, "AXEnhancedUserInterface", enhancedBefore == true ? kCFBooleanTrue : kCFBooleanFalse)

        let manualResult = AX.set(application, "AXManualAccessibility", kCFBooleanTrue)
        try? await Task.sleep(for: .milliseconds(400))
        if let manualGroup = DockAccessibility.missionControlElement() {
            let children = AX.elements(manualGroup, kAXChildrenAttribute)
            counts["AXChildren (AXManualAccessibility)"] = children.count
            if !children.isEmpty {
                lines.append("")
                lines.append("## Subtree with AXManualAccessibility")
                lines.append(DockAccessibility.render(DockAccessibility.subtree(of: manualGroup)))
            }
        }
        AX.set(application, "AXManualAccessibility", kCFBooleanFalse)
        report.missionControlChildren = counts

        lines.append("")
        lines.append("## Children counts")
        lines += counts.sorted { $0.key < $1.key }.map { "- \($0.key): \($0.value)" }
        lines.append("- set AXEnhancedUserInterface: \(enhancedResult.name) · set AXManualAccessibility: \(manualResult.name)")

        let samples = DockAccessibility.hitTest(points: gridPoints())
        report.hitTestSamples = samples.count
        for sample in samples {
            report.hitTestOwners[sample.owner ?? sample.status, default: 0] += 1
        }
        let containerIdentifiers = [DockAccessibility.missionControlIdentifier, MissionControlAccessibility.displayIdentifier]
        let dockElements = samples.filter { sample in
            (sample.owner == "Dock" || sample.owner == "WindowManager")
                && !containerIdentifiers.contains(sample.identifier ?? "")
                && sample.role != "AXApplication"
        }
        report.hitTestDockElements = Array(Set(dockElements.map { "\($0.role ?? "?") id=\($0.identifier ?? "-") title=\($0.title ?? "-") desc=\($0.label ?? "-")" })).sorted()
        lines.append("")
        lines.append("## Hit test (\(samples.count) points)")
        lines += samples.map { "- " + $0.summary }

        lines.append("")
        lines.append("## Dock windows in the Window Server")
        lines.append("- before: " + report.dockWindowsBaseline.joined(separator: " | "))
        lines.append("- during Mission Control: " + report.dockWindowsDuringMissionControl.joined(separator: " | "))
        writeExploration(lines)
        console.say("    " + t(
            "Exploration saved: mc children \(counts.values.max() ?? 0), hit-test Dock elements \(report.hitTestDockElements.count)",
            "Exploración guardada: hijos de mc \(counts.values.max() ?? 0), elementos del Dock por hit-test \(report.hitTestDockElements.count)"
        ))
    }

    private func writeExploration(_ lines: [String]) {
        try? lines.joined(separator: "\n").write(to: outputDirectory.appendingPathComponent("mc-exploration.md"), atomically: true, encoding: .utf8)
    }

    private func gridPoints(columns: Int = 8, rows: Int = 6) -> [CGPoint] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.flatMap { screen -> [CGPoint] in
            let frame = ScreenGeometry.globalRect(fromAppKit: screen.frame, primaryScreenHeight: primaryHeight)
            return (0..<rows).flatMap { row in
                (0..<columns).map { column in
                    CGPoint(
                        x: frame.minX + frame.width * (CGFloat(column) + 0.5) / CGFloat(columns),
                        y: frame.minY + frame.height * (CGFloat(row) + 0.5) / CGFloat(rows)
                    )
                }
            }
        }
    }

    private func stepNativeKeys() async {
        phase = .nativeKeys
        console.title(t("Step 4/5 · Native Mission Control keys", "Paso 4/5 · Teclas nativas de Mission Control"))
        console.say(t(
            """
            Tabby is not intercepting anything now. Without touching the mouse, open Mission Control and try in this order:
              1. Tab
              2. Space
              3. The arrow keys ← → ↑ ↓
              4. Return (↩) on the highlighted window
            If Mission Control is still open, close it with Esc. Then come back here.
            """,
            """
            Ahora Tabby no intercepta nada. Sin tocar el mouse, abrí Mission Control y probá en este orden:
              1. Tab
              2. Espacio
              3. Las flechas ← → ↑ ↓
              4. Enter (↩) sobre la ventana resaltada
            Si Mission Control sigue abierto, cerralo con Esc. Después volvé acá.
            """
        ))
        await console.waitForReturn(t("Press Return (↩) here when you are back.", "Presioná Enter (↩) acá cuando vuelvas."))
        report.nativeKeys["tabDidSomething"] = await answer(t("Did Tab do anything visible?", "¿Tab hizo algo visible?"))
        report.nativeKeys["spaceShowedPreview"] = await answer(t("Did Space enlarge or preview a window?", "¿Espacio agrandó o previsualizó una ventana?"))
        report.nativeKeys["arrowsMoveSelection"] = await answer(t("Did the arrow keys move a highlight between windows, without the mouse?", "¿Las flechas movieron un resaltado entre ventanas, sin usar el mouse?"))
        report.nativeKeys["returnOpenedWindow"] = await answer(t("Did Return (↩) close Mission Control and open the highlighted window?", "¿Enter (↩) cerró Mission Control y abrió la ventana resaltada?"))
        phase = .idle
    }

    private func stepDemo() async {
        phase = .demo
        console.title(t("Step 5/5 · Tabby demo", "Paso 5/5 · Demo de Tabby"))
        console.say(t(
            """
            This is the most important step.
            Now Tabby takes over Tab and Return (↩) while Mission Control is open.
            Repeat at least 6 times:
              1. Open Mission Control.
              2. Press Tab a few times (⇧Tab goes back). Tabby shows the selected window in a bar at the bottom.
              3. Press Return (↩) to jump to it.
            At least once, pick a window that overlaps another window of the same app.
            Esc cancels. Each result is printed here.
            """,
            """
            Este es el paso más importante.
            Ahora Tabby toma Tab y Enter (↩) mientras Mission Control está abierto.
            Repetí al menos 6 veces:
              1. Abrí Mission Control.
              2. Presioná Tab varias veces (⇧Tab vuelve). Tabby muestra la ventana elegida en una barra abajo.
              3. Presioná Enter (↩) para ir a esa ventana.
            Al menos una vez, elegí una ventana que esté encima de otra de la misma app.
            Esc cancela. Cada resultado aparece acá.
            """
        ))
        while true {
            await console.waitForReturn(t("When you are done, come back to Terminal and press Return (↩) here.", "Cuando termines, volvé a Terminal y presioná Enter (↩) acá."))
            endSession(reason: "stepEnded")
            if !report.sessions.isEmpty { break }
            let retry = await console.askYesNo(t(
                "I did not detect Mission Control during this step. Try it again?",
                "No detecté Mission Control durante este paso. ¿Lo intentamos de nuevo?"
            ))
            guard retry == true else { break }
            console.say(t("Open Mission Control now, press Tab and then Return (↩).", "Abrí Mission Control ahora, presioná Tab y después Enter (↩)."))
        }
        phase = .idle
        guard !report.sessions.isEmpty else {
            console.say(t("No Mission Control session was detected during the demo.", "No se detectó ninguna sesión de Mission Control durante la demo."))
            return
        }
        report.answers["sawHUD"] = await answer(t("While Mission Control was open, did you see Tabby's bar at the bottom?", "Con Mission Control abierto, ¿viste la barra de Tabby abajo?"))
        if report.sessions.contains(where: { $0.thumbnailsFound > 0 }) {
            report.answers["sawHighlight"] = await answer(t("Did you see a colored box around the highlighted thumbnail?", "¿Viste un recuadro de color alrededor de la miniatura resaltada?"))
            report.answers["highlightAligned"] = await answer(t("Was the box exactly on the thumbnail?", "¿El recuadro estaba justo sobre la miniatura?"))
        }
        report.answers["missionControlReactedToTab"] = await answer(t("When you pressed Tab, did Mission Control itself also react?", "Cuando presionaste Tab, ¿Mission Control también reaccionó por su cuenta?"))
        report.answers["landedOnHighlighted"] = await answer(t("After Return (↩), did you land on the window Tabby had shown?", "Después de Enter (↩), ¿terminaste en la ventana que mostraba Tabby?"))
        report.answers["keyboardFeltSlow"] = await answer(t("Did the keyboard or the Mac feel slow during the test?", "¿El teclado o la Mac se sintieron lentos durante la prueba?"))
    }

    private func answer(_ question: String) async -> String {
        switch await console.askYesNo(question) {
        case true?: "yes"
        case false?: "no"
        case nil: "skipped"
        }
    }

    private func handle(_ event: MissionControlEvent, at instant: ContinuousClock.Instant) {
        notificationsSeen = true
        report.events.append(.init(name: event.rawValue, atMs: milliseconds(from: startedAt, to: instant), phase: phase.rawValue))
        log.info("event \(event.rawValue, privacy: .public) phase \(self.phase.rawValue, privacy: .public)")
        switch event {
        case .showAllWindows:
            missionControlOpen = true
            console.say("  ● " + t("Mission Control opened", "Mission Control abierto"))
            missionControlOpened(at: instant, detectedBy: "notification")
        case .exit:
            missionControlOpen = false
            console.say("  ○ " + t("Mission Control closed", "Mission Control cerrado"))
            missionControlClosed(at: instant)
        case .showFrontWindows, .showDesktop:
            console.say("  · \(event.rawValue)")
        }
    }

    private func missionControlOpened(at instant: ContinuousClock.Instant, detectedBy source: String) {
        switch phase {
        case .detection:
            if let key = lastKeyDown, instant - key.at < .milliseconds(1500), instant > key.at {
                let latency = milliseconds(from: key.at, to: instant)
                report.triggers.append(.init(keyCode: Int(key.code), modifiers: key.modifiers.symbols, latencyMs: latency))
                console.say("    " + t("latency from the key press: \(Int(latency)) ms", "latencia desde la tecla: \(Int(latency)) ms"))
            }
            if !dumpedDuringDetection {
                dumpedDuringDetection = true
                scheduleTreeDumps()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard let self, self.missionControlOpen else { return }
                    self.captureWindowsDuringMissionControl()
                }
            }
        case .demo:
            startSession(detectedBy: source)
        case .idle, .nativeKeys:
            break
        }
    }

    private func missionControlClosed(at instant: ContinuousClock.Instant) {
        guard phase == .demo else { return }
        if var activation = pending, activation.exitAfterMs == nil {
            activation.exitAfterMs = milliseconds(from: activation.startedAt, to: instant)
            pending = activation
        }
        endSession(reason: pending == nil ? "closed" : "activated")
    }

    private func scheduleTreeDumps() {
        for delay in [0, 150, 400, 900] {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(delay))
                guard let self, self.missionControlOpen else { return }
                self.saveDockTree(label: "\(delay)ms")
            }
        }
    }

    private func saveDockTree(label: String) {
        let started = ContinuousClock().now
        guard let tree = DockAccessibility.tree() else {
            console.say("    " + t("Could not read the Dock tree", "No pude leer el árbol del Dock"))
            return
        }
        let elapsed = milliseconds(from: started, to: ContinuousClock().now)
        let name = "dock-tree-\(label).txt"
        try? DockAccessibility.render(tree).write(to: outputDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        let stats = DockAccessibility.statistics(tree)
        report.dockTrees.append(.init(label: label, file: name, nodes: stats.nodes, pressable: stats.pressable, withFrame: stats.withFrame, readMs: elapsed))
        console.say("    " + t(
            "Dock tree saved (\(label)): \(stats.nodes) elements, \(stats.pressable) pressable, \(Int(elapsed)) ms",
            "Árbol del Dock guardado (\(label)): \(stats.nodes) elementos, \(stats.pressable) presionables, \(Int(elapsed)) ms"
        ))
    }

    private func captureWindowsDuringMissionControl() {
        let started = ContinuousClock().now
        let windows = provider.snapshot()
        let elapsed = milliseconds(from: started, to: ContinuousClock().now)
        report.windowsDuringMissionControl = .init(
            windows: windows,
            diagnostics: provider.lastDiagnostics,
            reference: referenceWindowIDs,
            snapshotMs: elapsed
        )
    }

    private func startSession(detectedBy source: String) {
        endSession(reason: "replaced")
        let started = ContinuousClock().now
        let windows = provider.snapshot()
        let snapshotMs = milliseconds(from: started, to: ContinuousClock().now)
        sessionWindows = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        engine = NavigationEngine(windowIDs: windows.map(\.id))
        thumbnails = [:]
        sessionKeys = [:]
        report.sessions.append(.init(
            index: report.sessions.count + 1,
            detectedBy: source,
            windows: windows.count,
            snapshotMs: snapshotMs,
            secureInput: SystemStatus.secureInputEnabled
        ))
        interceptor.setMode(.intercept)
        resolveThumbnails()
        render()
        console.say("  ▶ " + t(
            "Session \(report.sessions.count): \(windows.count) windows, \(thumbnails.count) thumbnails found",
            "Sesión \(report.sessions.count): \(windows.count) ventanas, \(thumbnails.count) miniaturas encontradas"
        ))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.missionControlOpen, self.engine != nil else { return }
            let before = self.thumbnails.count
            self.resolveThumbnails()
            if self.thumbnails.count != before {
                self.render()
            }
        }
    }

    private func resolveThumbnails() {
        let started = ContinuousClock().now
        let found = MissionControlAccessibility.thumbnails()
        let windows = Array(sessionWindows.values)
        for (id, index) in MissionControlAccessibility.match(windows: windows, thumbnails: found.map(\.info)) {
            thumbnails[id] = found[index]
        }
        if let last = report.sessions.indices.last {
            report.sessions[last].thumbnailsFound = thumbnails.count
            report.sessions[last].thumbnailSearchMs = milliseconds(from: started, to: ContinuousClock().now)
        }
    }

    private func render() {
        guard let engine, let id = engine.selectedID, let window = sessionWindows[id] else {
            overlay.showHUD(text: t("No windows", "Sin ventanas"), near: nil)
            return
        }
        let position = (engine.selectedIndex ?? 0) + 1
        let title = window.title.map { " — \($0)" } ?? ""
        let thumbnailFrame = thumbnails[id]?.info.frame
        overlay.showHighlight(globalRect: thumbnailFrame)
        overlay.showHUD(text: "\(window.appName)\(title)  ·  \(position)/\(engine.windowIDs.count)", near: thumbnailFrame ?? window.frame)
    }

    private func handleKey(_ key: NavigationKey) {
        guard phase == .demo, engine != nil else { return }
        sessionKeys[key.rawValue, default: 0] += 1
        switch key {
        case .next:
            engine?.next()
            render()
        case .previous:
            engine?.previous()
            render()
        case .select:
            activateSelection()
        }
    }

    private func activateSelection() {
        guard let engine, let id = engine.selectedID, let window = sessionWindows[id] else { return }
        let thumbnail = thumbnails[id]
        var strategy = nextStrategy(hasThumbnail: thumbnail != nil)
        interceptor.setMode(.off)
        overlay.hide()
        self.engine = nil
        let started = ContinuousClock().now
        var detail: [String: String] = [:]
        switch strategy {
        case .dockThumbnail:
            if let thumbnail {
                let result = WindowActivator.pressThumbnail(thumbnail.element)
                detail["press"] = result.name
                if result != .success, let element = provider.element(for: id) {
                    strategy = .accessibility
                    detail["fallback"] = "accessibility"
                    detail.merge(WindowActivator.activateWithAccessibility(pid: window.pid, window: element)) { _, new in new }
                }
            }
        case .accessibility:
            if let element = provider.element(for: id) {
                detail = WindowActivator.activateWithAccessibility(pid: window.pid, window: element)
            } else {
                detail["error"] = "noElement"
            }
        case .runningApplication:
            detail = WindowActivator.activateWithRunningApplication(pid: window.pid, window: provider.element(for: id))
        }
        pending = PendingActivation(target: window, strategy: strategy, startedAt: started, detail: detail, exitAfterMs: nil)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            self?.verifyActivation()
        }
    }

    private func nextStrategy(hasThumbnail: Bool) -> ActivationStrategy {
        defer { attemptCounter += 1 }
        let rotation: [ActivationStrategy] = hasThumbnail
            ? [.dockThumbnail, .accessibility, .dockThumbnail, .runningApplication]
            : [.accessibility, .runningApplication]
        return rotation[attemptCounter % rotation.count]
    }

    private func verifyActivation() {
        guard let activation = pending else { return }
        pending = nil
        let focused = WindowActivator.focusedWindow()
        let exactWindow = focused?.windowID == activation.target.id
        let rightApp = focused?.pid == activation.target.pid
        let stayedOpen = missionControlOpen
        if stayedOpen {
            WindowActivator.postKey(KeyCode.escape)
        }
        report.attempts.append(.init(
            index: report.attempts.count + 1,
            strategy: activation.strategy.rawValue,
            targetApp: activation.target.appName,
            exactWindow: exactWindow,
            rightApp: rightApp,
            missionControlExitMs: activation.exitAfterMs,
            missionControlStayedOpen: stayedOpen,
            detail: activation.detail
        ))
        let mark = exactWindow ? "✅" : (rightApp ? "⚠️" : "❌")
        let exit = activation.exitAfterMs.map { "\(Int($0)) ms" } ?? t("did not close", "no se cerró")
        console.say("    \(mark) \(activation.strategy.rawValue) → \(activation.target.appName) · " + t(
            "exact window: \(exactWindow) · Mission Control closed: \(exit)",
            "ventana exacta: \(exactWindow) · Mission Control se cerró: \(exit)"
        ))
    }

    private func endSession(reason: String) {
        guard engine != nil || !sessionWindows.isEmpty else { return }
        interceptor.setMode(.off)
        overlay.hide()
        if let last = report.sessions.indices.last {
            report.sessions[last].keys = sessionKeys
            report.sessions[last].endReason = reason
        }
        engine = nil
        sessionWindows = [:]
        thumbnails = [:]
    }

    private func finish() {
        pollTask?.cancel()
        observer.stop()
        dockSniffer.stop()
        interceptor.setMode(.off)
        overlay.hide()
        report.finishedAt = Date()
        report.permissions = ProbeReport.Permissions()
        report.tapTimeouts = interceptor.timeoutCount
        interceptor.uninstall()
        report.verdicts = ProbeReport.verdicts(for: report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            try? data.write(to: outputDirectory.appendingPathComponent("report.json"))
        }
        let summary = report.markdownSummary()
        try? summary.write(to: outputDirectory.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
        console.title(t("Results", "Resultados"))
        console.say(summary)
        console.say()
        console.say(t("Done. Results saved in:", "Listo. Resultados guardados en:") + " \(outputDirectory.path)")
    }

    private func dumpOnly() async -> Int32 {
        guard ensureAccessibility() else { return 2 }
        console.say(t(
            "Open Mission Control now and leave it open. The Dock tree is saved in 5 seconds.",
            "Abrí Mission Control ahora y dejalo abierto. El árbol del Dock se guarda en 5 segundos."
        ))
        for remaining in stride(from: 5, through: 1, by: -1) {
            console.say("  \(remaining)…")
            try? await Task.sleep(for: .seconds(1))
        }
        saveDockTree(label: "manual")
        console.say(outputDirectory.path)
        return 0
    }

    private func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
        let components = (end - start).components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
