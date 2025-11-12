@echo off
:: Ensure the script runs with administrator privileges
:init
    echo Checking for administrator privileges...
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo This script must be run as administrator. Please run it with administrator privileges.
        pause
        exit /b
    )

:: Delete system sound files
:delete_sound_files
    echo Deleting system sound files...
    set "sound_dir=%windir%\Media"
    for %%f in ("%sound_dir%\*.wav") do (
        echo Deleting %%f
        takeown /f "%%f" /a >nul 2>&1
        icacls "%%f" /grant administrators:F >nul 2>&1
        del /f /q "%%f" >nul 2>&1
    )
    echo System sound files have been deleted.

:: Delete registry entries related to sound schemes
:delete_registry_keys
    echo Deleting registry entries related to sound schemes...
    reg delete "HKEY_CURRENT_USER\Control Panel\SoundSchemes" /f >nul 2>&1
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\SoundSchemes" /f >nul 2>&1
    echo Registry entries have been deleted.

:: Disable system sounds
:disable_system_sounds
    echo Disabling system sounds...
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SoundSchemes" /v Current /t REG_SZ /d "No Sounds" /f >nul 2>&1
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\SoundSchemes" /v Current /t REG_SZ /d "No Sounds" /f >nul 2>&1
    echo System sounds have been disabled.

:: Completion
:completion
    echo Operation completed!
    echo All system sounds have been permanently deleted and disabled.
    pause
    exit /b