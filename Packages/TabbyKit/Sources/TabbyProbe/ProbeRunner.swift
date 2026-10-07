import AppKit
import OSLog
import TabbyKit

enum ProbeCommand: String {
    case run
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
    private let observer = MissionControlObserver()
    private let interceptor = KeyboardInterceptor()
    private let provider = WindowProvider()
    private let overlay = SelectionOverlay()
    private let dumpFinished = Inbox<Bool>()
    private let outputDirectory: URL
    private let startedAt: ContinuousClock.Instant

    private var report = ProbeReport()
    private var phase: Phase = .idle
    private var missionControlOpen = false
    private var lastKeyDown: (code: UInt16, modifiers: ModifierSet, at: ContinuousClock.Instant)?
    private var dumpedDuringDetection = false
    private var referenceWindowIDs: Set<CGWindowID> = []

    private var engine: NavigationEngine?
    private var sessionWindows: [CGWindowID: MissionWindow] = [:]
    private var thumbnails: [CGWindowID: DockCandidate] = [:]
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
        }
    }

    private func printEnvironment() {
        console.say("tabby-probe · \(SystemStatus.macOSVersion)")
        console.say("Accessibility: \(SystemStatus.accessibilityTrusted)")
        console.say("Input Monitoring: \(SystemStatus.listenEventAccess)")
        console.say("Post events: \(SystemStatus.postEventAccess)")
        console.say("Secure input: \(SystemStatus.secureInputEnabled)")
        console.say("Dock pid: \(DockAccessibility.pid.map { String($0) } ?? "-")")
        console.say("_AXUIElementGetWindow: \(PrivateAXBridge.isAvailable)")
        for screen in NSScreen.screens {
            console.say("Screen: \(screen.localizedName) \(NSStringFromRect(screen.frame)) @\(screen.backingScaleFactor)x")
        }
    }

    private func guided() async -> Int32 {
        console.title("Tabby probe · Spike 0")
        console.say(t("Guided test, about 10 minutes. Results stay on this Mac:", "Prueba guiada de unos 10 minutos. Los resultados quedan en esta Mac:"))
        console.say("  \(outputDirectory.path)")
        guard ensureAccessibility() else { return 2 }
        AX.setGlobalTimeout(0.3)
        report.screens = NSScreen.screens.map {
            ProbeReport.Screen(name: $0.localizedName, frame: $0.frame, scale: Double($0.backingScaleFactor))
        }
        startObserving()
        await stepWindows()
        await stepDetection()
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
        interceptor.onKey = { [weak self] key in
            self?.handleKey(key)
        }
        interceptor.onKeyDown = { [weak self] code, modifiers in
            self?.lastKeyDown = (code, modifiers, ContinuousClock().now)
        }
        report.tapInstalled = interceptor.install()
        let registrationText = report.observerRegistration.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        console.say(t("Mission Control observer: ", "Observador de Mission Control: ") + registrationText)
        console.say(t("Keyboard tap installed: ", "Tap de teclado instalado: ") + (report.tapInstalled ? "✅" : "❌"))
    }

    private func stepWindows() async {
        console.title(t("Step 1/4 · Windows", "Paso 1/4 · Ventanas"))
        console.say(t(
            "Open several windows. Ideally: 2 overlapping Finder windows, a browser, 2 Terminal windows and VS Code.",
            "Abrí varias ventanas. Ideal: 2 ventanas de Finder superpuestas, un navegador, 2 ventanas de Terminal y VS Code."
        ))
        await console.waitForReturn(t("When they are open, press Return here.", "Cuando estén abiertas, presioná Return acá."))
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
            "Windows: \(windows.count) · matched with _AXUIElementGetWindow: \(diagnostics.matchedByPrivateAPI) · by frame: \(diagnostics.matchedByFrame) · unmatched: \(diagnostics.unmatched) · \(Int(elapsed)) ms",
            "Ventanas: \(windows.count) · emparejadas con _AXUIElementGetWindow: \(diagnostics.matchedByPrivateAPI) · por frame: \(diagnostics.matchedByFrame) · sin emparejar: \(diagnostics.unmatched) · \(Int(elapsed)) ms"
        ))
    }

    private func stepDetection() async {
        phase = .detection
        console.title(t("Step 2/4 · Detection", "Paso 2/4 · Detección"))
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
        await console.waitForReturn(t("When you are done, press Return here.", "Cuando termines, presioná Return acá."))
        interceptor.setMode(.off)
        phase = .idle
        let opens = report.events.filter { $0.phase == Phase.detection.rawValue && $0.name == MissionControlEvent.showAllWindows.rawValue }.count
        let exits = report.events.filter { $0.phase == Phase.detection.rawValue && $0.name == MissionControlEvent.exit.rawValue }.count
        console.say(t("Detected \(opens) openings and \(exits) closings.", "Detecté \(opens) aperturas y \(exits) cierres."))
    }

    private func stepNativeKeys() async {
        phase = .nativeKeys
        console.title(t("Step 3/4 · Native Mission Control keys", "Paso 3/4 · Teclas nativas de Mission Control"))
        console.say(t(
            "Tabby is not intercepting anything now. Open Mission Control and try: ← → ↑ ↓, Tab, Space and Return. Then close it (Esc) and come back here.",
            "Ahora Tabby no intercepta nada. Abrí Mission Control y probá: ← → ↑ ↓, Tab, Espacio y Return. Después cerralo (Esc) y volvé acá."
        ))
        await console.waitForReturn(t("Press Return here when you are back.", "Presioná Return acá cuando vuelvas."))
        report.nativeKeys["arrowsMoveSelection"] = await answer(t("Did the arrow keys move a highlight between windows?", "¿Las flechas movieron un resaltado entre ventanas?"))
        report.nativeKeys["tabDidSomething"] = await answer(t("Did Tab do anything visible?", "¿Tab hizo algo visible?"))
        report.nativeKeys["spaceShowedPreview"] = await answer(t("Did Space enlarge or preview a window?", "¿Espacio agrandó o previsualizó una ventana?"))
        report.nativeKeys["returnOpenedWindow"] = await answer(t("Did Return open a window?", "¿Return abrió una ventana?"))
        phase = .idle
    }

    private func stepDemo() async {
        phase = .demo
        console.title(t("Step 4/4 · Tabby demo", "Paso 4/4 · Demo de Tabby"))
        console.say(t(
            """
            Now Tabby takes over Tab and Return while Mission Control is open.
            Repeat at least 6 times:
              1. Open Mission Control.
              2. Press Tab a few times (⇧Tab goes back). Tabby highlights a window.
              3. Press Return to jump to it.
            At least once, pick a window that overlaps another window of the same app.
            Esc cancels. Each result is printed here.
            """,
            """
            Ahora Tabby toma Tab y Return mientras Mission Control está abierto.
            Repetí al menos 6 veces:
              1. Abrí Mission Control.
              2. Presioná Tab varias veces (⇧Tab vuelve). Tabby resalta una ventana.
              3. Presioná Return para ir a esa ventana.
            Al menos una vez, elegí una ventana que esté encima de otra de la misma app.
            Esc cancela. Cada resultado aparece acá.
            """
        ))
        await console.waitForReturn(t("When you are done, come back to Terminal and press Return here.", "Cuando termines, volvé a Terminal y presioná Return acá."))
        endSession(reason: "stepEnded")
        phase = .idle
        guard !report.sessions.isEmpty else { return }
        report.answers["sawHUD"] = await answer(t("While Mission Control was open, did you see Tabby's bar at the bottom?", "Con Mission Control abierto, ¿viste la barra de Tabby abajo?"))
        if report.sessions.contains(where: { $0.thumbnailsFound > 0 }) {
            report.answers["sawHighlight"] = await answer(t("Did you see a colored box around the highlighted thumbnail?", "¿Viste un recuadro de color alrededor de la miniatura resaltada?"))
            report.answers["highlightAligned"] = await answer(t("Was the box exactly on the thumbnail?", "¿El recuadro estaba justo sobre la miniatura?"))
        }
        report.answers["missionControlReactedToTab"] = await answer(t("When you pressed Tab, did Mission Control itself also react?", "Cuando presionaste Tab, ¿Mission Control también reaccionó por su cuenta?"))
        report.answers["landedOnHighlighted"] = await answer(t("After Return, did you land on the window Tabby had highlighted?", "Después de Return, ¿terminaste en la ventana que Tabby había resaltado?"))
    }

    private func answer(_ question: String) async -> String {
        switch await console.askYesNo(question) {
        case true?: "yes"
        case false?: "no"
        case nil: "skipped"
        }
    }

    private func handle(_ event: MissionControlEvent, at instant: ContinuousClock.Instant) {
        report.events.append(.init(name: event.rawValue, atMs: milliseconds(from: startedAt, to: instant), phase: phase.rawValue))
        log.info("event \(event.rawValue, privacy: .public) phase \(self.phase.rawValue, privacy: .public)")
        switch event {
        case .showAllWindows:
            missionControlOpen = true
            console.say("  ● " + t("Mission Control opened", "Mission Control abierto"))
            missionControlOpened(at: instant)
        case .exit:
            missionControlOpen = false
            console.say("  ○ " + t("Mission Control closed", "Mission Control cerrado"))
            missionControlClosed(at: instant)
        case .showFrontWindows, .showDesktop:
            console.say("  · \(event.rawValue)")
        }
    }

    private func missionControlOpened(at instant: ContinuousClock.Instant) {
        switch phase {
        case .detection:
            if let key = lastKeyDown, instant - key.at < .milliseconds(1500) {
                let latency = milliseconds(from: key.at, to: instant)
                report.triggers.append(.init(keyCode: Int(key.code), modifiers: key.modifiers.symbols, latencyMs: latency))
                console.say("    " + t("latency from the key press: \(Int(latency)) ms", "latencia desde la tecla: \(Int(latency)) ms"))
            }
            if !dumpedDuringDetection {
                dumpedDuringDetection = true
                scheduleTreeDumps()
                scheduleWindowSnapshotDuringMissionControl()
            }
        case .demo:
            startSession()
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

    private func scheduleWindowSnapshotDuringMissionControl() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, self.missionControlOpen else { return }
            let started = ContinuousClock().now
            let windows = self.provider.snapshot()
            let elapsed = self.milliseconds(from: started, to: ContinuousClock().now)
            self.report.windowsDuringMissionControl = .init(
                windows: windows,
                diagnostics: self.provider.lastDiagnostics,
                reference: self.referenceWindowIDs,
                snapshotMs: elapsed
            )
        }
    }

    private func startSession() {
        endSession(reason: "replaced")
        let started = ContinuousClock().now
        let windows = provider.snapshot()
        let snapshotMs = milliseconds(from: started, to: ContinuousClock().now)
        sessionWindows = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        engine = NavigationEngine(windowIDs: windows.map(\.id))
        thumbnails = [:]
        sessionKeys = [:]
        report.sessions.append(.init(index: report.sessions.count + 1, windows: windows.count, snapshotMs: snapshotMs, secureInput: SystemStatus.secureInputEnabled))
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
        let candidates = DockAccessibility.pressableCandidates()
        for window in sessionWindows.values where thumbnails[window.id] == nil {
            if let match = DockAccessibility.bestThumbnail(for: window, in: candidates) {
                thumbnails[window.id] = match
            }
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
        let thumbnailFrame = thumbnails[id]?.frame
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
        observer.stop()
        interceptor.setMode(.off)
        overlay.hide()
        report.finishedAt = Date()
        report.permissions = ProbeReport.Permissions()
        report.tapDisabledBySystem = interceptor.systemDisableCount
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
        observer.onEvent = { [weak self] event, _ in
            guard let self, event == .showAllWindows else { return }
            self.missionControlOpen = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self else { return }
                self.saveDockTree(label: "manual")
                self.dumpFinished.push(true)
            }
        }
        guard observer.start() != nil else {
            console.say(t("Could not observe the Dock.", "No pude observar el Dock."))
            return 1
        }
        console.say(t("Open Mission Control now (60 s limit).", "Abrí Mission Control ahora (60 s de límite)."))
        let done = await dumpFinished.next(timeout: .seconds(60))
        observer.stop()
        console.say(done == true ? outputDirectory.path : t("Timed out.", "Se agotó el tiempo."))
        return done == true ? 0 : 1
    }

    private func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
        let components = (end - start).components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
