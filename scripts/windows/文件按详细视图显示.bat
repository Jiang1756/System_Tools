@echo off
echo 正在设置资源管理器以“详细信息”视图显示...
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DetailsAreaMode" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DetailsAreaMode" /t REG_DWORD /d 1 /f
echo 设置完成！
pause