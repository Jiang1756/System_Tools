@echo off
title PTC Creo 残留清理工具 (Win7 兼容版)

echo ==============================================
echo   PTC Creo 残留清理工具  (批處理版)
echo   請務必以【管理員】身份運行本批處理
echo ==============================================
echo.

REM 1. 檢查是否以管理員身份運行（利用 net session）
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [錯誤] 當前批處理未以管理員身份運行。
    echo 請右鍵本 .bat 文件，選擇「以管理員身份運行」。
    pause
    goto :EOF
)

REM 2. 準備臨時文件，存放待刪除目錄列表
set "PTC_LIST_FILE=%TEMP%\ptc_cleanup_paths.txt"
if exist "%PTC_LIST_FILE%" del /f /q "%PTC_LIST_FILE%" >nul 2>&1

echo [信息] 將掃描常見盤符上的 PTC/Creo 安裝路徑...
echo.

REM 3. 要掃描的盤符（可自行增加，例如 F）
set "DRIVES=C D E"

REM 4. 掃描各盤符中的典型安裝目錄
for %%D in (%DRIVES%) do (
    if exist "%%D:\" (
        call :CheckAndAddPath "%%D:\PTC"
        call :CheckAndAddPath "%%D:\ptc"
        call :CheckAndAddPath "%%D:\Creo"
        call :CheckAndAddPath "%%D:\creo"
        call :CheckAndAddPath "%%D:\Program Files\PTC"
        call :CheckAndAddPath "%%D:\Program Files (x86)\PTC"
    )
)

REM 5. 用戶相關目錄（ProgramData / AppData）
call :CheckAndAddPath "%ProgramData%\PTC"
call :CheckAndAddPath "%LOCALAPPDATA%\PTC"
call :CheckAndAddPath "%APPDATA%\PTC"

REM 6. TEMP 目錄下的 PTC* 臨時文件/文件夾
for /d %%T in ("%TEMP%\PTC*") do (
    if exist "%%T" (
        echo [發現] 臨時目錄/文件夾：%%T
        echo %%T>>"%PTC_LIST_FILE%"
    )
)
for %%T in ("%TEMP%\PTC*") do (
    if exist "%%T" (
        echo [發現] 臨時文件：%%T
        echo %%T>>"%PTC_LIST_FILE%"
    )
)

REM 7. 展示收集到的目錄，讓用戶確認
if not exist "%PTC_LIST_FILE%" (
    echo [信息] 未發現明顯的 PTC/Creo 殘留目錄，可能已經清理過。
    goto CLEAN_SERVICES
)

echo.
echo [提示] 發現以下可能是 PTC / Creo 殘留的目錄或文件：
echo --------------------------------------------------------------
type "%PTC_LIST_FILE%"
echo --------------------------------------------------------------
echo.

set /p CONFIRM=是否刪除以上所有目錄/文件？(Y/N)： 
if /I not "%CONFIRM%"=="Y" (
    echo [信息] 用戶取消了刪除目錄操作，將跳過目錄刪除。
    goto CLEAN_SERVICES
)

REM 8. 刪除收集到的目錄/文件
echo.
echo [操作] 開始刪除上述目錄/文件...
for /f "usebackq delims=" %%P in ("%PTC_LIST_FILE%") do (
    if exist "%%P" (
        echo   刪除：%%P
        REM 嘗試先當作目錄刪，如果失敗再當作文件刪
        rd /s /q "%%P" >nul 2>&1
        if exist "%%P" (
            del /f /q "%%P" >nul 2>&1
        )
    )
)

:CLEAN_SERVICES
echo.
echo ==============================================
echo   停止並刪除 PTC License 相關服務
echo ==============================================

REM 9. 停止並刪除 PTC License Server 服務
call :StopAndDeleteService lmadmin_ptc
call :StopAndDeleteService lmgrd_ptc

echo.
echo (提示) FlexNet Licensing Service 可能被其他軟件共用，默認不自動刪除。
echo.

