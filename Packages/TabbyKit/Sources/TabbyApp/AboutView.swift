import AppKit
import SwiftUI
import TabbyKit

struct AboutView: View {
    let version: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            BrandLogo(height: 84)
            Text(localized("Version \(version)", "Versión \(version)")).foregroundStyle(.secondary)
            Text(localized("Navigate Mission Control with your keyboard.", "Navegá Mission Control con el teclado."))
            if let repository = Brand.repository {
                Link("github.com/cristiandjr/tabby", destination: repository)
            }
            VStack(spacing: 10) {
                Text(localized("Made with ❤️ in Argentina 🇦🇷", "Hecho con ❤️ en Argentina 🇦🇷"))
                    .font(.headline)
                Text(localized(
                    "Tabby is free and open source. If it saves you time every day, you can buy me a coffee: every contribution helps add features and keep Tabby up to date with each new macOS.",
                    "Tabby es gratis y de código abierto. Si te ahorra tiempo todos los días, podés invitarme un café: cada aporte ayuda a sumar funciones y a mantener Tabby al día con cada macOS nuevo."
                ))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text(localized("Mercado Pago alias", "Alias de Mercado Pago"))
                        .foregroundStyle(.secondary)
                    Text(Brand.mercadoPagoAlias)
                        .font(.body.monospaced().bold())
                        .textSelection(.enabled)
                    Button(copied ? localized("Copied ✓", "Copiado ✓") : localized("Copy alias", "Copiar alias")) {
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
            Text(localized(
                "MIT license. The Tabby name, logo and icon belong to their author.",
                "Licencia MIT. El nombre, el logo y el ícono de Tabby son de su autor."
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
