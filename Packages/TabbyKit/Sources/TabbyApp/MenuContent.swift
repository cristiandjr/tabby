import SwiftUI
import TabbyKit

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let update = model.availableUpdate {
            Button("New Version \(update.version) Available…") {
                model.openUpdate()
            }
            Divider()
        }
        Text(model.status)
        if !model.hasAccessibility {
            Button("Grant Accessibility Permission…") {
                model.openAccessibilitySettings()
            }
        } else if model.liftsSelection && !model.hasScreenRecording {
            Button("Allow Screen Recording to Lift Windows…") {
                model.requestScreenRecording()
            }
        }
        Divider()
        Toggle("Enabled", isOn: $model.isEnabled)
        Button("Settings…") {
            model.showSettings(using: openSettings)
        }
        .keyboardShortcut(",")
        Button("Diagnostics…") {
            model.showDiagnostics()
        }
        Divider()
        Button("Open Mission Control") {
            model.openMissionControl()
        }
        Divider()
        Button("About Tabby") {
            model.showSettings(using: openSettings, tab: .about)
        }
        Divider()
        Button("Quit Tabby") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
