import AppKit

@MainActor
func testMissionControlAvoidance() {
    typealias Window = MissionControlAvoidance.SystemWindow
    let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let upperAppKit = CGRect(x: -438, y: 1117, width: 2048, height: 1152)
    let upper = MissionControlAvoidance.windowBounds(for: upperAppKit, primaryFrame: primary)
    precondition(upper == CGRect(x: -438, y: -1152, width: 2048, height: 1152),
                 "upper display must use negative Quartz Y, not main-screen or origin-zero assumptions")
    let side = CGRect(x: -1920, y: -250, width: 1920, height: 1080)
    precondition(MissionControlAvoidance.windowBounds(for: side, primaryFrame: primary).minY == 287,
                 "offset side displays convert independently of focus")

    let idle = [Window(layer: 20, bounds: primary),
                Window(layer: 0, bounds: primary),
                Window(layer: 20, bounds: CGRect(x: 500, y: 1040, width: 728, height: 77))]
    precondition(MissionControlAvoidance.clearance(for: primary, windows: idle) == 0,
                 "ordinary full-screen Dock tracking surface and bottom Dock do not lower the rope")
    let fullOverview = idle + [Window(layer: 18, bounds: primary)]
    let lowerClearance = MissionControlAvoidance.clearance(for: primary, windows: fullOverview)
    precondition(lowerClearance > 200 && lowerClearance <= 280, "full overview reserves room for Spaces")
    precondition(MissionControlAvoidance.clearance(for: upper, windows: fullOverview) == 0,
                 "overview on one display does not displace the rope on another")
    let upperOverview = [Window(layer: 18, bounds: upper)]
    precondition(MissionControlAvoidance.clearance(for: upper, windows: upperOverview) > 200,
                 "full overview on the upper screen is detected")
    let union = primary.union(upper)
    precondition(MissionControlAvoidance.clearance(for: primary, windows: [Window(layer: 18, bounds: union)]) > 0,
                 "a surface spanning displays still covers the lower screen")
    let strip = Window(layer: 20, bounds: CGRect(x: -438, y: -1152, width: 2048, height: 180))
    precondition(MissionControlAvoidance.clearance(for: upper, windows: [strip]) == 196,
                 "separate top strip uses its observed height plus a gap")
    precondition(MissionControlAvoidance.clearance(for: primary, windows: [strip]) == 0,
                 "upper strip cannot be mistaken for a lower-screen strip")
    let narrow = Window(layer: 20, bounds: CGRect(x: 0, y: 0, width: 400, height: 180))
    let middle = Window(layer: 20, bounds: CGRect(x: 0, y: 300, width: 1728, height: 180))
    precondition(MissionControlAvoidance.clearance(for: primary, windows: [narrow, middle]) == 0,
                 "small Dock popovers and non-top windows are not Spaces strips")

    let dockInfo: [String: Any] = [kCGWindowOwnerPID as String: NSNumber(value: 42),
                                    kCGWindowLayer as String: 18,
                                    kCGWindowBounds as String: primary.dictionaryRepresentation]
    var otherApp = dockInfo
    otherApp[kCGWindowOwnerPID as String] = NSNumber(value: 43)
    var malformed = dockInfo
    malformed.removeValue(forKey: kCGWindowBounds as String)
    let parsed = MissionControlAvoidance.systemWindows(in: [otherApp, malformed, dockInfo], owners: [42: .dock])
    precondition(parsed.count == 1 && parsed[0].bounds == primary,
                 "only Dock-owned, valid metadata participates; window titles are unnecessary")

    var managerInfo = dockInfo
    managerInfo[kCGWindowOwnerPID as String] = NSNumber(value: 43)
    managerInfo[kCGWindowLayer as String] = 19
    let bothOwners = MissionControlAvoidance.systemWindows(in: [dockInfo, managerInfo],
                                                           owners: [42: .dock, 43: .windowManager])
    precondition(bothOwners.map(\.owner) == [.dock, .windowManager],
                 "window ownership survives decoding so layers have process-specific meanings")
    let showDesktop = Window(layer: 18, bounds: primary, owner: .windowManager)
    let stageIcon = Window(layer: 19, bounds: CGRect(x: 2823, y: 771, width: 66, height: 82), owner: .windowManager)
    precondition(MissionControlAvoidance.clearance(for: primary, windows: [showDesktop, stageIcon]) == 0,
                 "WindowManager Show Desktop and small off-screen Stage Manager icons do not trigger avoidance")
    let managerOverview = Window(layer: 19, bounds: upper, owner: .windowManager)
    precondition(MissionControlAvoidance.clearance(for: upper, windows: [managerOverview]) > 0 &&
                 MissionControlAvoidance.clearance(for: primary, windows: [managerOverview]) == 0,
                 "macOS 27 overview without a separate bar uses a fallback only on the affected screen")

    var samples = 0
    var observed = fullOverview
    let monitor = MissionControlAvoidance(readWindows: { samples += 1; return observed })
    precondition(monitor.clearance(for: primary, now: 0, responsive: false) > 0)
    _ = monitor.clearance(for: upper, now: 0.05, responsive: true)
    precondition(samples == 1, "cache can be re-evaluated for another display without another enumeration")
    observed = idle
    precondition(monitor.clearance(for: primary, now: 0.1, responsive: true) > 0)
    precondition(monitor.clearance(for: primary, now: 0.21, responsive: true) == 0 && samples == 2,
                 "overview exit is detected at the responsive cadence")
    _ = monitor.clearance(for: primary, now: 0.5, responsive: false)
    precondition(samples == 2, "idle polling stays limited to once per second")
    monitor.reset()
    _ = monitor.clearance(for: primary, now: 0.6, responsive: false)
    precondition(samples == 3, "wake/reset invalidates cached Dock windows")

    let visible = CGRect(x: 0, y: 60, width: 1728, height: 1025)
    let original = LinePanel.placement(screenFrame: primary, visibleFrame: visible, height: 216, clearance: 0)
    let lowered = LinePanel.placement(screenFrame: primary, visibleFrame: visible, height: 216, clearance: lowerClearance)
    precondition(original.maxY == visible.maxY && lowered.maxY == primary.maxY - lowerClearance,
                 "normal placement respects menu bar; overview placement clears the strip")
    precondition(lowered.minY >= visible.minY && lowered.width == visible.width,
                 "drop target remains wholly within the display's usable area")
    let small = CGRect(x: 0, y: 0, width: 500, height: 200)
    precondition(LinePanel.placement(screenFrame: small, visibleFrame: small, height: 216, clearance: 280) == small,
                 "small displays clamp the panel instead of placing it off-screen")
    if let screen = NSScreen.screens.first {
        let panel = LinePanel(content: NSView())
        panel.placeOnScreen(screen)
        let normalFrame = panel.frame
        panel.placeOnScreen(screen, avoidingTop: 250)
        precondition(panel.level == .statusBar && panel.frame.maxY < normalFrame.maxY,
                     "actual AppKit panel is lowered and raised above Dock overview surfaces")
        precondition(panel.collectionBehavior.contains(.stationary) && !panel.canBecomeKey,
                     "avoidance does not activate or join the overview's window rearrangement")
        panel.placeOnScreen(screen)
        precondition(panel.level == .floating && panel.frame == normalFrame,
                     "overview exit restores both position and ordinary window level")
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.placeOnScreen(screen, avoidingTop: 250)
            let start = panel.frame
            panel.placeOnScreen(screen, animateReturn: true)
            precondition(panel.frame == start && panel.isReturning,
                         "overview exit starts from the lowered frame without jumping")
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            precondition(panel.frame.minY > start.minY && panel.frame.minY < normalFrame.minY,
                         "the actual AppKit window passes through intermediate positions")
            for _ in 0..<10 {
                panel.placeOnScreen(screen, animateReturn: true)
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            precondition(!panel.isReturning && panel.frame == normalFrame && panel.level == .floating,
                         "regular pointer polling cannot restart or interrupt the return")

            panel.placeOnScreen(screen, avoidingTop: 250)
            panel.placeOnScreen(screen, animateReturn: true)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
            var held = true
            panel.shouldHoldPosition = { held }
            let heldFrame = panel.frame
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            precondition(panel.frame == heldFrame && panel.isReturning,
                         "a new click or drag holds the window at its current position")
            held = false
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.65))
            precondition(panel.frame == normalFrame && !panel.isReturning,
                         "the return resumes after interaction ends")

            panel.placeOnScreen(screen, avoidingTop: 250)
            panel.placeOnScreen(screen, animateReturn: true)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
            panel.placeOnScreen(screen, avoidingTop: 250)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.65))
            precondition(!panel.isReturning && panel.frame == start && panel.level == .statusBar,
                         "reopening overview cancels the old return without a later jump")
            print("PASS: live panel return animation, repeated polling, interaction hold/resume and overview re-entry")
        }
        panel.close()
    }
    print("Mission Control detection, polling and panel placement tests passed")
}
