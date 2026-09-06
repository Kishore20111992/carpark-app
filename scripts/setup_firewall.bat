@echo off
title Configure Windows Firewall for ParkFlow
echo =====================================================================
echo   [P] Configuring Windows Firewall for ParkFlow On-Premises (Port 8501)
echo =====================================================================
echo.

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Requesting Administrator permissions...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo [INFO] Adding inbound firewall rule for TCP port 8501...
netsh advfirewall firewall add rule name="ParkFlow Smart Parking System" dir=in action=allow protocol=TCP localport=8501 profile=private,domain >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Windows Firewall successfully configured!
    echo [INFO] Port 8501 is now open for local network devices.
) else (
    echo [ERROR] Failed to add firewall rule.
)

echo.
pause
