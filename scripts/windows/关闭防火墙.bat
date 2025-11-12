@echo off
:: 确保脚本以管理员权限运行
:init
    echo Checking for administrator privileges...
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo This script must be run as administrator. Please run it with administrator privileges.
        pause
        exit /b
    )

:: 关闭 Windows 防火墙
:disable_firewall
    echo Disabling Windows Firewall...
    netsh advfirewall set allprofiles state off
    echo Windows Firewall has been disabled.

:: 修改注册表以防止防火墙自动启用
:disable_firewall_registry
    echo Modifying registry to prevent Windows Firewall from being re-enabled...
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall" /v "EnableFirewall" /t REG_DWORD /d "0" /f >nul 2>&1
    echo Registry settings have been updated to prevent firewall re-enablement.

:: 完成
:completion
    echo Operation completed successfully!
    echo Windows Firewall has been disabled and will not be re-enabled automatically.
    pause
    exit /b