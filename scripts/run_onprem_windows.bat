@echo off
REM ==============================================================================
REM ParkFlow On-Premises Windows Runner
REM Launches ParkFlow on port 8501, accessible across the local network / intranet
REM ==============================================================================

title ParkFlow On-Premises Parking Management System

cd /d "%~dp0\.."

echo =====================================================================
echo   [P] ParkFlow - Smart Parking Bay Management System (On-Premises)
echo =====================================================================
echo.

REM Set Persistent Database Directory
if not exist "data" mkdir data
if exist "parking.db" (
    if not exist "data\parking.db" copy /y "parking.db" "data\parking.db" >nul
)
set PARKFLOW_DB_PATH=data\parking.db

echo [INFO] Database Location: %CD%\%PARKFLOW_DB_PATH%
echo [INFO] Checking Python runtime...

python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python was not found on PATH. Please install Python 3.10+ and add it to PATH.
    pause
    exit /b 1
)

REM Check if port 8501 is already listening
netstat -ano | findstr ":8501" | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [WARNING] A service is already active on port 8501.
    echo [INFO] ParkFlow is already running and accessible!
    echo [INFO] Local URL:   http://localhost:8501
    goto :end
)

echo [INFO] Installing / verifying required libraries...
python -m pip install -q -r requirements.txt

echo.
echo [INFO] Starting ParkFlow production server...
echo [INFO] Local Access:   http://localhost:8501
echo [INFO] Network Access: http://0.0.0.0:8501
echo [INFO] Keep this window open or use 'run_background.vbs' for invisible mode.
echo [INFO] Press Ctrl+C to stop.
echo.

python -m streamlit run app.py --server.port=8501 --server.address=0.0.0.0 --server.headless=true --browser.gatherUsageStats=false

:end
pause
