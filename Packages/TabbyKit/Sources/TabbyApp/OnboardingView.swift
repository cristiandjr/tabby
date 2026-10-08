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
                    Button("Back") { move(by: -1) }
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
                Text("Welcome to Tabby").font(.title2.bold())
                Text("Navigate Mission Control without touching your mouse.")
                    .foregroundStyle(.secondary)
                shortcutList.padding(.top, 6)
            }
        case .accessibility:
            page(
                image: Image(systemName: "hand.raised.circle.fill"),
                title: "Accessibility permission",
                text: "Tabby needs it to detect Mission Control, read your windows and focus the one you choose. It only listens to the keyboard while Mission Control is open."
            ) {
                if model.hasAccessibility {
                    status("Permission granted")
                } else {
                    Button("Open System Settings") {
                        model.requestAccessibility()
                    }
                    Text("Turn on Tabby in the list. This page updates by itself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        case .test:
            page(
                image: Image(systemName: "rectangle.3.group.fill"),
                title: "Try it",
                text: "Open Mission Control the way you usually do: its shortcut, F3, the trackpad gesture or a hot corner."
            ) {
                if !model.hasAccessibility {
                    Text("First grant the Accessibility permission.")
                        .foregroundStyle(.orange)
                } else if model.missionControlDetections > detectionsAtStart {
                    status("Detected! Press Tab to choose and Return to go there.")
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for Mission Control…").foregroundStyle(.secondary)
                    }
                    Button("Open Mission Control") {
                        model.openMissionControl()
                    }
                }
            }
        case .lift:
            page(
                image: Image(systemName: "sparkles.rectangle.stack.fill"),
                title: "Lift the selected window",
                text: "Optional. The selected window grows a little so you always see where you are. It needs Screen Recording: Tabby keeps the images in memory only while Mission Control is open."
            ) {
                Toggle("Lift the selected window", isOn: $model.liftsSelection)
                    .toggleStyle(.switch)
                if model.liftsSelection {
                    if model.hasScreenRecording {
                        status("Screen Recording allowed")
                    } else {
                        Button("Allow Screen Recording…") {
                            model.requestScreenRecording()
                        }
                    }
                }
            }
        case .done:
            page(
                image: Image(systemName: "checkmark.circle.fill"),
                title: "All set",
                text: "Tabby lives in the menu bar. Change everything in Settings (⌘,)."
            ) {
                shortcutList
                Toggle("Launch at login", isOn: $model.launchesAtLogin)
                    .toggleStyle(.switch)
                    .disabled(model.isTranslocated)
                if model.isTranslocated {
                    Text("To launch at login, move Tabby to Applications and open it again.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("Made with ❤️ in Argentina 🇦🇷")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var shortcutList: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            row(KeyLabels.describe(model.shortcuts.next), "next window")
            row(KeyLabels.describe(model.shortcuts.previous), "previous window")
            row(KeyLabels.describe(model.shortcuts.activate), "go to the window")
            row("\(model.shortcuts.moveModifiers.symbols)1…9", "move it to that desktop")
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .done: "Finish"
        default: "Continue"
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
