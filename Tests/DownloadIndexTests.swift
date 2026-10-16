import Foundation

@main
struct DownloadIndexTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("TEST FAILED: \(message)") }
    }

    static func main() throws {
        for excluded in [".DS_Store", ".hidden.pdf", "~$draft.docx", "movie.mp4.part",
                         "paper.pdf.crdownload", "a.zip.download", "clip.opdownload",
                         "data.tmp", "archive.aria2", "video.filepart"] {
            check(!DownloadIndex.isCandidateName(excluded), "should reject \(excluded)")
        }
        for valid in ["paper.pdf", "dataset.zip", "photo.png", "video.mov", "README", "file.final.pdf"] {
            check(DownloadIndex.isCandidateName(valid), "should accept \(valid)")
        }
        let now = Date()
        func file(_ path: String, size: Int64 = 100, modified: Date? = nil) -> DownloadFile {
            DownloadFile(url: URL(fileURLWithPath: "/tmp/\(path)"), size: size,
                         modified: modified ?? now.addingTimeInterval(-30),
                         created: now.addingTimeInterval(-120), added: now.addingTimeInterval(-10))
        }

        var gate = DownloadCompletionGate()
        check(gate.completed([file("a.pdf")], now: now).isEmpty, "one stable sample is not enough")
        check(gate.completed([file("a.pdf")], now: now.addingTimeInterval(1)).count == 1,
              "second unchanged sample qualifies")

        // File grows mid-download: the stable-sample streak must restart.
        check(gate.completed([file("a.pdf", size: 120)], now: now.addingTimeInterval(2)).isEmpty,
              "writing invalidates previous completed fingerprint")
        check(gate.completed([file("a.pdf", size: 120)], now: now.addingTimeInterval(3)).count == 1,
              "changed file needs another stable sample")

        var recentlyTouched = DownloadCompletionGate()
        let active = file("b.zip", modified: now)
        check(recentlyTouched.completed([active], now: now).isEmpty, "first sample")
        check(recentlyTouched.completed([active], now: now.addingTimeInterval(1)).isEmpty,
              "one second quiet is insufficient")
        check(recentlyTouched.completed([active], now: now.addingTimeInterval(3)).count == 1,
              "quiet two-second period satisfied")

        // Deletion then new download at the same path must not inherit stability.
        check(gate.completed([], now: now).isEmpty, "empty scan")
        check(gate.completed([file("a.pdf")], now: now).isEmpty, "reappearing path needs fresh samples")

        // File system scan includes ordinary files and directories, but excludes
        // browser temporary files and temporary download directories.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("clothesline-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for (name, contents) in [
            ("research.pdf", "real"), ("archive.zip.part", "unfinished"), (".secret", "hidden"),
            ("dataset.csv", "1,2,3"), ("note.txt.crdownload", "partial"), ("dataset.csv.crdownload", "active")
        ] {
            try contents.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("folder.zip"),
                                                withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("unfinished.download"),
                                                withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("link"),
                                                  withDestinationURL: folder.appendingPathComponent("research.pdf"))
        let results = try DownloadIndex.scan(folder)
        check(Set(results.map { $0.url.lastPathComponent }) == Set(["research.pdf", "folder.zip"]),
              "scan should include files and folders, excluding incomplete downloads")

        let directory = results.first { $0.isDirectory }!
        check(directory.url.lastPathComponent == "folder.zip", "directory metadata")
        var changedDirectory = directory
        changedDirectory = DownloadFile(url: directory.url, size: 0, modified: now,
                                        created: directory.created, added: directory.added, isDirectory: true)
        check(directory.fingerprint == changedDirectory.fingerprint,
              "directory content updates must not invalidate dismissal")
        var directoryGate = DownloadCompletionGate()
        check(directoryGate.completed([directory], now: now.addingTimeInterval(10)).isEmpty, "folder needs stable samples")
        check(directoryGate.completed([directory], now: now.addingTimeInterval(11)).count == 1, "stable folder qualifies")
        print("PASS: name filters, stable samples, quiet period, rename/reset safety, folder scanning")

        let suite = "Clothesline-Display-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DisplayPreferences(defaults: defaults)
        check(preferences.hoverDelay == 0, "default hover delay")
        preferences.hoverDelay = 1.26
        check(DisplayPreferences(defaults: defaults).hoverDelay == 1.3, "delay persists at 0.1s precision")
        preferences.hoverDelay = -1
        check(preferences.hoverDelay == 0, "negative delay clamped")
        preferences.hoverDelay = .infinity
        check(preferences.hoverDelay == 0, "invalid delay falls back safely")
        preferences.hoverDelay = 100
        check(preferences.hoverDelay == 10, "delay upper bound")
        let parent = URL(fileURLWithPath: "/tmp")
        let otherParent = URL(fileURLWithPath: "/tmp/another")
        check(preferences.retentionLifetime == 0, "default keeps items indefinitely")
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.standardizedFileURL.path
        defaults.set([downloads: 86400, otherParent.path: 3600], forKey: DisplayPreferences.legacyLifetimesKey)
        check(preferences.retentionLifetime == 86400, "migration preserves the existing Downloads choice")
        preferences.retentionLifetime = 60
        check(DisplayPreferences(defaults: defaults).retentionLifetime == 60, "shared retention persists")
        preferences.retentionLifetime = 0
        check(preferences.retentionLifetime == 0, "explicit unlimited overrides legacy preferences")
        preferences.retentionLifetime = -1
        check(preferences.retentionLifetime == 0, "invalid retention falls back to default")
        let policy = ItemExpirationPolicy(lifetime: 60)
        let recent = file("recent.pdf")
        let expired = DownloadFile(url: parent.appendingPathComponent("old"), size: 0, modified: now,
                                   created: now.addingTimeInterval(-1000), added: now.addingTimeInterval(-60), isDirectory: true)
        let noAddedDate = DownloadFile(url: parent.appendingPathComponent("no-added.txt"), size: 1, modified: now,
                                       created: now.addingTimeInterval(-60), added: nil)
        check(policy.includes(recent, now: now), "recent arrival included")
        check(!policy.includes(recent, now: now.addingTimeInterval(50)), "expires exactly at boundary without new scan data")
        check(!policy.includes(expired, now: now), "directory modification does not renew arrival age")
        check(!policy.includes(noAddedDate, now: now), "missing entry date falls back to creation")
        let unlimited = DownloadFile(url: otherParent.appendingPathComponent("old.txt"), size: 1,
                                     modified: .distantPast, created: .distantPast, added: nil)
        check(!policy.includes(unlimited, now: now), "one retention applies to every automatic source")
        check(ItemExpirationPolicy().includes(unlimited, now: now), "zero retention means never expire")
        print("PASS: display preference persistence/precision, shared expiration boundaries and migration")

        var reveal = LineRevealController()
        func poll(_ time: Double, top: Bool = true, over: Bool = false, shown: Bool = false,
                  items: Bool = true, pinned: Bool = false, held: Bool = false, delay: Double = 0.5) -> Bool {
            reveal.reveal(atTop: top, overLine: over, isRevealed: shown, hasItems: items,
                          alwaysVisible: pinned, interactionHeld: held, delay: delay, now: time)
        }
        check(!poll(0) && !poll(0.4), "brief hover stays hidden")
        check(!poll(0.45, top: false), "leaving cancels hover")
        check(!poll(1) && !poll(1.4) && poll(1.5), "new hover waits full delay")
        check(poll(1.6, top: false, over: true, shown: true), "pointer can move onto cards")
        check(poll(2.0, top: false, shown: true), "brief leave grace period")
        check(!poll(2.4, top: false, shown: true), "hides after grace period")
        reveal.reset()
        check(!poll(3, items: false) && !poll(30, items: false), "empty rope never opens on hover")
        check(!poll(30.1) && poll(30.6), "new arrival starts fresh dwell")
        check(!poll(30.7, shown: true, items: false), "last expiration hides even while at top")
        check(poll(31, items: false, pinned: true), "explicit always-visible still works")
        reveal.reset()
        check(poll(32, delay: 0), "zero delay reveals on first sample")
        check(poll(33, top: false, shown: true, items: false, held: true), "drag retains source when scan expires")
        check(!poll(34, top: false, shown: true, items: false), "drag completion permits empty hide")
        reveal.reset()
        check(!poll(35, delay: 1.3) && !poll(36.2, delay: 1.3) && poll(36.4, delay: 1.3),
              "noninteger configurable delay")
        reveal.reset()
        check(!poll(40), "screen/settings changes reset dwell")
        reveal.reset()
        check(!reveal.reveal(atTop: true, overLine: false, isRevealed: false, hasItems: false,
                             alwaysVisible: false, externalDrag: true, delay: 0.5, now: 50), "empty drop target waits for hover")
        check(reveal.reveal(atTop: true, overLine: false, isRevealed: false, hasItems: false,
                            alwaysVisible: false, externalDrag: true, delay: 0.5, now: 51), "intentional Finder drag can populate an empty rope")
        print("PASS: delayed reveal, hover cancellation, empty suppression, drag hold and always-visible")
    }
}
