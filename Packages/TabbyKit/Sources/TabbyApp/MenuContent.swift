import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel

    var body: some View {
        Text(model.status)
        if !model.hasAccessibility {
            Button(localized("Grant Accessibility Permission…", "Dar permiso de Accesibilidad…")) {
                model.openAccessibilitySettings()
            }
        }
        Divider()
        Toggle(localized("Enabled", "Activado"), isOn: $model.isEnabled)
        Toggle(localized("Lift the Selected Window", "Agrandar la ventana seleccionada"), isOn: $model.liftsSelection)
        if model.liftsSelection && !model.hasScreenRecording {
            Button(localized("Allow Screen Recording to Lift Windows…", "Permitir Grabación de pantalla para agrandar…")) {
                model.requestScreenRecording()
            }
        }
        Toggle(localized("Launch at Login", "Abrir al iniciar sesión"), isOn: $model.launchesAtLogin)
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
