import AppKit

@MainActor
func testHiddenDuringMissionControlReturn() throws {
    guard let screen = NSScreen.screens.first,
          !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
    let panel = LinePanel(content: NSView())
    defer { panel.close() }
    panel.placeOnScreen(screen)
    let normalFrame = panel.frame
    panel.placeOnScreen(screen, avoidingTop: 250)
    panel.placeOnScreen(screen, animateReturn: true)
    precondition(panel.isReturning)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    // Same explicit-hide transition as AppDelegate.setAlwaysVisible(false).
    var reveal = RopeVisibilityController()
    reveal.reset()
    var shown = false
    for _ in 0..<30 {
        panel.placeOnScreen(screen, animateReturn: shown)
        shown = reveal.reveal(atTop: false, overLine: false, isRevealed: shown,
                              alwaysVisible: false,
                              interactionHeld: panel.isReturning,
                              now: ProcessInfo.processInfo.systemUptime)
        guard !shown else {
            print("FAIL: explicit hide during return reopened the rope with the pointer away")
            throw NSError(domain: "MissionControlReturn", code: 1)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
    precondition(!panel.isReturning && panel.frame == normalFrame && panel.level == .floating,
                 "hidden return still completes and restores ordinary window placement")
    print("PASS: explicit hide during return stays hidden through animation and hide grace")
}
