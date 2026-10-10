import AppKit
import SwiftUI
import TabbyKit

struct AboutView: View {
    let version: String

    var body: some View {
        VStack(spacing: 12) {
            BrandLogo(height: 84)
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Navigate Mission Control with your keyboard.")
            if let repository = Brand.repository {
                Link("github.com/cristiandjr/tabby", destination: repository)
            }
            VStack(spacing: 12) {
                Text("Made with ❤️ in Argentina 🇦🇷")
                    .font(.headline)
                Text("Tabby is free and open source. If it saves you time every day, you can buy me a coffee: every contribution helps add features and keep Tabby up to date with each new macOS.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                CopyRow(label: "Mercado Pago alias (Argentina)", value: Brand.mercadoPagoAlias, button: "Copy alias")
                CopyRow(label: "USDT on the \(Brand.usdtNetwork) network (anywhere in the world)", value: Brand.usdtAddress, button: "Copy address")
                Text("Send only USDT on the \(Brand.usdtNetwork) network to that address.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

private struct CopyRow: View {
    let label: String
    let value: String
    let button: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(value)
                    .font(.callout.monospaced().bold())
                    .textSelection(.enabled)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(copied ? "Copied ✓" : button) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                    copied = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
