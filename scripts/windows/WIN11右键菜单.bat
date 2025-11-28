@echo off
chcp 65001
title Windows 11 右键菜单切换工具
color 0A

echo ==============================================
echo  Windows 11 右键菜单切换工具
echo ==============================================
echo  1. 恢复默认右键菜单
echo  2. 恢复经典右键菜单
echo ==============================================
echo.
set /p choice= 请输入选项 (1 或 2) 并按回车:

if "%choice%"=="1" (
    echo 正在恢复默认上下文右键菜单...
    reg.exe delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f

    echo 正在重启资源管理器使设置生效...
    taskkill /f /im explorer.exe >nul 2>&1
    start explorer.exe

    echo 操作完成！默认右键菜单已生效。
) else if "%choice%"=="2" (
    echo 正在恢复经典上下文右键菜单...
    reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f

    echo 正在重启资源管理器使设置生效...
    taskkill /f /im explorer.exe >nul 2>&1
    start explorer.exe

    echo 操作完成！经典右键菜单已生效。
) else (
    echo 无效的选项，请重新运行程序并输入1或2。
)

echo.
pause