@echo off
title ParkFlow Status Checker
echo =====================================================================
echo   [P] ParkFlow On-Premises Service Status
echo =====================================================================
echo.

setlocal enabledelayedexpansion
set RUNNING=0
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8501" ^| findstr "LISTENING"') do (
    set PID=%%a
    set RUNNING=1
)

if "!RUNNING!"=="1" (
    echo [STATUS] ONLINE - Process ID: !PID!
    echo.
    echo [ACCESS URLS]
    echo   - Local Workstation:    http://localhost:8501
    echo   - Local LAN / Wi-Fi:    http://10.9.240.129:8501
    echo.
    echo [DATABASE]
    echo   - Path: %~dp0..\data\parking.db
) else (
    echo [STATUS] OFFLINE
    echo [INFO] ParkFlow is not currently running.
    echo [INFO] Run 'run_onprem_windows.bat' or 'run_background.vbs' to start it.
)

echo.
if "%1"=="--no-pause" goto :eof
pause
