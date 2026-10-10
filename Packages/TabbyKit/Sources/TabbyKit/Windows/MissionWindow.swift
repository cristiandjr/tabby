import CoreGraphics
import Foundation

public struct MissionWindow: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let bundleID: String?
    public let appName: String
    public let title: String?
    public let frame: CGRect
    public let displayID: CGDirectDisplayID
    public let zIndex: Int

    public init(
        id: CGWindowID,
        pid: pid_t,
        bundleID: String?,
        appName: String,
        title: String?,
        frame: CGRect,
        displayID: CGDirectDisplayID,
        zIndex: Int
    ) {
        self.id = id
        self.pid = pid
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.frame = frame
        self.displayID = displayID
        self.zIndex = zIndex
    }
}

public struct CGWindowRecord: Equatable, Sendable {
    public let id: CGWindowID
    public let pid: pid_t
    public let ownerName: String
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(id: CGWindowID, pid: pid_t, ownerName: String, layer: Int, alpha: Double, bounds: CGRect) {
        self.id = id
        self.pid = pid
        self.ownerName = ownerName
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }

    public init?(dictionary: [String: Any]) {
        guard let number = dictionary[kCGWindowNumber as String] as? NSNumber,
              let pid = dictionary[kCGWindowOwnerPID as String] as? NSNumber,
              let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
        else { return nil }
        self.init(
            id: number.uint32Value,
            pid: pid.int32Value,
            ownerName: dictionary[kCGWindowOwnerName as String] as? String ?? "",
            layer: (dictionary[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
            alpha: (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
            bounds: bounds
        )
    }
}

public enum WindowFilter {
    public static let minimumSide: CGFloat = 50

    public static func candidates(_ records: [CGWindowRecord], excluding pids: Set<pid_t> = []) -> [CGWindowRecord] {
        records.filter { record in
            record.layer == 0
                && record.alpha > 0.01
                && record.bounds.width >= minimumSide
                && record.bounds.height >= minimumSide
                && !pids.contains(record.pid)
        }
    }
}

public enum CGWindowSource {
    public static func onScreen() -> [CGWindowRecord] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap(CGWindowRecord.init(dictionary:))
    }

    public static func existingIDs() -> Set<CGWindowID> {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
    }

    public static func bounds(for ids: [CGWindowID]) -> [CGWindowID: CGRect] {
        guard !ids.isEmpty else { return [:] }
        let wanted = Set(ids)
        return onScreen().reduce(into: [:]) { result, record in
            if wanted.contains(record.id) {
                result[record.id] = record.bounds
            }
        }
    }
}
