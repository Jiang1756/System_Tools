<#
    Script Name : Disable-DriverUpdate-Global.ps1
    Purpose     : 
        1. Disable Windows Update from including drivers in quality updates
        2. Disable automatic driver searching from Windows Update
    Note        : Must be run in an elevated (Administrator) PowerShell
#>

# Stop on any error
$ErrorActionPreference = "Stop"

# 1. Check for administrator privileges
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Please run this script in an elevated (Administrator) PowerShell window." -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Administrator check passed." -ForegroundColor Green

# 2. Disable Windows Update driver inclusion
$wuKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

Write-Host "[INFO] Creating / updating registry key: $wuKeyPath" -ForegroundColor Yellow
New-Item -Path $wuKeyPath -Force | Out-Null

Set-ItemProperty -Path $wuKeyPath `
    -Name "ExcludeWUDriversInQualityUpdate" `
    -Type DWord `
    -Value 1

Write-Host "[OK] ExcludeWUDriversInQualityUpdate set to 1" -ForegroundColor Green

# 3. Disable driver searching from Windows Update
$driverSearchKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

Write-Host "[INFO] Creating / updating registry key: $driverSearchKey" -ForegroundColor Yellow
New-Item -Path $driverSearchKey -Force | Out-Null

# 0 = Never search Windows Update for drivers
Set-ItemProperty -Path $driverSearchKey `
    -Name "SearchOrderConfig" `
    -Type DWord `
    -Value 0

# 0 = Disable driver update wizard online search
Set-ItemProperty -Path $driverSearchKey `
    -Name "DriverUpdateWizardWuSearchEnabled" `
    -Type DWord `
    -Value 0

Write-Host "[OK] SearchOrderConfig set to 0" -ForegroundColor Green
Write-Host "[OK] DriverUpdateWizardWuSearchEnabled set to 0" -ForegroundColor Green

# 4. Show current values
Write-Host ""
Write-Host "Current configuration:" -ForegroundColor Cyan
Get-ItemProperty -Path $wuKeyPath | Select-Object ExcludeWUDriversInQualityUpdate | Format-List
Get-ItemProperty -Path $driverSearchKey | Select-Object SearchOrderConfig, DriverUpdateWizardWuSearchEnabled | Format-List

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Driver updates via Windows Update are now disabled" -ForegroundColor Cyan
Write-Host " Please reboot Windows to fully apply the settings  " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
