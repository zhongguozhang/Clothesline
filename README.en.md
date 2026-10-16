# <img src="assets/clothesline-icon.png" alt="Clothesline icon" width="48" height="48"> Clothesline

**English** · [简体中文](README.md)

**Keep downloaded files at the top of your screen for quick access.**

Clothesline is a native file utility for macOS and Windows that presents recent files and folders as cards on a clothesline at the top of your screen, ready to preview, open, drag, and manage.

It watches Downloads by default. Add more watched folders or hang frequently used folders as shortcuts. Choose automatic hiding or keep the clothesline visible. Removing a card only hides its shortcut; macOS also offers a separate, confirmed Move to Trash action. Everything runs locally, without an account or cloud service.

## Demo

A 36-second recording showing file cards and colorful clothespins. The rc.3 universal candidate includes the colorful clothespins and subsequent updates.

https://github.com/user-attachments/assets/aab83014-934a-43c0-bc72-8055df02e67b

[Download the demo (MP4, about 4 MB)](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.1/Clothesline-demo.mp4)

## Download and install

| System | Package | Requirements | Release notes and checksums |
|---|---|---|---|
| macOS · rc.3 | [Universal DMG](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.3/Clothesline-0.1.0-rc.3-universal.dmg) | macOS 14+, Intel / Apple Silicon | [Release and SHA-256](https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.3) |
| Windows · rc.1 | [Setup](https://github.com/zhongguozhang/Clothesline/releases/download/windows-v0.1.0-rc.1/Clothesline-0.1.0-windows-rc.1-x64-Setup.exe) · [Portable ZIP](https://github.com/zhongguozhang/Clothesline/releases/download/windows-v0.1.0-rc.1/Clothesline-0.1.0-windows-rc.1-x64-portable.zip) | Windows 10 1809+ / 11, x64 (Intel/AMD) | [Release and SHA-256](https://github.com/zhongguozhang/Clothesline/releases/tag/windows-v0.1.0-rc.1) |

- **macOS**: Open the DMG, drag Clothesline.app into Applications, and launch it. One Universal package includes native Intel and Apple Silicon code.
- **Windows**: Run Setup, or extract the entire portable ZIP and run Clothesline.exe. The runtime is included. Find the tray icon and move the pointer to the top of the primary work area. See the [Windows guide](windows/README.en.md).

These are candidate packages: macOS is ad-hoc signed and not notarized; Windows is not code-signed. Verify the download source and follow the system's first-launch prompts.

The detailed features and usage instructions below primarily describe macOS; see the Windows guide for platform differences. Choose **Language / 语言 → English** in the app menu for English menus.

## Features

- **Copy names and paths (macOS source build)**: Right-click a file or folder to copy its name (including extension) or full absolute path as plain text. Copy feedback is preserved, and owned copies do not feed back into clipboard notes.
- **Watch downloads**: Watch Downloads and multiple added folders, showing recent files and top-level folders. Watched folders persist across restarts; polling covers missed events and wake from sleep.
- **Detect completed downloads**: Filter hidden files, symbolic links, and temporary items such as `.crdownload`, `.download`, `.part`, and `.tmp`. Display files after two stable scans, at least two seconds without changes, and no companion temporary download.
- **Hang files and folders**: Drag one or multiple items from Finder or select them from the menu. Store persistent references while originals stay in place.
- **Preview and open**: Show document, image, and video thumbnails, with system icons for other types. Click for Quick Look, double-click to open in the default app, and open folders in Finder.
- **Drag files out**: Provide real files to other apps or Finder with copy-only effects. Originals stay in place. Right-click to copy or reveal in Finder.
- **Pin frequent items**: Pin individual files or folders so new arrivals cannot displace them. Pins survive restarts; overflow can be scrolled. Taking an item down unpins it; clearing unpins all.
- **Identify files clearly**: Hover for about 0.4 seconds to see the full name, source folder, size, and creation/modification dates. Folder contents are not counted recursively. Unavailable cards retain last-known metadata and recover when accessible again.
- **Rename quickly**: Rename the original file while keeping its extension. Reject collisions and stale metadata without overwriting another file.
- **Recent files drawer**: Search up to 200 recent file references, hang them again, or drag them out. Missing or inaccessible originals are omitted.
- **Clipboard images and text**: Independent switches, both off by default, accept new copies only. Notes support preview, editing, copying, and Save As; images support preview, copying, and Save As. Deduplicate content and suppress the app's own copies. Saved screenshots use ordinary folder watching.
- **Session content management**: Clipboard copies stay within the current session and out of persistent recent records. Quitting or clearing removes only owned copies, preserving exported files; crashes may leave temporary copies. Limits: 100 items per session, image inputs up to 32 MB, and text up to 200 KB. Enable intake as needed.
- **System sharing**: Right-click → Share opens the macOS share picker. AirDrop, Mail, and other services depend on the system and installed apps.
- **Safe removal**: Taking cards down, clearing, or quitting does not delete, move, or overwrite originals. Only a separately confirmed Move to Trash action moves files or folders and their contents; restore them in Finder. Reset hidden records to show removed files again; replacing a download also allows it to reappear.
- **Flexible display**: Alternating colorful clothespins and spring animations, automatic hiding or always-visible mode, adjustable item counts and card size, and saved preferences. Use `⌃⌥T` to toggle visibility.

## Quick reference

| Action | Result |
|---|---|
| Hover at the top of the screen / menu bar | Show the clothesline |
| Move the pointer away | Hide it in automatic mode |
| Click a file | Quick Look preview |
| Double-click | Open with the default app; folders open in Finder |
| Drag to an app or Finder | Offer the real file for copying |
| Right-click | Preview, open, reveal, copy, remove, or move to Trash |
| Move to Trash | After confirmation, move the original item and any folder contents to macOS Trash |
| × / remove / clear | Hide cards; preserve original files |
| Add watched folder (添加监控文件夹…) | Add folders while existing watchers continue |
| Hang folder (挂上文件夹…) | Add folder shortcuts without moving them |
| Always visible / auto-hide | Save the display preference |
| Show removed files again | Clear hidden-item records |
| `⌃⌥T` | Toggle pinned visibility |

## Safety and limitations

- Removing cards, clearing the clothesline, or quitting does not delete, move, or overwrite original files. Only the separately confirmed Trash action moves originals. No permanent deletion is provided; folders move with all their contents.
- Download completion is heuristic. A download paused for more than two seconds under its final filename without a companion temporary file may appear early.
- Watching is limited to top-level items and does not recursively monitor folder contents. Folder stability does not guarantee every contained file has finished writing.
- Preferences, folder bookmarks, and hidden-item records are stored locally. The app connects to GitHub only when you choose Check for Updates; files and clipboard content are never uploaded. There is no telemetry, account, or screenshot capture. Clipboard content is read only for explicitly enabled types.
- Integration tests verify real directory events, file URLs, safe removal, Trash recovery, multiple watchers, bookmark restoration, and drag payloads. Actual receiving-app drag behavior, full UI interactions, browser downloads, permission denial, sleep, multiple displays, and macOS 14 compatibility still require manual acceptance.
- Developer ID notarization, automatic installation of updates, and full accessibility are not included.

## Copyright and origin

Tendedero source code is published under MIT by Alejandro Buján. Clothesline adapts its clothesline structure, floating interactions, animation, and card design ideas. See the [upstream license](https://github.com/alejandrobujan/tendedero/blob/main/LICENSE). The upstream name, icon, and documentation images are not used. Clothesline has an independent name and icon; the full license and original copyright notice are retained in [LICENSE](LICENSE), including inside the app bundle.

## Ongoing development

Development follows [AGENTS.md](AGENTS.md). Each iteration updates [PROJECT_STATE.md](PROJECT_STATE.md), [HANDOFF_LATEST.md](HANDOFF_LATEST.md), and [CHANGELOG.md](CHANGELOG.md). Verified changes are committed and pushed to this public repository without force-pushing. See [ROADMAP.md](ROADMAP.md) for pending acceptance work.

## Application Menu

- **Launch at Login** toggles the macOS login item and shows its actual status. If approval is needed, use the System Settings entry. Install in Applications before enabling it.
- **Check for Updates…** checks published GitHub versions only when clicked and opens the release page if a newer version exists. It does not install updates. Candidate builds include candidate and stable releases; stable builds include stable releases only.
- **About Clothesline…** shows the version, repository, and bundled MIT license.
- **Language / 语言** switches Simplified Chinese and English menus, card context menus, and recent files UI, preserving the choice across launches.

The rc.3 universal candidate is `0.1.0-rc.3` (build 3) and includes these additions.
