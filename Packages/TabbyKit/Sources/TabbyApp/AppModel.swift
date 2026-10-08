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

    var liftsSelection = UserDefaults.standard.object(forKey: AppModel.liftsSelectionKey) as? Bool ?? true {
        didSet { applyLiftsSelection() }
    }

    private(set) var hasAccessibility = AX.isTrusted
    private(set) var hasScreenRecording = OverlayPresenter.canCaptureWindows

    @ObservationIgnored let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    @ObservationIgnored private static let liftsSelectionKey = "liftsSelection"
    @ObservationIgnored private let presenter = OverlayPresenter()
    @ObservationIgnored private let controller: SessionController
    @ObservationIgnored private let log = Log.logger("app")
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var screenRecordingTask: Task<Void, Never>?

    init() {
        controller = SessionController(dependencies: .live(presenter: presenter))
        presenter.liftsSelection = liftsSelection
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

    func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        screenRecordingTask?.cancel()
        screenRecordingTask = Task { @MainActor [weak self] in
            for _ in 0..<120 {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.hasScreenRecording = OverlayPresenter.canCaptureWindows
                if self.hasScreenRecording { return }
            }
        }
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

    private func applyLiftsSelection() {
        UserDefaults.standard.set(liftsSelection, forKey: Self.liftsSelectionKey)
        presenter.liftsSelection = liftsSelection
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
            hasScreenRecording = OverlayPresenter.canCaptureWindows
            log.info("mission control opened with \(windows) windows")
        case .activated(_, let result):
            log.info("activated exact=\(result.exact) strategy=\(result.strategy.rawValue, privacy: .public) in \(Int(result.elapsed / .milliseconds(1)))ms")
        case .moved(_, let desktop, let result):
            log.info("moved to desktop \(desktop) result=\(String(describing: result), privacy: .public)")
        case .selected, .closed:
            break
        }
    }
}
