import Foundation

func testMissionControlHiddenReveal() throws {
    func check(_ condition: Bool, _ message: String) throws {
        guard condition else {
            print("FAIL: \(message)")
            throw NSError(domain: "MissionControlHiddenReveal", code: 1)
        }
    }
    // Replay drag -> drop -> leave -> hide -> click empty overview -> exit.
    // The change counts model a new drag followed by its retained pasteboard.
    // Nothing reads or writes the user's clipboard or drag payload here.
    for clickInsideOldPanel in [false, true] {
        var drag = ExternalFileDragTracker()
        var reveal = RopeVisibilityController()
        var shown = false
        func poll(_ time: Double, pressed: Bool = false, count: Int = 11,
                  over: Bool = false, overview: Bool = true, top: Bool = false) -> Bool {
            let external = drag.update(isPressed: pressed, changeCount: count, hasFileURLs: true)
            shown = reveal.reveal(atTop: top, overLine: over, isRevealed: shown,
                                  alwaysVisible: false, externalDrag: external,
                                  avoidingMissionControl: overview, now: time)
            return shown
        }
        try check(!poll(0, count: 10), "initial hidden rope remains hidden")
        try check(poll(1, pressed: true), "new Finder drag reveals the lowered target")
        try check(poll(1.1, over: true), "dropping onto the rope keeps it visible")
        try check(!poll(2), "leaving the rope hides it while overview stays open")
        try check(!poll(3, pressed: true, over: clickInsideOldPanel),
                  "clicking blank overview must not reopen the hidden rope (inside old panel: \(clickInsideOldPanel))")
        try check(!poll(3.1, over: clickInsideOldPanel), "mouse-up must not reopen hidden rope")
        try check(!poll(3.8, overview: false), "overview exit keeps the rope hidden")
        try check(!poll(5, overview: false), "hidden state persists after the return interval")
        try check(poll(6, pressed: true, count: 12), "a later new file drag can still reveal the rope")
        try check(!poll(7, count: 12), "new drag release still allows auto-hide")
        try check(poll(8, count: 12, overview: false, top: true), "normal menu-bar hover still reveals")
    }
    var drag = ExternalFileDragTracker()
    try check(!drag.update(isPressed: false, changeCount: 20, hasFileURLs: true), "idle seeds drag session")
    try check(!drag.update(isPressed: true, changeCount: 20, hasFileURLs: true), "stale file types cannot turn a click into a drag")
    try check(!drag.update(isPressed: true, changeCount: 21, hasFileURLs: false), "text or non-file drags do not open the file target")
    try check(drag.update(isPressed: true, changeCount: 21, hasFileURLs: true), "file types arriving after declaration still activate the current drag")
    try check(!drag.update(isPressed: false, changeCount: 21, hasFileURLs: true), "mouse-up ends the active drag")
    var reveal = RopeVisibilityController()
    try check(!reveal.reveal(atTop: false, overLine: true, isRevealed: false,
                            alwaysVisible: false, avoidingMissionControl: true, now: 0),
              "moving across the transparent hidden panel does not reopen it")
    try check(reveal.reveal(atTop: false, overLine: false, isRevealed: false,
                           alwaysVisible: false, externalDrag: true, avoidingMissionControl: true, now: 1),
              "a real file drag immediately reveals an empty overview drop target")
    reveal.reset()
    try check(!reveal.reveal(atTop: false, overLine: false, isRevealed: false,
                            alwaysVisible: false, interactionHeld: true, now: 10),
              "an animation hold preserves an explicit hidden state")
    try check(!reveal.reveal(atTop: false, overLine: false, isRevealed: false,
                            alwaysVisible: false, now: 10.1),
              "ending a hidden hold cannot start a fresh reveal grace period")
    print("PASS: hidden overview rope stays hidden on blank click and exit; new drag and normal hover still work")
}
