import AppKit
import Foundation

@main
struct MacIntegrationTests {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let keys = ["dismissedFiles", "attachedFolderBookmarks", "alwaysShowLine", "recentFileBookmarks", "pinnedFiles", "menuLanguage"]
        let saved = keys.map { defaults.object(forKey: $0) }
        for key in keys { defaults.removeObject(forKey: key) }
        defer {
            for (key, old) in zip(keys, saved) {
                if let old { defaults.set(old, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        AppLanguage.current = .chinese
        try testAppServices()
        try testDisplayExpiration()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Clothesline-acceptance-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("real-download.txt")
        let partial = folder.appendingPathComponent("real-download.txt.crdownload")
        let bytes = Data("Clothesline real file acceptance\n".utf8)
        let line = Line()
        var observed = false
        var failure: String?
        let watcher = DownloadsWatcher(folder: folder, onUpdate: { files in
            line.adopt(files)
            if files.contains(where: { $0.path == file.path }) { observed = true }
        }, onFailure: { failure = $0 })
        watcher.start()
        defer { watcher.stop() }
        try bytes.write(to: partial)
        RunLoop.main.run(until: Date().addingTimeInterval(3))
        precondition(line.items.isEmpty, "temporary download must stay off rope")
        try FileManager.default.moveItem(at: partial, to: file)
        for _ in 0..<12 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            if observed { break }
        }
        precondition(observed && failure == nil, "watcher must publish completed real file")
        precondition(line.items.count == 1 && line.items[0].file.path == file.standardizedFileURL.path, "rope must use actual URL")
        line.dismiss(line.items[0].id)
        precondition(line.items.isEmpty, "take down must hide card")
        line.adopt([])
        let files = try DownloadIndex.scan(folder)
        line.adopt(files)
        precondition(line.items.isEmpty, "empty scan must not lose dismissal")
        let restored = Line()
        restored.adopt(files)
        precondition(restored.items.isEmpty, "dismissal must survive restart")
        line.resetDismissed()
        precondition(line.items.count == 1, "reset must restore card")
        line.dismissAll()
        precondition(line.items.isEmpty, "clear must hide card")
        let remainingBytes = try Data(contentsOf: file)
        precondition(remainingBytes == bytes, "dismiss/clear must preserve original bytes")
        let directory = folder.appendingPathComponent("attached-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let child = directory.appendingPathComponent("child.txt")
        try bytes.write(to: child)
        try line.attachFolder(directory)
        precondition(line.items.count == 1 && line.items[0].file.isDirectory, "manual folder on rope")
        let restoredFolders = Line()
        restoredFolders.adopt([])
        precondition(restoredFolders.items.count == 1, "attached folder survives restart")
        line.dismiss(line.items[0].id)
        precondition(FileManager.default.fileExists(atPath: child.path), "take down preserves folder contents")
        try line.attachFolder(directory)
        let folderID = line.items[0].id
        let trashedDirectory = try line.moveToTrash(folderID)
        precondition(!FileManager.default.fileExists(atPath: directory.path), "folder moved out of original location")
        let trashedChild = try Data(contentsOf: trashedDirectory.appendingPathComponent("child.txt"))
        precondition(trashedChild == bytes && line.items.isEmpty, "folder contents recoverable in Trash")
        try FileManager.default.moveItem(at: trashedDirectory, to: directory)
        line.resetDismissed()
        line.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let fileID = line.items[0].id
        // A changed file must not be deleted using an old card's metadata.
        try Data("changed".utf8).write(to: file)
        do {
            try line.moveToTrash(fileID)
            preconditionFailure("stale file must be rejected")
        } catch {
            precondition(FileManager.default.fileExists(atPath: file.path) && line.items.count == 1,
                         "failed trash must preserve source and card")
        }
        line.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let trashedFile = try line.moveToTrash(line.items[0].id)
        precondition(!FileManager.default.fileExists(atPath: file.path) && line.items.isEmpty, "file trashed and card removed")
        let recovered = try Data(contentsOf: trashedFile)
        precondition(recovered == Data("changed".utf8), "file recoverable in Trash")
        try FileManager.default.moveItem(at: trashedFile, to: file)
        let delegate = AppDelegate()
        delegate.setAlwaysVisible(true)
        precondition(delegate.pinned && AppDelegate().pinned, "always show persists across app instances")
        delegate.setAlwaysVisible(false)
        precondition(!AppDelegate().pinned, "auto hide persists across app instances")
        let dragPayload = GrabView.filePasteboardItem(file)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        precondition(board.writeObjects([dragPayload]), "write drag payload")
        let dropped = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        precondition(dropped?.first?.standardizedFileURL.path == file.standardizedFileURL.path,
                     "drop target must decode real file URL")
        precondition(board.propertyList(forType: GrabView.filenamesType) as? [String] == [file.standardizedFileURL.path],
                     "legacy desktop drop target must decode file paths")
        let dragLine = Line()
        dragLine.adopt(try DownloadIndex.scan(folder).filter { !$0.isDirectory })
        let originalID = dragLine.items[0].id
        dragLine.pressedID = originalID
        dragLine.adopt([])
        precondition(dragLine.items.first?.id == originalID, "press must retain drag source across scan")
        dragLine.draggingID = originalID
        dragLine.pressedID = nil
        dragLine.updateVisibleItems()
        precondition(dragLine.items.first?.id == originalID, "drag must retain source until session ends")
        dragLine.draggingID = nil
        dragLine.updateVisibleItems()
        precondition(dragLine.items.isEmpty, "pending scan applied after drag")
        let suite = "Clothesline-Multi-\(UUID())"
        let isolatedDefaults = UserDefaults(suiteName: suite)!
        defer { isolatedDefaults.removePersistentDomain(forName: suite) }
        let secondFolder = folder.appendingPathComponent("second-watch", isDirectory: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: false)
        let secondFile = secondFolder.appendingPathComponent("second.txt")
        try bytes.write(to: secondFile)
        var merged: [DownloadFile] = []
        let multi = FolderMonitors(defaults: isolatedDefaults) { merged = $0 }
        multi.start()
        defer { multi.stop() }
        try multi.add(folder)
        try multi.add(secondFolder)
        try multi.add(folder)
        precondition(multi.folders.count == 3, "Downloads plus two distinct monitors")
        for _ in 0..<16 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            if merged.contains(where: { $0.path == file.standardizedFileURL.path }) &&
                merged.contains(where: { $0.path == secondFile.standardizedFileURL.path }) { break }
        }
        precondition(merged.contains { $0.path == file.standardizedFileURL.path } &&
                     merged.contains { $0.path == secondFile.standardizedFileURL.path }, "both folders deliver files")
        precondition(Set(merged.map(\.path)).count == merged.count, "merged paths deduplicated")
        multi.stop()
        let restarted = FolderMonitors(defaults: isolatedDefaults) { _ in }
        restarted.start()
        precondition(restarted.folders.count == 3, "monitors survive restart with default Downloads")
        restarted.stop()
        let drag = GrabView()
        precondition(drag.draggingSession(NSDraggingSession(), sourceOperationMaskFor: .outsideApplication) == .copy)
        // New features use only files in the temporary acceptance directory.
        let manualA = folder.appendingPathComponent("manual-one.txt")
        let manualB = folder.appendingPathComponent("manual-two.pdf")
        try bytes.write(to: manualA); try bytes.write(to: manualB)
        let staging = Line()
        try staging.attachFiles([manualA, manualB, manualA])
        precondition(staging.items.filter { $0.url == manualA }.count == 1, "attach deduplicates files")
        let afterRestart = Line(); afterRestart.adopt([])
        precondition(afterRestart.items.contains { $0.url.resolvingSymlinksInPath().path == manualB.resolvingSymlinksInPath().path }, "manual files persist")
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.writeObjects([manualA as NSURL, manualB as NSURL])
        precondition(FileDropView.urls(from: pasteboard).count == 2, "Finder multi-file payload")
        let renameID = staging.items.first { $0.url == manualB }!.id
        try staging.rename(renameID, stem: "manual-one")
        let pdfURL = staging.items.first { $0.url.pathExtension == "pdf" }!.url
        let collision = folder.appendingPathComponent("occupied.pdf")
        try bytes.write(to: collision)
        let pdfID = staging.items.first { $0.url == pdfURL }!.id
        var rejected = false
        do { try staging.rename(pdfID, stem: "occupied") } catch { rejected = true }
        precondition(rejected, "rename refuses same-extension conflict")
        try staging.rename(pdfID, stem: "renamed-document")
        let renamed = folder.appendingPathComponent("renamed-document.pdf")
        precondition(FileManager.default.fileExists(atPath: renamed.path), "extension retained")
        let renamedBytes = try Data(contentsOf: renamed)
        precondition(renamedBytes == bytes, "rename preserves bytes")
        precondition(staging.recentFiles(matching: "RENAMED-DOCUMENT").count == 1, "case insensitive recent search")
        let renamedCard = staging.items.first { $0.url == renamed }!
        staging.dismiss(renamedCard.id)
        precondition(staging.recentFiles(matching: "renamed-document").count == 1, "drawer retains hidden files")
        try staging.attachFiles([renamed])
        precondition(staging.items.contains { $0.url == renamed }, "drawer can rehang hidden file")
        let pinLine = Line(); pinLine.maxItems = 100
        try pinLine.attachFiles([manualA])
        let pinID = pinLine.items.first { $0.url.resolvingSymlinksInPath().path == manualA.resolvingSymlinksInPath().path }!.id
        pinLine.togglePin(pinID)
        pinLine.maxItems = 1; pinLine.updateVisibleItems()
        try pinLine.attachFiles([renamed])
        precondition(pinLine.items.count == 1 && pinLine.items[0].pinned && pinLine.items[0].url.resolvingSymlinksInPath().path == manualA.resolvingSymlinksInPath().path, "new file cannot evict pin")
        let pinRestart = Line(); pinRestart.maxItems = 1; pinRestart.adopt([])
        precondition(pinRestart.items.contains { $0.pinned && $0.url.lastPathComponent == manualA.lastPathComponent }, "pin survives restart")
        let info = pinLine.identityDescription(pinLine.items[0])
        precondition(info.contains(manualA.lastPathComponent) && info.contains(folder.lastPathComponent) && info.contains("修改"), "full identity metadata")
        try FileManager.default.removeItem(at: manualA)
        pinLine.adopt([])
        precondition(pinLine.items[0].unavailable && pinLine.identityDescription(pinLine.items[0]).contains("最后记录"), "missing pin explicitly marked")
        try bytes.write(to: manualA); pinLine.updateVisibleItems()
        precondition(!pinLine.items[0].unavailable, "restored source becomes available")
        pinLine.dismiss(pinLine.items[0].id)
        precondition(!pinLine.items.contains { $0.pinned }, "taking down unpins without deleting")
        print("PASS: pin capacity/restart, complete identity, missing source and recovery")
        let identityPanel = FileIdentityPanel()
        let infoID = UUID()
        identityPanel.update(id: infoID, description: "acceptance file identity", anchor: NSRect(x: 100, y: 400, width: 150, height: 120))
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        precondition(identityPanel.displayedText == "acceptance file identity", "explicit hover info presented")
        identityPanel.hide()
        identityPanel.update(id: infoID, description: "cancelled identity")
        identityPanel.hide()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        precondition(identityPanel.currentID == nil && identityPanel.displayedText.isEmpty, "leaving card cancels delayed information")
        print("PASS: explicit identity panel and hover cancellation")
        let clipboardBoard = NSPasteboard.withUniqueName()
        let clipboardLine = Line()
        defer { clipboardLine.clearClipboardStorage(); clipboardBoard.releaseGlobally() }
        var captures = 0
        let intake = ClipboardMonitor(pasteboard: clipboardBoard, defaults: isolatedDefaults) { content, manual in
            captures += 1
            try clipboardLine.attachClipboard(content, manual: manual)
        }
        precondition(!intake.imagesEnabled && !intake.textEnabled, "clipboard opt in independently")
        clipboardBoard.clearContents(); clipboardBoard.setString("acceptance note", forType: .string)
        intake.poll()
        precondition(captures == 0, "disabled monitor never captures")
        intake.setTextEnabled(true); intake.poll()
        precondition(captures == 0, "enabling does not capture old clipboard")
        clipboardBoard.clearContents(); clipboardBoard.setString("acceptance note", forType: .string)
        intake.poll()
        let note = clipboardLine.items.first { $0.noteText == "acceptance note" }!
        precondition(captures == 1 && note.isClipboard, "new text becomes note")
        clipboardBoard.clearContents(); clipboardBoard.setString("acceptance note", forType: .string)
        intake.poll()
        precondition(clipboardLine.items.filter { $0.noteText == "acceptance note" }.count == 1, "duplicate note not hung twice")
        clipboardLine.dismiss(note.id)
        clipboardBoard.clearContents(); clipboardBoard.setString("acceptance note", forType: .string)
        intake.poll()
        precondition(!clipboardLine.items.contains { $0.noteText == "acceptance note" }, "duplicate does not resurrect removed note")
        let manuallyCaptured = try intake.captureCurrent()
        precondition(manuallyCaptured && clipboardLine.items.contains { $0.noteText == "acceptance note" }, "manual rehang")
        let editable = clipboardLine.items.first { $0.noteText == "acceptance note" }!
        try clipboardLine.editNote(editable.id, text: "edited note")
        precondition(clipboardLine.items.contains { $0.noteText == "edited note" }, "editable note")
        let ownedURL = clipboardLine.items.first { $0.noteText == "edited note" }!.url
        precondition(clipboardLine.recent.allSatisfy { $0.url != ownedURL }, "notes excluded from persistent recent files")
        let beforeOwnedCopy = captures
        clipboardBoard.clearContents(); clipboardBoard.setString("own copy", forType: .string)
        ClipboardMonitor.markOwned(clipboardBoard); intake.poll()
        precondition(captures == beforeOwnedCopy, "own copy ignored")
        intake.setTextEnabled(false)
        clipboardBoard.clearContents(); clipboardBoard.setString("manual-only note", forType: .string)
        intake.poll()
        let manualWithBothOff = try intake.captureCurrent()
        precondition(manualWithBothOff, "manual capture works when both switches off")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.setColor(.red, atX: 0, y: 0)
        let imageData = bitmap.representation(using: .png, properties: [:])!
        intake.setImagesEnabled(true)
        clipboardBoard.clearContents(); clipboardBoard.setData(imageData, forType: .png)
        clipboardBoard.setString("image alt text", forType: .string)
        intake.poll()
        let imageCard = clipboardLine.items.first { $0.isClipboard && $0.noteText == nil }!
        precondition(imageCard.url.pathExtension == "png", "clipboard image creates image card")
        clipboardBoard.clearContents(); clipboardBoard.setData(imageData, forType: .png); intake.poll()
        precondition(clipboardLine.items.filter { $0.isClipboard && $0.noteText == nil }.count == 1, "image deduplication")
        intake.setImagesEnabled(false); intake.setTextEnabled(true)
        let beforeImageOff = captures
        clipboardBoard.clearContents(); clipboardBoard.setData(imageData, forType: .png)
        clipboardBoard.setString("image alt text", forType: .string); intake.poll()
        precondition(captures == beforeImageOff, "image alternatives do not become notes")
        clipboardBoard.clearContents(); clipboardBoard.writeObjects([manualA as NSURL]); intake.poll()
        precondition(captures == beforeImageOff, "Finder file paths not treated as notes")
        let restoredIntake = ClipboardMonitor(pasteboard: clipboardBoard, defaults: isolatedDefaults) { _, _ in }
        precondition(!restoredIntake.imagesEnabled && restoredIntake.textEnabled, "independent preferences persist")
        clipboardLine.clearClipboardStorage()
        let sourceBytes = try Data(contentsOf: manualA)
        precondition(!FileManager.default.fileExists(atPath: ownedURL.path) && sourceBytes == bytes, "only owned clipboard session files cleaned")
        print("PASS: clipboard opt-in, manual capture, note/image deduplication, own-copy suppression, editing, source safety")
        print("PASS: macOS live watcher, temporary rename, actual rope URL, dismissal/restart/clear and source bytes, copy-only drag, attached folders, recoverable file/folder trash, stale deletion rejection, display persistence")
    }
}
