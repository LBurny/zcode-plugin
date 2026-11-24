# zcode-plugin

[English](README.md) | 中文

[ZCode](https://github.com/zai-org/ZCode) 的小插件集合。`plugins/` 下一个目录一个插件，通过市场目录分发，不需要额外装应用，也没有常驻后台进程。

## 有什么

| 插件 | 作用 | 命令 |
| ---- | ---- | ---- |
| `no-taskbar-dot` | 让 ZCode 不再在 Windows 任务栏图标上画未读红点，也可以随时恢复 | `/taskbar-dot` |

目前只有一个插件。市场目录已经按多插件组织：在 `plugins/<name>/` 下加目录，再在 `.claude-plugin/marketplace.json` 里加一条条目即可。

## 安装

在 ZCode 桌面端打开 **插件市场 → 添加 → 添加插件市场**，粘贴 `https://github.com/LBurny/zcode-plugin` 并确认。然后在 **个人 → zcode-plugin → 任务栏红点开关 → 安装**。命令会以 `/taskbar-dot` 出现。

从本地仓库安装时，把仓库根目录（含 `.claude-plugin/marketplace.json` 的那一层）作为市场来源填进去，不用填 URL。

## no-taskbar-dot

仅 Windows。

```text
/taskbar-dot            # 等同 apply：不再画红点
/taskbar-dot status     # 查看补丁是否在位
/taskbar-dot restore    # 回到官方行为，红点回来
```

`apply` 之后要完全退出 ZCode 再打开才生效。

### 为什么要改 `app.asar`

红点不是应用内元素。桌面端主进程用 `BrowserWindow.setOverlayIcon()` 绘制，底层走 Shell 的 `ITaskbarList3::SetOverlayIcon`。在 Windows 10 上实测：

- 对别的进程的窗口调用 `SetOverlayIcon` 返回 `E_FAIL`（`0x80004005`），对自己的窗口调用同样的接口返回 `S_OK`。Shell 只允许窗口所属进程管理自己的 overlay，所以外部写一个"轮询清除"的后台程序行不通。
- ZCode 4.0.0 没有任何关闭角标的设置项，插件也够不到主进程：技能、命令、MCP 服务、UI 插件都跑在渲染层或独立进程里。

唯一的可靠做法是让应用自己不画。`app.asar` 里是这段压缩代码：

```js
function cV(e){return e==="win32"}i(cV,"supportsWindowOverlayBadge");
```

脚本原地替换平台字面量：

```js
function cV(e){return e==="never"}i(cV,"supportsWindowOverlayBadge");
```

共 7 个字节，等长替换，所以 asar 头部、文件偏移和文件大小都不变。这个 Electron 构建的 `EnableEmbeddedAsarIntegrityValidation` 是关闭的（fuse 串 `101000011`，第 5 位），改过的 `app.asar` 照常加载。之后 Windows 分支永不成立，不再设置 overlay；macOS / Linux 的 `setBadgeCount` 分支不受影响，应用内未读蓝点、声音提醒和系统通知也都不变。

### 脚本不会做什么

它用唯一锚点（`,"supportsWindowOverlayBadge")`）定位补丁点，要求只有一个候选，校验周边代码形态（`e==="win32"`），写入后再读回文件复核。锚点找不到、出现多个、代码形态不符或写入后复核不一致，都会直接中止且不改动文件。

### 注意

- **必须重启 ZCode。** 运行中的主进程用的是启动时加载的代码。
- **自动更新会覆盖补丁。** 更新会替换 `app.asar`，更新后重新执行 `/taskbar-dot apply`。如果脚本报"找不到锚点"，说明新版本的打包结构变了，要按新版本重新定位补丁点，别硬改。
- **卸载插件前先 restore**，否则补丁会留着。卸载插件本身不会还原补丁。
- 补丁点与版本绑定。已在 Windows 10 22H2 + ZCode 4.0.0（`4.0.0.10870`）上验证。

## 目录

```text
.claude-plugin/marketplace.json   ZCode 从 GitHub 或本地目录读取的市场目录
plugins/no-taskbar-dot/
  .zcode-plugin/plugin.json       插件清单
  commands/taskbar-dot.md         /taskbar-dot
  scripts/taskbar-dot.ps1         status / apply / restore（PowerShell 5.1+，无需管理员权限）
  README.md
```

## 许可

MIT
