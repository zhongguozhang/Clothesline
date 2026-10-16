import AppKit

/// Non-activating, transparent overlay over the active screen's usable top edge.
final class LinePanel: NSPanel {
    private struct ReturnMotion {
        let start: CGRect
        let target: CGRect
        var elapsed: TimeInterval = 0
        var lastTick = ProcessInfo.processInfo.systemUptime
    }
    private var returnMotion: ReturnMotion?
    private var returnTimer: Timer?
    private var placementScreen: CGRect?
    var shouldHoldPosition: (() -> Bool)?
    var isReturning: Bool { returnMotion != nil }

    init(content: NSView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        contentView = content
    }
    var onScroll: ((NSEvent) -> Void)?
    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, let onScroll { onScroll(event) }
        else { super.sendEvent(event) }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first
    }

    @discardableResult
    func placeOnScreen(_ screen: NSScreen? = nil, avoidingTop clearance: CGFloat = 0,
                       animateReturn: Bool = false) -> Bool {
        guard let screen = screen ?? Self.screenUnderPointer() else { return false }
        let target = Self.placement(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                    height: Layout.panelHeight, clearance: clearance)
        let sameScreen = placementScreen == screen.frame
        placementScreen = screen.frame
        // Pointer polling must not restart the animation or snap to its end.
        if sameScreen, clearance == 0, returnMotion?.target == target { return false }
        stopReturnMotion()
        // Mission Control's Dock surfaces sit above ordinary floating windows.
        // Raise only while avoiding them, and keep the Spaces strip unobstructed.
        let targetLevel: NSWindow.Level = clearance > 0 ? .statusBar : .floating
        let changed = frame != target || level != targetLevel
        if animateReturn, sameScreen, clearance == 0, level == .statusBar,
           frame.minY < target.minY, frame.minX == target.minX, frame.size == target.size,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            returnMotion = ReturnMotion(start: frame, target: target)
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advanceReturnMotion() }
            }
            returnTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            return true
        }
        if level != targetLevel { level = targetLevel }
        if frame != target { setFrame(target, display: true) }
        return changed
    }

    private func advanceReturnMotion() {
        guard var motion = returnMotion else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let delta = now - motion.lastTick
        motion.lastTick = now
        // Keep the actual window still while AppKit tracks a click or drag.
        if shouldHoldPosition?() == true {
            returnMotion = motion
            return
        }
        motion.elapsed += delta
        let progress = min(1, motion.elapsed / 0.6)
        let eased = progress * progress * (3 - 2 * progress)
        var next = motion.start
        next.origin.y += (motion.target.minY - motion.start.minY) * eased
        returnMotion = motion
        setFrame(progress == 1 ? motion.target : next, display: true)
        if progress == 1 {
            stopReturnMotion()
            level = .floating
        }
    }

    private func stopReturnMotion() {
        returnTimer?.invalidate()
        returnTimer = nil
        returnMotion = nil
    }

    override func close() {
        stopReturnMotion()
        super.close()
    }

    static func placement(screenFrame: CGRect, visibleFrame: CGRect,
                          height: CGFloat, clearance: CGFloat) -> CGRect {
        let height = min(height, visibleFrame.height)
        let top = min(visibleFrame.maxY, screenFrame.maxY - max(0, clearance))
        return CGRect(x: visibleFrame.minX, y: max(visibleFrame.minY, top - height),
                      width: visibleFrame.width, height: height)
    }
}
