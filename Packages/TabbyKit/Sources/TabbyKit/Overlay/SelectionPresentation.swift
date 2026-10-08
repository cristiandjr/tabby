import CoreGraphics

public struct SelectionPresentation: Equatable, Sendable {
    public var windowID: CGWindowID
    public var label: String
    public var thumbnailFrame: CGRect?
    public var fallbackFrame: CGRect
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool
    public var neighborFrames: [CGWindowID: CGRect]

    public init(
        windowID: CGWindowID,
        label: String,
        thumbnailFrame: CGRect?,
        fallbackFrame: CGRect,
        cornerRadius: CGFloat,
        isHighlighted: Bool,
        neighborFrames: [CGWindowID: CGRect] = [:]
    ) {
        self.windowID = windowID
        self.label = label
        self.thumbnailFrame = thumbnailFrame
        self.fallbackFrame = fallbackFrame
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.neighborFrames = neighborFrames
    }
}

@MainActor
public protocol SelectionPresenting: AnyObject {
    func prepare(for windows: [MissionWindow])
    func present(_ presentation: SelectionPresentation)
    func dismiss()
}
