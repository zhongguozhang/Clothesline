import Foundation

/// Independent completion gates per folder; merges snapshots without losing
/// another folder's items when just one watcher updates.
@MainActor
final class FolderMonitors {
    private(set) var folders: [URL] = []
    private(set) var failures: [String: String] = [:]
    private var watchers: [String: DownloadsWatcher] = [:]
    private var snapshots: [String: [DownloadFile]] = [:]
    private var scoped: [URL] = []
    private let defaults: UserDefaults
    private let onUpdate: ([DownloadFile]) -> Void
    private let key = "monitoredFolderBookmarks"

    var expirationPolicy: ItemExpirationPolicy {
        let preferences = DisplayPreferences(defaults: defaults)
        return ItemExpirationPolicy(lifetime: preferences.retentionLifetime)
    }

    /// Reapply preferences immediately, including when a longer lifetime restores items.
    func refresh() {
        var unique: [String: DownloadFile] = [:]
        for file in snapshots.values.flatMap({ $0 }) { unique[file.path] = file }
        onUpdate(unique.values.sorted {
            $0.recency == $1.recency ? $0.path > $1.path : $0.recency > $1.recency
        })
    }

    static var downloads: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    init(defaults: UserDefaults = .standard, onUpdate: @escaping ([DownloadFile]) -> Void) {
        self.defaults = defaults
        self.onUpdate = onUpdate
    }

    func start() {
        stop()
        addWatcher(Self.downloads)
        var bookmarks = defaults.array(forKey: key) as? [Data] ?? []
        if let legacy = defaults.data(forKey: "folderBookmark") { bookmarks.append(legacy) }
        for data in bookmarks {
            var stale = false
            if let url = (try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale)) ??
                (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)) {
                addWatcher(url)
            }
        }
    }

    func add(_ url: URL) throws {
        guard watchers[url.standardizedFileURL.path] == nil else { return }
        let data = try (try? url.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil, relativeTo: nil)) ??
            (url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil))
        var bookmarks = defaults.array(forKey: key) as? [Data] ?? []
        bookmarks.append(data)
        defaults.set(bookmarks, forKey: key)
        addWatcher(url)
    }

    private func addWatcher(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard watchers[path] == nil else { return }
        if url.startAccessingSecurityScopedResource() { scoped.append(url) }
        folders.append(url)
        let watcher = DownloadsWatcher(folder: url, onUpdate: { [weak self] files in
            guard let self else { return }
            self.snapshots[path] = files
            self.refresh()
        }, onFailure: { [weak self] failure in
            self?.failures[path] = failure
            // Keep aging cached items even while this directory is inaccessible.
            if failure != nil { self?.refresh() }
        })
        watchers[path] = watcher
        watcher.start()
    }

    func wake() { for watcher in watchers.values { watcher.wake() } }

    func stop() {
        for watcher in watchers.values { watcher.stop() }
        for url in scoped { url.stopAccessingSecurityScopedResource() }
        watchers.removeAll(); snapshots.removeAll(); scoped.removeAll()
        folders.removeAll(); failures.removeAll()
    }
}
