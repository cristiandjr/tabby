import ApplicationServices
import Carbon
import Foundation

public enum SystemStatus {
    public static var macOSVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    public static var accessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static var listenEventAccess: Bool {
        CGPreflightListenEventAccess()
    }

    public static var postEventAccess: Bool {
        CGPreflightPostEventAccess()
    }

    public static var secureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
