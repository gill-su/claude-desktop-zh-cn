@echo off
chcp 65001 >nul 2>&1
REM 雙擊本檔即可安裝 Claude Desktop 繁體中文。
REM 會自動呼叫同資料夾的 PowerShell 腳本，並請求系統管理員權限。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0一鍵安裝-繁體中文.ps1"
pause
