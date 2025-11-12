@echo off
:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 请以管理员身份运行此批处理文件！
    pause
    exit /b
)

echo 正在禁用 Windows Defender SmartScreen...

:: 禁用资源管理器（Explorer）中的 SmartScreen 提示
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d Off /f

:: 禁用通过组策略对 Defender SmartScreen 的启用（适用于部分系统版本）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender SmartScreen" /v EnableSmartScreen /t REG_DWORD /d 0 /f

:: 禁用系统级 SmartScreen 设置（部分版本可能生效）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f

echo 操作已完成！
echo 请重启计算机以使设置生效。
pause
