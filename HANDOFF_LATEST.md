# 最新交接：菜单栏图标

2026-11-03（Asia/Shanghai）。菜单栏改用独立 20×18 pt AppKit 矢量模板图标：去除底板、渐变与阴影，放大 T 恤轮廓并保留绳与夹子；isTemplate 由系统适配明暗及选中状态。彩色应用图标、安装包图标和 README 图片不变。

新增 MenuBarIcon.swift，AppDelegate 不再将完整 icns 缩为菜单栏图标。起始 git fetch 成功，本地与 origin/main 无分叉。

下一步：验收浅色/深色菜单栏与菜单选中效果；本轮不发行新 DMG。

本轮验证：scripts/test-core.sh、scripts/test-macos.sh、scripts/build-app.sh release 均通过，包含 arm64/x86_64。既有粘贴板/CoreDrag/颜色空间诊断未导致失败。未将集成回归视作 UI 实测。
