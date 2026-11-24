# zcode-plugin

English | [中文](README.zh.md)

Small plugins for [ZCode](https://github.com/zai-org/ZCode).

| Plugin | What it does | Command |
| ------ | ------------ | ------- |
| [`no-taskbar-dot`](plugins/no-taskbar-dot) | Stops ZCode from painting the unread red dot on its Windows taskbar icon | `/taskbar-dot` |

## Install

**Plugin Marketplace → Add → Add plugin marketplace**, paste `https://github.com/LBurny/zcode-plugin`, then install **No Taskbar Dot** under **Personal → zcode-plugin**. For a local checkout, use the repository root as the source instead of the URL.

## Usage

```text
/taskbar-dot            # stop drawing the red dot
/taskbar-dot status     # is the patch in place?
/taskbar-dot restore    # stock behavior
```

## How it works

The dot is drawn by the main process through `BrowserWindow.setOverlayIcon()`. The Shell only accepts that call from the window's owning process — other processes get `E_FAIL` — and ZCode has no setting for it, so the plugin flips one literal in `app.asar`:

```js
function cV(e){return e==="win32"}   // before
function cV(e){return e==="never"}   // after
```

Seven bytes, same length: the asar header, offsets and file size stay unchanged, and the shipped build has asar integrity validation disabled. The script fails closed when the anchor is missing or ambiguous.

## Notes

- Restart ZCode after `apply`.
- An app update restores `app.asar`; run `apply` again.
- Run `restore` before uninstalling the plugin.
- Windows only. Verified on ZCode 4.0.0 (`4.0.0.10870`).

## License

MIT
