import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class WindowSnapshotter {
    private static let log = Log.logger("snapshots")

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    private var content: Task<SCShareableContent?, Never>?
    private var images: [CGWindowID: CGImage] = [:]
    private var pending: [CGWindowID: Task<CGImage?, Never>] = [:]

    func warmUp() {
        content = Task {
            do {
                return try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            } catch {
                Self.log.error("shareable content: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
    }

    func reset() {
        content?.cancel()
        content = nil
        pending.values.forEach { $0.cancel() }
        pending = [:]
        images = [:]
    }

    func cachedImage(for id: CGWindowID) -> CGImage? {
        images[id]
    }

    func prefetch(_ id: CGWindowID, size: CGSize) {
        guard images[id] == nil, pending[id] == nil else { return }
        Task {
            _ = await image(for: id, size: size)
        }
    }

    func image(for id: CGWindowID, size: CGSize) async -> CGImage? {
        if let image = images[id] { return image }
        if let task = pending[id] { return await task.value }
        guard let content else { return nil }
        let task = Task { () -> CGImage? in
            guard let window = await content.value?.windows.first(where: { $0.windowID == id }) else { return nil }
            do {
                return try await Self.capture(window, size: size)
            } catch {
                Self.log.error("capture \(id): \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        pending[id] = task
        let image = await task.value
        guard pending[id] == task else { return image }
        pending[id] = nil
        images[id] = image
        return image
    }

    private static func capture(_ window: SCWindow, size: CGSize) async throws -> CGImage {
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(size.width.rounded()), 1)
        configuration.height = max(Int(size.height.rounded()), 1)
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration
        )
    }
}
