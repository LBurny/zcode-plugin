---
description: 关闭或恢复 ZCode 桌面端在 Windows 任务栏图标上的未读红点
argument-hint: apply | restore | status
allowed-tools: Bash, Read
---

用户请求管理 ZCode 任务栏未读红点。

## 背景（已知事实）

- 红点由桌面端主进程 `BrowserWindow.setOverlayIcon()` 调用 Shell 的 `ITaskbarList3` 绘制，只有窗口所属进程能设置/清除；外部进程调用返回 `E_FAIL`，所以**不存在**外部轮询清除或"监听后清掉"的方案。
- 应用内没有关闭角标的设置项，也没有可截断该链路的 UI 插件 API。
- 因此本插件用原地补丁：把 `app.asar` 里 `supportsWindowOverlayBadge` 内的 `"win32"` 等长替换为 `"never"`（7 字节，文件大小与 asar 头部偏移不变），主进程之后不再设置 overlay。侧栏蓝点、通知等其他行为不受影响。

## 步骤

1. 把 `$ARGUMENTS` 归一化为动作：
   - 空、`apply`、`off`、`disable` → `apply`
   - `restore`、`revert`、`on`、`enable` → `restore`
   - `status`、`check` → `status`
   - 无法判断时先问用户，不要猜。

2. 定位插件的 `scripts/taskbar-dot.ps1`：
   - 若环境变量 `ZCODE_PLUGIN_ROOT` 或 `CLAUDE_PLUGIN_ROOT` 有值，用其值拼接；
   - 否则用 Bash 执行 `ls -dt "$HOME"/.zcode/cli/plugins/cache/*/no-taskbar-dot/*/ 2>/dev/null | head -1`，取最新目录；
   - 若仍找不到，报告实际执行的命令与输出，不要自行猜测路径。

3. 用 Bash 执行（把 `<plugin-root>` 换成上一步得到的绝对路径）：

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<plugin-root>/scripts/taskbar-dot.ps1" -Action <动作>
   ```

4. 把脚本输出原样转述给用户，并补充：
   - `apply` 后必须**完全退出并重新打开 ZCode** 才生效（已打开的窗口里主进程代码已加载）。
   - 应用自动更新会覆盖 `app.asar`，更新后红点会回来，重新 `/taskbar-dot apply` 即可。
   - 想恢复官方行为随时 `/taskbar-dot restore`。

## 约束

- 不要结束、重启用户的 ZCode 进程，也不要修改 `app.asar` 的其他字节。
- 不要用 `-AppPath` 猜测安装目录；只有脚本自动探测失败时，才把探测到的候选项列给用户并询问。
- 脚本报错时如实转述错误文本，不要声称已生效。
