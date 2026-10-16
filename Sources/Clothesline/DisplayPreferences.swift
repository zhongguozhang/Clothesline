import Foundation

/// Shared by settings, folder monitoring and the pointer controller.
struct DisplayPreferences {
    static let hoverKey = "lineHoverDelay"
    static let retentionKey = "itemRetentionLifetime"
    static let legacyLifetimesKey = "monitoredFolderLifetimes"
    static let defaultHoverDelay: TimeInterval = 0
    static let defaultLifetime: TimeInterval = 0
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hoverDelay: TimeInterval {
        get {
            guard defaults.object(forKey: Self.hoverKey) != nil else { return Self.defaultHoverDelay }
            return Self.normalizedHoverDelay(defaults.double(forKey: Self.hoverKey))
        }
        nonmutating set { defaults.set(Self.normalizedHoverDelay(newValue), forKey: Self.hoverKey) }
    }

    static func normalizedHoverDelay(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultHoverDelay }
        return (min(10, max(0, value)) * 10).rounded() / 10
    }

    /// One lifetime for automatic files, folders, clipboard images and notes.
    /// Preserve a previous directory choice on upgrade, preferring Downloads.
    var retentionLifetime: TimeInterval {
        get {
            if let saved = defaults.object(forKey: Self.retentionKey) as? NSNumber {
                return Self.normalizedLifetime(saved.doubleValue)
            }
            let legacy = defaults.dictionary(forKey: Self.legacyLifetimesKey) ?? [:]
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.standardizedFileURL.path
            let value = downloads.flatMap { legacy[$0] as? NSNumber }
                ?? legacy.keys.sorted().compactMap { legacy[$0] as? NSNumber }.first
            return value.map { Self.normalizedLifetime($0.doubleValue) } ?? Self.defaultLifetime
        }
        nonmutating set { defaults.set(Self.normalizedLifetime(newValue), forKey: Self.retentionKey) }
    }

    private static func normalizedLifetime(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite, value >= 0 else { return defaultLifetime }
        return value == 0 ? 0 : min(365 * 24 * 60 * 60, max(60, value))
    }
}

struct ItemExpirationPolicy {
    var lifetime: TimeInterval = 0

    func includes(since date: Date, now: Date) -> Bool {
        lifetime <= 0 || now.timeIntervalSince(date) < lifetime
    }

    func includes(_ file: DownloadFile, now: Date) -> Bool {
        // Editing a file or directory must not renew its entry time.
        includes(since: file.recency, now: now)
    }
}

/// Monotonic times prevent wall-clock changes from completing a hover early.
struct LineRevealController {
    private var enteredTopAt: TimeInterval?
    private var lastInside: TimeInterval?

    mutating func reset() {
        enteredTopAt = nil
        lastInside = nil
    }

    mutating func reveal(atTop: Bool, overLine: Bool, isRevealed: Bool,
                         hasItems: Bool, alwaysVisible: Bool, interactionHeld: Bool = false,
                         externalDrag: Bool = false,
                         delay: TimeInterval, now: TimeInterval) -> Bool {
        if interactionHeld {
            enteredTopAt = nil
            lastInside = now
            return isRevealed
        }
        guard hasItems || externalDrag else {
            reset()
            return alwaysVisible
        }
        if atTop {
            if enteredTopAt == nil { enteredTopAt = now }
        } else { enteredTopAt = nil }
        let waited = enteredTopAt.map { now - $0 >= delay } ?? false
        if (atTop && (isRevealed || waited)) || (isRevealed && overLine) {
            lastInside = now
        }
        return alwaysVisible || (lastInside.map { now - $0 < 0.75 } ?? false)
    }
}
