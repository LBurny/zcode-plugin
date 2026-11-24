# zcode-plugin

[English](README.md) | 中文

[ZCode](https://github.com/zai-org/ZCode) 的小插件集合。

| 插件 | 作用 | 命令 |
| ---- | ---- | ---- |
| [`no-taskbar-dot`](plugins/no-taskbar-dot) | 让 ZCode 不再在 Windows 任务栏图标上画未读红点 | `/taskbar-dot` |

## 安装

**插件市场 → 添加 → 添加插件市场**，粘贴 `https://github.com/LBurny/zcode-plugin`，然后在 **个人 → zcode-plugin** 里安装 **任务栏红点开关**。本地仓库安装时，把仓库根目录作为市场来源填进去。

## 用法

```text
/taskbar-dot            # 不再画红点
/taskbar-dot status     # 补丁是否在位
/taskbar-dot restore    # 回到官方行为
```

## 原理

红点由主进程 `BrowserWindow.setOverlayIcon()` 绘制。Shell 只接受窗口所属进程的调用（其他进程返回 `E_FAIL`），应用也没有开关，所以插件改 `app.asar` 里的一个字面量：

```js
function cV(e){return e==="win32"}   // 改前
function cV(e){return e==="never"}   // 改后
```

7 个字节、等长替换：asar 头部、偏移和文件大小都不变，且该构建关闭了 asar 完整性校验。锚点缺失或有多个候选时，脚本会中止且不写入。

## 注意

- `apply` 后要重启 ZCode。
- 应用更新会还原 `app.asar`，重新执行 `apply` 即可。
- 卸载插件前先 `restore`。
- 仅 Windows，已在 ZCode 4.0.0（`4.0.0.10870`）验证。

## 许可

MIT
