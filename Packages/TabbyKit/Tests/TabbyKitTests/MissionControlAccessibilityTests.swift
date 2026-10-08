import CoreGraphics
import Testing
@testable import TabbyKit

@Suite("MissionControlAccessibility")
struct MissionControlAccessibilityTests {
    private func window(_ id: CGWindowID, _ bundleID: String, _ title: String?, width: CGFloat = 800, height: CGFloat = 600) -> MissionWindow {
        MissionWindow(
            id: id,
            pid: 1,
            bundleID: bundleID,
            appName: bundleID,
            title: title,
            frame: CGRect(x: 0, y: 0, width: width, height: height),
            displayID: 1,
            zIndex: 0
        )
    }

    private func thumbnail(_ bundleID: String, _ title: String?, width: CGFloat = 400, height: CGFloat = 300) -> ThumbnailInfo {
        ThumbnailInfo(bundleID: bundleID, spaceID: "5", title: title, frame: CGRect(x: 0, y: 0, width: width, height: height))
    }

    @Test func parsesTheThumbnailIdentifier() {
        let info = ThumbnailInfo(identifier: "com.mitchellh.ghostty.space.4", title: "zsh", frame: CGRect(x: 1, y: 2, width: 3, height: 4))
        #expect(info?.bundleID == "com.mitchellh.ghostty")
        #expect(info?.spaceID == "4")
        #expect(info?.title == "zsh")
    }

    @Test func rejectsIdentifiersWithoutSpace() {
        #expect(ThumbnailInfo(identifier: "mc.display", title: nil, frame: .zero) == nil)
        #expect(ThumbnailInfo(identifier: nil, title: nil, frame: .zero) == nil)
    }

    @Test func matchesByBundleAndTitle() {
        let windows = [window(1, "com.apple.finder", "dev"), window(2, "com.apple.finder", "Downloads")]
        let thumbnails = [thumbnail("com.apple.finder", "Downloads"), thumbnail("com.apple.finder", "dev")]
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: thumbnails)
        #expect(matches[1] == 1)
        #expect(matches[2] == 0)
    }

    @Test func fallsBackToTheClosestAspectRatioWithinTheSameApp() {
        let windows = [window(1, "com.brave.Browser", nil, width: 1600, height: 900), window(2, "com.brave.Browser", nil, width: 600, height: 900)]
        let thumbnails = [thumbnail("com.brave.Browser", "Tall", width: 200, height: 300), thumbnail("com.brave.Browser", "Wide", width: 320, height: 180)]
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: thumbnails)
        #expect(matches[1] == 1)
        #expect(matches[2] == 0)
    }

    @Test func neverMatchesAcrossApps() {
        let matches = MissionControlAccessibility.match(
            windows: [window(1, "com.apple.finder", "dev")],
            thumbnails: [thumbnail("com.brave.Browser", "dev")]
        )
        #expect(matches.isEmpty)
    }
}
