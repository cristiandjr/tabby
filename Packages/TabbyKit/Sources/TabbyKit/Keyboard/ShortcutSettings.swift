public struct ShortcutSettings: Codable, Equatable, Sendable {
    public enum Issue: Equatable, Sendable {
        case duplicate(KeyCombo)
        case clashesWithMove(KeyCombo)
        case systemShortcut(KeyCombo)

        public var isError: Bool {
            if case .systemShortcut = self { return false }
            return true
        }
    }

    public var next: KeyCombo
    public var previous: KeyCombo
    public var activate: KeyCombo
    public var moveModifiers: ModifierSet

    public init(next: KeyCombo, previous: KeyCombo, activate: KeyCombo, moveModifiers: ModifierSet) {
        self.next = next
        self.previous = previous
        self.activate = activate
        self.moveModifiers = moveModifiers
    }

    public static let standard = ShortcutSettings(next: .next, previous: .previous, activate: .select, moveModifiers: .command)

    public static let moveModifierChoices: [ModifierSet] = [.command, .option, [.option, .command], [.shift, .command], [.control, .option]]

    static let arrowKeys: Set<UInt16> = [123, 124, 125, 126]

    public var navigation: [KeyCombo] {
        [next, previous, activate]
    }

    public var keymap: Keymap {
        var bindings = Keymap.moveToDesktop(modifiers: moveModifiers)
        bindings[next] = .next
        bindings[previous] = .previous
        bindings[activate] = .activate
        if activate == .select {
            bindings[.selectKeypad] = .activate
        }
        return Keymap(bindings: bindings)
    }

    public var issues: [Issue] {
        var found: [Issue] = []
        let combos = navigation
        for (index, combo) in combos.enumerated() where combos[..<index].contains(combo) {
            found.append(.duplicate(combo))
        }
        let moveCombos = Set(Keymap.moveToDesktop(modifiers: moveModifiers).keys)
        found += combos.filter(moveCombos.contains).map(Issue.clashesWithMove)
        found += (combos + Array(moveCombos).sorted { $0.keyCode < $1.keyCode })
            .filter(Self.isSystemDesktopShortcut)
            .map(Issue.systemShortcut)
        return found
    }

    public var isValid: Bool {
        !issues.contains { $0.isError }
    }

    static func isSystemDesktopShortcut(_ combo: KeyCombo) -> Bool {
        guard combo.modifiers == .control else { return false }
        return arrowKeys.contains(combo.keyCode) || KeyCode.digits.contains(combo.keyCode)
    }
}
