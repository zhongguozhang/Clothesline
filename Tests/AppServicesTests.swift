import AppKit
import ServiceManagement

@MainActor
private final class FakeLoginService: LoginService {
    var status: SMAppService.Status = .notRegistered
    var registered = 0
    var unregistered = 0
    var fail = false
    func register() throws {
        if fail { throw URLError(.noPermissionsToReadFile) }
        registered += 1; status = .enabled
    }
    func unregister() throws {
        if fail { throw URLError(.noPermissionsToReadFile) }
        unregistered += 1; status = .notRegistered
    }
}

@MainActor
func testAppServices() throws {
    let old = UserDefaults.standard.object(forKey: "menuLanguage")
    defer {
        if let old { UserDefaults.standard.set(old, forKey: "menuLanguage") }
        else { UserDefaults.standard.removeObject(forKey: "menuLanguage") }
    }
    let fake = FakeLoginService()
    let login = LoginItems(service: fake)
    precondition(fake.registered == 0, "constructing login controller must not change settings")
    try login.toggle(); precondition(login.status == .enabled && fake.registered == 1)
    try login.toggle(); precondition(login.status == .notRegistered && fake.unregistered == 1)
    fake.status = .requiresApproval
    try login.toggle(); precondition(fake.unregistered == 2, "pending approval can be turned off")
    fake.fail = true
    do { try login.toggle(); preconditionFailure("service errors must propagate") } catch {}
    precondition(login.status == .notRegistered)

    let versions = ["0.1.0-rc.2", "0.1.0-rc.3", "0.1.0-rc.10", "0.1.0", "0.1.1", "0.2.0", "1.0.0"]
    for (a, b) in zip(versions, versions.dropFirst()) { precondition(AppVersion(a)! < AppVersion(b)!) }
    precondition(AppVersion("v0.1.0+abc") == AppVersion("0.1.0"))
    for invalid in ["", "v", "-", "garbage", "0.1", "0.1.0-", "0.1.0-rc..1", "0.a.0"] { precondition(AppVersion(invalid) == nil) }
    let releases = Data("""
    [
      {"tag_name":"v0.1.0-rc.2","html_url":"https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.2","draft":false,"prerelease":true},
      {"tag_name":"v0.1.0-rc.10","html_url":"https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.10","draft":false,"prerelease":true},
      {"tag_name":"v0.0.9","html_url":"https://github.com/zhongguozhang/Clothesline/releases/tag/v0.0.9","draft":false,"prerelease":false},
      {"tag_name":"v5.0.0-beta.1","html_url":"https://github.com/zhongguozhang/Clothesline/releases/tag/v5.0.0-beta.1","draft":false,"prerelease":false},
      {"tag_name":"v9.0.0","html_url":"https://github.com/zhongguozhang/Clothesline/releases/tag/v9.0.0","draft":true,"prerelease":false},
      {"tag_name":"v8.0.0","html_url":"https://example.com/evil","draft":false,"prerelease":false}
    ]
    """.utf8)
    let candidate = try ReleaseSelection.newest(in: releases, current: AppVersion("0.1.0-rc.3")!)
    precondition(candidate?.tag_name == "v5.0.0-beta.1")
    precondition(AppVersion("0.1.0-rc.10")! > AppVersion("0.1.0-rc.3")!)
    let stable = try ReleaseSelection.newest(in: releases, current: AppVersion("0.1.0")!)
    precondition(stable?.tag_name == "v0.0.9", "stable builds must not offer prereleases")
    let empty = try ReleaseSelection.newest(in: Data("[]".utf8), current: AppVersion("0.1.0")!)
    precondition(empty == nil)
    do { _ = try ReleaseSelection.newest(in: Data("oops".utf8), current: AppVersion("0.1.0")!); preconditionFailure() } catch {}

    let delegate = AppDelegate()
    let menu = NSMenu()
    AppLanguage.current = .english
    delegate.menuNeedsUpdate(menu)
    precondition(menu.items.contains { $0.title == "Launch at Login" })
    precondition(menu.items.contains { $0.title == "Check for Updates…" })
    precondition(menu.items.contains { $0.title == "About Clothesline…" })
    precondition(!menu.items.contains { $0.title == "Settings…" })
    let autoHideIndex = menu.items.firstIndex { $0.title == "Auto-hide Clothesline" }!
    precondition(menu.items[autoHideIndex + 1].title == "Hover to Show Clothesline Delay…")
    let countIndex = menu.items.firstIndex { $0.title == "Items to Keep" }!
    precondition(menu.items[countIndex + 1].title == "Item Retention Time…")
    let clipboard = menu.items.first { $0.title == "Clipboard" }!.submenu!
    precondition(clipboard.items.filter { !$0.isSeparatorItem }.count == 3)
    let languages = menu.items.first { $0.title == "Language / 语言" }!.submenu!
    let chinese = languages.items.first { $0.title == "简体中文" }!
    _ = chinese.target?.perform(chinese.action, with: chinese)
    precondition(AppLanguage.current == .chinese, "menu action switches language")
    delegate.menuNeedsUpdate(menu)
    precondition(menu.items.contains { $0.title == "检查更新…" })
    precondition(!menu.items.contains { $0.title == "设置…" })
    precondition(menu.items[menu.items.firstIndex { $0.title == "自动隐藏晾衣绳" }! + 1].title == "悬停显示晾衣绳延迟…")
    precondition(menu.items[menu.items.firstIndex { $0.title == "保留文件数量" }! + 1].title == "保留文件时间…")
    precondition(ClosureMenuItem("快速预览", action: {}).title == "快速预览")
    AppLanguage.current = .english
    precondition(UserDefaults.standard.string(forKey: "menuLanguage") == "en")
    precondition(ClosureMenuItem("快速预览", action: {}).title == "Quick Look")
    print("PASS: login service transitions/errors, release ordering/filtering, bilingual menu actions and persistence")
}
