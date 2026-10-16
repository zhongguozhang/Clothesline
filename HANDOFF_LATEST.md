# 最新交接：Mission Control 避让修复

2026-10-16。独立分支 `fix/mission-control-occlusion` 基于上游 `d48feca`，修复隐藏晾衣绳时拖文件到状态栏被完整 Mission Control 遮挡的问题。

- MissionControlAvoidance 解析系统进程窗口元数据，兼容本机 macOS 27 的 WindowManager 表面和 Dock 检测路径；LinePanel 下移并临时提升层级，退出后 0.6 秒复位，交互期间暂停。
- RopeVisibilityController 与 ExternalFileDragTracker 区分新文件拖拽、普通点击和隐藏面板区域；保持隐藏状态，不因动画结束重启显示宽限。
- common-mode 指针轮询配合右键菜单 onPressChange 保护源卡片；拖入结束回调清理交互状态。
- 核心/macOS 集成回归、arm64 Release 构建和严格签名通过。主动隐藏窗口回归、右键菜单源保护回归均记录过修复前失败、修复后通过。
- 使用命令：`scripts/test-macos.sh`、`scripts/build-app.sh release native`、`codesign --verify --strict build/Clothesline.app`。Universal 构建未在本独立分支重验。
- 实际 Finder 拖放与隐藏后空白点击退出由用户在开发版上验收；独立提取后仅运行自动测试和构建，未重新人工 UI 验收。
- 仅 macOS 27.0.1 实测，其他版本未测试，仅供参考，请谨慎合并。下一步验证其他系统版本、逐屏和跨屏拖放。
- 不包含现有时间设置 PR #2 或复制名称/路径 PR #3；时间设置与此 PR 修改同一指针轮询入口，合并时须检查冲突。未创建 Release。

## 前轮：README 功能介绍整合

2026-10-15。按用户要求，README.md 的“新增工作流（源码开发版）”和“功能（V0.1）”去重整理为单一“功能介绍”，英文页合并为 Features。删除中文“macOS 构建与运行”和英文 Build from source 章节及残留构建命令；保留统一下载、视频、应用菜单、操作速查与许可。顺带修正旧限制列表对开机启动/英文界面的过时描述。

本轮仅文档改动。验证：双语功能覆盖与章节顺序审查、git diff --check；scripts/build-app.sh release（含核心测试）按项目约定执行。无需重复 macOS UI 或 Windows 安装回归，未声称 UI 实测。

下一步：提交、推送 main，并核对远端 SHA；已有候选安装包不重新发行，平台 UI 待验收项仍见 PROJECT_STATE.md。

同步记录：正文提交 86a644f；fetch 超时，推送两次（35/30 秒）超时。继续重试并核对远端；不能仅依据本地提交宣称 GitHub 页面已更新。

同步恢复：官方 Git 数据 API 已逐项匹配本地 blob、tree、commit SHA，原样传输 86a644f、189b315，再以 force=false 快进 main；核验远端 189b315。本地 origin/main 跟踪引用已更新。后续普通 Git 超时可采用同样的严格 SHA 匹配流程；若对象 SHA 不同或远端分叉，必须停止更新分支。

平台范围提示已同步改为“功能与操作说明”，不再提及已删除的构建章节。
