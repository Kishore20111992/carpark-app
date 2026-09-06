@echo off
title Stop ParkFlow Service
echo =====================================================================
echo   [P] Stopping ParkFlow On-Premises Service...
echo =====================================================================
echo.

setlocal enabledelayedexpansion
set FOUND=0

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8501" ^| findstr "LISTENING"') do (
    set PID=%%a
    if not "!PID!"=="" (
        echo [INFO] Terminating process ID !PID! on port 8501...
        taskkill /PID !PID! /F >nul 2>&1
        set FOUND=1
    )
)

if "!FOUND!"=="1" (
    echo [SUCCESS] ParkFlow service on port 8501 stopped.
) else (
    echo [INFO] No active ParkFlow service found running on port 8501.
)

echo.
if "%1"=="--no-pause" goto :eof
pause
