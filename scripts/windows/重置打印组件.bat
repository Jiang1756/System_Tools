@echo off
setlocal enabledelayedexpansion

title 打印系统重置工具 - by ChatGPT
echo ==========================================
echo         Windows 打印系统重置工具
echo ==========================================
echo.
echo 本工具将重置打印服务、清除缓存。
echo 可选操作包括：
echo   1. 清除打印机驱动配置
echo   2. 清除端口监视器配置
echo.
set /p delDrivers=是否清除打印机驱动配置? (Y/N): 
set /p delPorts=是否清除端口监视器配置? (Y/N): 

echo.
echo 停止打印服务...
net stop spooler

echo 清除打印任务缓存...
del /Q /F /S "%systemroot%\System32\spool\PRINTERS\*.*" >nul 2>&1

if /i "%delDrivers%"=="Y" (
    echo 删除打印机驱动注册表项...
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" /f >nul 2>&1
) else (
    echo 已跳过打印机驱动配置清除。
)

if /i "%delPorts%"=="Y" (
    echo 删除端口监视器注册表项...
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors" /f >nul 2>&1

    echo 重建默认本地端口监视器...
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Local Port" /ve /d "" /f
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Local Port" /v "Driver" /d "Local Port Monitor" /f
) else (
    echo 已跳过端口监视器清除。
)

echo 启动打印服务...
net start spooler

echo.
echo 打印系统重置完成！
echo 请手动重新添加打印机。
pause
