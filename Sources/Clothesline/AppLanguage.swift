import Foundation

// Only application UI labels are translated; file names and system errors stay intact.
enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans", english = "en"
    static var current: AppLanguage {
        get {
            if let value = UserDefaults.standard.string(forKey: "menuLanguage"), let saved = Self(rawValue: value) { return saved }
            return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "menuLanguage") }
    }
    static func text(_ chinese: String, _ english: String) -> String {
        current == .english ? english : chinese
    }
    static func translate(_ text: String) -> String {
        current == .english ? (englishLabels[text] ?? text) : text
    }
    static let englishLabels: [String: String] = [
        "晾衣绳 · Clothesline": "Clothesline", "一直显示晾衣绳": "Always Show Clothesline",
        "自动隐藏晾衣绳": "Auto-hide Clothesline", "挂上文件或文件夹…": "Hang Files or Folders…",
        "最近文件…": "Recent Files…", "剪贴板挂载": "Clipboard", "自动挂上图片 / 截图": "Automatically Hang Images / Screenshots",
        "自动挂上文字便签": "Automatically Hang Text Notes", "清空剪贴板挂载内容": "Clear Clipboard Items",
        "打开下载文件夹": "Open Downloads", "添加监控文件夹…": "Add Watched Folders…",
        "保留文件数量": "Items to Keep", "屏幕可容纳数量": "Fit to Screen", "卡片尺寸": "Card Size",
        "小": "Small", "中": "Medium", "大": "Large", "清空晾衣绳（不删除文件）": "Clear Clothesline (Keep Files)",
        "重新显示已取下的文件": "Show Removed Items Again", "快捷键：⌃⌥T": "Shortcut: ⌃⌥T",
        "退出 Clothesline": "Quit Clothesline", "开机启动": "Launch at Login", "检查更新…": "Check for Updates…",
        "正在检查更新…": "Checking for Updates…", "关于 Clothesline…": "About Clothesline…", "语言 / Language": "Language / 语言",
        "在系统设置中允许开机启动…": "Allow Login Item in System Settings…",
        "快速预览": "Quick Look", "打开文件": "Open File", "复制图片": "Copy Image", "复制文字": "Copy Text",
        "查看 / 编辑便签…": "View / Edit Note…", "另存为…": "Save As…", "在 Finder 中显示": "Show in Finder",
        "复制文件": "Copy File", "重命名…": "Rename…", "取消固定": "Unpin", "固定": "Pin", "分享…": "Share…",
        "复制文件名": "Copy File Name", "复制完整路径": "Copy Full Path",
        "从晾衣绳取下（保留原文件）": "Take Down (Keep Original)", "移到废纸篓…": "Move to Trash…",
        "最近文件": "Recent Files", "搜索文件名称": "Search file names", "挂上": "Hang", "打开": "Open",
        "暂无最近文件": "No recent files", "没有匹配的文件": "No matching files",
        "最多保留 200 个近期文件入口；源文件仍在原位置。": "Up to 200 recent file references. Originals stay in place.",
        "文字便签": "Text Note", "文件失效": "File Unavailable", "已固定": "Pinned", "已复制": "Copied", "已复制文字": "Text Copied",
        "最新下载的文件会挂在这里": "Recent downloads appear here",
        "保存": "Save", "取消": "Cancel", "重命名": "Rename", "移到废纸篓": "Move to Trash",
        "修改原文件名称，文件扩展名保持不变。": "Rename the original file while keeping its extension.",
        "源文件不存在或无法访问": "The original file is missing or inaccessible",
        "文件夹（不递归计算大小）": "Folder (contents not counted)", "剪贴板（本次会话）": "Clipboard (this session)",
        "本次会话已挂载 100 条剪贴板内容，请清空剪贴板挂载内容后重试。": "This session already has 100 clipboard items. Clear clipboard items and try again.",
        "便签不能为空，且需在 200 KB 以内。": "Notes must not be empty or exceed 200 KB.",
        "请选择可访问的文件或文件夹。": "Choose an accessible file or folder.",
        "文件已改变或不存在，请刷新后重试。": "The file has changed or is missing. Refresh and try again.",
        "名称不能为空或包含 /、: 等无效字符。": "Names must not be empty or contain invalid characters such as / or :.",
        "同名文件已存在，请使用其他名称。不会覆盖原文件。": "An item with that name already exists. Choose another name; the original will not be overwritten.",
        "文件已改变或不存在，请等待刷新后重试。": "The file has changed or is missing. Wait for a refresh and try again.",
        "文件夹及其内容会从原位置移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。": "The folder and its contents will move to Trash and can be restored in Finder. To hide the card, choose Take Down instead.",
        "原文件会移到废纸篓，可在 Finder 中恢复。若只想隐藏卡片，请选择“从晾衣绳取下”。": "The original file will move to Trash and can be restored in Finder. To hide the card, choose Take Down instead.",
        "挂上晾衣绳": "Hang on Clothesline", "添加监控文件夹": "Add Watched Folders",
        "新文件夹与 Downloads 同时监控，不会替换已有监控。": "Watch new folders alongside Downloads and existing folders.",
        "挂上文件或文件夹快捷入口，保留在原位置。Downloads 监听仍然继续。": "Hang references to files or folders. Originals stay in place; Downloads monitoring continues."
    ]
}
