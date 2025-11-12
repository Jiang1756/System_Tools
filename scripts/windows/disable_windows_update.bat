@echo off
chcp 65001 >nul
setlocal

:: ============================================================
:: 关/控 Windows 更新和系统升级的脚本（多种手段叠加）
::
:: 主要效果：
::   1. 停止 Windows Update 服务
::   2. 尽量延长“暂停更新”的天数
::   3. 强制使用伪造的 WSUS（指向 127.0.0.1），阻断在线更新
::   4. 关闭自动更新、限制用户访问更新界面
::   5. 禁用更新“自我修复”相关服务（WaaSMedicSvc / UsoSvc）
::   6. 屏蔽部分 Windows 7 时代的升级推送提示
::
:: 风险提示：
::   长期完全不打补丁有安全风险，使用前建议先在测试环境验证，
::   并根据自己实际需求删减。
:: ============================================================

:: ---------- 1. 停止 Windows Update 服务，避免修改时被占用 ----------
net stop wuauserv

:: ---------- 2. 提高“暂停更新”的最大天数（部分 Win10 有效） ----------
:: 将“暂停更新”最大可设置天数改为 3000 天（约 8 年多）
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" ^
 /v "FlightSettingsMaxPauseDays" /t REG_DWORD /d 3000 /f

:: （原脚本此处有乱码注释，已删除）

:: ---------- 3. 把更新服务器指向本机，伪装 WSUS，阻断在线更新 ----------
:: 告诉系统：使用“企业内部 WSUS 服务器”而不是直接连微软
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "UseWUServer" /t REG_DWORD /d 1 /f

:: 指定“更新服务器地址”为本机 127.0.0.1（实际没有 WSUS 服务）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ^
 /v "WUServer" /t REG_SZ /d "http://127.0.0.1" /f

:: 指定“统计/状态服务器地址”为本机 127.0.0.1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ^
 /v "WUStatusServer" /t REG_SZ /d "http://127.0.0.1" /f

:: 这样做的结果：更新客户端尝试连一个“假服务器”，无法真正获取更新。

:: ---------- 4. 启用某些更新相关策略（延迟/权限） ----------
:: 允许使用“暂停/延期更新”的策略（不代表一定会更新）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ^
 /v "PauseDeferrals" /t REG_DWORD /d 1 /f

:: 允许非管理员在需要时提升权限执行更新（在整体禁更下影响不大）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ^
 /v "ElevateNonAdmins" /t REG_DWORD /d 1 /f

:: ---------- 5. 禁止用户打开 Windows 更新界面 ----------
:: 隐藏/禁止“Windows 更新”相关入口
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" ^
 /v "NoWindowsUpdate" /t REG_DWORD /d 1 /f

:: 禁止用户通过控制面板/设置访问 Windows 更新
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" ^
 /v "DisableWindowsUpdateAccess" /t REG_DWORD /d 1 /f

:: ---------- 6. 自动更新相关的详细开关 ----------
:: 完全关闭自动更新（不自动下载、不自动安装）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "NoAutoUpdate" /t REG_DWORD /d 1 /f

:: 自动安装“次要更新”（结合整体策略，实际能否生效视系统而定）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "AutoInstallMinorUpdates" /t REG_DWORD /d 1 /f

:: 关闭自定义“自动检测更新频率”的功能
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "DetectionFrequencyEnabled" /t REG_DWORD /d 0 /f

:: 关于 RescheduleWaitTimeEnabled：
::   下两行先写 0 再写 1，最终生效值是 1（后面覆盖前面）。
::   这里保留原逻辑，只在注释里说明。
:: 关闭“重新计划等待时间策略”
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "RescheduleWaitTimeEnabled" /t REG_DWORD /d 0 /f

:: 再次开启“重新计划等待时间策略”（最终结果：该键值为 1）
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" ^
 /v "RescheduleWaitTimeEnabled" /t REG_DWORD /d 1 /f

:: ---------- 7. 禁止系统版本升级（例如推送高版本 Windows） ----------
:: 禁用 Windows Anytime Upgrade / 版本升级向导（老系统用得多）
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\WAU" ^
 /v "Disabled" /t REG_DWORD /d 1 /f

:: 禁止通过 Windows Update 升级到新版本操作系统（如 10 → 11）
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ^
 /v "DisableOSUpgrade" /t REG_DWORD /d 1 /f

:: ---------- 8. 禁用“修复更新组件”的关键服务 ----------
:: WaaSMedicSvc（Windows Update Medic Service：尝试修复更新组件）
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" ^
 /v "Start" /t REG_DWORD /d 4 /f

:: UsoSvc（Update Orchestrator Service：调度更新的检测/下载/安装）
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UsoSvc" ^
 /v "Start" /t REG_DWORD /d 4 /f

:: Start = 4 表示“禁用服务，不随系统启动”

:: ---------- 9. Windows 7/老系统的升级提示屏蔽 ----------
:: 禁止预订 Windows 10 升级（Windows 7 时期的 OSUpgrade 机制）
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\OSUpgrade" ^
 /v "ReservationsAllowed" /t REG_DWORD /d 0 /f

:: 禁用 GWX（Get Windows 10）相关升级图标和提示
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Gwx" ^
 /v "DisableGwx" /t REG_DWORD /d 1 /f

:: 屏蔽 Windows 7 结束支持（End Of Support）的通知
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\EOSNotify" ^
 /v "DiscontinueEOS" /t REG_DWORD /d 1 /f

:: ---------- 10. 尝试重新启动 Windows Update 服务 ----------
:: 说明：
::   虽然上面做了大量禁用/指向本机等操作，
::   但这里仍尝试把 wuauserv 启动起来，部分场景下用于保留
::   “更新组件存在但几乎不会成功连网更新”的状态。
net start wuauserv

:: 保持窗口，方便查看命令执行结果
pause
