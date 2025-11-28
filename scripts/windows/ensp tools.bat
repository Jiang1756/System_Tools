@echo off
title ENSPģ��������С����
mode con: cols=70 lines=25

:: �Զ��������ԱȨ��
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' neq '0' (
    echo �����������ԱȨ��...
    set "batchArgs= %*"
    setlocal EnableDelayedExpansion
    set "batchArgs=!batchArgs:"=\"!"
    mshta vbscript:Execute("CreateObject(""Shell.Application"").ShellExecute""cmd.exe"",""/c \"\"%~f0\"\" !batchArgs!"","""",""runas"",1)(window.close)" && exit /b
)

:: Windows�汾��⣨�����Ŵ��ڵ���26000ʱ��ʾ��
for /f %%i in ('powershell -command "[System.Environment]::OSVersion.Version.Build"') do set "BuildNumber=%%i"
if %BuildNumber% geq 26000 (
    echo.
    echo [����] ��⵽Windows�汾��%BuildNumber%������24H2
    echo ensp��֧�����°汾��Windows
    echo �뽵����24H2���°汾��ʹ��
    echo.
    timeout /t 5 >nul
    exit /b
)

:menu
cls
echo.
echo   ============================================
echo            ENSPģ��������С����
echo   ============================================
echo.

:: ��ȡVirtualBox�汾
set "vbox_version=δ��⵽"
for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Oracle\VirtualBox" /v Version 2^>nul ^| findstr "REG_SZ"') do set "vbox_version=%%i"

:: ���Hyper-V״̬
set "hyperv_status=���ʧ��"
for /f "tokens=3" %%i in ('powershell -command "Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All ^| Select-Object -ExpandProperty State"') do (
    if "%%i"=="Enabled" (set "hyperv_status=������") else (set "hyperv_status=δ����")
)

echo   VirtualBox��ǰ�汾��%vbox_version%
echo   Hyper-V��ǰ״̬��%hyperv_status%
echo.
echo   1. �л�VirtualBox�� 6.0.14
echo   2. �л�VirtualBox�� 5.2.44
echo   3. �ر�Hyper-V���ܣ���������
echo   4. ����Mobaxterm��Ӣ�İ棩
echo   q. �˳�����
echo.
choice /c 1234q /n /m "��ѡ����� (1/2/3/4/q): "

if errorlevel 5 exit /b
if errorlevel 4 goto download_mobaxterm
if errorlevel 3 goto disable_hyperv
if errorlevel 2 goto revert
if errorlevel 1 goto upgrade

:upgrade
reg add "HKLM\SOFTWARE\Oracle\VirtualBox" /v Version /d "6.0.14" /f > nul
reg add "HKLM\SOFTWARE\Oracle\VirtualBox" /v VersionExt /d "6.0.14" /f > nul
echo.
if errorlevel 1 (
    echo [����] �޸�ʧ�ܣ�����Ȩ�޺�ע���·��
) else (
    echo [�ɹ�] ���л��� 6.0.14 �汾��
)
timeout /t 2 > nul
goto menu

:revert
reg add "HKLM\SOFTWARE\Oracle\VirtualBox" /v Version /d "5.2.44" /f > nul
reg add "HKLM\SOFTWARE\Oracle\VirtualBox" /v VersionExt /d "5.2.44" /f > nul
echo.
if errorlevel 1 (
    echo [����] �޸�ʧ�ܣ�����Ȩ�޺�ע���·��
) else (
    echo [�ɹ�] �ѻ�ԭ�� 5.2.44 �汾��
)
timeout /t 2 > nul
goto menu

:disable_hyperv
echo.
echo [����] ���ڹر�Hyper-V����...
dism /Online /Disable-Feature:Microsoft-Hyper-V-All /NoRestart > nul
if %errorlevel% neq 0 (
    echo [����] ����ʧ�ܣ��볢���ֶ�ִ�У�
    echo dism /Online /Disable-Feature:Microsoft-Hyper-V-All
) else (
    echo [�ɹ�] Hyper-V�ѽ��ã���Ҫ������Ч��
    choice /m "�Ƿ����������������(y/n) "
    if %errorlevel% equ 1 (
        shutdown /r /t 0
    ) else (
        echo ���Ժ���Ҫ�ֶ����������
    )
)
timeout /t 3 > nul
goto menu

:download_mobaxterm
start "" "https://mobaxterm.mobatek.net/download-home-edition.html"
echo.
echo [�ɹ�] �ѵ��������������ҳ�棡
timeout /t 2 > nul
goto menu