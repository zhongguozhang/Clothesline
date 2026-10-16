# 最新交接：README 功能介绍整合

2026-10-15。按用户要求，README.md 的“新增工作流（源码开发版）”和“功能（V0.1）”去重整理为单一“功能介绍”，英文页合并为 Features。删除中文“macOS 构建与运行”和英文 Build from source 章节及残留构建命令；保留统一下载、视频、应用菜单、操作速查与许可。顺带修正旧限制列表对开机启动/英文界面的过时描述。

本轮仅文档改动。验证：双语功能覆盖与章节顺序审查、git diff --check；scripts/build-app.sh release（含核心测试）按项目约定执行。无需重复 macOS UI 或 Windows 安装回归，未声称 UI 实测。

下一步：提交、推送 main，并核对远端 SHA；已有候选安装包不重新发行，平台 UI 待验收项仍见 PROJECT_STATE.md。

同步记录：正文提交 86a644f；fetch 超时，推送两次（35/30 秒）超时。继续重试并核对远端；不能仅依据本地提交宣称 GitHub 页面已更新。

同步恢复：官方 Git 数据 API 已逐项匹配本地 blob、tree、commit SHA，原样传输 86a644f、189b315，再以 force=false 快进 main；核验远端 189b315。本地 origin/main 跟踪引用已更新。后续普通 Git 超时可采用同样的严格 SHA 匹配流程；若对象 SHA 不同或远端分叉，必须停止更新分支。

平台范围提示已同步改为“功能与操作说明”，不再提及已删除的构建章节。

# 最新交接：复制文件名与完整路径

2026-10-16，分支 feat/copy-file-name-path，基于上游 main 的 d48feca。

文件及文件夹卡片右键新增“复制文件名”和“复制完整路径”。名称保留扩展名，路径为标准绝对路径纯文本，沿用复制反馈与自身剪贴板标记；剪贴板图片/便签菜单保持内容复制。

验证通过：scripts/test-core.sh、scripts/test-macos.sh、scripts/build-app.sh release native；git diff --check。覆盖独立剪贴板验证文件/文件夹、中文、空格、特殊字符、扩展名、绝对路径纯文本及自身复制回流抑制。未声称真实跨应用粘贴 UI 已验收。

构建验证为 Apple Silicon 原生 Release。Universal 打包的 Swift 6.4 兼容修复另留在本地开发分支，不混入本功能。既有编译/粘贴板/CoreDrag 诊断仍出现。

下一步：人工验收平台交互，确认 PR 草稿后再创建 PR。此分支不依赖其他功能分支，未更新系统安装应用或远端发行资产。
