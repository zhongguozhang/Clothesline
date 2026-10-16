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
        try testMissionControlHiddenReveal()
    }
}
