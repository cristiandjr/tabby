import CoreGraphics
import Foundation

public enum NavigationKey: String, Codable, Sendable {
    case next
    case previous
    case select
}

@MainActor
public final class KeyboardInterceptor {
    public enum Mode: Sendable {
        case off
        case observe
        case intercept
    }

    public struct Bindings: Sendable {
        public var next: [KeyCombo]
        public var previous: [KeyCombo]
        public var select: [KeyCombo]

        public init(next: [KeyCombo], previous: [KeyCombo], select: [KeyCombo]) {
            self.next = next
            self.previous = previous
            self.select = select
        }

        public static let standard = Bindings(next: [.next], previous: [.previous], select: [.select, .selectKeypad])

        public func key(for keyCode: UInt16, flags: CGEventFlags) -> NavigationKey? {
            if next.contains(where: { $0.matches(keyCode: keyCode, flags: flags) }) { return .next }
            if previous.contains(where: { $0.matches(keyCode: keyCode, flags: flags) }) { return .previous }
            if select.contains(where: { $0.matches(keyCode: keyCode, flags: flags) }) { return .select }
            return nil
        }
    }

    public var bindings: Bindings
    public var onKey: (@MainActor (NavigationKey) -> Void)?
    public var onKeyDown: (@MainActor (UInt16, ModifierSet) -> Void)?
    public private(set) var mode: Mode = .off
    public private(set) var isInstalled = false
    public private(set) var systemDisableCount = 0

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var swallowed: Set<UInt16> = []
    private var drainGeneration = 0

    public init(bindings: Bindings = .standard) {
        self.bindings = bindings
    }

    @discardableResult
    public func install() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<KeyboardInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                let typeRaw = type.rawValue
                let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                let flagsRaw = event.flags.rawValue
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                let consume = MainActor.assumeIsolated {
                    interceptor.process(typeRaw: typeRaw, keyCode: keyCode, flagsRaw: flagsRaw, isRepeat: isRepeat)
                }
                return consume ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: false)
        tap = port
        source = runLoopSource
        isInstalled = true
        return true
    }

    public func setMode(_ newMode: Mode) {
        mode = newMode
        drainGeneration += 1
        if newMode == .off, !swallowed.isEmpty {
            let generation = drainGeneration
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, self.drainGeneration == generation else { return }
                self.swallowed.removeAll()
                self.updateTap()
            }
        }
        updateTap()
    }

    private func updateTap() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: mode != .off || !swallowed.isEmpty)
    }

    private func process(typeRaw: UInt32, keyCode: UInt16, flagsRaw: UInt64, isRepeat: Bool) -> Bool {
        guard let type = CGEventType(rawValue: typeRaw) else { return false }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            systemDisableCount += 1
            updateTap()
            return false
        case .keyDown:
            let flags = CGEventFlags(rawValue: flagsRaw)
            onKeyDown?(keyCode, ModifierSet(flags))
            guard mode == .intercept, let key = bindings.key(for: keyCode, flags: flags) else { return false }
            swallowed.insert(keyCode)
            if !(isRepeat && key == .select) {
                Task { @MainActor [weak self] in
                    self?.onKey?(key)
                }
            }
            return true
        case .keyUp:
            guard swallowed.remove(keyCode) != nil else { return false }
            if mode == .off { updateTap() }
            return true
        default:
            return false
        }
    }
}