REM 10. 終止常見的 Creo 相關進程
echo ==============================================
echo   結束 PTC / Creo 相關進程
echo ==============================================
echo.

for %%P in (xtop.exe parametric.exe simulate.exe creosvw.exe) do (
    tasklist /FI "IMAGENAME eq %%P" | find /I "%%P" >nul 2>&1
    if not errorlevel 1 (
        echo 終止進程 %%P ...
        taskkill /F /IM %%P >nul 2>&1
    )
)

REM 可選：殺掉所有以 ptc 開頭的進程（可能略暴力，視情況開啟）
REM taskkill /F /IM ptc*.exe >nul 2>&1

REM 11. 刪除 PTC 相關註冊表鍵
echo.
echo ==============================================
echo   刪除 PTC 相關註冊表項
echo ==============================================
echo.

call :DeleteRegKey "HKLM\SOFTWARE\PTC"
call :DeleteRegKey "HKLM\SOFTWARE\Wow6432Node\PTC"
call :DeleteRegKey "HKCU\SOFTWARE\PTC"

REM 12. 刪除 PTC 相關環境變量（機器級 + 用戶級）
echo.
echo ==============================================
echo   刪除 PTC 相關環境變量
echo ==============================================
echo.

call :DeleteEnvVar PTC_D_LICENSE_FILE
call :DeleteEnvVar LM_LICENSE_FILE

REM 13. 清理臨時文件
if exist "%PTC_LIST_FILE%" del /f /q "%PTC_LIST_FILE%" >nul 2>&1

echo.
echo ==============================================
echo   PTC Creo 殘留清理完成，建議重啟系統
echo ==============================================
echo.
pause
goto :EOF


REM -----------------------------------------------
REM 子程序：檢查目錄是否存在，存在則記錄到臨時文件
REM %1 = 路徑
REM -----------------------------------------------
:CheckAndAddPath
set "CHK_PATH=%~1"
if not "%CHK_PATH%"=="" (
    if exist "%CHK_PATH%" (
        echo [發現] 目錄：%CHK_PATH%
        echo %CHK_PATH%>>"%PTC_LIST_FILE%"
    )
)
goto :EOF

REM -----------------------------------------------
REM 子程序：停止並刪除服務
REM %1 = 服務名
REM -----------------------------------------------
:StopAndDeleteService
set "SVC=%~1"
sc query "%SVC%" >nul 2>&1
if errorlevel 1 (
    echo [信息] 未找到服務：%SVC%，跳過。
    goto :EOF
)

echo [操作] 嘗試停止服務：%SVC% ...
net stop "%SVC%" /y >nul 2>&1

echo [操作] 刪除服務：%SVC% ...
sc delete "%SVC%" >nul 2>&1

goto :EOF

REM -----------------------------------------------
REM 子程序：刪除註冊表鍵（如果存在）
REM %1 = 註冊表鍵路徑（含根，例如 HKLM\SOFTWARE\PTC）
REM -----------------------------------------------
:DeleteRegKey
set "REGKEY=%~1"
reg query "%REGKEY%" >nul 2>&1
if errorlevel 1 (
    echo [信息] 未發現註冊表鍵：%REGKEY%
    goto :EOF
)

echo [操作] 刪除註冊表鍵：%REGKEY%
reg delete "%REGKEY%" /f >nul 2>&1
goto :EOF

REM -----------------------------------------------
REM 子程序：刪除環境變量（機器級 + 用戶級）
REM %1 = 環境變量名
REM -----------------------------------------------
:DeleteEnvVar
set "ENVNAME=%~1"
echo [操作] 清理環境變量：%ENVNAME%

REM 刪除系統級環境變量（HKLM）
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%ENVNAME%" /f >nul 2>&1

REM 刪除用戶級環境變量（HKCU）
reg delete "HKCU\Environment" /v "%ENVNAME%" /f >nul 2>&1

REM 刪除當前進程中的環境變量
set "%ENVNAME%="
goto :EOF
