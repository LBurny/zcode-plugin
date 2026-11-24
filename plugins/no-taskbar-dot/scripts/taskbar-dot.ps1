<#
.SYNOPSIS
    开关 ZCode 桌面端在 Windows 任务栏图标上的未读红点。

.DESCRIPTION
    红点来自 Electron 主进程 BrowserWindow.setOverlayIcon()（Shell 的 ITaskbarList3），
    该调用只允许窗口所属进程发起，外部进程调用会返回 E_FAIL，因此无法用外部轮询清除。
    本脚本改为原地修改 ZCode 自带的 app.asar：把 supportsWindowOverlayBadge 里
    "win32" 等长替换为 "never"，主进程之后不再设置 overlay。

    改动只有 7 个字节，且等长替换，asar 头部、文件偏移、文件大小都不变；
    该版本 Electron 的 EnableEmbeddedAsarIntegrityValidation fuse 为关闭状态。

.PARAMETER Action
    status  : 只读检查当前状态（默认）
    apply   : 关闭任务栏红点
    restore : 恢复官方行为（红点回来）

.PARAMETER AppPath
    ZCode 安装目录或 resources\app.asar 的完整路径。默认自动探测。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File taskbar-dot.ps1 -Action apply

.NOTES
    需要重启 ZCode 才生效。应用自动更新会覆盖 app.asar，更新后重新执行 apply 即可。
#>
[CmdletBinding()]
param(
    [ValidateSet('status', 'apply', 'restore')]
    [string]$Action = 'status',

    [string]$AppPath
)

$ErrorActionPreference = 'Stop'

$Anchor = ',"supportsWindowOverlayBadge")'
$DotOn = '"win32"'
$DotOff = '"never"'
# Latin1：每个字节映射一个字符，字节与字符一一对应，用于无损定位与写回。
$Encoding = [System.Text.Encoding]::GetEncoding(28591)
$RegionBeforeAnchor = 240

function Write-Step([string]$Message) {
    Write-Output $Message
}

function Test-AppRoot([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path 'resources\app.asar') -PathType Leaf)
}

function Get-CandidateRoots {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($proc in @(Get-Process ZCode -ErrorAction SilentlyContinue)) {
        try {
            if ($proc.Path) { $candidates.Add((Split-Path -Parent $proc.Path)) }
        } catch { }
    }

    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $uninstallRoots) {
        try {
            Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like 'ZCode*' -and $_.InstallLocation } |
                ForEach-Object { $candidates.Add($_.InstallLocation) }
        } catch { }
    }

    if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\ZCode')) }
    if ($env:ProgramFiles) { $candidates.Add((Join-Path $env:ProgramFiles 'ZCode')) }
    if (${env:ProgramFiles(x86)}) { $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'ZCode')) }
    $candidates.Add('D:\Code\ZCode')

    return $candidates
}

function Resolve-AsarPath([string]$Explicit) {
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit -PathType Leaf) {
            if ([System.IO.Path]::GetFileName($Explicit) -ne 'app.asar') {
                throw "指定的文件不是 app.asar：$Explicit"
            }
            return (Resolve-Path -LiteralPath $Explicit).Path
        }
        if (Test-AppRoot $Explicit) {
            return (Join-Path (Resolve-Path -LiteralPath $Explicit).Path 'resources\app.asar')
        }
        throw "路径下找不到 resources\app.asar：$Explicit"
    }

    $seen = New-Object System.Collections.Generic.HashSet[string]
    $tried = New-Object System.Collections.Generic.List[string]
    foreach ($root in (Get-CandidateRoots)) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $normalized = $root.TrimEnd('\')
        if (-not $seen.Add($normalized)) { continue }
        $tried.Add($normalized)
        if (Test-AppRoot $normalized) {
            return (Join-Path $normalized 'resources\app.asar')
        }
    }

    throw ("没有找到 ZCode 安装目录（找不到 resources\app.asar）。已尝试：`n  " + ($tried -join "`n  ") + "`n请用 -AppPath 指定安装目录。")
}

function Get-AnchorOffsets([System.IO.FileStream]$Stream) {
    $chunkSize = 4MB
    $buffer = New-Object byte[] $chunkSize
    $keep = $Anchor.Length - 1
    $carry = ''
    $carryBase = [long]0
    $hits = New-Object System.Collections.Generic.List[long]

    $Stream.Position = 0
    while ($true) {
        $read = $Stream.Read($buffer, 0, $chunkSize)
        if ($read -le 0) { break }

        $text = $carry + $Encoding.GetString($buffer, 0, $read)
        $searchFrom = 0
        while ($searchFrom -le $text.Length - $Anchor.Length) {
            $index = $text.IndexOf($Anchor, $searchFrom, [System.StringComparison]::Ordinal)
            if ($index -lt 0) { break }
            $hits.Add($carryBase + $index)
            if ($hits.Count -gt 1) { return $hits }
            $searchFrom = $index + 1
        }

        $carryLength = [Math]::Min($keep, $text.Length)
        $carry = $text.Substring($text.Length - $carryLength)
        $carryBase = $carryBase + $text.Length - $carryLength
    }

    return $hits
}

function Read-RegionBeforeAnchor([System.IO.FileStream]$Stream, [long]$AnchorOffset) {
    $length = [int][Math]::Min([long]$RegionBeforeAnchor, $AnchorOffset)
    if ($length -le 0) { throw '补丁锚点位于文件开头，文件结构异常。' }
    $buffer = New-Object byte[] $length
    $Stream.Position = $AnchorOffset - $length
    $read = $Stream.Read($buffer, 0, $length)
    return [pscustomobject]@{
        Text   = $Encoding.GetString($buffer, 0, $read)
        Offset = $AnchorOffset - $length
    }
}

