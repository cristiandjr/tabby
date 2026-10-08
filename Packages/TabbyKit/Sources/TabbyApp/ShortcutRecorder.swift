import AppKit
import SwiftUI
import TabbyKit

struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(recording ? "Press keys…" : KeyLabels.describe(combo))
                .frame(minWidth: 120)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear(perform: stop)
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                let modifiers = ModifierSet(event.cgEvent?.flags ?? [])
                if event.keyCode != KeyCode.escape || !modifiers.isEmpty {
                    combo = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
                }
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = false
    }
}
