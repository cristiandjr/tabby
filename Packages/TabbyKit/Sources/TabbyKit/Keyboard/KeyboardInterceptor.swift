import CoreGraphics
import Foundation

public enum NavigationKey: String, Codable, Sendable {
    case next
    case previous
    case select
}

public final class KeyboardInterceptor: @unchecked Sendable {
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

    public typealias KeyHandler = @MainActor @Sendable (NavigationKey) -> Void
    public typealias KeyDownHandler = @MainActor @Sendable (UInt16, ModifierSet, ContinuousClock.Instant) -> Void

    private let lock = NSLock()
    private var currentMode: Mode = .off
    private var currentBindings: Bindings
    private var keyHandler: KeyHandler?
    private var keyDownHandler: KeyDownHandler?
    private var swallowed: Set<UInt16> = []
    private var drainGeneration = 0
    private var timeouts = 0
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?

    public init(bindings: Bindings = .standard) {
        currentBindings = bindings
    }

    public var mode: Mode {
        locked { currentMode }
    }

    public var isInstalled: Bool {
        locked { tap != nil }
    }

    public var timeoutCount: Int {
        locked { timeouts }
    }

    public var bindings: Bindings {
        get { locked { currentBindings } }
        set { locked { currentBindings = newValue } }
    }

    public var onKey: KeyHandler? {
        get { locked { keyHandler } }
        set { locked { keyHandler = newValue } }
    }

    public var onKeyDown: KeyDownHandler? {
        get { locked { keyDownHandler } }
        set { locked { keyDownHandler = newValue } }
    }

    @discardableResult
    public func install() -> Bool {
        if isInstalled { return true }
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            guard let self else {
                ready.signal()
                return
            }
            self.runTapLoop(ready: ready)
        }
        thread.name = "io.github.cristiandjr.tabby.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return isInstalled
    }

    public func uninstall() {
        let (port, loop) = locked { () -> (CFMachPort?, CFRunLoop?) in
            defer {
                tap = nil
                runLoop = nil
                currentMode = .off
                swallowed.removeAll()
            }
            return (tap, runLoop)
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let loop {
            CFRunLoopStop(loop)
        }
    }

    public func setMode(_ newMode: Mode) {
        let (port, enable, generation) = locked { () -> (CFMachPort?, Bool, Int) in
            currentMode = newMode
            drainGeneration += 1
            return (tap, newMode != .off || !swallowed.isEmpty, drainGeneration)
        }
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: enable)
        if newMode == .off, enable {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.finishDrain(generation: generation)
            }
        }
    }

    private func runTapLoop(ready: DispatchSemaphore) {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<KeyboardInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            ready.signal()
            return
        }
        CGEvent.tapEnable(tap: port, enable: false)
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        let loop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(loop, source, .commonModes)
        locked {
            tap = port
            runLoop = loop
        }
        ready.signal()
        CFRunLoopRun()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout:
            let (port, enable) = locked { () -> (CFMachPort?, Bool) in
                timeouts += 1
                return (tap, currentMode != .off || !swallowed.isEmpty)
            }
            if enable, let port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return false
        case .tapDisabledByUserInput:
            return false
        case .keyDown:
            let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let now = ContinuousClock().now
            let (keyDown, handler, key) = locked { () -> (KeyDownHandler?, KeyHandler?, NavigationKey?) in
                guard currentMode == .intercept, let key = currentBindings.key(for: keyCode, flags: flags) else {
                    return (keyDownHandler, nil, nil)
                }
                swallowed.insert(keyCode)
                return (keyDownHandler, keyHandler, key)
            }
            if let keyDown {
                let modifiers = ModifierSet(flags)
                Task { @MainActor in
                    keyDown(keyCode, modifiers, now)
                }
            }
            guard let key else { return false }
            if let handler, !(isRepeat && key == .select) {
                Task { @MainActor in
                    handler(key)
                }
            }
            return true
        case .keyUp:
            let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let (consumed, portToDisable) = locked { () -> (Bool, CFMachPort?) in
                guard swallowed.remove(keyCode) != nil else { return (false, nil) }
                return (true, currentMode == .off && swallowed.isEmpty ? tap : nil)
            }
            if let portToDisable {
                CGEvent.tapEnable(tap: portToDisable, enable: false)
            }
            return consumed
        default:
            return false
        }
    }

    private func finishDrain(generation: Int) {
        let port = locked { () -> CFMachPort? in
            guard drainGeneration == generation, currentMode == .off else { return nil }
            swallowed.removeAll()
            return tap
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
