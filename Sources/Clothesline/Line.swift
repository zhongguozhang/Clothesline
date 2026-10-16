import AppKit
import Combine
import QuickLookThumbnailing

struct Pegged: Identifiable, Equatable {
    let id: UUID
    let file: DownloadFile
    var thumb: NSImage
    let tilt: Double
    var falling = false
    var flying = false
    var noteText: String?
    var isClipboard = false
    var pinned = false
    var unavailable = false
    var url: URL { file.url }
    var isRecording: Bool {
        ["mov", "mp4", "m4v", "avi", "webm", "mkv"].contains(url.pathExtension.lowercased())
    }
    static func == (lhs: Pegged, rhs: Pegged) -> Bool {
        lhs.id == rhs.id && lhs.thumb === rhs.thumb && lhs.falling == rhs.falling && lhs.noteText == rhs.noteText && lhs.pinned == rhs.pinned && lhs.unavailable == rhs.unavailable && lhs.file == rhs.file
    }
}

@MainActor
final class Line: ObservableObject {
    @Published private(set) var items: [Pegged] = []
    @Published var draggingID: UUID?
    @Published var pressedID: UUID?
    @Published var copiedID: UUID?
    @Published var revealed = false
    @Published var gust = 0
    @Published var scroll: CGFloat = 0

    var maxItems = 8
    var visibleCount = 8
    var hitRects: [UUID: CGRect] = [:]
    let drawerButtonID = UUID()
    var showRecent: () -> Void = {}

