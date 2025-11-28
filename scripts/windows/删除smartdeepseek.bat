@echo off
%1 %2
ver|find "5.">nul&&goto :admin
mshta vbscript:CreateObject("Shell.Application").ShellExecute("%~s0","goto :admin","","runas",1)(close)&exit
:admin

echo 正在尝试禁用SmartScreen相关功能...
echo -----------------------------------

echo [1/6] 关闭Defender防篡改保护
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d 0 /f

echo [2/6] 修改注册表设置
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Edge\SmartScreenEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Edge\SmartScreenPuaEnabled" /t REG_DWORD /d 0 /f

echo [3/6] 停止相关服务
sc config SecurityHealthService start= disabled >nul
sc stop SecurityHealthService >nul 2>&1
sc config WdNisSvc start= disabled >nul
sc stop WdNisSvc >nul 2>&1

echo [4/6] 禁用Edge SmartScreen
set "edgePath=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if exist "%edgePath%" (
  takeown /f "%edgePath%" /a >nul
  icacls "%edgePath%" /grant administrators:F >nul
  attrib -s -h -r "%edgePath%"
)

echo [5/6] 刷新组策略
gpupdate /force >nul

echo [6/6] 清理完成，建议重启系统
echo -----------------------------------
echo 操作已完成，部分设置需要重启生效！
echo 按任意键尝试重启资源管理器...
pause >nul

taskkill /f /im explorer.exe >nul
start explorer.exe

echo 建议手动执行完整系统重启（shutdown /r /t 0）
pause