import CoreGraphics

@MainActor
public protocol MissionControlMonitoring: AnyObject {
    func isOpen() -> Bool?
}

@MainActor
public protocol WindowProviding: AnyObject {
    func snapshot() -> [MissionWindow]
    func realSize(of id: CGWindowID) -> CGSize?
    func liveFrames(of ids: [CGWindowID]) -> [CGWindowID: CGRect]
    func visibleWindowIDs(on display: CGDirectDisplayID) -> Set<CGWindowID>
}

@MainActor
public protocol ThumbnailProviding: AnyObject {
    func thumbnails(for windows: [MissionWindow]) -> [CGWindowID: MissionControlThumbnail]
}

@MainActor
public protocol KeyboardIntercepting: AnyObject {
    var onAction: KeyboardInterceptor.ActionHandler? { get set }
    var keymap: Keymap { get set }
    var isInstalled: Bool { get }
    var timeoutCount: Int { get }
    func install() -> Bool
    func uninstall()
    func setMode(_ mode: KeyboardInterceptor.Mode)
}

@MainActor
public protocol PointerMonitoring: AnyObject {
    var location: CGPoint { get }
    func start(onMove: @escaping @MainActor (CGPoint) -> Void)
    func stop()
}

@MainActor
public struct SessionDependencies {
    public var monitor: any MissionControlMonitoring
    public var windows: any WindowProviding
    public var thumbnails: any ThumbnailProviding
    public var activator: any WindowActivating
    public var mover: any SpaceMoving
    public var presenter: any SelectionPresenting
    public var keyboard: any KeyboardIntercepting
    public var pointer: any PointerMonitoring
    public var clock: any SessionClock
    public var reducesMotion: @MainActor () -> Bool

    public init(
        monitor: any MissionControlMonitoring,
        windows: any WindowProviding,
        thumbnails: any ThumbnailProviding,
        activator: any WindowActivating,
        mover: any SpaceMoving,
        presenter: any SelectionPresenting,
        keyboard: any KeyboardIntercepting,
        pointer: any PointerMonitoring,
        clock: any SessionClock,
        reducesMotion: @escaping @MainActor () -> Bool = { false }
    ) {
        self.monitor = monitor
        self.windows = windows
        self.thumbnails = thumbnails
        self.activator = activator
        self.mover = mover
        self.presenter = presenter
        self.keyboard = keyboard
        self.pointer = pointer
        self.clock = clock
        self.reducesMotion = reducesMotion
    }
}
