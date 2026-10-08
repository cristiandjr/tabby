import SwiftUI
import TabbyKit

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(model.status)
        if !model.hasAccessibility {
            Button(localized("Grant Accessibility Permission…", "Dar permiso de Accesibilidad…")) {
                model.openAccessibilitySettings()
            }
        } else if model.liftsSelection && !model.hasScreenRecording {
            Button(localized("Allow Screen Recording to Lift Windows…", "Permitir Grabación de pantalla para agrandar…")) {
                model.requestScreenRecording()
            }
        }
        Divider()
        Toggle(localized("Enabled", "Activado"), isOn: $model.isEnabled)
        Button(localized("Settings…", "Configuración…")) {
            model.showSettings(using: openSettings)
        }
        .keyboardShortcut(",")
        Divider()
        Button(localized("Open Mission Control", "Abrir Mission Control")) {
            model.openMissionControl()
        }
        Divider()
        Text(localized("Version \(model.version)", "Versión \(model.version)"))
        Button(localized("Quit Tabby", "Salir de Tabby")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
