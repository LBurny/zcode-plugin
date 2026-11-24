# no-taskbar-dot

Windows only. Removes the unread red dot that ZCode paints on its taskbar icon, and puts it back on demand.

```text
/taskbar-dot            # stop drawing the red dot
/taskbar-dot status     # is the patch in place?
/taskbar-dot restore    # stock behavior
```

It patches `app.asar` in place (7 bytes, same length); restart ZCode afterwards. An app update reverts it, and `restore` undoes it at any time.

Why a patch: `setOverlayIcon` is restricted to the window's owning process, so no external watcher can clear the dot. Details in the [repo README](../../README.md) or [中文](../../README.zh.md).
