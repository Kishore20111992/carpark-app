#!/usr/bin/env python3
"""
ParkFlow Database Backup Utility (On-Premises Disaster Recovery)
Performs zero-downtime hot backups using SQLite's online backup API.
Can be scheduled via Linux cron or Windows Task Scheduler.
"""

import os
import sqlite3
import shutil
from datetime import datetime
import glob

BACKUP_RETENTION_DAYS = 14

def backup_database(src_db=None, backup_dir="backups"):
    """Creates a timestamped snapshot of the SQLite database."""
    if src_db is None:
        src_db = os.getenv("PARKFLOW_DB_PATH")
        if not src_db:
            src_db = "data/parking.db" if os.path.exists("data/parking.db") else "parking.db"

    if not os.path.exists(src_db):
        print(f"[ERROR] Source database '{src_db}' does not exist. Run ParkFlow first to initialize.")
        return None

    os.makedirs(backup_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest_file = os.path.join(backup_dir, f"parking_backup_{timestamp}.db")

    print(f"[INFO] Starting live backup of '{src_db}' to '{dest_file}'...")
    
    # Use SQLite Online Backup API for consistency
    src_conn = sqlite3.connect(src_db)
    dest_conn = sqlite3.connect(dest_file)
    with dest_conn:
        src_conn.backup(dest_conn, pages=100)
    dest_conn.close()
    src_conn.close()

    file_size_kb = round(os.path.getsize(dest_file) / 1024, 2)
    print(f"[SUCCESS] Backup successfully created: {dest_file} ({file_size_kb} KB)")

    # Clean old backups beyond retention
    prune_old_backups(backup_dir, max_keep=30)
    return dest_file

def prune_old_backups(backup_dir, max_keep=30):
    """Retains the most recent backup files and cleans up older ones."""
    pattern = os.path.join(backup_dir, "parking_backup_*.db")
    backups = sorted(glob.glob(pattern), key=os.path.getmtime, reverse=True)
    if len(backups) > max_keep:
        for old in backups[max_keep:]:
            try:
                os.remove(old)
                print(f"[PRUNE] Removed old backup: {old}")
            except Exception as e:
                print(f"[WARN] Failed to remove {old}: {e}")

if __name__ == "__main__":
    backup_database()
