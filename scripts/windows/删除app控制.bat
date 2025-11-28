@echo off
%1 %2
ver|find "5.">nul&&goto :admin
mshta vbscript:CreateObject("Shell.Application").ShellExecute("%~s0","goto :admin","","runas",1)(close)&exit
:admin

echo [INFO] Windows App & Browser Control Remover
echo --------------------------------------------
echo WARNING: This will disable critical security features!
echo Proceed at your own risk. Not recommended for most users!
echo --------------------------------------------

echo [1/8] Disabling Tamper Protection...
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d 0 /f >nul 2>&1

echo [2/8] Modifying registry settings...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "ConfigureAppInstallControlEnabled" /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\SmartScreen" /v "EnableSmartScreen" /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f >nul

echo [3/8] Stopping and disabling services...
sc config SecurityHealthService start= disabled >nul
sc stop SecurityHealthService >nul 2>&1
sc config WdNisSvc start= disabled >nul
sc stop WdNisSvc >nul 2>&1
sc config webthreatdefsvc start= disabled >nul
sc stop webthreatdefsvc >nul 2>&1

echo [4/8] Forcing Microsoft Edge SmartScreen removal...
set "edgePath=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if exist "%edgePath%" (
    takeown /f "%edgePath%" /a >nul
    icacls "%edgePath%" /grant:r *S-1-5-32-544:F /t /c /q >nul
    attrib -s -h -r "%edgePath%"
)

echo [5/8] Disabling Microsoft Store SmartScreen...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f >nul

echo [6/8] Applying group policy changes...
gpupdate /force >nul

echo [7/8] Resetting Windows Security components...
PowerShell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >nul 2>&1
PowerShell -Command "Set-MpPreference -DisableIOAVProtection $true" >nul 2>&1

echo [8/8] Finalizing changes...
echo --------------------------------------------
echo WARNING: Security features have been disabled!
echo 1. Some changes require reboot to take effect
echo 2. Windows Update may re-enable protections
echo 3. System is now vulnerable to malware attacks

choice /c YN /m "Restart explorer.exe now? (Y/N)"
if errorlevel 2 exit
taskkill /f /im explorer.exe >nul
start explorer.exe
echo Operation completed. Full system reboot recommended!
pause