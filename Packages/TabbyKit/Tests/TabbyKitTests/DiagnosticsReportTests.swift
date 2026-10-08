import Testing
@testable import TabbyKit

@Suite("DiagnosticsReport")
struct DiagnosticsReportTests {
    private func report(accessibility: Bool = true, session: DiagnosticsReport.Session? = nil) -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: "0.1.0", build: "202610081006", macOS: "27.0.1 (26A434)", architecture: "arm64",
            displays: [.init(width: 1920, height: 1080, scale: 1), .init(width: 1680, height: 1050, scale: 2)],
            accessibility: accessibility, screenRecording: true, postEvents: true, listenEvents: true, secureInput: false,
            privateWindowAPI: true, enabled: true, running: true, keyboardTap: true, tapTimeouts: 0,
            shortcuts: ["next ⇥", "previous ⇧⇥"], liftSetting: true, reduceMotion: false, translocated: false,
            launchAtLogin: "not registered", lastSession: session
        )
    }

    @Test func capabilityLevelFollowsPermissionAndThumbnails() {
        #expect(report(accessibility: false).capabilityLevel == 0)
        #expect(report().capabilityLevel == nil)
        #expect(report(session: .init(windows: 4, thumbnails: 0)).capabilityLevel == 2)
        #expect(report(session: .init(windows: 4, thumbnails: 4)).capabilityLevel == 3)
    }

    @Test func describesTheEnvironmentWithoutPersonalData() {
        let activation = ActivationResult(exact: true, strategy: .dockThumbnail, elapsed: .milliseconds(29))
        let text = report(session: .init(windows: 5, thumbnails: 5, activation: activation, move: .moved(createdDesktops: 1))).text
        #expect(text.contains("Tabby 0.1.0 (202610081006)"))
        #expect(text.contains("Displays: 1920×1080 @1x, 1680×1050 @2x"))
        #expect(text.contains("Capability level: 3 (full)"))
        #expect(text.contains("Last activation: exact · dockThumbnail · 29 ms"))
        #expect(text.contains("Last move: moved(createdDesktops: 1)"))
        #expect(text.contains("Lift effect: on · active: yes"))
    }

    @Test func asksToOpenMissionControlBeforeTheFirstSession() {
        #expect(report().text.contains("Capability level: unknown, open Mission Control once"))
    }
}
