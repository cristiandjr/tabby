import AppKit
import SwiftUI

enum Brand {
    static let blue = Color(red: 0.04, green: 0.36, blue: 1.0)
    static let cyan = Color(red: 0.07, green: 0.85, blue: 1.0)
    static let gradient = LinearGradient(colors: [blue, cyan], startPoint: .bottomLeading, endPoint: .topTrailing)
    static let mercadoPagoAlias = "cristiandjr.mp"
    static let repository = URL(string: "https://github.com/cristiandjr/tabby")

    static func logo(dark: Bool) -> NSImage? {
        Bundle.main.url(forResource: dark ? "Logo-dark" : "Logo-light", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }
}

struct BrandLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var height: CGFloat

    var body: some View {
        if let image = Brand.logo(dark: colorScheme == .dark) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: height * 0.6, height: height * 0.6)
                Text("Tabby").font(.system(size: height * 0.35, weight: .bold))
            }
        }
    }
}
