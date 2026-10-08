import AppKit
import SwiftUI
import TabbyKit

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralSettings(model: model)
                .tabItem { Label(localized("General", "General"), systemImage: "gearshape") }
            ShortcutsSettings(model: model)
                .tabItem { Label(localized("Shortcuts", "Atajos"), systemImage: "keyboard") }
            AboutView(version: model.version)
                .tabItem { Label(localized("About", "Acerca de"), systemImage: "info.circle") }
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle(localized("Enabled", "Activado"), isOn: $model.isEnabled)
                Toggle(localized("Launch at login", "Abrir al iniciar sesión"), isOn: $model.launchesAtLogin)
                    .disabled(model.isTranslocated)
            } footer: {
                if model.isTranslocated {
                    Text(localized(
                        "To launch at login, move Tabby to Applications and open it again.",
                        "Para abrir al iniciar sesión, mové Tabby a Aplicaciones y abrila de nuevo."
                    ))
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(localized("Show the welcome tour", "Ver la bienvenida")) {
                    model.showOnboarding()
                }
            }
            Section {
                Toggle(localized("Lift the selected window", "Agrandar la ventana seleccionada"), isOn: $model.liftsSelection)
                PermissionRow(
                    title: localized("Screen Recording", "Grabación de pantalla"),
                    granted: model.hasScreenRecording,
                    action: model.requestScreenRecording
                )
            } footer: {
                Text(localized(
                    "Optional. Tabby captures the windows of the current display only while Mission Control is open, keeps them in memory and drops them when it closes.",
                    "Opcional. Tabby captura las ventanas de la pantalla actual solo mientras Mission Control está abierto, las guarda en memoria y las descarta al cerrarlo."
                ))
                .foregroundStyle(.secondary)
            }
            Section(localized("Required", "Obligatorio")) {
                PermissionRow(
                    title: localized("Accessibility", "Accesibilidad"),
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
                LabeledContent(localized("Next window", "Siguiente ventana")) {
                    ShortcutRecorder(combo: binding(\.next))
                }
                LabeledContent(localized("Previous window", "Ventana anterior")) {
                    ShortcutRecorder(combo: binding(\.previous))
                }
                LabeledContent(localized("Go to window", "Ir a la ventana")) {
                    ShortcutRecorder(combo: binding(\.activate))
                }
                Picker(localized("Move to desktop", "Mover a escritorio"), selection: moveModifiers) {
                    ForEach(ShortcutSettings.moveModifierChoices, id: \.rawValue) { modifiers in
                        Text("\(modifiers.symbols) 1…9").tag(modifiers)
                    }
                }
            } header: {
                Text(localized("Inside Mission Control", "Dentro de Mission Control"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                        Text(message.text).foregroundStyle(message.isError ? .red : .orange)
                    }
                    Text(localized(
                        "Shortcuts only work while Mission Control is open. If the desktop doesn't exist, Tabby creates it.",
                        "Los atajos solo funcionan con Mission Control abierto. Si el escritorio no existe, Tabby lo crea."
                    ))
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(localized("Restore default shortcuts", "Restablecer atajos")) {
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
        let prefix = rejected ? localized("Not saved: ", "No se guardó: ") : ""
        switch issue {
        case .duplicate(let combo):
            return prefix + localized("\(KeyLabels.describe(combo)) is already used by another action", "\(KeyLabels.describe(combo)) ya lo usa otra acción")
        case .clashesWithMove(let combo):
            return prefix + localized("\(KeyLabels.describe(combo)) already moves windows to a desktop", "\(KeyLabels.describe(combo)) ya mueve ventanas a un escritorio")
        case .systemShortcut(let combo):
            return localized(
                "\(KeyLabels.describe(combo)) switches desktops in macOS; inside Mission Control Tabby will use it instead",
                "\(KeyLabels.describe(combo)) cambia de escritorio en macOS; dentro de Mission Control lo va a usar Tabby"
            )
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
                Label(localized("Allowed", "Permitido"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(localized("Allow…", "Permitir…"), action: action)
            }
        }
    }
}
