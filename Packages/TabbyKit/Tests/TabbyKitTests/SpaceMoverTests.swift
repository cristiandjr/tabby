import CoreGraphics
import Testing
@testable import TabbyKit

@MainActor
@Suite("SpaceMover")
struct SpaceMoverTests {
    let system = FakeSpaceSystem()
    let clock = TestClock()
    let window = makeWindow(7)

    private var mover: SpaceMover {
        SpaceMover(system: system, clock: clock)
    }

    @Test func dragsTheThumbnailToAnExistingDesktop() async {
        let result = await mover.move(window, toDesktop: 2)
        #expect(result == .moved(createdDesktops: 0))
        #expect(system.additions == 0)
        #expect(system.events.first == .move(CGPoint(x: 250, y: 500)))
        #expect(system.events.contains(.up(CGPoint(x: 960, y: 102))))
    }

    @Test func createsTheMissingDesktopsUpToTheNumber() async {
        let result = await mover.move(window, toDesktop: 5)
        #expect(result == .moved(createdDesktops: 3))
        #expect(system.desktopCount == 5)
        #expect(system.events.contains(.up(CGPoint(x: 768 + 4 * 192, y: 102))))
    }

    @Test func rejectsNumbersOutsideTheMacOSLimit() async {
        #expect(await mover.move(window, toDesktop: 17) == .failed(.invalidDesktop, createdDesktops: 0))
        #expect(await mover.move(window, toDesktop: 0) == .failed(.invalidDesktop, createdDesktops: 0))
        #expect(system.events.isEmpty)
    }

    @Test func refusesWindowsThatAreOnAllDesktops() async {
        system.onAllDesktops = true
        let result = await mover.move(window, toDesktop: 3)
        #expect(result == .failed(.onAllDesktops, createdDesktops: 0))
        #expect(system.additions == 0)
        #expect(system.events.isEmpty)
    }

    @Test func stopsWhenADesktopCannotBeCreated() async {
        system.addCreatesDesktop = false
        let result = await mover.move(window, toDesktop: 3)
        #expect(result == .failed(.desktopNotCreated, createdDesktops: 0))
        #expect(system.events.isEmpty)
    }

    @Test func alwaysReleasesTheMouseAndRestoresThePointer() async {
        system.acceptsDrop = false
        let result = await mover.move(window, toDesktop: 2)
        #expect(result == .failed(.dropRejected, createdDesktops: 0))
        #expect(system.downs == 1)
        #expect(system.ups == 1)
        #expect(system.lastWarp == CGPoint(x: 500, y: 500))
        #expect(system.events.last == .warp(CGPoint(x: 500, y: 500)))
    }

    @Test func releasesTheMouseEvenIfTheBarNeverExpands() async {
        system.expandsAfterDrags = .max
        let result = await mover.move(window, toDesktop: 2)
        #expect(!result.moved)
        #expect(system.ups == 1)
        #expect(system.lastWarp == CGPoint(x: 500, y: 500))
    }

    @Test func failsWithoutAThumbnailOrASpacesBar() async {
        system.thumbnail = nil
        #expect(await mover.move(window, toDesktop: 2) == .failed(.noThumbnail, createdDesktops: 0))
        system.thumbnail = CGRect(x: 0, y: 0, width: 10, height: 10)
        system.hasBar = false
        #expect(await mover.move(window, toDesktop: 2) == .failed(.noSpacesBar, createdDesktops: 0))
        #expect(system.events.isEmpty)
    }
}
