import Testing
@testable import TabbyKit

@Suite("MissionControlDetector")
struct MissionControlDetectorTests {
    @Test func reportsOpeningOnce() {
        var detector = MissionControlDetector()
        #expect(detector.feed(true) == .opened)
        #expect(detector.feed(true) == nil)
    }

    @Test func confirmsClosingAfterTwoReadings() {
        var detector = MissionControlDetector()
        _ = detector.feed(true)
        #expect(detector.feed(false) == nil)
        #expect(detector.feed(false) == .closed)
        #expect(detector.feed(false) == nil)
    }

    @Test func ignoresUnknownReadings() {
        var detector = MissionControlDetector()
        #expect(detector.feed(nil) == nil)
        _ = detector.feed(true)
        #expect(detector.feed(nil) == nil)
        #expect(detector.isOpen)
    }

    @Test func closedWhileAlreadyClosedIsNotAChange() {
        var detector = MissionControlDetector()
        #expect(detector.feed(false) == nil)
    }
}
