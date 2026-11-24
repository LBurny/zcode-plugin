# no-taskbar-dot

Stops ZCode from painting the unread red dot on its Windows taskbar icon. Part of the [zcode-plugin](../..) marketplace; see the [Chinese README](../../README.zh.md) for the same content in Chinese.

```text
/taskbar-dot            # same as apply
/taskbar-dot status     # is the patch in place?
/taskbar-dot restore    # stock behavior
```

## How it works

The dot comes from the desktop main process calling `BrowserWindow.setOverlayIcon()`, which reaches the Shell's `ITaskbarList3::SetOverlayIcon`. That call is restricted to the window's owning process — from another process it returns `E_FAIL` — and ZCode has no setting for it, so the only reliable fix is to stop the app from drawing it.

`scripts/taskbar-dot.ps1` flips one literal in `app.asar`:

```js
function cV(e){return e==="win32"}   // before
function cV(e){return e==="never"}   // after
```

Seven bytes, same length, so the asar header, its offsets and the file size are unchanged. The shipped build has asar integrity validation disabled, so the file still loads.

## Safety

- Locates the patch point by a unique anchor, requires a single candidate, checks the surrounding code shape, and verifies the result after writing.
- Aborts without modifying anything when the anchor is missing, ambiguous, or the shape changed.
- Writes the file in place; no admin rights needed for a per-user install.

## Limitations

- Windows only.
- Restart ZCode after `apply`.
- An app update replaces `app.asar` and the dot returns; run `apply` again.
- Restore before uninstalling the plugin; uninstalling does not undo the patch.
- The patch point is tied to ZCode 4.0.0 (`4.0.0.10870`).

## Files

```text
.zcode-plugin/plugin.json   manifest
commands/taskbar-dot.md     slash command
scripts/taskbar-dot.ps1     status / apply / restore
```