    private struct ClipboardEntry {
        var content: ClipboardContent
        let url: URL
    }
    private var clipboardEntries: [ClipboardEntry] = []
    private var clipboardDirectory: URL?
    private struct Pin: Codable {
        var file: DownloadFile
        var bookmark: Data
    }
    private var pins: [Pin] = []
    private var latest: [DownloadFile] = []
    @Published private(set) var recent: [DownloadFile] = []
    var interactionHeld = false
    private var attachedFolders: [URL] = []
    private static let foldersKey = "attachedFolderBookmarks"
    private var dismissed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "dismissedFiles") ?? [])
    private static let dismissalKey = "dismissedFiles"
    static let keepChoices = [25, 50, 100]
    static var keepOnLine: Int? {
        get {
            let n = UserDefaults.standard.integer(forKey: "keepOnLine")
            return keepChoices.contains(n) ? n : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepOnLine") }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "pinnedFiles") {
            pins = (try? JSONDecoder().decode([Pin].self, from: data)) ?? []
        }
        attachedFolders = (UserDefaults.standard.array(forKey: Self.foldersKey) as? [Data] ?? []).compactMap {
            var stale = false
            return try? URL(resolvingBookmarkData: $0, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        recent = (UserDefaults.standard.array(forKey: "recentFileBookmarks") as? [Data] ?? []).compactMap {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: $0, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
            return try? DownloadIndex.read(url)
        }
        // Gentle periodic gusts without keeping the CPU busy for animation.
        Timer.scheduledTimer(withTimeInterval: 16, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.gust &+= 1 }
        }
    }

    func adopt(_ files: [DownloadFile]) {
        latest = files
        remember(files)
        // A completion scan can temporarily be empty at startup or while a
        // file changes. It is not evidence that dismissed files were deleted.
        updateVisibleItems()
    }

    func updateVisibleItems() {
        // Preserve the AppKit drag source even when the Downloads scan changes.
        guard pressedID == nil, draggingID == nil else { return }
        let attached = attachedFolders.compactMap { try? DownloadIndex.read($0) }
        let attachedPaths = Set(attached.map(\.path))
        let originalFiles = attached + latest.filter { !attachedPaths.contains($0.path) }
        remember(originalFiles)
        let clipboardFiles = clipboardEntries.compactMap { try? DownloadIndex.read($0.url) }
        let combined = clipboardFiles + originalFiles
        for index in pins.indices {
            var stale = false
            let url = (try? URL(resolvingBookmarkData: pins[index].bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)) ?? pins[index].file.url
            if let fresh = try? DownloadIndex.read(url) { pins[index].file = fresh }
        }
        let pinPaths = Set(pins.map { $0.file.path })
        // Missing source cards remain explicit instead of silently disappearing.
        let missing = items.filter { !$0.isClipboard && !pinPaths.contains($0.file.path) && (try? DownloadIndex.read($0.url)) == nil }.map(\.file)
        var unique: [String: DownloadFile] = [:]
        for file in combined + missing { unique[file.path] = (try? DownloadIndex.read(file.url)) ?? file }
        let ordinary = (combined + missing).compactMap { unique.removeValue(forKey: $0.path) }
            .filter { !pinPaths.contains($0.path) && !dismissed.contains($0.fingerprint) }
        let selected = Array((pins.map(\.file) + ordinary.prefix(max(0, maxItems - pins.count))).reversed())
        let previous = Dictionary(uniqueKeysWithValues: items.map { ($0.file.fingerprint, $0) })
        var newItems: [Pegged] = []
        for file in selected {
            if var existing = previous[file.fingerprint] {
                existing.pinned = pinPaths.contains(file.path)
                existing.unavailable = (try? DownloadIndex.read(file.url)) == nil
                newItems.append(existing)
            } else {
                let image = NSWorkspace.shared.icon(forFile: file.path)
                image.size = NSSize(width: 120, height: 120)
                let entry = clipboardEntries.first { $0.url.path == file.path }
                let note: String? = entry.flatMap { if case .text(let text) = $0.content { return text }; return nil }
                let item = Pegged(id: UUID(), file: file, thumb: image,
                                  tilt: Double.random(in: -2.5...2.5), noteText: note, isClipboard: entry != nil, pinned: pinPaths.contains(file.path), unavailable: (try? DownloadIndex.read(file.url)) == nil)
                newItems.append(item)
                requestThumbnail(for: item)
            }
        }
        if items.map(\.id) != newItems.map(\.id) { scroll = 0 }
        if items != newItems { items = newItems }
    }

    func togglePin(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), !item.isClipboard else { return }
        if pins.contains(where: { $0.file.path == item.file.path }) {
            pins.removeAll { $0.file.path == item.file.path }
        } else {
            do {
                let bookmark = try item.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                pins.append(Pin(file: item.file, bookmark: bookmark))
                dismissed.remove(item.file.fingerprint)
            } catch { NSAlert(error: error).runModal(); return }
        }
        savePins(); updateVisibleItems()
    }
    private func savePins() {
        if let data = try? JSONEncoder().encode(pins) { UserDefaults.standard.set(data, forKey: "pinnedFiles") }
    }
    func identityDescription(_ item: Pegged) -> String {
        let fresh = try? DownloadIndex.read(item.url)
        let file = fresh ?? item.file
        let size = file.isDirectory ? AppLanguage.translate("文件夹（不递归计算大小）") : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
        let date = DateFormatter(); date.dateStyle = .medium; date.timeStyle = .medium
        let source = item.isClipboard ? AppLanguage.translate("剪贴板（本次会话）") : file.url.deletingLastPathComponent().path
        if AppLanguage.current == .english {
            return "Name: \(item.noteText == nil ? file.url.lastPathComponent : "Text Note")\nSource: \(source)\nSize: \(size)\nCreated: \(date.string(from: file.created))\nModified: \(date.string(from: file.modified))" + (fresh == nil ? "\n⚠ Original missing or inaccessible; size and dates are last known values." : "")
        }
        return "名称：\(item.noteText == nil ? file.url.lastPathComponent : "文字便签")\n来源：\(source)\n大小：\(size)\n创建：\(date.string(from: file.created))\n修改：\(date.string(from: file.modified))" +
            (fresh == nil ? "\n⚠ 源文件不存在或无法访问；大小和时间为最后记录。" : "")
    }
    func validateAvailable(_ id: UUID) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        guard (try? DownloadIndex.read(item.url)) != nil else {
            updateVisibleItems()
            let alert = NSAlert(); alert.messageText = AppLanguage.translate("源文件不存在或无法访问")
            alert.informativeText = item.url.path + AppLanguage.text("\n请检查文件位置或访问权限；可取下失效卡片。", "\nCheck the file location or permissions; you can take down this card.")
            alert.runModal(); return false
        }
        return true
    }

    /// Clipboard payloads are owned session files, excluded from persistent history/bookmarks.
    func attachClipboard(_ content: ClipboardContent, manual: Bool = false) throws {
        if let existing = clipboardEntries.first(where: { $0.content.identity == content.identity }) {
            if manual, let file = try DownloadIndex.read(existing.url) {
                dismissed.remove(file.fingerprint)
                UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
                updateVisibleItems(); revealed = true
            }
            return
        }
        guard clipboardEntries.count < 100 else {
            throw NSError(domain: "Clothesline", code: 7, userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("本次会话已挂载 100 条剪贴板内容，请清空剪贴板挂载内容后重试。")])
        }
        if clipboardDirectory == nil {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Clothesline-Clipboard-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                                                  attributes: [.posixPermissions: 0o700])
            clipboardDirectory = folder
        }
        guard let folder = clipboardDirectory else { return }
        let url = folder.appendingPathComponent((content.isText ? "便签-" : "剪贴板图片-") + UUID().uuidString)
            .appendingPathExtension(content.isText ? "txt" : "png")
        try content.data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        clipboardEntries.insert(ClipboardEntry(content: content, url: url), at: 0)
        updateVisibleItems(); revealed = true
    }

    func clearClipboardStorage() {
        guard pressedID == nil, draggingID == nil else { return }
        if let folder = clipboardDirectory {
            dismissed = dismissed.filter { !$0.hasPrefix(folder.path + "/") }
            try? FileManager.default.removeItem(at: folder)
            UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        }
        clipboardEntries.removeAll(); clipboardDirectory = nil
        updateVisibleItems()
    }

    func requestEditNote(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let text = item.noteText else { return }
        interactionHeld = true
        defer { interactionHeld = false }
        let alert = NSAlert()
        alert.messageText = AppLanguage.translate("文字便签")
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
        editor.isRichText = false; editor.string = text
        let scroll = NSScrollView(frame: editor.frame)
        scroll.hasVerticalScroller = true; scroll.documentView = editor
        alert.accessoryView = scroll
        alert.addButton(withTitle: AppLanguage.translate("保存")); alert.addButton(withTitle: AppLanguage.translate("取消"))
        alert.window.initialFirstResponder = editor
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try editNote(id, text: editor.string) }
        catch { NSAlert(error: error).runModal() }
    }

    func editNote(_ id: UUID, text: String) throws {
        guard let item = items.first(where: { $0.id == id }), item.noteText != nil,
              let index = clipboardEntries.firstIndex(where: { $0.url == item.url }) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 200_000 else {
            throw NSError(domain: "Clothesline", code: 6, userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("便签不能为空，且需在 200 KB 以内。")])
        }
        try Data(text.utf8).write(to: item.url, options: .atomic)
        clipboardEntries[index].content = .text(text)
        updateVisibleItems()
    }

    func saveClipboard(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), item.isClipboard else { return }
        interactionHeld = true
        defer { interactionHeld = false }
        let picker = NSSavePanel()
        picker.nameFieldStringValue = item.noteText != nil ? AppLanguage.text("便签.txt", "Note.txt") : AppLanguage.text("剪贴板图片.png", "Clipboard.png")
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let destination = picker.url else { return }
        do { try Data(contentsOf: item.url).write(to: destination, options: .atomic) }
        catch { NSAlert(error: error).runModal() }
    }

    private func requestThumbnail(for item: Pegged) {
        guard !item.file.isDirectory, item.noteText == nil else { return }
        let request = QLThumbnailGenerator.Request(fileAt: item.url,
            size: CGSize(width: 240, height: 220), scale: 2,
            representationTypes: [.thumbnail, .lowQualityThumbnail])
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                self.items[index].thumb = image
            }
        }
    }

    func dismiss(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        pins.removeAll { $0.file.path == item.file.path }; savePins()
        dismissed.insert(item.file.fingerprint)
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func dismissAll() {
        pins.removeAll(); savePins()
        for item in items { dismissed.insert(item.file.fingerprint) }
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func resetDismissed() {
        dismissed.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func attachFolder(_ url: URL) throws {
        guard let file = try DownloadIndex.read(url) else {
            throw NSError(domain: "Clothesline", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("请选择可访问的文件或文件夹。")])
        }
        if !attachedFolders.contains(where: { $0.standardizedFileURL.path == file.path }) {
            // Prepare persistence before changing the display. Normal bookmarks
            // suit the current non-sandboxed local build and survive renames.
            _ = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            attachedFolders.insert(url, at: 0)
            saveAttachedFolders()
        }
        dismissed.remove(file.fingerprint)
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissalKey)
        updateVisibleItems()
    }

    func attachFiles(_ urls: [URL]) throws {
        for url in urls { try attachFolder(url) }
        revealed = true
    }

    private func remember(_ files: [DownloadFile]) {
        var unique = Dictionary(uniqueKeysWithValues: recent.map { ($0.path, $0) })
        for file in files { unique[file.path] = file }
        let updated = Array(unique.values.compactMap { try? DownloadIndex.read($0.url) }
            .sorted { $0.recency == $1.recency ? $0.path > $1.path : $0.recency > $1.recency }.prefix(200))
        guard updated != recent else { return }
        recent = updated
        let bookmarks = recent.compactMap { try? $0.url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
        UserDefaults.standard.set(bookmarks, forKey: "recentFileBookmarks")
    }

    func recentFiles(matching query: String) -> [DownloadFile] {
        recent.filter { query.isEmpty || $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) }
            .compactMap { try? DownloadIndex.read($0.url) }
    }

    func rename(_ id: UUID, stem: String) throws {
        guard let item = items.first(where: { $0.id == id }), !item.isClipboard,
              let fresh = try DownloadIndex.read(item.url), fresh.fingerprint == item.file.fingerprint else {
            throw NSError(domain: "Clothesline", code: 3, userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("文件已改变或不存在，请刷新后重试。")])
        }
        let name = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains(":"), !name.contains("\0") else {
            throw NSError(domain: "Clothesline", code: 4, userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("名称不能为空或包含 /、: 等无效字符。")])
        }
        let ext = item.file.isDirectory ? "" : item.url.pathExtension
        let target = item.url.deletingLastPathComponent().appendingPathComponent(ext.isEmpty ? name : name + "." + ext)
        guard target.path != item.url.path else { return }
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw NSError(domain: "Clothesline", code: 5, userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("同名文件已存在，请使用其他名称。不会覆盖原文件。")])
        }
        try FileManager.default.moveItem(at: item.url, to: target)
        items.removeAll { $0.id == id }
        for index in pins.indices where pins[index].file.path == item.file.path {
            if let fresh = try DownloadIndex.read(target) {
                pins[index].file = fresh
                pins[index].bookmark = try target.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            }
        }
        savePins()
        attachedFolders = attachedFolders.map { $0.standardizedFileURL.path == item.file.path ? target : $0 }
        latest.removeAll { $0.path == item.file.path }
        recent.removeAll { $0.path == item.file.path }
        if let updated = try DownloadIndex.read(target) { latest.insert(updated, at: 0); remember([updated]) }
        saveAttachedFolders()
        updateVisibleItems()
    }

    func requestRename(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        interactionHeld = true
        defer { interactionHeld = false }
        let alert = NSAlert()
        alert.messageText = AppLanguage.text("重命名“\(item.url.lastPathComponent)”", "Rename ‘\(item.url.lastPathComponent)’")
        alert.informativeText = AppLanguage.translate("修改原文件名称，文件扩展名保持不变。")
        let field = NSTextField(string: item.file.isDirectory || item.url.pathExtension.isEmpty
            ? item.url.lastPathComponent : item.url.deletingPathExtension().lastPathComponent)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: AppLanguage.translate("重命名")); alert.addButton(withTitle: AppLanguage.translate("取消"))
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try rename(id, stem: field.stringValue) }
        catch { NSAlert(error: error).runModal() }
    }

    private func saveAttachedFolders() {
        let bookmarks = attachedFolders.compactMap {
            try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: Self.foldersKey)
    }

    /// The explicit delete command uses Trash. Taking down a card never calls this.
    @discardableResult
    func moveToTrash(_ id: UUID) throws -> URL {
        guard let item = items.first(where: { $0.id == id }), !item.isClipboard,
              let current = try DownloadIndex.read(item.url),
              current.fingerprint == item.file.fingerprint else {
            throw NSError(domain: "Clothesline", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: AppLanguage.translate("文件已改变或不存在，请等待刷新后重试。")])
        }
        var result: NSURL?
        try FileManager.default.trashItem(at: item.url, resultingItemURL: &result)
        pins.removeAll { $0.file.path == item.file.path }; savePins()
        items.removeAll { $0.id == id }
        latest.removeAll { $0.path == item.file.path }
        recent.removeAll { $0.path == item.file.path }
        remember([])
        attachedFolders.removeAll { $0.standardizedFileURL.path == item.file.path }
        saveAttachedFolders()
        updateVisibleItems()
        return (result as URL?) ?? item.url
    }

    func requestTrash(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = AppLanguage.text("将“\(item.url.lastPathComponent)”移到废纸篓？", "Move ‘\(item.url.lastPathComponent)’ to Trash?")
        alert.informativeText = item.file.isDirectory
            ? AppLanguage.translate("文件夹及其内容会从原位置移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。")
            : AppLanguage.translate("原文件会移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLanguage.translate("取消"))
        alert.addButton(withTitle: AppLanguage.translate("移到废纸篓"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try moveToTrash(id) }
        catch { NSAlert(error: error).runModal() }
    }

    func open(_ id: UUID) {
        guard validateAvailable(id) else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ id: UUID) {
        guard validateAvailable(id) else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copy(_ id: UUID) {
        guard validateAvailable(id) else { return }
        guard let item = items.first(where: { $0.id == id }) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = item.noteText { pb.setString(text, forType: .string) }
        else if item.isClipboard, let data = try? Data(contentsOf: item.url) { pb.setData(data, forType: .png) }
        else { pb.writeObjects([item.url as NSURL]) }
        ClipboardMonitor.markOwned(pb)
        showCopiedFeedback(id)
    }

    enum FileTextField { case name, fullPath }

    func copyFileText(_ id: UUID, _ field: FileTextField, to pasteboard: NSPasteboard = .general) {
        guard let item = items.first(where: { $0.id == id }), !item.isClipboard else { return }
        // Copy the card's reference as plain text, including for unavailable sources.
        let text = field == .name ? item.url.lastPathComponent : item.url.standardizedFileURL.path
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return }
        ClipboardMonitor.markOwned(pasteboard)
        showCopiedFeedback(id)
    }

    private func showCopiedFeedback(_ id: UUID) {
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            if self?.copiedID == id { self?.copiedID = nil }
        }
    }

    func quickLook(_ id: UUID) {
        guard validateAvailable(id) else { return }
        let active = items.map(\.url)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        QuickLook.shared.show(active, at: index)
    }

    func scroll(by distance: CGFloat) {
        let limit = CGFloat(max(0, items.count - visibleCount)) * Layout.spacing
        scroll = min(limit, max(0, scroll + distance))
    }
}
