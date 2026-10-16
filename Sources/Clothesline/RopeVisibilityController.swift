import Foundation

/// Preserves the rope's visibility across pointer, drag and overview transitions.
struct RopeVisibilityController {
    private var lastInside: TimeInterval?

    mutating func reset() {
        lastInside = nil
    }

    mutating func reveal(atTop: Bool, overLine: Bool, isRevealed: Bool,
                         alwaysVisible: Bool, interactionHeld: Bool = false,
                         externalDrag: Bool = false, avoidingMissionControl: Bool = false,
                         now: TimeInterval) -> Bool {
        // A hidden lowered panel is not a hover edge. Only a real file drag
        // may reveal it away from the menu bar; overLine keeps visible cards up.
        let atTop = atTop || (avoidingMissionControl && externalDrag)
        if interactionHeld {
            // Holding an animation or interaction preserves visibility; it
            // must not schedule a reveal after the user explicitly hides it.
            lastInside = isRevealed ? now : nil
            return isRevealed
        }
        if atTop || (isRevealed && overLine) {
            lastInside = now
        }
        return alwaysVisible || (lastInside.map { now - $0 < 0.75 } ?? false)
    }
}

/// Tracks drag intent separately from the global left-button state.
struct ExternalFileDragTracker {
    private var idleChangeCount: Int?

    mutating func update(isPressed: Bool, changeCount: Int, hasFileURLs: Bool) -> Bool {
        guard isPressed, let idleChangeCount else {
            self.idleChangeCount = changeCount
            return false
        }
        // Drag pasteboard contents survive mouse-up. Only a new drag session
        // can activate the target; a click must not reuse the previous file URL.
        return changeCount != idleChangeCount && hasFileURLs
    }
}
