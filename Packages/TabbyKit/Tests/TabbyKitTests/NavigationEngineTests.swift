import CoreGraphics
import Testing
@testable import TabbyKit

@Suite("NavigationEngine")
struct NavigationEngineTests {
    @Test func startsOnThePreviouslyUsedWindow() {
        let engine = NavigationEngine(windowIDs: [10, 20, 30])
        #expect(engine.selectedID == 20)
        #expect(engine.selectedIndex == 1)
    }

    @Test func selectsTheOnlyWindow() {
        let engine = NavigationEngine(windowIDs: [10])
        #expect(engine.selectedID == 10)
    }

    @Test func emptyListHasNoSelection() {
        var engine = NavigationEngine(windowIDs: [])
        engine.next()
        engine.previous()
        #expect(engine.selectedID == nil)
        #expect(engine.selectedIndex == nil)
    }

    @Test func nextWrapsAround() {
        var engine = NavigationEngine(windowIDs: [1, 2, 3])
        engine.next()
        #expect(engine.selectedID == 3)
        engine.next()
        #expect(engine.selectedID == 1)
    }

    @Test func previousWrapsAround() {
        var engine = NavigationEngine(windowIDs: [1, 2, 3], initialIndex: 0)
        engine.previous()
        #expect(engine.selectedID == 3)
        engine.previous()
        #expect(engine.selectedID == 2)
    }

    @Test func keepsTheSelectionWhenTheListIsReordered() {
        var engine = NavigationEngine(windowIDs: [1, 2, 3])
        engine.update(windowIDs: [3, 2, 1])
        #expect(engine.selectedID == 2)
    }

    @Test func movesToTheNextWindowWhenTheSelectedOneDisappears() {
        var engine = NavigationEngine(windowIDs: [1, 2, 3])
        engine.update(windowIDs: [1, 3])
        #expect(engine.selectedID == 3)
    }

    @Test func movesToThePreviousWindowWhenTheLastOneDisappears() {
        var engine = NavigationEngine(windowIDs: [1, 2, 3], initialIndex: 2)
        engine.update(windowIDs: [1, 2])
        #expect(engine.selectedID == 2)
    }

    @Test func clearsTheSelectionWhenAllWindowsDisappear() {
        var engine = NavigationEngine(windowIDs: [1, 2])
        engine.update(windowIDs: [])
        #expect(engine.selectedID == nil)
    }
}
