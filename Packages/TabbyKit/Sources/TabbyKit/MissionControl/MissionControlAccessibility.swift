import AppKit
import ApplicationServices

public struct ThumbnailInfo: Equatable, Sendable {
    public let bundleID: String?
    public let spaceID: String?
    public let title: String?
    public let frame: CGRect

    public init(bundleID: String?, spaceID: String?, title: String?, frame: CGRect) {
        self.bundleID = bundleID
        self.spaceID = spaceID
        self.title = title
        self.frame = frame
    }

    public init?(identifier: String?, title: String?, frame: CGRect?) {
        guard let identifier, let frame, let range = identifier.range(of: ".space.", options: .backwards) else { return nil }
        self.init(
            bundleID: String(identifier[..<range.lowerBound]),
            spaceID: String(identifier[range.upperBound...]),
            title: title,
            frame: frame
        )
    }
}

public struct MissionControlThumbnail {
    public let element: AXUIElement
    public let info: ThumbnailInfo
}

public enum MissionControlAccessibility {
    public static let windowManagerBundleID = "com.apple.WindowManager"
    public static let displayIdentifier = "mc.display"

    @MainActor
    public static var windowManagerPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: windowManagerBundleID).first?.processIdentifier
    }

    @MainActor
    public static func tree(maxDepth: Int = 10, maxNodes: Int = 3000) -> AXNode? {
        guard let pid = windowManagerPID else { return nil }
        return DockAccessibility.subtree(of: AX.application(pid), maxDepth: maxDepth, maxNodes: maxNodes)
    }

    @MainActor
    public static func displays() -> [AXUIElement] {
        guard let pid = windowManagerPID else { return [] }
        let found = descendants(of: AX.application(pid), maxDepth: 6, maxNodes: 1500) {
            AX.string($0, "AXIdentifier") == displayIdentifier
        }
        return found.isEmpty ? displaysByHitTest() : found
    }

    @MainActor
    public static func thumbnails() -> [MissionControlThumbnail] {
        let all = displays().flatMap { display in
            descendants(of: display, maxDepth: 6, maxNodes: 1500) { element in
                AX.string(element, kAXRoleAttribute) == kAXButtonRole
                    && (AX.string(element, "AXIdentifier")?.contains(".space.") ?? false)
            }
            .compactMap { element in
                ThumbnailInfo(
                    identifier: AX.string(element, "AXIdentifier"),
                    title: AX.string(element, kAXTitleAttribute) ?? AX.string(element, kAXDescriptionAttribute),
                    frame: AX.frame(element)
                ).map { MissionControlThumbnail(element: element, info: $0) }
            }
        }
        var seen = Set<String>()
        return all.filter { seen.insert(deduplicationKey($0.info)).inserted }
    }

    public static func deduplicationKey(_ info: ThumbnailInfo) -> String {
        let frame = info.frame.integral
        return "\(info.bundleID ?? "")|\(info.spaceID ?? "")|\(info.title ?? "")|\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)"
    }

    public static func match(windows: [MissionWindow], thumbnails: [ThumbnailInfo]) -> [CGWindowID: Int] {
        var result: [CGWindowID: Int] = [:]
        var used = Set<Int>()
        for window in windows {
            guard let title = window.title, !title.isEmpty else { continue }
            if let index = thumbnails.indices.first(where: {
                !used.contains($0) && thumbnails[$0].bundleID == window.bundleID && thumbnails[$0].title == title
            }) {
                result[window.id] = index
                used.insert(index)
            }
        }
        for window in windows where result[window.id] == nil {
            let aspect = window.frame.width / max(window.frame.height, 1)
            let candidates = thumbnails.indices.filter { !used.contains($0) && thumbnails[$0].bundleID == window.bundleID }
            let best = candidates.min { first, second in
                abs(aspectRatio(thumbnails[first].frame) - aspect) < abs(aspectRatio(thumbnails[second].frame) - aspect)
            }
            if let best {
                result[window.id] = best
                used.insert(best)
            }
        }
        return result
    }

    private static func aspectRatio(_ frame: CGRect) -> CGFloat {
        frame.width / max(frame.height, 1)
    }

    @MainActor
    private static func displaysByHitTest() -> [AXUIElement] {
        let systemWide = AXUIElementCreateSystemWide()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var found: [AXUIElement] = []
        for screen in NSScreen.screens {
            let frame = ScreenGeometry.globalRect(fromAppKit: screen.frame, primaryScreenHeight: primaryHeight)
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(systemWide, Float(frame.minX + 4), Float(frame.maxY - 4), &hit) == .success else { continue }
            var current = hit
            var steps = 0
            while let element = current, steps < 8 {
                if AX.string(element, "AXIdentifier") == displayIdentifier {
                    found.append(element)
                    break
                }
                current = AX.element(element, kAXParentAttribute)
                steps += 1
            }
        }
        return found
    }

    @MainActor
    private static func descendants(
        of root: AXUIElement,
        maxDepth: Int,
        maxNodes: Int,
        where predicate: (AXUIElement) -> Bool
    ) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [(element: AXUIElement, depth: Int)] = [(root, 0)]
        var budget = maxNodes
        var index = 0
        while index < queue.count, budget > 0 {
            let item = queue[index]
            index += 1
            budget -= 1
            if predicate(item.element) {
                result.append(item.element)
                continue
            }
            if item.depth < maxDepth {
                for child in AX.elements(item.element, kAXChildrenAttribute) {
                    queue.append((child, item.depth + 1))
                }
            }
        }
        return result
    }
}
