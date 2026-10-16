import AppKit
import SwiftUI

/// Receives actual Finder URLs; stores references without moving their originals.
final class FileDropView: NSHostingView<LineView> {
    let line: Line
    convenience init(line: Line) { self.init(rootView: LineView(line: line)) }
    required init(rootView: LineView) {
        self.line = rootView.line
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !Self.urls(from: sender.draggingPasteboard).isEmpty else { return [] }
        line.revealed = true
        line.interactionHeld = true
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { line.interactionHeld = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { line.interactionHeld = false }
        let urls = Self.urls(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        do { try line.attachFiles(urls); return true }
        catch { NSAlert(error: error).runModal(); return false }
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { line.interactionHeld = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { line.interactionHeld = false }
}
