import AppKit
import SwiftUI
import TabbyKit

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, accessibility, test, lift, done
    }

    @Bindable var model: AppModel
    let finish: () -> Void
    @State private var step = Step.welcome
    @State private var detectionsAtStart = 0

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.rawValue) { item in
                        Circle()
                            .fill(item == step ? Brand.blue : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step != .welcome {
                    Button(localized("Back", "Atrás")) { move(by: -1) }
                }
                Button(primaryTitle) { step == .done ? finish() : move(by: 1) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.blue)
            }
        }
        .padding(28)
        .frame(width: 540, height: 440)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 14) {
                BrandLogo(height: 110)
                Text(localized("Welcome to Tabby", "Bienvenido a Tabby")).font(.title2.bold())
                Text(localized("Navigate Mission Control without touching your mouse.", "Navegá Mission Control sin tocar el mouse."))
                    .foregroundStyle(.secondary)
                shortcutList.padding(.top, 6)
            }
        case .accessibility:
            page(
                image: Image(systemName: "hand.raised.circle.fill"),
                title: localized("Accessibility permission", "Permiso de Accesibilidad"),
                text: localized(
                    "Tabby needs it to detect Mission Control, read your windows and focus the one you choose. It only listens to the keyboard while Mission Control is open.",
                    "Tabby lo necesita para detectar Mission Control, leer tus ventanas y enfocar la que elijas. Solo escucha el teclado mientras Mission Control está abierto."
                )
            ) {
                if model.hasAccessibility {
                    status(localized("Permission granted", "Permiso concedido"))
                } else {
                    Button(localized("Open System Settings", "Abrir Configuración del Sistema")) {
                        model.requestAccessibility()
                    }
                    Text(localized("Turn on Tabby in the list. This page updates by itself.", "Activá Tabby en la lista. Esta pantalla se actualiza sola."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        case .test:
            page(
                image: Image(systemName: "rectangle.3.group.fill"),
                title: localized("Try it", "Probalo"),
                text: localized(
                    "Open Mission Control the way you usually do: its shortcut, F3, the trackpad gesture or a hot corner.",
                    "Abrí Mission Control como siempre: con su atajo, F3, el gesto o una esquina activa."
                )
            ) {
                if !model.hasAccessibility {
                    Text(localized("First grant the Accessibility permission.", "Primero dale el permiso de Accesibilidad."))
                        .foregroundStyle(.orange)
                } else if model.missionControlDetections > detectionsAtStart {
                    status(localized("Detected! Press Tab to choose and Return to go there.", "¡Detectado! Tocá Tab para elegir y Enter para ir a esa ventana."))
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(localized("Waiting for Mission Control…", "Esperando Mission Control…")).foregroundStyle(.secondary)
                    }
                    Button(localized("Open Mission Control", "Abrir Mission Control")) {
                        model.openMissionControl()
                    }
                }
            }
        case .lift:
            page(
                image: Image(systemName: "sparkles.rectangle.stack.fill"),
                title: localized("Lift the selected window", "Agrandar la ventana seleccionada"),
                text: localized(
                    "Optional. The selected window grows a little so you always see where you are. It needs Screen Recording: Tabby keeps the images in memory only while Mission Control is open.",
                    "Opcional. La ventana elegida crece un poco para que siempre veas dónde estás. Necesita Grabación de pantalla: Tabby guarda las imágenes en memoria solo mientras Mission Control está abierto."
                )
            ) {
                Toggle(localized("Lift the selected window", "Agrandar la ventana seleccionada"), isOn: $model.liftsSelection)
                    .toggleStyle(.switch)
                if model.liftsSelection {
                    if model.hasScreenRecording {
                        status(localized("Screen Recording allowed", "Grabación de pantalla permitida"))
                    } else {
                        Button(localized("Allow Screen Recording…", "Permitir Grabación de pantalla…")) {
                            model.requestScreenRecording()
                        }
                    }
                }
            }
        case .done:
            page(
                image: Image(systemName: "checkmark.circle.fill"),
                title: localized("All set", "¡Listo!"),
                text: localized("Tabby lives in the menu bar. Change everything in Settings (⌘,).", "Tabby vive en la barra de menús. Cambiá todo en Configuración (⌘,).")
            ) {
                shortcutList
                Toggle(localized("Launch at login", "Abrir al iniciar sesión"), isOn: $model.launchesAtLogin)
                    .toggleStyle(.switch)
                    .disabled(model.isTranslocated)
                if model.isTranslocated {
                    Text(localized(
                        "To launch at login, move Tabby to Applications and open it again.",
                        "Para abrir al iniciar sesión, mové Tabby a Aplicaciones y abrila de nuevo."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Text(localized("Made with ❤️ in Argentina 🇦🇷", "Hecho con ❤️ en Argentina 🇦🇷"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var shortcutList: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            row(KeyLabels.describe(model.shortcuts.next), localized("next window", "siguiente ventana"))
            row(KeyLabels.describe(model.shortcuts.previous), localized("previous window", "ventana anterior"))
            row(KeyLabels.describe(model.shortcuts.activate), localized("go to the window", "ir a la ventana"))
            row("\(model.shortcuts.moveModifiers.symbols)1…9", localized("move it to that desktop", "moverla a ese escritorio"))
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: localized("Get Started", "Empezar")
        case .done: localized("Finish", "Terminar")
        default: localized("Continue", "Continuar")
        }
    }

    private func move(by offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        if next == .test {
            detectionsAtStart = model.missionControlDetections
        }
        step = next
    }

    private func row(_ keys: String, _ action: String) -> some View {
        GridRow {
            Text(keys).font(.body.monospaced()).foregroundStyle(.primary)
            Text(action).foregroundStyle(.secondary)
        }
    }

    private func status(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
    }

    private func page<Extra: View>(image: Image, title: String, text: String, @ViewBuilder extra: () -> Extra) -> some View {
        VStack(spacing: 14) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(Brand.gradient)
            Text(title).font(.title2.bold())
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10, content: extra)
                .padding(.top, 6)
        }
        .frame(maxWidth: 440)
    }
}
