import AppKit
import Observation
import ServiceManagement
import SwiftUI
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

    private(set) var shortcuts = AppModel.loadShortcuts()
    private(set) var rejectedShortcutIssues: [ShortcutSettings.Issue] = []
    private(set) var hasAccessibility = AX.isTrusted
    private(set) var hasScreenRecording = OverlayPresenter.canCaptureWindows
    private(set) var missionControlDetections = 0
    var settingsTab = SettingsTab.general

    let isTranslocated = Bundle.main.bundlePath.contains("/AppTranslocation/")

    @ObservationIgnored let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    @ObservationIgnored private static let liftsSelectionKey = "liftsSelection"
    @ObservationIgnored private static let shortcutsKey = "shortcuts"
    @ObservationIgnored private static let onboardingKey = "onboardingCompleted"
    @ObservationIgnored private let onboarding = HostedWindow()
    @ObservationIgnored private let diagnostics = HostedWindow()
    @ObservationIgnored private var lastSession: DiagnosticsReport.Session?
    @ObservationIgnored private var windowObserver: NSObjectProtocol?
    @ObservationIgnored private let presenter = OverlayPresenter()
    @ObservationIgnored private let controller: SessionController
    @ObservationIgnored private let log = Log.logger("app")
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var screenRecordingTask: Task<Void, Never>?

    init() {
        controller = SessionController(dependencies: .live(presenter: presenter))
        presenter.liftsSelection = liftsSelection
        controller.setKeymap(shortcuts.keymap)
        controller.onEvent = { [weak self] event in
            self?.record(event)
        }
        windowObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
            let closing = (notification.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                self?.hideFromDockIfNoWindows(closing: closing)
            }
        }
        let needsOnboarding = !UserDefaults.standard.bool(forKey: Self.onboardingKey)
        if hasAccessibility {
            startIfNeeded()
        } else {
            if !needsOnboarding {
                AX.requestTrust()
            }
            waitForAccessibility()
        }
        if needsOnboarding {
            Task { @MainActor [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func showOnboarding() {
        showInDock()
        onboarding.show(title: "Tabby", transparentTitleBar: true, onClose: { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.onboardingKey)
            self?.hasAccessibility = AX.isTrusted
        }, content: {
            OnboardingView(model: self) { [weak self] in self?.onboarding.close() }
        })
    }

    func showDiagnostics() {
        showInDock()
        diagnostics.show(title: "Tabby Diagnostics") {
            DiagnosticsView(model: self)
        }
    }

    func requestAccessibility() {
        AX.requestTrust()
        openAccessibilitySettings()
        if permissionTask == nil {
            waitForAccessibility()
        }
    }

    func diagnosticsReport() -> DiagnosticsReport {
        hasAccessibility = AX.isTrusted
        hasScreenRecording = OverlayPresenter.canCaptureWindows
        let shortcuts = shortcuts
        return DiagnosticsReport(
            appVersion: version,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev",
            macOS: SystemStatus.macOSVersion.replacingOccurrences(of: "Version ", with: ""),
            architecture: Self.architecture,
            displays: NSScreen.screens.map { .init(width: Int($0.frame.width), height: Int($0.frame.height), scale: $0.backingScaleFactor) },
            accessibility: hasAccessibility,
            screenRecording: hasScreenRecording,
            postEvents: SystemStatus.postEventAccess,
            listenEvents: SystemStatus.listenEventAccess,
            secureInput: SystemStatus.secureInputEnabled,
            privateWindowAPI: PrivateAXBridge.isAvailable,
            enabled: isEnabled,
            running: controller.isRunning,
            keyboardTap: controller.keyboardTapInstalled,
            tapTimeouts: controller.keyboardTapTimeouts,
            shortcuts: [
                "next \(KeyLabels.describe(shortcuts.next))",
                "previous \(KeyLabels.describe(shortcuts.previous))",
                "go \(KeyLabels.describe(shortcuts.activate))",
                "move \(shortcuts.moveModifiers.symbols)1…9",
            ],
            liftSetting: liftsSelection,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            translocated: isTranslocated,
            launchAtLogin: Self.launchAtLoginStatus,
            lastSession: lastSession
        )
    }

    private func showInDock() {
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }

    private func hideFromDockIfNoWindows(closing: ObjectIdentifier?) {
        Task { @MainActor in
            await Task.yield()
            let open = NSApplication.shared.windows.contains { window in
                ObjectIdentifier(window) != closing && window.isVisible && !(window is NSPanel) && window.styleMask.contains(.titled)
            }
            if !open {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "Apple Silicon"
        #else
        "Intel"
        #endif
    }

    private static var launchAtLoginStatus: String {
        switch SMAppService.mainApp.status {
        case .enabled: "enabled"
        case .notRegistered: "not registered"
        case .requiresApproval: "requires approval"
        case .notFound: "not found"
        @unknown default: "unknown"
        }
    }

    var status: String {
        guard hasAccessibility else {
            return "Waiting for Accessibility permission"
        }
        return isEnabled
            ? "Tabby is active"
            : "Tabby is paused"
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func updateShortcuts(_ change: (inout ShortcutSettings) -> Void) {
        var candidate = shortcuts
        change(&candidate)
        guard candidate.isValid else {
            rejectedShortcutIssues = candidate.issues
            return
        }
        rejectedShortcutIssues = []
        shortcuts = candidate
        controller.setKeymap(candidate.keymap)
        if let data = try? JSONEncoder().encode(candidate) {
            UserDefaults.standard.set(data, forKey: Self.shortcutsKey)
        }
    }

    func resetShortcuts() {
        updateShortcuts { $0 = .standard }
    }

    func showSettings(using openSettings: OpenSettingsAction, tab: SettingsTab? = nil) {
        if let tab {
            settingsTab = tab
        }
        hasScreenRecording = OverlayPresenter.canCaptureWindows
        hasAccessibility = AX.isTrusted
        showInDock()
        NSApplication.shared.activate()
        openSettings()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            NSApplication.shared.windows
                .first { !($0 is NSPanel) && $0.isVisible && $0.styleMask.contains(.titled) }?
                .orderFrontRegardless()
        }
    }

    private static func loadShortcuts() -> ShortcutSettings {
        guard let data = UserDefaults.standard.data(forKey: shortcutsKey),
              let saved = try? JSONDecoder().decode(ShortcutSettings.self, from: data),
              saved.isValid
        else { return .standard }
        return saved
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
                    self.permissionTask = nil
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
            missionControlDetections += 1
            lastSession = DiagnosticsReport.Session(windows: windows, thumbnails: controller.matchedThumbnails)
            log.info("mission control opened with \(windows) windows")
        case .activated(_, let result):
            lastSession?.activation = result
            log.info("activated exact=\(result.exact) strategy=\(result.strategy.rawValue, privacy: .public) in \(Int(result.elapsed / .milliseconds(1)))ms")
        case .moved(_, let desktop, let result):
            lastSession?.move = result
            log.info("moved to desktop \(desktop) result=\(String(describing: result), privacy: .public)")
        case .selected, .closed:
            break
        }
    }
}
