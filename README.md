# zcode-plugin

English | [中文](README.zh.md)

Small plugins for [ZCode](https://github.com/zai-org/ZCode). One plugin per directory under `plugins/`, delivered through a marketplace catalog. Nothing here needs a separate app or a background process.

## What you get

| Plugin | What it does | Command |
| ------ | ------------ | ------- |
| `no-taskbar-dot` | Stops ZCode from painting the unread red dot on its Windows taskbar icon, and puts it back on demand | `/taskbar-dot` |

One plugin so far. The catalog is ready for more: add a directory under `plugins/<name>/` and one entry in `.claude-plugin/marketplace.json`.

## Install

In ZCode Desktop, open **Plugin Marketplace → Add → Add plugin marketplace**, paste `https://github.com/LBurny/zcode-plugin`, and confirm. Then pick **Personal → zcode-plugin → No Taskbar Dot → Install**. The command appears as `/taskbar-dot`.

From a local checkout, add the repository root — the directory that holds `.claude-plugin/marketplace.json` — as the marketplace source instead of the URL.

## no-taskbar-dot

Windows only.

```text
/taskbar-dot            # same as apply: stop drawing the red dot
/taskbar-dot status     # report whether the patch is in place
/taskbar-dot restore    # back to stock: the red dot returns
```

After `apply`, quit ZCode completely and start it again.

### Why it patches `app.asar`

The dot is not an in-app element. The desktop main process draws it with `BrowserWindow.setOverlayIcon()`, which goes through the Shell's `ITaskbarList3::SetOverlayIcon`. Measured on Windows 10:

- Calling `SetOverlayIcon` on a window owned by another process returns `E_FAIL` (`0x80004005`); the identical call on a window owned by the calling process returns `S_OK`. The Shell only lets the owning process manage a window's overlay, so no external watcher can clear it.
- ZCode 4.0.0 exposes no setting for the badge, and no plugin surface reaches the main process: skills, commands, MCP servers and UI plugins all run in the renderer or in separate processes.

The only reliable route is to stop the app from drawing it. `app.asar` ships this compiled code:

```js
function cV(e){return e==="win32"}i(cV,"supportsWindowOverlayBadge");
```

The script rewrites the platform literal in place:

```js
function cV(e){return e==="never"}i(cV,"supportsWindowOverlayBadge");
```

Seven bytes, same length, so the asar header, its file offsets and the file size stay identical. The shipped Electron build has `EnableEmbeddedAsarIntegrityValidation` turned off (fuse wire `101000011`, position 5), so the modified `app.asar` still loads. On Windows the badge branch is then never taken and no overlay is set. The macOS and Linux `setBadgeCount` branches are untouched, and so are in-app unread dots, sounds and notifications.

### What the script refuses to do

It finds the patch point through a unique anchor (`,"supportsWindowOverlayBadge")`), requires exactly one candidate, verifies the surrounding code shape (`e==="win32"`), and re-reads the file after writing. If the anchor is missing, appears more than once, the code shape changed, or the post-write check disagrees, it aborts without touching the file.

### Caveats

- **Restart ZCode.** A running main process keeps the code it loaded at startup.
- **Auto-update reverts the patch.** An update replaces `app.asar`; run `/taskbar-dot apply` again afterwards. If the script then reports a missing anchor, the bundle layout changed — re-locate the patch point for that version instead of forcing it.
- **Restore before uninstalling** the plugin if you want stock behavior back. Removing the plugin does not undo the patch.
- The patch point is version-specific. Verified against ZCode 4.0.0 (`4.0.0.10870`) on Windows 10 22H2.

## Layout

```text
.claude-plugin/marketplace.json   catalog ZCode reads from a GitHub or directory source
plugins/no-taskbar-dot/
  .zcode-plugin/plugin.json       plugin manifest
  commands/taskbar-dot.md         /taskbar-dot
  scripts/taskbar-dot.ps1         status / apply / restore (PowerShell 5.1+, no admin)
  README.md
```

## License

MIT
