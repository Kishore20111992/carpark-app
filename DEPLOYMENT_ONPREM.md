# 🏢 ParkFlow - On-Premises Deployment & Operations Guide

This guide provides complete instructions for deploying and running **ParkFlow** on private on-premises infrastructure (local physical servers, bare-metal machines, internal VMware/Hyper-V virtual machines, or corporate intranets).

---

## 🏗️ Architecture Overview

```
                          [ Local Corporate Intranet / LAN ]
                                         │
                                         ▼
                             ┌───────────────────────┐
                             │    Nginx Proxy (80)   │
                             │  (SSL / TLS Term 443) │
                             └───────────┬───────────┘
                                         │  (WebSocket + HTTP)
                                         ▼
                             ┌───────────────────────┐
                             │  ParkFlow App (8501)  │
                             │  (Streamlit Engine)   │
                             └───────────┬───────────┘
                                         │
                                         ▼
                             ┌───────────────────────┐
                             │ Persistent SQLite DB  │
                             │ (/app/data/parking.db)│
                             └───────────────────────┘
```

- **Zero Cloud Dependencies**: The system runs entirely within your perimeter without needing external cloud connectivity.
- **Data Sovereignty**: All customer license plates, payment records, and bay statuses reside in a local SQLite file.
- **WebSocket Reactive Stream**: Nginx is pre-configured with `Upgrade` headers for instant UI updates.

---

## 🚀 Deployment Option 1: Docker Compose (Recommended)

Docker Compose provides container isolation, automatic service restart on server reboot, and simplified dependency management.

### 1. Prerequisites
- Docker Engine 24.0+ and Docker Compose v2+ installed on the host.

### 2. Quickstart
```bash
# 1. Clone or copy the project folder to the on-prem server
cd /opt/parkflow # (or your chosen path)

# 2. Build and launch the container stack in background
docker compose up -d --build
```

### 3. Verification
Check container health:
```bash
docker compose ps
```

Access the application from any computer on the local network:
- **Intranet HTTP URL**: `http://<SERVER_IP_ADDRESS>` (Port 80 via Nginx)
- **Direct App URL**: `http://<SERVER_IP_ADDRESS>:8501`

### 4. Container Management Commands
- **View Live Logs**:
  ```bash
  docker compose logs -f parkflow-app
  ```
- **Restart Application**:
  ```bash
  docker compose restart
  ```
- **Stop Application**:
  ```bash
  docker compose down
  ```
- **Database Location**: The database is stored at `./data/parking.db` on the host machine and is never lost when containers restart or rebuild.

---

## 🐧 Deployment Option 2: Linux Systemd (Bare-Metal / VM)

If Docker is not used in your organization, run ParkFlow directly via Python and `systemd`.

### 1. Automated Setup
Run the automated installation script with root privileges:
```bash
sudo chmod +x scripts/deploy_linux.sh
sudo ./scripts/deploy_linux.sh
```
Select **Option 2 (Native Systemd)**. The script will:
1. Create a dedicated low-privilege `parkflow` system user.
2. Install Python virtualenv at `/opt/parkflow/venv`.
3. Install dependencies from `requirements.txt`.
4. Register and start `/etc/systemd/system/parkflow.service`.

### 2. Managing the Service
- **Check Status**: `sudo systemctl status parkflow`
- **Restart Service**: `sudo systemctl restart parkflow`
- **Stop Service**: `sudo systemctl stop parkflow`
- **View Live Logs**: `sudo journalctl -u parkflow -f`

---

## 🪟 Deployment Option 3: Windows On-Premises (Current Machine)

ParkFlow includes a full turnkey management suite for Windows on-premises deployment:

