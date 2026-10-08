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

    @Test func standardKeymapResolvesSessionActions() {
        let keymap = Keymap.standard
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: []) == .next)
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: .maskShift) == .previous)
        #expect(keymap.action(forKeyCode: KeyCode.returnKey, flags: []) == .activate)
        #expect(keymap.action(forKeyCode: KeyCode.keypadEnter, flags: .maskNumericPad) == .activate)
        #expect(keymap.action(forKeyCode: KeyCode.escape, flags: []) == nil)
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: .maskCommand) == nil)
    }

    @Test func onlyNavigationRepeatsWhenHeld() {
        #expect(SessionAction.next.repeatsWhenHeld)
        #expect(SessionAction.previous.repeatsWhenHeld)
        #expect(!SessionAction.activate.repeatsWhenHeld)
    }

    @Test func keymapRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Keymap.standard)
        #expect(try JSONDecoder().decode(Keymap.self, from: data) == .standard)
    }
}
