import ApplicationServices
import Foundation

public enum AX {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestTrust() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static func setGlobalTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), seconds)
    }

    public static func application(_ pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    public static func raw(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    public static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        raw(element, attribute) as? String
    }

    public static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (raw(element, attribute) as? NSNumber)?.boolValue
    }

    public static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = raw(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    public static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        guard let values = raw(element, attribute) as? [AnyObject] else { return [] }
        return values.compactMap { value in
            CFGetTypeID(value) == AXUIElementGetTypeID() ? (value as! AXUIElement) : nil
        }
    }

    public static func frame(_ element: AXUIElement) -> CGRect? {
        guard let origin = point(element, kAXPositionAttribute), let size = size(element, kAXSizeAttribute) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    public static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    public static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    public static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success, let names else { return [] }
        return (names as? [String]) ?? []
    }

    public static func attributeNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success, let names else { return [] }
        return (names as? [String]) ?? []
    }

    public static func parameterizedAttributeNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyParameterizedAttributeNames(element, &names) == .success, let names else { return [] }
        return (names as? [String]) ?? []
    }

    public static func pid(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    public static func describe(_ value: CFTypeRef?) -> String {
        guard let value else { return "nil" }
        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            let element = value as! AXUIElement
            return "<\(string(element, kAXRoleAttribute) ?? "?") \(string(element, "AXIdentifier") ?? "")>"
        }
        if let array = value as? [AnyObject] {
            return "[\(array.count): " + array.prefix(5).map { describe($0) }.joined(separator: ", ") + "]"
        }
        return String(describing: value)
    }

    @discardableResult
    public static func perform(_ element: AXUIElement, _ action: String) -> AXError {
        AXUIElementPerformAction(element, action as CFString)
    }

    @discardableResult
    public static func set(_ element: AXUIElement, _ attribute: String, _ value: CFTypeRef) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = raw(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}

extension AXError {
    private static let names: [Int32: String] = [
        0: "success",
        -25200: "failure",
        -25201: "illegalArgument",
        -25202: "invalidUIElement",
        -25203: "invalidUIElementObserver",
        -25204: "cannotComplete",
        -25205: "attributeUnsupported",
        -25206: "actionUnsupported",
        -25207: "notificationUnsupported",
        -25208: "notImplemented",
        -25209: "notificationAlreadyRegistered",
        -25210: "notificationNotRegistered",
        -25211: "apiDisabled",
        -25212: "noValue",
        -25213: "parameterizedAttributeUnsupported",
        -25214: "notEnoughPrecision",
    ]

    public var name: String {
        Self.names[rawValue] ?? "error(\(rawValue))"
    }
}
