import CoreGraphics

public struct Keymap: Codable, Hashable, Sendable {
    public var bindings: [KeyCombo: SessionAction]

    public init(bindings: [KeyCombo: SessionAction]) {
        self.bindings = bindings
    }

    public static let standard = Keymap(bindings: [
        .next: .next,
        .previous: .previous,
        .select: .activate,
        .selectKeypad: .activate,
    ])

    public func action(forKeyCode keyCode: UInt16, flags: CGEventFlags) -> SessionAction? {
        bindings[KeyCombo(keyCode: keyCode, modifiers: ModifierSet(flags))]
    }
}
