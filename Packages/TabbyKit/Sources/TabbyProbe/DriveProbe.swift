import AppKit
import TabbyKit

@MainActor
enum DriveProbe {
    static func run(cycles: Int = 6) async -> Int32 {
        guard AX.isTrusted, SystemStatus.postEventAccess else {
            AX.requestTrust()
            say("The app that launched the probe needs Accessibility permission and permission to post events.")
            return 2
        }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.cristiandjr.tabby").isEmpty else {
            say("Tabby.app is not running.")
            return 1
        }
        AX.setGlobalTimeout(0.3)
        let originalApp = NSWorkspace.shared.frontmostApplication
        let provider = WindowProvider()
        var passed = 0
        say("drive: \(cycles) cycles against Tabby.app")
        for index in 0..<cycles {
            let all = provider.snapshot()
            let order = all.filter { $0.displayID == all.first?.displayID }.map(\.id)
            guard order.count >= 2 else {
                say("  at least 2 windows are needed")
                break
            }
            let tabs = index % min(3, order.count)
            let expected = order[(1 + tabs) % order.count]
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            guard await waitUntil(timeout: .seconds(3), { isOpen }) else {
                say("  \(index + 1). Mission Control did not open")
                continue
            }
            try? await Task.sleep(for: .milliseconds(600))
            for _ in 0..<tabs where isOpen {
                WindowActivator.postKey(KeyCode.tab)
                try? await Task.sleep(for: .milliseconds(150))
            }
            if isOpen {
                WindowActivator.postKey(KeyCode.returnKey)
            }
            let closed = await waitUntil(timeout: .seconds(2), { !isOpen })
            try? await Task.sleep(for: .milliseconds(700))
            let focused = WindowActivator.focusedWindow()?.windowID
            let exact = focused == expected
            if exact { passed += 1 }
            say("  \(index + 1). tabs \(tabs) · Mission Control closed \(closed) · exact window \(exact)")
            if isOpen {
                WindowActivator.postKey(KeyCode.escape)
                try? await Task.sleep(for: .milliseconds(600))
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        originalApp?.activate(options: [])
        say("drive: \(passed)/\(cycles) exact")
        return passed == cycles ? 0 : 1
    }

    private static var isOpen: Bool {
        DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature())
    }

    private static func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private static func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}
