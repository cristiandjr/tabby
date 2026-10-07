import CoreGraphics
import Testing
@testable import TabbyKit

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
    @Test func convertsTopLeftToBottomLeftCoordinates() {
        let rect = ScreenGeometry.appKitRect(fromGlobal: CGRect(x: 100, y: 50, width: 200, height: 100), primaryScreenHeight: 1000)
        #expect(rect == CGRect(x: 100, y: 850, width: 200, height: 100))
    }

    @Test func conversionIsReversible() {
        let original = CGRect(x: -300, y: 120, width: 640, height: 480)
        let appKit = ScreenGeometry.appKitRect(fromGlobal: original, primaryScreenHeight: 1117)
        #expect(ScreenGeometry.globalRect(fromAppKit: appKit, primaryScreenHeight: 1117) == original)
    }

    @Test func handlesScreensAboveThePrimaryScreen() {
        let rect = ScreenGeometry.appKitRect(fromGlobal: CGRect(x: 0, y: -500, width: 100, height: 100), primaryScreenHeight: 1000)
        #expect(rect == CGRect(x: 0, y: 1400, width: 100, height: 100))
    }
}
