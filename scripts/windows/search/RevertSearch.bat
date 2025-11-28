@echo off
:: 還原之前對 Windows 搜索的修改，重新啟用索引和 Web 搜索（部分）

echo === 檢查管理員權限 ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [錯誤] 需要以「管理員身份」運行本批處理。
    pause
    exit /b 1
)

echo.
echo === 1. 重新啟用 Windows Search 服務（索引器） ===
sc config "WSearch" start= delayed-auto >nul 2>&1
sc start "WSearch" >nul 2>&1
echo 已嘗試啟動 Windows Search 並設為自動(延遲啟動)。

echo.
echo === 2. 刪除/重置註冊表策略 ===

:: 刪除搜索框建議策略
reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" ^
    /v DisableSearchBoxSuggestions /f >nul 2>&1

:: 恢復 Bing 搜索 / 定位（不設值即使用默認）
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" ^
    /v BingSearchEnabled /f >nul 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" ^
    /v AllowSearchToUseLocation /f >nul 2>&1

:: 刪除 Windows Search 策略項
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /f >nul 2>&1

echo 已嘗試刪除相關策略鍵值（恢復為系統默認行為）。

echo.
echo === 3. 重啟資源管理器 ===
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo.
echo === 完成 ===
echo 大部分搜索相關限制已移除；如需完全生效，建議重啟電腦。
pause