### 1. Operations & Management Scripts (`scripts/`)
| Script | Description |
|---|---|
| [`run_onprem_windows.bat`](file:///e:/mainframe-storage-app/scripts/run_onprem_windows.bat) | Starts the server in an interactive console window with live logs and port collision prevention. |
| [`run_background.vbs`](file:///e:/mainframe-storage-app/scripts/run_background.vbs) | Starts the server completely silently in the background (no visible command prompt). |
| [`status_onprem_windows.bat`](file:///e:/mainframe-storage-app/scripts/status_onprem_windows.bat) | Checks live service status, active PID, local URL, LAN/Wi-Fi IP URL, and database health. |
| [`stop_onprem_windows.bat`](file:///e:/mainframe-storage-app/scripts/stop_onprem_windows.bat) | Gracefully terminates any running ParkFlow process on port 8501. |
| [`enable_autostart.bat`](file:///e:/mainframe-storage-app/scripts/enable_autostart.bat) | Configures Windows Startup (`shell:startup`) so ParkFlow starts automatically on PC reboot. |
| [`disable_autostart.bat`](file:///e:/mainframe-storage-app/scripts/disable_autostart.bat) | Disables automatic startup on Windows boot. |
| [`setup_firewall.bat`](file:///e:/mainframe-storage-app/scripts/setup_firewall.bat) | Self-elevating administrator batch file to configure Windows Firewall for port 8501. |

### 2. Desktop Shortcut
- A 1-click shortcut (`ParkFlow Smart Parking.url`) has been created on your **Desktop** and in the project folder root. Double-clicking it opens the dashboard immediately in your default browser.

### 3. Network & LAN Access
Any device (cashier desktop, barrier POS tablet, guard mobile phone) connected to the local network or Wi-Fi can access the system at:
- **Local Workstation**: `http://localhost:8501`
- **Intranet / Local LAN**: `http://10.9.240.129:8501`

---

## 🔒 Enterprise SSL / HTTPS Configuration (Optional)

To enable HTTPS with company internal SSL certificates:

1. Copy your SSL certificate and private key into `nginx/certs/`:
   ```bash
   cp your_company.crt nginx/certs/parkflow.crt
   cp your_company.key nginx/certs/parkflow.key
   ```
2. Open [`nginx/nginx.conf`](file:///e:/mainframe-storage-app/nginx/nginx.conf) and uncomment the SSL block:
   ```nginx
   listen 443 ssl http2;
   ssl_certificate /etc/nginx/certs/parkflow.crt;
   ssl_certificate_key /etc/nginx/certs/parkflow.key;
   ```
3. Restart Nginx:
   ```bash
   docker compose restart parkflow-proxy
   ```

---

## 🛡️ Firewall & Network Rules

Ensure the following inbound ports are open on the on-prem host firewall:

| Port | Protocol | Purpose | Access Scope |
|---|---|---|---|
| **80** | TCP (HTTP) | Nginx Reverse Proxy | Local Intranet / Subnet |
| **443** | TCP (HTTPS) | Secure Nginx (if enabled) | Local Intranet / Subnet |
| **8501** | TCP (HTTP) | Direct Streamlit App Port | Admin / Debug Only |

### Example Linux Firewall (UFW):
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 💾 Automated Database Backups (Disaster Recovery)

ParkFlow includes a hot-backup utility ([`scripts/backup_db.py`](file:///e:/mainframe-storage-app/scripts/backup_db.py)) that takes point-in-time snapshots of `parking.db` without locking the database or interrupting check-ins.

### Test Backup Manually
```bash
python scripts/backup_db.py
```
Backups are saved to `./backups/parking_backup_YYYYMMDD_HHMMSS.db`.

### Schedule Daily Backups (Linux Cron)
Add this line to `crontab -e` to run automated backups every night at 2:00 AM:
```bash
0 2 * * * cd /opt/parkflow && /opt/parkflow/venv/bin/python scripts/backup_db.py >> /var/log/parkflow_backup.log 2>&1
```

### Restoring from Backup
If data recovery is needed:
1. Stop the application: `docker compose down` or `sudo systemctl stop parkflow`.
2. Replace `data/parking.db` with the chosen backup file:
   ```bash
   cp backups/parking_backup_YYYYMMDD_HHMMSS.db data/parking.db
   ```
3. Start the application: `docker compose up -d` or `sudo systemctl start parkflow`.
