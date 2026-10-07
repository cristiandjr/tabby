import CoreGraphics

public struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let shift = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    public init(_ flags: CGEventFlags) {
        var set: ModifierSet = []
        if flags.contains(.maskControl) { set.insert(.control) }
        if flags.contains(.maskAlternate) { set.insert(.option) }
        if flags.contains(.maskShift) { set.insert(.shift) }
        if flags.contains(.maskCommand) { set.insert(.command) }
        self = set
    }

    public var symbols: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }
}

public enum KeyCode {
    public static let tab: UInt16 = 48
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let escape: UInt16 = 53
}

public struct KeyCombo: Codable, Hashable, Sendable {
    public let keyCode: UInt16
    public let modifiers: ModifierSet

    public init(keyCode: UInt16, modifiers: ModifierSet = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        self.keyCode == keyCode && modifiers == ModifierSet(flags)
    }

    public static let next = KeyCombo(keyCode: KeyCode.tab)
    public static let previous = KeyCombo(keyCode: KeyCode.tab, modifiers: .shift)
    public static let select = KeyCombo(keyCode: KeyCode.returnKey)
    public static let selectKeypad = KeyCombo(keyCode: KeyCode.keypadEnter)
}