function Get-BadgeState([System.IO.FileStream]$Stream) {
    $anchors = Get-AnchorOffsets $Stream
    if ($anchors.Count -eq 0) {
        throw '在 app.asar 里找不到 supportsWindowOverlayBadge 定义，可能版本结构已变化，未做任何修改。'
    }
    if ($anchors.Count -gt 1) {
        throw 'supportsWindowOverlayBadge 出现多次，无法确定补丁位置，未做任何修改。'
    }

    $anchorOffset = $anchors[0]
    $region = Read-RegionBeforeAnchor $Stream $anchorOffset

    $onIndex = $region.Text.LastIndexOf($DotOn, [System.StringComparison]::Ordinal)
    $offIndex = $region.Text.LastIndexOf($DotOff, [System.StringComparison]::Ordinal)

    if ($onIndex -ge 0 -and $offIndex -ge 0) {
        throw '锚点附近同时存在 "win32" 与 "never"，状态不明确，未做任何修改。'
    }

    $index = if ($onIndex -ge 0) { $onIndex } else { $offIndex }
    if ($index -lt 0) {
        throw '锚点附近找不到平台字面量（"win32" / "never"），可能版本结构已变化，未做任何修改。'
    }
    if ($index -ne $region.Text.IndexOf($(if ($onIndex -ge 0) { $DotOn } else { $DotOff }), [System.StringComparison]::Ordinal)) {
        throw '锚点附近的平台字面量出现多次，无法确定补丁位置，未做任何修改。'
    }
    if ($index -lt 4 -or $region.Text.Substring($index - 4, 4) -cne 'e===') {
        throw '平台字面量前的代码形态与预期不符（预期 e==="win32"），未做任何修改。'
    }

    return [pscustomobject]@{
        State         = if ($onIndex -ge 0) { 'on' } else { 'off' }
        LiteralOffset = $region.Offset + $index
        AnchorOffset  = $anchorOffset
    }
}

function Get-AppVersion([string]$AsarPath) {
    $exe = Join-Path (Split-Path -Parent (Split-Path -Parent $AsarPath)) 'ZCode.exe'
    if (Test-Path -LiteralPath $exe) {
        $version = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
        if ($version) { return $version.Trim() }
    }
    return 'unknown'
}

function Get-RunningState {
    $processes = @(Get-Process ZCode -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) { return 'no' }
    return ('yes (pid ' + (($processes | ForEach-Object { $_.Id }) -join ',') + ')')
}

try {
    $asarPath = Resolve-AsarPath $AppPath
} catch {
    Write-Output ("错误：" + $_.Exception.Message)
    exit 2
}

$appRoot = Split-Path -Parent (Split-Path -Parent $asarPath)
$version = Get-AppVersion $asarPath
$running = Get-RunningState

Write-Output ("ZCode  : " + $appRoot + "  (version " + $version + ")")
Write-Output ("app.asar: " + $asarPath)

if ($Action -eq 'status') {
    $stream = [System.IO.File]::Open($asarPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { $state = Get-BadgeState $stream } finally { $stream.Close() }

    if ($state.State -eq 'off') {
        Write-Output '状态   : 补丁已生效 —— 任务栏不再显示未读红点（重启 ZCode 后才反映到运行中的实例）'
    } else {
        Write-Output '状态   : 官方原样 —— 任务有新消息时任务栏图标显示红点'
    }
    Write-Output ("运行中 : " + $running)
    exit 0
}

if ($running -ne 'no') {
    Write-Step '提示   : ZCode 正在运行，脚本会就地写入，改动需要重启 ZCode 才生效。'
}

$wantedState = if ($Action -eq 'apply') { 'off' } else { 'on' }
$targetLiteral = if ($wantedState -eq 'off') { $DotOff } else { $DotOn }
$targetLabel = if ($wantedState -eq 'off') { '关闭任务栏红点' } else { '恢复任务栏红点' }

try {
    $stream = [System.IO.File]::Open($asarPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
} catch {
    Write-Output ("错误：无法写入 app.asar（" + $_.Exception.Message + "）。如果 ZCode 安装在受保护目录，请用管理员身份运行本脚本。")
    exit 3
}

try {
    $state = Get-BadgeState $stream
    if ($state.State -eq $wantedState) {
        Write-Output ("结果   : 已经是目标状态（" + $targetLabel + "），无需修改。")
        Write-Output ("运行中 : " + $running)
        exit 0
    }

    $lengthBefore = $stream.Length
    $bytes = $Encoding.GetBytes($targetLiteral)
    $stream.Position = $state.LiteralOffset
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush($true)
    if ($stream.Length -ne $lengthBefore) {
        throw '写入后文件长度发生变化，已中止（这是不应该发生的情况，请恢复备份或重装应用）。'
    }

    $verify = Get-BadgeState $stream
    if ($verify.State -ne $wantedState) {
        throw '写入后校验失败：补丁状态与目标不一致。'
    }

    Write-Output ("结果   : 已" + $targetLabel + "（app.asar 第 " + $state.LiteralOffset + " 字节起，" + $bytes.Length + " 字节等长替换）")
    Write-Output '生效   : 需要重启 ZCode 桌面端；应用自动更新会还原官方 app.asar，更新后请重新执行 apply。'
    Write-Output ("运行中 : " + $running)
    exit 0
} catch {
    Write-Output ("错误：" + $_.Exception.Message)
    exit 4
} finally {
    $stream.Close()
}
