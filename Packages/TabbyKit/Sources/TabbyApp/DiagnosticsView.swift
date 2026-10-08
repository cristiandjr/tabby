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
                    check(localized("Accessibility", "Accesibilidad"), report.accessibility)
                    check(localized("Keyboard (only while Mission Control is open)", "Teclado (solo con Mission Control abierto)"), report.keyboardTap)
                    check(localized("Screen Recording (optional)", "Grabación de pantalla (opcional)"), report.screenRecording)
                    check(localized("Secure Input off", "Entrada segura desactivada"), !report.secureInput)
                }
                ScrollView {
                    Text(report.text)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                Text(localized(
                    "The report has no window titles, keystrokes or personal data. Paste it in a GitHub issue.",
                    "El reporte no tiene títulos de ventanas, teclas ni datos personales. Pegalo en un issue de GitHub."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            HStack {
                Button(localized("Open Mission Control", "Abrir Mission Control")) {
                    model.openMissionControl()
                }
                Button(localized("Refresh", "Actualizar")) {
                    refresh()
                }
                Spacer()
                Button(copied ? localized("Copied ✓", "Copiado ✓") : localized("Copy Report", "Copiar reporte")) {
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
