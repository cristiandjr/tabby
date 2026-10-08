import AppKit
import SwiftUI
import TabbyKit

struct DiagnosticsView: View {
    let model: AppModel
    @State private var report: DiagnosticsReport?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let report {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    check("Accessibility", report.accessibility)
                    check("Keyboard (only while Mission Control is open)", report.keyboardTap)
                    check("Screen Recording (optional)", report.screenRecording)
                    check("Secure Input off", !report.secureInput)
                }
                ScrollView {
                    Text(report.text)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                Text("The report has no window titles, keystrokes or personal data. Paste it in a GitHub issue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Open Mission Control") {
                    model.openMissionControl()
                }
                Button("Refresh") {
                    refresh()
                }
                Spacer()
                Button(copied ? "Copied ✓" : "Copy Report") {
                    refresh()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report?.text ?? "", forType: .string)
                    copied = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 600, height: 520)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        report = model.diagnosticsReport()
        copied = false
    }

    private func check(_ title: String, _ ok: Bool) -> some View {
        GridRow {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(title)
        }
    }
}
