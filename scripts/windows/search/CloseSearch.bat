@echo off
:: 关闭除应用启动外的大部分搜索功能
:: 需要以管理员身份运行

echo === 检查管理员权限 ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 需要以「管理员身份」运行本批处理脚本。
    echo 右鍵本文件 → 以管理员身份运行。
    pause
    exit /b 1
)

echo.
echo === 1. 禁用 Windows Search 服務（停止索引器） ===
:: 停止 Windows Search 服務，關閉索引
sc stop "WSearch" >nul 2>&1
:: 將啟動類型設置為禁用，防止重啟後再次啟動
sc config "WSearch" start= disabled >nul 2>&1

echo 已嘗試停止並禁用 Windows Search 服務（索引器）。

echo.
echo === 2. 寫入註冊表：關閉 Bing/Web 搜索 & 建議 ===

:: 關閉搜索框建議（開始菜單 / 任務欄搜索框）
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" ^
    /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1

:: 關閉 Bing 搜索 & 禁止搜索使用定位
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" ^
    /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" ^
    /v AllowSearchToUseLocation /t REG_DWORD /d 0 /f >nul 2>&1

:: 關閉 Web 搜索（策略路徑，對 Win10/11 專業版/企業版同樣生效）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" ^
    /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1

:: 禁止搜索使用 Web（包括計量連接）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" ^
    /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" ^
    /v ConnectedSearchUseWebOverMeteredConnections /t REG_DWORD /d 0 /f >nul 2>&1

:: 可選：關閉搜索歷史（讓搜索更「乾淨」）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" ^
    /v DisableSearchHistory /t REG_DWORD /d 1 /f >nul 2>&1

echo 已寫入註冊表策略：關閉 Web/Bing 搜索和建議/歷史。

echo.
echo === 3. 重啟資源管理器，使部分設置立即生效 ===
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo.
echo === 4. 完成 ===
echo - 已禁用索引服務（Windows Search）。
echo - 已關閉 Bing/Web 搜索、搜索建議、搜索歷史。
echo - Win+Q 仍可用於啟動應用（App Launcher）。
echo 如需完全生效，建議重啟電腦一次。
pause
