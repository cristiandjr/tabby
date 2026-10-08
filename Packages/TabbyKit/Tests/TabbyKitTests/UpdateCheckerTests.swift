import Foundation
import Testing
@testable import TabbyKit

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    @Test func comparesSemanticVersions() {
        #expect(SemanticVersion.isNewer("0.1.1", than: "0.1.0"))
        #expect(SemanticVersion.isNewer("0.2.0", than: "0.1.9"))
        #expect(SemanticVersion.isNewer("1.0.0", than: "0.9.9"))
        #expect(!SemanticVersion.isNewer("0.1.0", than: "0.1.0"))
        #expect(!SemanticVersion.isNewer("0.1.0", than: "0.1.1"))
        #expect(SemanticVersion.isNewer("v0.1.1", than: "0.1.0"))
    }

    @Test func aStableReleaseIsNewerThanItsPrereleases() {
        #expect(SemanticVersion.isNewer("0.1.0", than: "0.1.0-alpha.2"))
        #expect(!SemanticVersion.isNewer("0.1.0-alpha.2", than: "0.1.0"))
        #expect(SemanticVersion.isNewer("0.1.0-alpha.2", than: "0.1.0-alpha.1"))
        #expect(SemanticVersion.isNewer("0.1.0-alpha.10", than: "0.1.0-alpha.9"))
        #expect(SemanticVersion.isNewer("0.1.0-beta.1", than: "0.1.0-alpha.3"))
        #expect(SemanticVersion.isNewer("0.1.1-alpha.1", than: "0.1.0"))
    }

    @Test func readsTheLatestReleaseFromGitHub() throws {
        let json = #"{"tag_name": "v0.1.0-alpha.2", "html_url": "https://github.com/cristiandjr/tabby/releases/tag/v0.1.0-alpha.2"}"#
        let release = try #require(UpdateChecker.parse(Data(json.utf8)))
        #expect(release.version == "0.1.0-alpha.2")
        #expect(release.url.absoluteString == "https://github.com/cristiandjr/tabby/releases/tag/v0.1.0-alpha.2")
    }

    @Test func ignoresLinksOutsideTheRepository() {
        let json = #"{"tag_name": "v9.9.9", "html_url": "https://example.com/tabby"}"#
        #expect(UpdateChecker.parse(Data(json.utf8)) == nil)
        #expect(UpdateChecker.parse(Data("not json".utf8)) == nil)
    }
}
