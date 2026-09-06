@echo off
title ParkFlow Auto-Start Removal
echo =====================================================================
echo   [P] Disabling ParkFlow Auto-Start on Windows Startup
echo =====================================================================
echo.

if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ParkFlow.lnk" (
    del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ParkFlow.lnk"
    echo [SUCCESS] Auto-start shortcut removed from Windows Startup folder.
) else (
    echo [INFO] ParkFlow was not configured in Windows Startup.
)

echo.
pause
