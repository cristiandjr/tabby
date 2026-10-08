import AppKit
import TabbyKit

@MainActor
enum NotificationSniffer {
    private static var records: [(ms: Int, source: String, name: String)] = []
    private static var start = ContinuousClock().now

    static func run(cycles: Int = 3) async -> Int32 {
        guard AX.isTrusted, SystemStatus.postEventAccess else {
            AX.requestTrust()
            say("Accessibility and post-event permissions are needed.")
            return 2
        }
        start = ContinuousClock().now
        let distributed = DistributedNotificationCenter.default()
        let distributedToken = distributed.addObserver(forName: nil, object: nil, queue: .main) { notification in
            let name = notification.name.rawValue
            MainActor.assumeIsolated { record("distributed", name) }
        }
        let workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(forName: nil, object: nil, queue: .main) { notification in
            let name = notification.name.rawValue
            MainActor.assumeIsolated { record("workspace", name) }
        }
        try? await Task.sleep(for: .seconds(2))
        record("probe", "baseline-end")
        for index in 1...cycles {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            _ = await waitUntil(timeout: .seconds(3), { isOpen })
            record("probe", "mc-open-\(index)")
            try? await Task.sleep(for: .milliseconds(1200))
            WindowActivator.postKey(KeyCode.escape)
            _ = await waitUntil(timeout: .seconds(3), { !isOpen })
            record("probe", "mc-closed-\(index)")
            try? await Task.sleep(for: .milliseconds(1500))
        }
        distributed.removeObserver(distributedToken)
        NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken)
        let baselineNames = Set(records.prefix { $0.name != "baseline-end" }.map(\.name))
        for entry in records where entry.source == "probe" || !baselineNames.contains(entry.name) {
            say("\(entry.ms) ms  \(entry.source)  \(entry.name)")
        }
        say("total notifications: \(records.count)")
        return 0
    }

    private static func record(_ source: String, _ name: String) {
        let elapsed = (ContinuousClock().now - start).components
        records.append((Int(elapsed.seconds) * 1000 + Int(elapsed.attoseconds / 1_000_000_000_000_000), source, name))
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
