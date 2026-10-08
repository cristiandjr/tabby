import AppKit
import TabbyKit

@MainActor
final class DemoRunner {
    private let controller = SessionController()
    private let selfTest: Bool
    private var lastActivation: (window: MissionWindow, exact: Bool, strategy: ActivationStrategy)?

    init(selfTest: Bool) {
        self.selfTest = selfTest
    }

    func run() async -> Int32 {
        guard AX.isTrusted else {
            AX.requestTrust()
            say(t(
                "This terminal app needs Accessibility permission: System Settings → Privacy & Security → Accessibility. Then run the command again.",
                "Esta app de terminal necesita permiso de Accesibilidad: Configuración del Sistema → Privacidad y seguridad → Accesibilidad. Después volvé a correr el comando."
            ))
            return 2
        }
        controller.onEvent = { [weak self] event in
            self?.log(event)
        }
        guard controller.start() else {
            say(t("Tabby could not start the keyboard tap.", "Tabby no pudo iniciar el tap de teclado."))
            return 2
        }
        if selfTest {
            return await runSelfTest()
        }
        say(t(
            """
            Tabby (demo) is running ✓
            Open Mission Control the way you always do, then:
              Tab / ⇧Tab   choose a window
              Return (↩)   go to that window
              Esc          close without choosing
            Press Ctrl+C here to quit.
            """,
            """
            Tabby (demo) está funcionando ✓
            Abrí Mission Control como siempre y después:
              Tab / ⇧Tab   elegir una ventana
              Enter (↩)    ir a esa ventana
              Esc          cerrar sin elegir
            Presioná Ctrl+C acá para salir.
            """
        ))
        while true {
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    private func log(_ event: SessionController.Event) {
        switch event {
        case .opened(let count):
            say("● " + t("Mission Control · \(count) windows", "Mission Control · \(count) ventanas"))
        case .selected(let window):
            say("  → \(describe(window))")
        case .activated(let window, let exact, let strategy, _):
            lastActivation = (window, exact, strategy)
            say("  \(exact ? "✅" : "⚠️") \(describe(window))" + (exact ? "" : t(" (focus did not match)", " (el foco no coincidió)")))
        case .closed:
            say("○ " + t("closed", "cerrado"))
        }
    }

    private func runSelfTest() async -> Int32 {
        let originalApp = NSWorkspace.shared.frontmostApplication
        let cycles = 6
        var passed = 0
        say("self-test: \(cycles) cycles")
        for index in 0..<cycles {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            guard await waitUntil(timeout: .seconds(3), { self.controller.isSessionActive }) else {
                say("  \(index + 1). session did not start")
                continue
            }
            try? await Task.sleep(for: .milliseconds(450))
            lastActivation = nil
            for _ in 0..<(index % 3) where controller.isSessionActive {
                WindowActivator.postKey(KeyCode.tab)
                try? await Task.sleep(for: .milliseconds(150))
            }
            let thumbnailInfo = "thumbnails \(controller.matchedThumbnails) · selected has thumbnail \(controller.selectedHasThumbnail)"
            if controller.isSessionActive {
                WindowActivator.postKey(KeyCode.returnKey)
            }
            say("     \(thumbnailInfo)")
            _ = await waitUntil(timeout: .seconds(3), { self.lastActivation != nil })
            if lastActivation?.exact == true { passed += 1 }
            say("  \(index + 1). \(lastActivation.map { "\($0.strategy.rawValue) exact=\($0.exact)" } ?? "no activation")")
            try? await Task.sleep(for: .milliseconds(700))
            if DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature()) {
                WindowActivator.postKey(KeyCode.escape)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        controller.stop()
        originalApp?.activate(options: [])
        say("self-test: \(passed)/\(cycles) exact")
        return passed == cycles ? 0 : 1
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

    private func describe(_ window: MissionWindow) -> String {
        window.title.map { "\(window.appName) — \($0)" } ?? window.appName
    }

    private func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}
