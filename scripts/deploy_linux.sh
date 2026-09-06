#!/usr/bin/env bash
# ==============================================================================
# ParkFlow On-Premises Linux Deployment Script
# Supports: Ubuntu, Debian, RHEL, CentOS, Rocky Linux
# ==============================================================================

set -e

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

echo "======================================================================"
echo "  🅿️  ParkFlow On-Premises Deployment Utility"
echo "======================================================================"
echo ""
echo "Select deployment mode:"
echo "  1) Docker Compose (Recommended - Containerized with Nginx)"
echo "  2) Native Systemd Service (Bare-Metal / VM Python)"
echo ""
read -rp "Enter choice [1 or 2, default 1]: " DEPLOY_MODE
DEPLOY_MODE=${DEPLOY_MODE:-1}

if [ "$DEPLOY_MODE" = "1" ]; then
    echo ""
    echo "--- Deploying via Docker Compose ---"
    
    if ! command -v docker &> /dev/null; then
        echo "[ERROR] Docker is not installed. Please install docker before proceeding."
        exit 1
    fi

    # Ensure persistent data directory exists
    mkdir -p data
    mkdir -p nginx/certs
    chmod 755 data

    echo "[INFO] Building and launching containers..."
    docker compose up -d --build

    echo ""
    echo "======================================================================"
    echo "  ✅ ParkFlow Successfully Deployed via Docker Compose!"
    echo "  Intranet / LAN Access: http://$(hostname -I | awk '{print $1}')"
    echo "  Direct App Port:       http://$(hostname -I | awk '{print $1}'):8501"
    echo "======================================================================"
    docker compose ps

elif [ "$DEPLOY_MODE" = "2" ]; then
    echo ""
    echo "--- Deploying via Native Linux Systemd ---"

    if [ "$EUID" -ne 0 ]; then
        echo "[ERROR] Please run as root (sudo ./scripts/deploy_linux.sh) to configure systemd."
        exit 1
    fi

    INSTALL_PATH="/opt/parkflow"
    echo "[INFO] Target installation directory: $INSTALL_PATH"
    
    # Create user if needed
    if ! id -u parkflow >/dev/null 2>&1; then
        useradd -r -s /bin/false -d "$INSTALL_PATH" parkflow
        echo "[INFO] Created system user: parkflow"
    fi

    mkdir -p "$INSTALL_PATH"
    mkdir -p "$INSTALL_PATH/data"

    echo "[INFO] Copying application files..."
    cp -r "$APP_DIR"/* "$INSTALL_PATH/"

    echo "[INFO] Setting up Python virtual environment..."
    python3 -m venv "$INSTALL_PATH/venv"
    "$INSTALL_PATH/venv/bin/pip" install --upgrade pip
    "$INSTALL_PATH/venv/bin/pip" install -r "$INSTALL_PATH/requirements.txt"

    chown -R parkflow:parkflow "$INSTALL_PATH"
    chmod 750 "$INSTALL_PATH/data"

    echo "[INFO] Registering systemd service..."
    cp "$INSTALL_PATH/parkflow.service" /etc/systemd/system/parkflow.service
    systemctl daemon-reload
    systemctl enable parkflow.service
    systemctl restart parkflow.service

    echo ""
    echo "======================================================================"
    echo "  ✅ ParkFlow Systemd Service is Active!"
    echo "  URL: http://$(hostname -I | awk '{print $1}'):8501"
    echo "  Status check: sudo systemctl status parkflow"
    echo "  Logs:         sudo journalctl -u parkflow -f"
    echo "======================================================================"
else
    echo "Invalid choice. Aborting."
    exit 1
fi
