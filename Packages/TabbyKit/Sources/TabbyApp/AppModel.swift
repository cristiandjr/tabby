import AppKit
import Observation
import ServiceManagement
import TabbyKit

@MainActor
@Observable
final class AppModel {
    var isEnabled = true {
        didSet { applyEnabled() }
    }

    var launchesAtLogin = SMAppService.mainApp.status == .enabled {
        didSet { applyLaunchAtLogin() }
    }

    private(set) var hasAccessibility = AX.isTrusted

    @ObservationIgnored let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    @ObservationIgnored private let controller = SessionController()
    @ObservationIgnored private let log = Log.logger("app")
    @ObservationIgnored private var permissionTask: Task<Void, Never>?

    init() {
        controller.onEvent = { [weak self] event in
            self?.record(event)
        }
        if hasAccessibility {
            startIfNeeded()
        } else {
            AX.requestTrust()
            waitForAccessibility()
        }
    }

    var status: String {
        guard hasAccessibility else {
            return localized("Waiting for Accessibility permission", "Esperando el permiso de Accesibilidad")
        }
        return isEnabled
            ? localized("Tabby is active", "Tabby está activo")
            : localized("Tabby is paused", "Tabby está en pausa")
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openMissionControl() {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private func applyEnabled() {
        if isEnabled {
            startIfNeeded()
        } else {
            controller.stop()
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchesAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startIfNeeded() {
        guard isEnabled, hasAccessibility, !controller.isRunning else { return }
        if !controller.start() {
            log.error("session controller did not start")
        }
    }

    private func waitForAccessibility() {
        permissionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if AX.isTrusted {
                    self.hasAccessibility = true
                    self.startIfNeeded()
                    return
                }
            }
        }
    }

    private func record(_ event: SessionController.Event) {
        switch event {
        case .opened(let windows):
            log.info("mission control opened with \(windows) windows")
        case .activated(_, let exact, let strategy, let elapsed):
            log.info("activated exact=\(exact) strategy=\(strategy.rawValue, privacy: .public) in \(Int(elapsed / .milliseconds(1)))ms")
        case .selected, .closed:
            break
        }
    }
}
