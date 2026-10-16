# <img src="assets/clothesline-icon.png" alt="Clothesline 图标" width="48" height="48"> Clothesline · 晾衣绳

[English](README.en.md) · **简体中文**

**把下载文件挂在屏幕顶部，随手预览、拖拽与使用。**

Clothesline（晾衣绳）提供 macOS 和 Windows 原生版本，将最近下载或新增的文件与目录，以卡片形式挂在屏幕顶部，方便随手预览、打开、拖拽和管理。

默认监控 Downloads，也可添加多个监控文件夹，或手动挂上常用目录。晾衣绳支持自动隐藏与一直显示；取下卡片只隐藏入口，macOS 另提供独立确认的“移到废纸篓”操作。所有功能在本机运行，无需账号或云端服务。

## 使用演示

下面是约 36 秒的实际使用录屏，展示晾衣绳的文件卡片与彩色夹子。

https://github.com/user-attachments/assets/aab83014-934a-43c0-bc72-8055df02e67b

**[下载演示视频（MP4，约 4 MB）](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.1/Clothesline-demo.mp4)**

rc.3 通用候选安装包包含录屏中的彩色夹子和后续功能更新。

## 下载安装

| 系统 | 安装包 | 系统要求 | 发行说明与校验 |
|---|---|---|---|
| macOS · rc.3 | [通用 DMG](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.3/Clothesline-0.1.0-rc.3-universal.dmg) | macOS 14+，Intel / Apple Silicon | [版本与 SHA-256](https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.3) |
| Windows · rc.1 | [安装程序](https://github.com/zhongguozhang/Clothesline/releases/download/windows-v0.1.0-rc.1/Clothesline-0.1.0-windows-rc.1-x64-Setup.exe) · [便携 ZIP](https://github.com/zhongguozhang/Clothesline/releases/download/windows-v0.1.0-rc.1/Clothesline-0.1.0-windows-rc.1-x64-portable.zip) | Windows 10 1809+ / 11，x64（Intel、AMD） | [版本与 SHA-256](https://github.com/zhongguozhang/Clothesline/releases/tag/windows-v0.1.0-rc.1) |

- **macOS**：打开 DMG，将 Clothesline.app 拖入 Applications，再打开应用。通用包包含 Intel 与 Apple Silicon 两种原生架构。
- **Windows**：运行安装程序，或完整解压便携 ZIP 后运行 Clothesline.exe，无需另装 .NET。在任务栏通知区域找到图标，鼠标移至主屏工作区域顶部展开；详情见 [Windows 使用说明](windows/README.md)。

当前均为候选安装包：macOS 尚未 Developer ID 签名/Apple 公证，Windows 尚未代码签名。首次打开时请核对下载来源，并按系统提示操作。

以下详细功能与操作说明主要针对 macOS；Windows 功能差异见上方使用说明。

## 功能介绍

- **自动监控下载**：默认监听 `~/Downloads`，可添加多个监控文件夹，启动后显示近期文件与顶层目录；监控列表重启后保留，轮询兜底处理事件丢失和睡眠唤醒。
- **下载完成检测**：过滤隐藏文件、符号链接及 `.crdownload`、`.download`、`.part`、`.tmp` 等临时项目。文件连续两次扫描大小和修改时间不变、静默至少 2 秒且无对应临时下载文件后，才挂上晾衣绳。
- **手动挂载文件与文件夹**：从 Finder 拖入一个或多个文件、文件夹，或通过菜单选择挂载；只保存快捷入口，原文件保持原位置，入口重启后保留。
- **预览与打开**：生成 PDF、图片、视频缩略图，其他类型使用系统图标；单击 Quick Look 预览，双击用默认应用打开，文件夹在 Finder 中打开。
- **拖出使用**：将卡片上的真实文件拖入其他 App 或 Finder，默认只提供复制操作，不移动源文件；也可右键复制文件或在 Finder 中定位。
- **固定常用项目**：右键固定单个文件或文件夹，新挂载不会将它挤走，重启后恢复。超过屏幕容量可滚动查看；取下取消该项固定，清空取消全部固定。
- **完整文件身份**：悬停约 0.4 秒显示完整名称、来源目录、大小和创建/修改时间。文件夹不递归统计大小；失效项目标红并保留最后信息，恢复访问后自动恢复。
- **快速重命名**：在卡片上修改原文件名称，保留文件扩展名；同名冲突或文件已变化时提示，不覆盖其他文件。
- **最近文件抽屉**：从绳上或菜单打开，按名称搜索最多 200 个近期文件入口，支持重新挂上和拖出；无法访问的源文件不显示。
- **剪贴板图片与文字**：图片 / 截图、文字便签分别开关，默认关闭，只接入开启后新复制的内容。文字可预览、编辑、复制、另存为；图片可预览、复制、另存为。相同内容不重复挂载，应用自己的复制不会自动回流。已保存的截图仍按普通监控文件处理。
- **会话内容管理**：剪贴板副本仅在本次会话内保存，不加入持久最近文件记录；退出或清空只清理自建副本，用户另存文件不受影响。异常退出可能遗留临时副本。每会话最多 100 条，图片输入 32 MB、文字 200 KB 以内，请按需开启。
- **系统分享**：卡片右键“分享…”进入 macOS 分享菜单，AirDrop、邮件等可用服务由系统及已安装应用决定。
- **安全取下与删除**：`×`、取下、清空和退出只改变展示状态，不删除、移动或覆盖原文件。只有明确选择并确认“移到废纸篓”才移动原文件或文件夹及其内容，可从 Finder 废纸篓恢复；重新显示已取下文件可清除隐藏记录，重新下载替换文件也会再次显示。
- **灵活展示**：六色衣夹交替搭配弹簧动画；可选择自动隐藏或一直显示，设置文件数量与卡片尺寸，偏好重启后保留。`⌃⌥T` 快速切换显示方式。

- **悬停显示晾衣绳延迟（macOS 源码开发版）**：在“自动隐藏晾衣绳”下方打开独立修改页。默认 0.0 秒，范围 0.0–10.0 秒，精度 0.1 秒；移开后重新计时，文件、文件夹和剪贴板图片/便签均适用。
- **保留文件时间（macOS 源码开发版）**：在“保留文件数量”下方打开独立修改页，统一设置监控文件、文件夹和剪贴板内容的保留时长，默认永不过期。到期只隐藏，原文件和系统剪贴板不变，固定及手动文件保留；空绳不因普通悬停展开。

## 应用菜单

- **开机启动**：菜单勾选开启，再点取消；状态读取 macOS 登录项。若系统要求批准，菜单提供系统设置入口。建议将应用放入“应用程序”后设置。
- **检查更新…**：仅点击时连接 GitHub 查询发布版本；有新版时前往发布页下载，不会自动安装。候选版可检查后续候选版和正式版，正式版只提示正式版。
- **关于 Clothesline…**：查看版本、项目主页和随应用携带的 MIT 许可。
- **语言 / Language**：切换简体中文、English，选择保留到下次启动。菜单、卡片右键菜单和近期文件界面随之切换；系统窗口及错误信息可能遵循系统语言。

rc.3 通用候选包为 `0.1.0-rc.3`（build 3），包含上述新菜单。

## 操作速查

| 操作 | 结果 |
|---|---|
| 鼠标移到菜单栏 / 屏幕顶部 | 显示晾衣绳 |
| 鼠标离开晾衣绳 | 自动收起 |
| 单击文件 | Quick Look 预览 |
| 双击文件 | 默认应用打开 |
| 拖拽到 App/Finder | 复制真实文件链接所指的内容（由目标处理） |
| 右键 | 快速预览、打开、显示于 Finder、复制、取下、移到废纸篓 |
| 右键 → 移到废纸篓… | 确认后将原文件或目录及内容移到废纸篓 |
| 菜单栏 → 挂上文件夹… | 选择一个或多个目录挂上，原位置不变 |
| 菜单栏 → 一直显示 / 自动隐藏 | 设置显示方式并记住选择 |
| 左上角 × | 仅隐藏卡片，源文件不变 |
| 菜单栏 → 清空 | 隐藏当前项目，不删除任何文件 |
| 菜单栏 → 重新显示已取下的文件 | 清除隐藏记录，重新展示最近文件 |
| ⌃⌥T | 切换固定显示 |

## 目录

```text
Clothesline/
├── Package.swift
├── Sources/Clothesline/
│   ├── main.swift, AppDelegate.swift
│   ├── DownloadsWatcher.swift     # vnode 事件 + 扫描 + 唤醒
│   ├── DownloadIndex.swift       # 下载文件过滤、完成度确认（可在 Linux 单测）
│   ├── Line.swift                # 文件列表、隐藏状态、真实文件操作、缩略图
│   ├── LinePanel.swift, LineView.swift, PeggedView.swift
│   ├── GrabArea.swift, QuickLook.swift, HotKey.swift
├── Tests/DownloadIndexTests.swift
├── scripts/test-core.sh
├── scripts/build-app.sh
└── assets/clothesline-icon.png  # 独立设计的图标
```

## 设计原则与限制

1. **取下与删除分开。** ×、取下、清空和退出不改变源文件；独立的“移到废纸篓…”命令在确认后调用 macOS 废纸篓，失败会提示。不会永久删除。目录移到废纸篓包含全部内容。
2. **不声称能百分之百识别下载完成。** 文件稳定检测 + 临时扩展名过滤足以覆盖常见浏览器流程，但极端情况下下载暂停超过 2 秒、文件先生成最终名称且没有临时伴随文件，仍有提前显示的可能。V0.2 可考虑扩展浏览器下载元数据、xattr 和更细粒度持续写入状态检测。
3. **本地访问。** 仅手动检查更新时连接 GitHub 获取发布信息；文件与剪贴板内容不上传，无遥测、无账户。监控目录选择、手动目录书签、显示方式及隐藏状态保存在本地 `UserDefaults`。
4. **单层监控。** 自动扫描顶层文件与目录，不递归。目录使用系统图标，双击在 Finder 打开；手动挂上的目录通过普通书签保存，当前适用于非沙盒本地版本。临时下载目录和符号链接不挂上。
5. **非破坏性拖出。** V0.1 源仅通告 `.copy`；如果想从 Downloads 移动到其他文件夹，需要使用 Finder 完成移动。未来可以考虑经确认的移动模式。
6. **可验收，不夸大。** 已在 macOS 构建启动并测试真实目录监听、真实 URL 卡片及非破坏性取下。运行应用已识别 Downloads 新文件。浏览器下载、完整 UI 交互、多屏和权限拒绝仍待验收。
7. **未包含**：Apple 公证、自动安装更新、高级全屏隐藏策略、完整无障碍 / VoiceOver。这些属于后续版本。

## 后续 macOS 验收清单

- [ ] Mac 源码构建成功，打开后菜单栏可见 Clothesline T 恤图标。
- [ ] 选择 Downloads 后自动显示最近文件（约 2 秒稳定扫描）。
- [ ] Chrome 下载 PDF/ZIP 时 `.crdownload` 不出现，完成后出现。
- [ ] Safari `.download` 包未出现，完成后出现。
- [ ] PDF 第一页、图片缩略图，以及 ZIP/DMG 系统图标正常。
- [ ] Quick Look、双击打开、拖拽复制、Finder 定位可用。
- [ ] 点击 `×`、清空以及卡片自动退出不影响原文件。
- [ ] 睡眠唤醒、多屏、屏幕缩放、不同 macOS 版本验证。
- [ ] 用户取消 Downloads 权限时错误提示与重新授权路径清楚。

## 版权与来源

Tendedero 源码由 Alejandro Buján 按 MIT 发布；本项目借鉴并改写其晾衣绳结构、悬浮交互、动画与卡片设计思想。参见 [原项目许可证](https://github.com/alejandrobujan/tendedero/blob/main/LICENSE)。Tendedero 的名称、图标和文档配图不在其 MIT 授权范围内，本项目没有使用。Clothesline 为独立项目；完整许可见 `LICENSE`。

## 持续开发

遵循 AGENTS.md，每轮更新 PROJECT_STATE.md、HANDOFF_LATEST.md、CHANGELOG.md 并提交 Git。运行 scripts/test-core.sh、scripts/test-macos.sh 和 scripts/build-app.sh release。GitHub 公开仓库：https://github.com/zhongguozhang/Clothesline。每轮验证、更新交接、提交后推送；开始工作先检查远端变化，禁止强制推送。

DMG 重建：`scripts/build-dmg.sh`（默认 Universal，支持 Intel / Apple Silicon；可选参数 `native`、`arm64` 或 `x86_64`）。
