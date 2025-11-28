@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Windows Update Hard Blocker (Win7 - Win11)

rem ================================================================
rem  Windows 更新全量拦截脚本
rem  - 支持 Win7 ~ Win11，彻底关闭相关服务/计划任务/策略
rem  - 组合策略：停服务 + 改启动类型 + 组策略 + 计划任务
rem  - 运行前请确保以管理员身份启动 (UAC)
rem ================================================================

call :RequireAdmin || goto :eof
echo.
echo [*] 正在应用安全策略以禁止系统更新，请稍候...

rem ---------- 停止并禁用关键更新服务 ----------
set "SERVICES=wuauserv bits dosvc usosvc waasmedicsvc sihsvc sedsvc uhssvc DoSvc UsoSvc WaaSMedicSvc"
for %%S in (%SERVICES%) do call :DisableService %%S

rem ---------- 禁用与更新相关的计划任务 ----------
for %%T in (
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
    "\Microsoft\Windows\WindowsUpdate\AUScheduledInstall"
    "\Microsoft\Windows\WindowsUpdate\Automatic App Update"
    "\Microsoft\Windows\WindowsUpdate\SIHPostReboot"
    "\Microsoft\Windows\WindowsUpdate\WUAppMonitor"
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan"
    "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker"
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task"
    "\Microsoft\Windows\UpdateOrchestrator\UpdateModelTask"
    "\Microsoft\Windows\UpdateOrchestrator\Reboot"
    "\Microsoft\Windows\UpdateOrchestrator\AC Power Install"
    "\Microsoft\Windows\UpdateOrchestrator\Maintenance Install"
    "\Microsoft\Windows\UpdateOrchestrator\MusUx_LogonUpdateResults"
    "\Microsoft\Windows\UpdateOrchestrator\MusUx_UpdateResults"
    "\Microsoft\Windows\UpdateOrchestrator\Sih"
    "\Microsoft\Windows\Servicing\StartComponentCleanup"
    "\Microsoft\Windows\Servicing\StartComponentCleanupTask"
    "\Microsoft\Windows\InstallService\ScanForUpdates"
    "\Microsoft\Windows\AppID\SmartScreenSpecific"
) do call :DisableTask %%~T

rem ---------- 组策略/注册表禁用更新 ----------
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DisableOSUpgrade" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DoNotConnectToWindowsUpdateInternetLocations" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "SetDisableUXWUAccess" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "WUServer" REG_SZ "http://127.0.0.1"
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "WUStatusServer" REG_SZ "http://127.0.0.1"
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "TargetReleaseVersion" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "TargetReleaseVersionInfo" REG_SZ " "
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "UseWUServer" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "ScheduledInstallDay" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "ScheduledInstallTime" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoRebootWithLoggedOnUsers" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "DetectionFrequencyEnabled" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AutoInstallMinorUpdates" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" REG_DWORD 0

rem 针对 Win7/Win8 的额外屏蔽
call :RegAdd "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" "AUOptions" REG_DWORD 1
call :RegAdd "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" "IncludeRecommendedUpdates" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" "EnableAutoUpdate" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade" "ReservationsAllowed" REG_DWORD 0
call :RegAdd "HKLM\SOFTWARE\Policies\Microsoft\Windows\Gwx" "DisableGwx" REG_DWORD 1

rem 当前用户层的可见入口禁用
call :RegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoWindowsUpdate" REG_DWORD 1
call :RegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" "DisableWindowsUpdateAccess" REG_DWORD 1
call :RegAdd "HKCU\Software\Microsoft\Windows\CurrentVersion\EOSNotify" "DiscontinueEOS" REG_DWORD 1

rem ---------- 加固 Windows Update Medic / 组件修复 ----------
for %%S in (WaaSMedicSvc UsoSvc DoSvc Sedsvc) do call :ForceServiceDisabled %%S

rem ---------- 屏蔽 Delivery Optimization ----------
net stop dosvc >nul 2>&1
call :RegAdd "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" "Start" REG_DWORD 4

echo.
echo [OK] 所有策略已写入。建议重启后检查“Windows Update”保持禁用状态。
echo       如需恢复，请自行将相应服务启动类型改回“手动/自动”，并删除上述策略。
pause
goto :eof

:RequireAdmin
fltmc >nul 2>&1
if not %errorlevel%==0 (
    echo [ERROR] 需要使用“以管理员身份运行”执行本脚本。
    exit /b 1
)
exit /b 0

:DisableService
set "svc=%~1"
if "%svc%"=="" exit /b 0
sc query "%svc%" >nul 2>&1 || exit /b 0
echo    停止服务: %svc%
sc stop "%svc%" >nul 2>&1
sc config "%svc%" start= disabled >nul 2>&1
call :RegAdd "HKLM\SYSTEM\CurrentControlSet\Services\%svc%" "Start" REG_DWORD 4
exit /b 0

:ForceServiceDisabled
set "svc=%~1"
if "%svc%"=="" exit /b 0
reg add "HKLM\SYSTEM\CurrentControlSet\Services\%svc%" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
exit /b 0

:DisableTask
set "task=%~1"
if "%task%"=="" exit /b 0
schtasks /Query /TN "%task%" >nul 2>&1 || exit /b 0
echo    禁用计划任务: %task%
schtasks /End /TN "%task%" >nul 2>&1
schtasks /Change /TN "%task%" /DISABLE >nul 2>&1
exit /b 0

:RegAdd
set "key=%~1"
set "value=%~2"
set "type=%~3"
set "data=%~4"
if "%key%"=="" exit /b 0
if "%value%"=="" (
    reg add "%key%" /t %type% /d "%data%" /f >nul 2>&1
) else (
    reg add "%key%" /v "%value%" /t %type% /d "%data%" /f >nul 2>&1
)
exit /b 0

