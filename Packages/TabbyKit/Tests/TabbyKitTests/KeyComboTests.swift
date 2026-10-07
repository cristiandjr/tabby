import CoreGraphics
import Foundation
import Testing
@testable import TabbyKit

@Suite("KeyCombo")
struct KeyComboTests {
    @Test func ignoresFlagsThatAreNotModifiers() {
        let flags: CGEventFlags = [.maskShift, .maskNumericPad, .maskSecondaryFn, .maskAlphaShift]
        #expect(ModifierSet(flags) == .shift)
    }

    @Test func matchesShiftTabOnlyForPrevious() {
        #expect(KeyCombo.previous.matches(keyCode: KeyCode.tab, flags: .maskShift))
        #expect(!KeyCombo.next.matches(keyCode: KeyCode.tab, flags: .maskShift))
        #expect(KeyCombo.next.matches(keyCode: KeyCode.tab, flags: []))
    }

    @Test func arrowFlagsDoNotBreakMatching() {
        let combo = KeyCombo(keyCode: 124)
        #expect(combo.matches(keyCode: 124, flags: [.maskNumericPad, .maskSecondaryFn]))
    }

    @Test func symbolsFollowTheMacOSOrder() {
        let modifiers: ModifierSet = [.command, .shift, .option, .control]
        #expect(modifiers.symbols == "⌃⌥⇧⌘")
    }

    @Test func roundTripsThroughJSON() throws {
        let combo = KeyCombo(keyCode: 46, modifiers: [.command, .shift])
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
    }

    @Test func standardBindingsResolveNavigationKeys() {
        let bindings = KeyboardInterceptor.Bindings.standard
        #expect(bindings.key(for: KeyCode.tab, flags: []) == .next)
        #expect(bindings.key(for: KeyCode.tab, flags: .maskShift) == .previous)
        #expect(bindings.key(for: KeyCode.returnKey, flags: []) == .select)
        #expect(bindings.key(for: KeyCode.keypadEnter, flags: .maskNumericPad) == .select)
        #expect(bindings.key(for: KeyCode.escape, flags: []) == nil)
        #expect(bindings.key(for: KeyCode.tab, flags: .maskCommand) == nil)
    }
}
