@echo off
title ParkFlow Auto-Start Setup
echo =====================================================================
echo   [P] Enabling ParkFlow Auto-Start on Windows Startup
echo =====================================================================
echo.

powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut(\"$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ParkFlow.lnk\"); $s.TargetPath = 'wscript.exe'; $s.Arguments = '\"' + (Resolve-Path 'scripts\run_background.vbs').Path + '\"'; $s.WorkingDirectory = (Get-Location).Path; $s.Save()"

if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ParkFlow.lnk" (
    echo [SUCCESS] Auto-start shortcut created in Windows Startup!
    echo [INFO] ParkFlow will now start automatically whenever you boot or log into Windows.
) else (
    echo [ERROR] Failed to create auto-start shortcut.
)

echo.
pause
