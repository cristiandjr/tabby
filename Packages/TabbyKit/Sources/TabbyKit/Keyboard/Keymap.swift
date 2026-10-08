import CoreGraphics

public struct Keymap: Codable, Hashable, Sendable {
    public var bindings: [KeyCombo: SessionAction]

    public init(bindings: [KeyCombo: SessionAction]) {
        self.bindings = bindings
    }

    public static let standard = ShortcutSettings.standard.keymap

    public static func moveToDesktop(modifiers: ModifierSet) -> [KeyCombo: SessionAction] {
        KeyCode.digits.enumerated().reduce(into: [:]) { result, item in
            result[KeyCombo(keyCode: item.element, modifiers: modifiers)] = .moveToDesktop(item.offset + 1)
        }
    }

    public func action(forKeyCode keyCode: UInt16, flags: CGEventFlags) -> SessionAction? {
        bindings[KeyCombo(keyCode: keyCode, modifiers: ModifierSet(flags))]
    }
}
