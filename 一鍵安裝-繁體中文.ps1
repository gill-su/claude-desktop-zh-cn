# =====================================================================
#  Claude Desktop 繁體中文（台灣）一鍵安裝
#  適用：Windows 的 Microsoft Store 版 Claude Desktop
#  作法：官方登入模式（會 patch app.asar，讓語言選單出現繁體中文）
#  說明：本腳本會自動提權、徹底關閉 Claude（避免檔案被鎖）、安裝、
#        設定語言為 zh-TW，最後重新開啟 Claude。
#  ⚠ 官方模式會停用 Cowork 沙箱/工作區，並改寫 Claude.exe 簽章。
# =====================================================================

$ErrorActionPreference = 'Stop'

# --- 1) 自動提權：改 WindowsApps 內的 Claude 需要系統管理員權限 ---
$id      = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '需要系統管理員權限，正在重新以管理員身分啟動…（請在 UAC 視窗按「是」）'
    Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    return
}

# --- 2) 定位補丁資料夾與安裝腳本 ---
$root      = Split-Path -Parent $PSCommandPath
$installer = Join-Path $root 'scripts\install_windows.ps1'
if (-not (Test-Path $installer)) {
    Write-Host "找不到 $installer" -ForegroundColor Red
    Write-Host '請確認本檔放在 claude-desktop-zh-cn 資料夾的最上層。' -ForegroundColor Red
    Read-Host '按 Enter 結束'; return
}

# --- 3) 徹底關閉 Claude Desktop（檔案被鎖會卡在 [7/8]，這是關鍵）---
function Stop-ClaudeDesktop {
    $procs = Get-CimInstance Win32_Process -Filter "Name='Claude.exe'" | Where-Object {
        $_.ExecutablePath -like '*WindowsApps*' -or [string]::IsNullOrEmpty($_.ExecutablePath)
    }
    foreach ($p in $procs) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {} }
}
Write-Host '正在關閉 Claude Desktop…'
1..6 | ForEach-Object { Stop-ClaudeDesktop; Start-Sleep -Milliseconds 400 }

# --- 4) 取得目前使用者資訊（傳給安裝腳本，讓語言設定寫到正確的設定檔）---
$sid  = $id.User.Value
$prof = $env:USERPROFILE

# --- 5) 執行：官方模式 + 繁體中文（台灣）---
Write-Host '開始安裝繁體中文補丁（官方登入模式 / zh-TW）…' -ForegroundColor Cyan
Write-Host '最後一步要重算 Claude.exe（約 220MB）完整性，可能要數分鐘，請耐心等候。' -ForegroundColor DarkGray
& $installer install zh-TW -PatchMode official `
    -OriginalUserSid       $sid  `
    -OriginalUserProfile   $prof `
    -OriginalAppData       $env:APPDATA `
    -OriginalLocalAppData  $env:LOCALAPPDATA

# --- 6) 把語言設定寫成 zh-TW（讓它直接開成中文）---
$cfgs = @("$env:APPDATA\Claude\config.json", "$env:APPDATA\Claude-3p\config.json")
Get-ChildItem "$env:LOCALAPPDATA\Packages\Claude_*\LocalCache\Roaming\Claude*\config.json" -ErrorAction SilentlyContinue |
    ForEach-Object { $cfgs += $_.FullName }
foreach ($c in ($cfgs | Select-Object -Unique)) {
    if (Test-Path $c) {
        try {
            $j = Get-Content $c -Raw | ConvertFrom-Json
            $j | Add-Member -NotePropertyName locale -NotePropertyValue 'zh-TW' -Force
            ($j | ConvertTo-Json -Depth 20) | Set-Content -Path $c -Encoding UTF8
        } catch {}
    }
}

# --- 7) 重新開啟 Claude ---
Write-Host ''
Write-Host '✅ 安裝完成！正在開啟 Claude…' -ForegroundColor Green
$app = Get-StartApps | Where-Object { $_.Name -eq 'Claude' } | Select-Object -First 1
if ($app) { Start-Process "shell:AppsFolder\$($app.AppID)" }
Write-Host ''
Write-Host '若介面仍是英文：左下角帳號 → Language → 選「繁體中文（台灣）」即可。' -ForegroundColor Yellow
Read-Host '按 Enter 結束'
