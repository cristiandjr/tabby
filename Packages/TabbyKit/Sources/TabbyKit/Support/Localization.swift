import Foundation

let prefersSpanish = Locale.preferredLanguages.first?.lowercased().hasPrefix("es") ?? false

public func localized(_ english: String, _ spanish: String) -> String {
    prefersSpanish ? spanish : english
}
