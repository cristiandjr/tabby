import AppKit
import SwiftUI
import TabbyKit

enum SettingsTab: Hashable {
    case general
    case shortcuts
    case about
}

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView(selection: $model.settingsTab) {
            GeneralSettings(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ShortcutsSettings(model: model)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(SettingsTab.shortcuts)
            AboutView(version: model.version)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $model.isEnabled)
                Toggle("Launch at login", isOn: $model.launchesAtLogin)
                    .disabled(model.isTranslocated)
            } footer: {
                if model.isTranslocated {
                    Text("To launch at login, move Tabby to Applications and open it again.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Show the welcome tour") {
                    model.showOnboarding()
                }
            }
            Section {
                Toggle("Lift the selected window", isOn: $model.liftsSelection)
                PermissionRow(
                    title: "Screen Recording",
                    granted: model.hasScreenRecording,
                    action: model.requestScreenRecording
                )
            } footer: {
                Text("Optional. Tabby captures the windows of the current display only while Mission Control is open, keeps them in memory and drops them when it closes.")
                    .foregroundStyle(.secondary)
            }
            Section("Required") {
                PermissionRow(
                    title: "Accessibility",
                    granted: model.hasAccessibility,
                    action: model.openAccessibilitySettings
                )
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutsSettings: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Next window") {
                    ShortcutRecorder(combo: binding(\.next))
                }
                LabeledContent("Previous window") {
                    ShortcutRecorder(combo: binding(\.previous))
                }
                LabeledContent("Go to window") {
                    ShortcutRecorder(combo: binding(\.activate))
                }
                Picker("Move to desktop", selection: moveModifiers) {
                    ForEach(ShortcutSettings.moveModifierChoices, id: \.rawValue) { modifiers in
                        Text("\(modifiers.symbols) 1…9").tag(modifiers)
                    }
                }
            } header: {
                Text("Inside Mission Control")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                        Text(message.text).foregroundStyle(message.isError ? .red : .orange)
                    }
                    Text("Shortcuts only work while Mission Control is open. If the desktop doesn't exist, Tabby creates it.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Restore default shortcuts") {
                    model.resetShortcuts()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var messages: [(text: String, isError: Bool)] {
        let rejected = model.rejectedShortcutIssues.filter(\.isError).map { (Self.describe($0, rejected: true), true) }
        let warnings = model.shortcuts.issues.filter { !$0.isError }.map { (Self.describe($0, rejected: false), false) }
        return rejected + warnings
    }

    private var moveModifiers: Binding<ModifierSet> {
        Binding(get: { model.shortcuts.moveModifiers }, set: { value in model.updateShortcuts { $0.moveModifiers = value } })
    }

    private func binding(_ path: WritableKeyPath<ShortcutSettings, KeyCombo>) -> Binding<KeyCombo> {
        Binding(get: { model.shortcuts[keyPath: path] }, set: { value in model.updateShortcuts { $0[keyPath: path] = value } })
    }

    private static func describe(_ issue: ShortcutSettings.Issue, rejected: Bool) -> String {
        let prefix = rejected ? "Not saved: " : ""
        switch issue {
        case .duplicate(let combo):
            return prefix + "\(KeyLabels.describe(combo)) is already used by another action"
        case .clashesWithMove(let combo):
            return prefix + "\(KeyLabels.describe(combo)) already moves windows to a desktop"
        case .systemShortcut(let combo):
            return "\(KeyLabels.describe(combo)) switches desktops in macOS; inside Mission Control Tabby will use it instead"
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        LabeledContent(title) {
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow…", action: action)
            }
        }
    }
}
