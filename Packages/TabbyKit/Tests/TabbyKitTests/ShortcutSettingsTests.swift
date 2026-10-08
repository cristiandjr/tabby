import Foundation
import Testing
@testable import TabbyKit

@Suite("ShortcutSettings")
struct ShortcutSettingsTests {
    @Test func standardMatchesTheDefaultKeymap() {
        let keymap = ShortcutSettings.standard.keymap
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: []) == .next)
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: .maskShift) == .previous)
        #expect(keymap.action(forKeyCode: KeyCode.returnKey, flags: []) == .activate)
        #expect(keymap.action(forKeyCode: KeyCode.keypadEnter, flags: []) == .activate)
        #expect(keymap.action(forKeyCode: 20, flags: .maskCommand) == .moveToDesktop(3))
        #expect(ShortcutSettings.standard.isValid)
        #expect(ShortcutSettings.standard.issues.isEmpty)
    }

    @Test func customShortcutsReplaceTheDefaults() {
        var settings = ShortcutSettings.standard
        settings.next = KeyCombo(keyCode: 124, modifiers: .option)
        settings.moveModifiers = [.option, .shift]
        let keymap = settings.keymap
        #expect(keymap.action(forKeyCode: 124, flags: .maskAlternate) == .next)
        #expect(keymap.action(forKeyCode: KeyCode.tab, flags: []) == nil)
        #expect(keymap.action(forKeyCode: 20, flags: [.maskAlternate, .maskShift]) == .moveToDesktop(3))
        #expect(keymap.action(forKeyCode: 20, flags: .maskCommand) == nil)
    }

    @Test func keypadEnterOnlyFollowsReturn() {
        var settings = ShortcutSettings.standard
        settings.activate = KeyCombo(keyCode: 49)
        #expect(settings.keymap.action(forKeyCode: KeyCode.keypadEnter, flags: []) == nil)
    }

    @Test func rejectsTheSameShortcutForTwoActions() {
        var settings = ShortcutSettings.standard
        settings.previous = .next
        #expect(settings.issues == [.duplicate(.next)])
        #expect(!settings.isValid)
    }

    @Test func rejectsANavigationShortcutThatMovesWindows() {
        var settings = ShortcutSettings.standard
        settings.activate = KeyCombo(keyCode: 18, modifiers: .command)
        #expect(settings.issues.contains(.clashesWithMove(KeyCombo(keyCode: 18, modifiers: .command))))
        #expect(!settings.isValid)
    }

    @Test func warnsAboutNativeDesktopShortcutsWithoutBlocking() {
        var settings = ShortcutSettings.standard
        settings.next = KeyCombo(keyCode: 124, modifiers: .control)
        #expect(settings.issues == [.systemShortcut(KeyCombo(keyCode: 124, modifiers: .control))])
        #expect(settings.isValid)
        settings = .standard
        settings.moveModifiers = .control
        #expect(settings.issues.count == 9)
        #expect(settings.isValid)
    }

    @Test func roundTripsThroughJSON() throws {
        var settings = ShortcutSettings.standard
        settings.moveModifiers = [.control, .option]
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(ShortcutSettings.self, from: data) == settings)
    }
}
