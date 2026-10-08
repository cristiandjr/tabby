import AppKit
import SwiftUI
import TabbyKit

struct AboutView: View {
    let version: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            BrandLogo(height: 84)
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Navigate Mission Control with your keyboard.")
            if let repository = Brand.repository {
                Link("github.com/cristiandjr/tabby", destination: repository)
            }
            VStack(spacing: 10) {
                Text("Made with ❤️ in Argentina 🇦🇷")
                    .font(.headline)
                Text("Tabby is free and open source. If it saves you time every day, you can buy me a coffee: every contribution helps add features and keep Tabby up to date with each new macOS.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("Mercado Pago alias")
                        .foregroundStyle(.secondary)
                    Text(Brand.mercadoPagoAlias)
                        .font(.body.monospaced().bold())
                        .textSelection(.enabled)
                    Button(copied ? "Copied ✓" : "Copy alias") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Brand.mercadoPagoAlias, forType: .string)
                        copied = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.blue)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Brand.gradient.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.gradient.opacity(0.45)))
            Text("MIT license. The Tabby name, logo and icon belong to their author.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
