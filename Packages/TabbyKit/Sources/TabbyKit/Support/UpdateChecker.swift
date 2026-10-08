import Foundation

public struct ReleaseInfo: Equatable, Sendable {
    public var version: String
    public var url: URL

    public init(version: String, url: URL) {
        self.version = version
        self.url = url
    }
}

public enum SemanticVersion {
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) > 0
    }

    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = split(lhs)
        let right = split(rhs)
        for index in 0..<3 where left.core[index] != right.core[index] {
            return left.core[index] < right.core[index] ? -1 : 1
        }
        switch (left.prerelease.isEmpty, right.prerelease.isEmpty) {
        case (true, true): return 0
        case (true, false): return 1
        case (false, true): return -1
        case (false, false): break
        }
        for (a, b) in zip(left.prerelease, right.prerelease) where a != b {
            if let x = Int(a), let y = Int(b) { return x < y ? -1 : 1 }
            if Int(a) != nil { return -1 }
            if Int(b) != nil { return 1 }
            return a < b ? -1 : 1
        }
        return left.prerelease.count == right.prerelease.count ? 0 : (left.prerelease.count < right.prerelease.count ? -1 : 1)
    }

    private static func split(_ version: String) -> (core: [Int], prerelease: [String]) {
        let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let parts = trimmed.split(separator: "-", maxSplits: 1).map(String.init)
        var core = (parts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
        while core.count < 3 { core.append(0) }
        let prerelease = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
        return (Array(core.prefix(3)), prerelease)
    }
}

public enum UpdateChecker {
    public static let repository = "cristiandjr/tabby"
    public static let releasesPrefix = "https://github.com/\(repository)/releases/"

    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = json["html_url"] as? String,
              page.lowercased().hasPrefix(releasesPrefix),
              let url = URL(string: page)
        else { return nil }
        return ReleaseInfo(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url: url)
    }

    public static func newerRelease(than currentVersion: String) async -> ReleaseInfo? {
        guard let endpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else { return nil }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Tabby/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration)
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = parse(data),
              SemanticVersion.isNewer(release.version, than: currentVersion)
        else { return nil }
        return release
    }
}
