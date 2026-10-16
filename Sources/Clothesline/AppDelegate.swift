import AppKit
import SwiftUI
import Quartz
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let line = Line()
    private let loginItems = LoginItems()
    private let updateChecker = UpdateChecker()
    private let identityPanel = FileIdentityPanel()
    private let preferences = DisplayPreferences()
    private let settingsWindow = SettingsWindow()
    private var revealController = LineRevealController()
    private var panel: LinePanel!
    private var statusItem: NSStatusItem!
    private var monitors: FolderMonitors?
    private var clipboard: ClipboardMonitor?
    private let recentDrawer = RecentDrawer()
    private var hotkey: HotKey?
    private var pointerTimer: Timer?
    private var expirationTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private(set) var pinned = UserDefaults.standard.bool(forKey: "alwaysShowLine")
    private var currentScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = LinePanel(content: FileDropView(line: line))
        line.showRecent = { [weak self] in
            guard let self else { return }; self.recentDrawer.show(line: self.line)
        }
        panel.placeOnScreen()
        panel.onScroll = { [weak self] event in
            self?.line.scroll(by: event.scrollingDeltaY + event.scrollingDeltaX)
        }
        panel.orderFrontRegardless()
        currentScreen = LinePanel.screenUnderPointer()
        recalculateCapacity()
        line.revealed = pinned

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧺"
        if let url = Bundle.main.url(forResource: "Clothesline", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.title = ""
            statusItem.button?.image = icon
        }
        statusItem.button?.toolTip = "Clothesline · 晾衣绳"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        monitors = FolderMonitors { [weak self] files in
            guard let self else { return }
            self.line.adopt(files, expiration: self.monitors?.expirationPolicy ?? ItemExpirationPolicy())
        }
        clipboard = ClipboardMonitor { [weak self] content, manual in
            try self?.line.attachClipboard(content, manual: manual)
        }
        line.setExpirationPolicy(ItemExpirationPolicy(lifetime: preferences.retentionLifetime))
        clipboard?.start()
        monitors?.start()
        hotkey = HotKey { [weak self] in self?.togglePinned() }
        pointerTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPointer() }
        }
        if let pointerTimer { RunLoop.main.add(pointerTimer, forMode: .common) }
        expirationTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.line.refreshExpiration() }
        }
        if let expirationTimer { RunLoop.main.add(expirationTimer, forMode: .common) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.revealController.reset()
                    self?.monitors?.wake()
                }
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        identityPanel.hide()
        monitors?.stop()
        clipboard?.stop()
        line.clearClipboardStorage()
        pointerTimer?.invalidate()
        expirationTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    private func addMonitoredFolders() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.prompt = AppLanguage.translate("添加监控文件夹")
        picker.message = AppLanguage.translate("新文件夹与 Downloads 同时监控，不会替换已有监控。")
        picker.directoryURL = FolderMonitors.downloads
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK else { return }
        for url in picker.urls {
            do { try monitors?.add(url) }
            catch { NSAlert(error: error).runModal() }
        }
    }

    private func recalculateCapacity() {
        let usable = max(200, panel.frame.width - 200)
        let fit = max(3, min(12, Int(usable / Layout.spacing)))
        line.visibleCount = fit
        line.maxItems = max(fit, Line.keepOnLine ?? fit)
        line.updateVisibleItems()
    }

    private func pollPointer() {
        let now = ProcessInfo.processInfo.systemUptime
        // AppKit owns mouse tracking from mouseDown through the drag session.
        // Do not turn the source window click-through, hide/reposition it, or
        // move it to another screen while that tracking is in progress.
        if line.pressedID != nil || line.draggingID != nil || line.interactionHeld {
            identityPanel.hide()
            _ = revealController.reveal(atTop: false, overLine: false, isRevealed: line.revealed,
                                        hasItems: !line.items.isEmpty, alwaysVisible: pinned,
                                        interactionHeld: true, delay: preferences.hoverDelay, now: now)
            panel.ignoresMouseEvents = false
            return
        }
        guard let screen = LinePanel.screenUnderPointer() else {
            revealController.reset()
            return
        }
        if screen.frame != currentScreen?.frame {
            revealController.reset()
            if !pinned { line.revealed = false }
            currentScreen = screen
            panel.placeOnScreen(screen)
            recalculateCapacity()
        }
        let mouse = NSEvent.mouseLocation
        let top = screen.visibleFrame.maxY
        let atTop = mouse.y >= top - 4 && mouse.y <= screen.frame.maxY + 1
        // Convert AppKit's bottom-up screen coordinates to SwiftUI's top-down
        // hosting-view coordinates, as used by HitRectsKey.
        let local = CGPoint(x: mouse.x - panel.frame.minX,
                            y: panel.frame.maxY - mouse.y)
        let overCard = line.hitRects.values.contains { $0.insetBy(dx: -4, dy: -4).contains(local) }
        let hovered = line.items.first { item in
            line.hitRects[item.id]?.contains(local) == true
        }
        let externalDragging = NSEvent.pressedMouseButtons & 1 != 0
        if line.revealed, !externalDragging, let item = hovered, let rect = line.hitRects[item.id] {
            let anchor = NSRect(x: panel.frame.minX + rect.minX,
                                y: panel.frame.maxY - rect.maxY,
                                width: rect.width, height: rect.height)
            identityPanel.update(id: item.id, description: line.identityDescription(item), anchor: anchor, screen: screen)
        } else { identityPanel.hide() }
        let overPanel = panel.frame.contains(mouse)

        let shouldReveal = revealController.reveal(
            atTop: atTop, overLine: overPanel || overCard, isRevealed: line.revealed,
            hasItems: !line.items.isEmpty, alwaysVisible: pinned,
            externalDrag: externalDragging, delay: preferences.hoverDelay, now: now)
        if shouldReveal != line.revealed { line.revealed = shouldReveal }
        if !shouldReveal { identityPanel.hide() }
        // During an external mouse drag, expose the full rope as a drop target.
        let externalDrag = NSEvent.pressedMouseButtons & 1 != 0 && line.draggingID == nil
        panel.ignoresMouseEvents = !shouldReveal || (!overCard && !externalDrag)
    }

    func setAlwaysVisible(_ enabled: Bool) {
        pinned = enabled
        UserDefaults.standard.set(enabled, forKey: "alwaysShowLine")
        revealController.reset()
        if pinned {
            panel?.placeOnScreen()
            line.revealed = true
        } else {
            line.revealed = false
        }
    }

    private func togglePinned() { setAlwaysVisible(!pinned) }

    private func showSettings(_ page: SettingsWindow.Page) {
        settingsWindow.show(page, preferences: preferences) { [weak self] in
            guard let self else { return }
            self.revealController.reset()
            self.line.setExpirationPolicy(ItemExpirationPolicy(lifetime: self.preferences.retentionLifetime))
        }
    }

    private func attachFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = true
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.prompt = AppLanguage.translate("挂上晾衣绳")
        picker.message = AppLanguage.translate("挂上文件或文件夹快捷入口，保留在原位置。Downloads 监听仍然继续。")
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK else { return }
        for url in picker.urls {
            do { try line.attachFolder(url) }
            catch { NSAlert(error: error).runModal() }
        }
    }

    // Dynamic menu. No app menu or Dock icon is required.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: AppLanguage.translate("晾衣绳 · Clothesline"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for folder in monitors?.folders ?? [] {
            let name = NSMenuItem(title: AppLanguage.text("监控：\(folder.lastPathComponent)", "Watching: \(folder.lastPathComponent)"), action: nil, keyEquivalent: "")
            name.isEnabled = false
            name.toolTip = folder.path
            menu.addItem(name)
            if let failure = monitors?.failures[folder.standardizedFileURL.path] {
                let problem = NSMenuItem(title: "⚠ \(failure)", action: nil, keyEquivalent: "")
                problem.isEnabled = false
                menu.addItem(problem)
            }
        }
        menu.addItem(.separator())
        let show = ClosureMenuItem("一直显示晾衣绳") { [weak self] in self?.togglePinned() }
        show.state = pinned ? .on : .off
        menu.addItem(show)
        let autoHide = ClosureMenuItem("自动隐藏晾衣绳") { [weak self] in self?.setAlwaysVisible(false) }
        autoHide.state = pinned ? .off : .on
        menu.addItem(autoHide)
        menu.addItem(ClosureMenuItem("悬停显示晾衣绳延迟…") { [weak self] in self?.showSettings(.hoverDelay) })
        menu.addItem(ClosureMenuItem("挂上文件或文件夹…") { [weak self] in self?.attachFolder() })
        menu.addItem(ClosureMenuItem("最近文件…") { [weak self] in
            guard let self else { return }; self.recentDrawer.show(line: self.line)
        })
        let clipboardMenu = NSMenu(title: AppLanguage.translate("剪贴板挂载"))
        let images = ClosureMenuItem("自动挂上图片 / 截图") { [weak self] in
            guard let self else { return }
            self.clipboard?.setImagesEnabled(!(self.clipboard?.imagesEnabled ?? false))
        }
        images.state = clipboard?.imagesEnabled == true ? .on : .off
        clipboardMenu.addItem(images)
        let text = ClosureMenuItem("自动挂上文字便签") { [weak self] in
            guard let self else { return }
            self.clipboard?.setTextEnabled(!(self.clipboard?.textEnabled ?? false))
        }
        text.state = clipboard?.textEnabled == true ? .on : .off
        clipboardMenu.addItem(text)
        clipboardMenu.addItem(.separator())
        clipboardMenu.addItem(ClosureMenuItem("清空剪贴板挂载内容") { [weak self] in
            self?.line.clearClipboardStorage()
        })
        if let failure = clipboard?.failure {
            let errorItem = NSMenuItem(title: "⚠ \(failure)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false; clipboardMenu.addItem(errorItem)
        }
        let clipboardItem = NSMenuItem(title: AppLanguage.translate("剪贴板挂载"), action: nil, keyEquivalent: "")
        clipboardItem.submenu = clipboardMenu
        menu.addItem(clipboardItem)
        menu.addItem(ClosureMenuItem("打开下载文件夹") {
            NSWorkspace.shared.open(FolderMonitors.downloads)
        })
        menu.addItem(ClosureMenuItem("添加监控文件夹…") { [weak self] in self?.addMonitoredFolders() })
        menu.addItem(.separator())

        let keepSubmenu = NSMenu(title: AppLanguage.translate("保留文件数量"))
        for choice in [0, 25, 50, 100] {
            let title = choice == 0 ? "屏幕可容纳数量" : AppLanguage.text("\(choice) 个文件", "\(choice) items")
            let item = ClosureMenuItem(title) { [weak self] in
                Line.keepOnLine = choice == 0 ? nil : choice
                self?.recalculateCapacity()
            }
            item.state = (Line.keepOnLine ?? 0) == choice ? .on : .off
            keepSubmenu.addItem(item)
        }
        let keepItem = NSMenuItem(title: AppLanguage.translate("保留文件数量"), action: nil, keyEquivalent: "")
        keepItem.submenu = keepSubmenu
        menu.addItem(keepItem)
        menu.addItem(ClosureMenuItem("保留文件时间…") { [weak self] in self?.showSettings(.retention) })

        let sizeSubmenu = NSMenu(title: AppLanguage.translate("卡片尺寸"))
        for size in Layout.Size.allCases {
            let title: String
            switch size { case .small: title = "小"; case .medium: title = "中"; case .large: title = "大" }
            let item = ClosureMenuItem(title) { [weak self] in
                Layout.size = size
                self?.panel.placeOnScreen()
                self?.recalculateCapacity()
            }
            item.state = Layout.size == size ? .on : .off
            sizeSubmenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: AppLanguage.translate("卡片尺寸"), action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("清空晾衣绳（不删除文件）") { [weak self] in self?.line.dismissAll() })
        menu.addItem(ClosureMenuItem("重新显示已取下的文件") { [weak self] in self?.line.resetDismissed() })
        menu.addItem(.separator())
        let hotkey = NSMenuItem(title: AppLanguage.translate("快捷键：⌃⌥T"), action: nil, keyEquivalent: "")
        hotkey.isEnabled = false
        menu.addItem(hotkey)
        menu.addItem(.separator())
        let login = ClosureMenuItem("开机启动") { [weak self] in self?.toggleLoginItem() }
        switch loginItems.status {
        case .enabled: login.state = .on
        case .requiresApproval: login.state = .mixed
        default: login.state = .off
        }
        menu.addItem(login)
        if loginItems.status == .requiresApproval {
            menu.addItem(ClosureMenuItem("在系统设置中允许开机启动…") { SMAppService.openSystemSettingsLoginItems() })
        }
        let updates = ClosureMenuItem(updateChecker.checking ? "正在检查更新…" : "检查更新…") { [weak self] in
            self?.updateChecker.check()
        }
        updates.isEnabled = !updateChecker.checking
        menu.addItem(updates)
        menu.addItem(ClosureMenuItem("关于 Clothesline…") { [weak self] in self?.showAbout() })
        let languages = NSMenu(title: "Language")
        for language in AppLanguage.allCases {
            let item = ClosureMenuItem(language == .chinese ? "简体中文" : "English") { [weak self] in
                AppLanguage.current = language
                self?.line.objectWillChange.send()
                self?.recentDrawer.refreshLanguage()
                if self?.settingsWindow.window?.isVisible == true, let page = self?.settingsWindow.page {
                    self?.showSettings(page)
                }
            }
            item.state = AppLanguage.current == language ? .on : .off
            languages.addItem(item)
        }
        let languageItem = NSMenuItem(title: AppLanguage.translate("语言 / Language"), action: nil, keyEquivalent: "")
        languageItem.submenu = languages
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("退出 Clothesline") { NSApp.terminate(nil) })
    }

    private func toggleLoginItem() {
        do {
            try loginItems.toggle()
            if loginItems.status == .requiresApproval {
                let alert = NSAlert()
                alert.messageText = AppLanguage.text("请允许开机启动", "Allow Launch at Login")
                alert.informativeText = AppLanguage.text("请在系统设置 → 通用 → 登录项中允许 Clothesline。", "Allow Clothesline in System Settings → General → Login Items.")
                alert.addButton(withTitle: AppLanguage.text("打开系统设置", "Open System Settings"))
                alert.addButton(withTitle: AppLanguage.text("稍后", "Later"))
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = AppLanguage.text("无法更改开机启动", "Unable to Change Launch at Login")
            alert.informativeText += AppLanguage.text("\n请将应用安装到‘应用程序’文件夹后重试。", "\nInstall the app in Applications and try again.")
            NSApp.activate(ignoringOtherApps: true); alert.runModal()
        }
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Clothesline · 晾衣绳"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        alert.informativeText = AppLanguage.text("版本", "Version") + " " + UpdateChecker.currentVersion + " (" + build + ")\n\n" +
            AppLanguage.text("把常用文件、文件夹和剪贴板内容挂在屏幕顶部，随手预览、拖拽和使用。", "Keep files, folders, and clipboard items at the top of your screen for quick preview, drag and drop, and reuse.")
        alert.addButton(withTitle: AppLanguage.text("关闭", "Close"))
        alert.addButton(withTitle: "GitHub")
        alert.addButton(withTitle: AppLanguage.text("版权与许可", "Credits & License"))
        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        if result == .alertSecondButtonReturn { NSWorkspace.shared.open(UpdateChecker.repository) }
        if result == .alertThirdButtonReturn {
            let license = NSAlert()
            license.messageText = AppLanguage.text("版权与许可", "Credits & License")
            let content = Bundle.main.url(forResource: "LICENSE", withExtension: nil)
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
                ?? AppLanguage.text("请查看项目仓库中的 LICENSE。", "See LICENSE in the project repository.")
            let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 280))
            text.isEditable = false; text.string = content
            let scroll = NSScrollView(frame: text.frame)
            scroll.hasVerticalScroller = true; scroll.documentView = text
            license.accessoryView = scroll
            license.addButton(withTitle: AppLanguage.text("好", "OK"))
            license.runModal()
        }
    }

    // Quick Look delegates are asked through the application responder chain.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLook.shared.take(panel)
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLook.shared.release(panel)
    }
}
