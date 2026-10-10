import CoreGraphics
import Foundation
import Testing
@testable import TabbyKit

@Suite("WindowFilter")
struct WindowFilterTests {
    private func record(id: CGWindowID, pid: pid_t = 100, layer: Int = 0, alpha: Double = 1, size: CGFloat = 400) -> CGWindowRecord {
        CGWindowRecord(id: id, pid: pid, ownerName: "App", layer: layer, alpha: alpha, bounds: CGRect(x: 0, y: 0, width: size, height: size))
    }

    @Test func keepsNormalWindowsInOrder() {
        let records: [CGWindowRecord] = [record(id: 1), record(id: 2)]
        let ids: [CGWindowID] = WindowFilter.candidates(records).map(\.id)
        let expected: [CGWindowID] = [1, 2]
        #expect(ids == expected)
    }

    @Test func dropsWindowsOutsideTheNormalLayer() {
        #expect(WindowFilter.candidates([record(id: 1, layer: 25)]).isEmpty)
    }

    @Test func dropsTransparentWindows() {
        #expect(WindowFilter.candidates([record(id: 1, alpha: 0)]).isEmpty)
    }

    @Test func dropsTinyWindows() {
        #expect(WindowFilter.candidates([record(id: 1, size: 20)]).isEmpty)
    }

    @Test func dropsExcludedProcesses() {
        let records: [CGWindowRecord] = [record(id: 1, pid: 7), record(id: 2, pid: 8)]
        let ids: [CGWindowID] = WindowFilter.candidates(records, excluding: [7]).map(\.id)
        let expected: [CGWindowID] = [2]
        #expect(ids == expected)
    }

    @MainActor @Test func picksTheDisplaySharingTheMostAreaAndNoneWhenOffScreen() {
        let displays: [(id: CGDirectDisplayID, bounds: CGRect)] = [
            (1, CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            (2, CGRect(x: 115, y: -1050, width: 1680, height: 1050)),
        ]
        #expect(WindowProvider.display(for: CGRect(x: 155, y: 101, width: 1722, height: 941), among: displays) == 1)
        #expect(WindowProvider.display(for: CGRect(x: 200, y: -600, width: 800, height: 500), among: displays) == 2)
        #expect(WindowProvider.display(for: CGRect(x: 100, y: -300, width: 800, height: 900), among: displays) == 1)
        #expect(WindowProvider.display(for: CGRect(x: -2023, y: 101, width: 1722, height: 941), among: displays) == nil)
        #expect(WindowProvider.display(for: CGRect(x: 1920, y: 0, width: 300, height: 300), among: displays) == nil)
    }

    @Test func parsesWindowServerDictionaries() {
        let dictionary: [String: Any] = [
            kCGWindowNumber as String: NSNumber(value: 42),
            kCGWindowOwnerPID as String: NSNumber(value: 314),
            kCGWindowOwnerName as String: "Finder",
            kCGWindowLayer as String: NSNumber(value: 0),
            kCGWindowAlpha as String: NSNumber(value: 1.0),
            kCGWindowBounds as String: CGRect(x: 10, y: 20, width: 800, height: 600).dictionaryRepresentation,
        ]
        let parsed = CGWindowRecord(dictionary: dictionary)
        #expect(parsed?.id == 42)
        #expect(parsed?.pid == 314)
        #expect(parsed?.ownerName == "Finder")
        #expect(parsed?.bounds == CGRect(x: 10, y: 20, width: 800, height: 600))
    }
}
