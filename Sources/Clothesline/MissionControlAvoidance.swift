import AppKit

/// Best-effort detection using public window metadata, without reading window
/// titles, capturing the screen, requesting permissions, or using private APIs.
/// System window layers are undocumented and may change between macOS releases.
@MainActor
final class MissionControlAvoidance {
    enum Owner: String {
        case dock = "com.apple.dock"
        case windowManager = "com.apple.WindowManager"
    }

    struct SystemWindow {
        let layer: Int
        let bounds: CGRect
        var owner: Owner = .dock
    }

    private let readWindows: @MainActor () -> [SystemWindow]
    private var windows: [SystemWindow] = []
    private var checkedAt: TimeInterval?

    init(readWindows: @escaping @MainActor () -> [SystemWindow] = { MissionControlAvoidance.systemWindows() }) {
        self.readWindows = readWindows
    }

    func reset() {
        checkedAt = nil
        windows = []
    }

    func clearance(for screenBounds: CGRect, now: TimeInterval, responsive: Bool) -> CGFloat {
        // Window enumeration is relatively expensive; never run it at the
        // pointer timer's 20 Hz. Check faster while showing/dragging the rope.
        let interval: TimeInterval = responsive ? 0.2 : 1
        if checkedAt.map({ now - $0 >= interval || now < $0 }) ?? true {
            windows = readWindows()
            checkedAt = now
        }
        return Self.clearance(for: screenBounds, windows: windows)
    }

    /// CGWindow coordinates are top-down relative to the primary display, not
    /// NSScreen.main (which follows focus). Negative coordinates are valid.
    static func windowBounds(for screenFrame: CGRect, primaryFrame: CGRect) -> CGRect {
        CGRect(x: screenFrame.minX, y: primaryFrame.maxY - screenFrame.maxY,
               width: screenFrame.width, height: screenFrame.height)
    }

    static func clearance(for screen: CGRect, windows: [SystemWindow]) -> CGFloat {
        guard screen.width > 0, screen.height > 0 else { return 0 }
        var stripClearance: CGFloat = 0
        var hasOverviewSurface = false
        for window in windows {
            let bounds = window.bounds
            guard bounds.width.isFinite, bounds.height.isFinite,
                  bounds.minX.isFinite, bounds.minY.isFinite,
                  bounds.maxY.isFinite,
                  bounds.width >= screen.width * 0.9,
                  bounds.intersection(screen).width >= screen.width * 0.9 else { continue }
            let overviewLayer = window.owner == .windowManager ? 19 : 18
            let isStripLayer = window.owner == .windowManager
                ? window.layer == 14 : (window.layer == 18 || window.layer == 20)
            if window.layer == overviewLayer && bounds.intersection(screen).height >= screen.height * 0.9 {
                // macOS 27 moved the overview from Dock to WindowManager.
                // Requiring display coverage excludes small Stage Manager icons.
                hasOverviewSurface = true
            } else if isStripLayer, abs(bounds.minY - screen.minY) <= 24,
                      bounds.height >= 32 && bounds.height <= screen.height * 0.4 {
                stripClearance = max(stripClearance, bounds.maxY - screen.minY + 16)
            }
            // A full-screen layer 20 surface alone is also present on an idle
            // desktop on recent macOS versions, so it is deliberately ignored.
        }
        // Prefer the actual Spaces bar boundary over a proportional estimate.
        // WindowManager layer 18 is Show Desktop, so it must not trigger this.
        if stripClearance > 0 { return stripClearance }
        return hasOverviewSurface ? min(280, max(160, screen.height * 0.22)) : 0
    }

    static func systemWindows() -> [SystemWindow] {
        var owners: [pid_t: Owner] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, let owner = Owner(rawValue: bundleID) {
                owners[app.processIdentifier] = owner
            }
        }
        guard !owners.isEmpty,
              let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return systemWindows(in: info, owners: owners)
    }

    static func systemWindows(in info: [[String: Any]], owners: [pid_t: Owner]) -> [SystemWindow] {
        info.compactMap { window in
            guard let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let owner = owners[pid],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary) else { return nil }
            return SystemWindow(layer: layer, bounds: bounds, owner: owner)
        }
    }
}
