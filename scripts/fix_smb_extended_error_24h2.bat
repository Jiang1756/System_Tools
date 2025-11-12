@echo off
title Windows 11 24H2 SMB 兼容性修复 - by jiang & ChatGPT

echo.
echo ================================
echo  Windows 11 24H2 SMB 擴展錯誤修復
echo  作用：放寬 SMB 客户端安全策略
echo  用於連接老 NAS / 路由器 / 無密碼共享等
echo ================================
echo.
echo  注意：請在【可信局域網】中使用本腳本！
echo  建議右鍵以「管理員身份運行」本批處理。
echo.
pause

REM 1. 允許 SMB 來賓(Guest)訪問 (對無密碼共享很關鍵)
REM 對應註冊表: HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters\AllowInsecureGuestAuth = 1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" ^
 /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f

echo.
echo [OK] 已設置允許 SMB 來賓(Guest)訪問。

REM 2. 通過 PowerShell 放寬 SMB 簽名和 Guest 設置
REM RequireSecuritySignature = $false    -> 不再強制要求 SMB 簽名
REM EnableInsecureGuestLogons = $true    -> 允許不安全的 Guest 登錄
echo.
echo 正在通過 PowerShell 放寬 SMB 客戶端配置...

powershell -NoLogo -NoProfile -Command ^
 "Set-SmbClientConfiguration -RequireSecuritySignature \$false -EnableSecuritySignature \$true -EnableInsecureGuestLogons \$true -Force"

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [警告] PowerShell 命令執行出錯，請確認：
    echo   1. 已以管理員身份運行此批處理；
    echo   2. 系統已啟用 PowerShell；
    echo 如不會處理，建議手動用「以管理員身份運行」PowerShell，再執行：
    echo   Set-SmbClientConfiguration -RequireSecuritySignature ^$false -EnableSecuritySignature ^$true -EnableInsecureGuestLogons ^$true -Force
) ELSE (
    echo.
    echo [OK] 已通過 PowerShell 更新 SMB 客戶端配置。
)

echo.
echo ================================
echo  操作完成，建議現在重啓電腦！
echo  重啓後再嘗試訪問 SMB 共享：
echo   - \\NAS_IP\共享名
echo   - \\路由器IP\U盤路徑 等
echo ================================
echo.
pause
