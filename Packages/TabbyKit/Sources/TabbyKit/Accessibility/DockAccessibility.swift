import AppKit
import ApplicationServices

public struct AXNode: Codable, Sendable {
    public var role: String?
    public var subrole: String?
    public var identifier: String?
    public var title: String?
    public var label: String?
    public var value: String?
    public var frame: CGRect?
    public var actions: [String]
    public var children: [AXNode]
}

public struct DockCandidate {
    public let element: AXUIElement
    public let role: String?
    public let title: String?
    public let label: String?
    public let frame: CGRect
}

public enum DockAccessibility {
    public static let bundleID = "com.apple.dock"
    static let dockItemRole = "AXDockItem"
    static let identifierAttribute = "AXIdentifier"

    @MainActor
    public static var pid: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier
    }

    @MainActor
    public static func tree(maxDepth: Int = 16, maxNodes: Int = 4000) -> AXNode? {
        guard let pid else { return nil }
        var budget = maxNodes
        return node(for: AX.application(pid), depth: 0, maxDepth: maxDepth, budget: &budget)
    }

    @MainActor
    public static func pressableCandidates(maxDepth: Int = 16, maxNodes: Int = 4000) -> [DockCandidate] {
        guard let pid else { return [] }
        var candidates: [DockCandidate] = []
        var budget = maxNodes
        var stack: [(element: AXUIElement, depth: Int)] = [(AX.application(pid), 0)]
        while budget > 0, let item = stack.popLast() {
            budget -= 1
            let role = AX.string(item.element, kAXRoleAttribute)
            if role == dockItemRole { continue }
            if AX.actions(item.element).contains(kAXPressAction), let frame = AX.frame(item.element) {
                candidates.append(DockCandidate(
                    element: item.element,
                    role: role,
                    title: AX.string(item.element, kAXTitleAttribute),
                    label: AX.string(item.element, kAXDescriptionAttribute),
                    frame: frame
                ))
            }
            if item.depth < maxDepth {
                for child in AX.elements(item.element, kAXChildrenAttribute) {
                    stack.append((child, item.depth + 1))
                }
            }
        }
        return candidates
    }

    public static func bestThumbnail(for window: MissionWindow, in candidates: [DockCandidate]) -> DockCandidate? {
        guard let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        let matches = candidates.filter { candidate in
            [candidate.title, candidate.label].contains { text in
                guard let text, !text.isEmpty else { return false }
                return text == title || text.contains(title)
            }
        }
        let aspect = window.frame.width / max(window.frame.height, 1)
        return matches.min { first, second in
            abs(first.frame.width / max(first.frame.height, 1) - aspect) < abs(second.frame.width / max(second.frame.height, 1) - aspect)
        }
    }

    public static func render(_ root: AXNode) -> String {
        var lines: [String] = []
        render(root, depth: 0, into: &lines)
        return lines.joined(separator: "\n")
    }

    public static func statistics(_ root: AXNode) -> (nodes: Int, pressable: Int, withFrame: Int) {
        var nodes = 0
        var pressable = 0
        var withFrame = 0
        var stack = [root]
        while let node = stack.popLast() {
            nodes += 1
            if node.frame != nil { withFrame += 1 }
            if node.role != dockItemRole, node.actions.contains(kAXPressAction) { pressable += 1 }
            stack.append(contentsOf: node.children)
        }
        return (nodes, pressable, withFrame)
    }

    @MainActor
    private static func node(for element: AXUIElement, depth: Int, maxDepth: Int, budget: inout Int) -> AXNode {
        budget -= 1
        var children: [AXNode] = []
        if depth < maxDepth {
            for child in AX.elements(element, kAXChildrenAttribute) {
                guard budget > 0 else { break }
                children.append(node(for: child, depth: depth + 1, maxDepth: maxDepth, budget: &budget))
            }
        }
        return AXNode(
            role: AX.string(element, kAXRoleAttribute),
            subrole: AX.string(element, kAXSubroleAttribute),
            identifier: AX.string(element, identifierAttribute),
            title: AX.string(element, kAXTitleAttribute),
            label: AX.string(element, kAXDescriptionAttribute),
            value: AX.string(element, kAXValueAttribute),
            frame: AX.frame(element),
            actions: AX.actions(element),
            children: children
        )
    }

    private static func render(_ node: AXNode, depth: Int, into lines: inout [String]) {
        var parts = [node.role ?? "?"]
        if let subrole = node.subrole { parts.append("subrole=\(subrole)") }
        if let identifier = node.identifier { parts.append("id=\(identifier)") }
        if let title = node.title, !title.isEmpty { parts.append("title=\"\(title)\"") }
        if let label = node.label, !label.isEmpty { parts.append("desc=\"\(label)\"") }
        if let value = node.value, !value.isEmpty { parts.append("value=\"\(value)\"") }
        if let frame = node.frame {
            parts.append("frame=(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))")
        }
        if !node.actions.isEmpty { parts.append("actions=\(node.actions.joined(separator: ","))") }
        lines.append(String(repeating: "  ", count: depth) + parts.joined(separator: " "))
        for child in node.children {
            render(child, depth: depth + 1, into: &lines)
        }
    }
}
