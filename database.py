import sqlite3
import os
from datetime import datetime, timedelta

DEFAULT_DB_PATH = os.getenv("PARKFLOW_DB_PATH", "parking.db")

def get_connection(db_path=None):
    """Returns a SQLite connection configured for dict-like rows."""
    if db_path is None:
        db_path = DEFAULT_DB_PATH
    db_dir = os.path.dirname(db_path)
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=30.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA journal_mode=WAL")
    except Exception:
        pass
    return conn

def init_db(db_path=DEFAULT_DB_PATH):
    """Initializes tables and seeds default rates and slots if not present."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        
        # 1. Slots table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS slots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                slot_number TEXT UNIQUE NOT NULL,
                zone TEXT NOT NULL,
                floor INTEGER NOT NULL,
                slot_type TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'Available',
                notes TEXT DEFAULT ''
            )
        """)
        
        # 2. Rates table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS rates (
                vehicle_type TEXT PRIMARY KEY,
                hourly_rate REAL NOT NULL,
                min_charge REAL NOT NULL,
                description TEXT
            )
        """)

        # 3. Tickets table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tickets (
                ticket_id TEXT PRIMARY KEY NOT NULL,
                vehicle_number TEXT NOT NULL,
                vehicle_type TEXT NOT NULL,
                driver_name TEXT,
                driver_phone TEXT,
                slot_id INTEGER NOT NULL,
                slot_number TEXT NOT NULL,
                entry_time TEXT NOT NULL,
                exit_time TEXT,
                duration_minutes INTEGER DEFAULT 0,
                rate_per_hour REAL NOT NULL,
                is_ev_charging INTEGER DEFAULT 0,
                ev_charging_fee REAL DEFAULT 0.0,
                subtotal REAL DEFAULT 0.0,
                tax REAL DEFAULT 0.0,
                total_fee REAL DEFAULT 0.0,
                payment_status TEXT DEFAULT 'Pending',
                payment_method TEXT DEFAULT '',
                is_active INTEGER DEFAULT 1,
                FOREIGN KEY (slot_id) REFERENCES slots(id)
            )
        """)

        # 4. Reservations table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS reservations (
                reservation_id TEXT PRIMARY KEY,
                customer_name TEXT NOT NULL,
                customer_phone TEXT NOT NULL,
                vehicle_number TEXT NOT NULL,
                vehicle_type TEXT NOT NULL,
                slot_id INTEGER NOT NULL,
                slot_number TEXT NOT NULL,
                reserved_for TEXT NOT NULL,
                created_at TEXT NOT NULL,
                status TEXT DEFAULT 'Active',
                deposit_amount REAL DEFAULT 0.0,
                payment_method TEXT DEFAULT 'UPI',
                payment_status TEXT DEFAULT 'Paid',
                grace_period_mins INTEGER DEFAULT 60,
                forfeited_at TEXT DEFAULT '',
                FOREIGN KEY (slot_id) REFERENCES slots(id)
            )
        """)
        
        # Ensure fastag_id, billing_model, and prepaid deposit columns exist on tickets
        cursor.execute("PRAGMA table_info(tickets)")
        ticket_cols = [c[1] for c in cursor.fetchall()]
        if "fastag_id" not in ticket_cols:
            cursor.execute("ALTER TABLE tickets ADD COLUMN fastag_id TEXT DEFAULT ''")
        if "billing_model" not in ticket_cols:
            cursor.execute("ALTER TABLE tickets ADD COLUMN billing_model TEXT DEFAULT 'prorated_30min'")
        if "prepaid_deposit" not in ticket_cols:
            cursor.execute("ALTER TABLE tickets ADD COLUMN prepaid_deposit REAL DEFAULT 0.0")
        if "reservation_id" not in ticket_cols:
            cursor.execute("ALTER TABLE tickets ADD COLUMN reservation_id TEXT DEFAULT ''")

        # Ensure deposit and no-show columns exist on reservations
        cursor.execute("PRAGMA table_info(reservations)")
        res_cols = [c[1] for c in cursor.fetchall()]
        if "deposit_amount" not in res_cols:
            cursor.execute("ALTER TABLE reservations ADD COLUMN deposit_amount REAL DEFAULT 0.0")
        if "payment_method" not in res_cols:
            cursor.execute("ALTER TABLE reservations ADD COLUMN payment_method TEXT DEFAULT 'UPI'")
        if "payment_status" not in res_cols:
            cursor.execute("ALTER TABLE reservations ADD COLUMN payment_status TEXT DEFAULT 'Paid'")
        if "grace_period_mins" not in res_cols:
            cursor.execute("ALTER TABLE reservations ADD COLUMN grace_period_mins INTEGER DEFAULT 60")
        if "forfeited_at" not in res_cols:
            cursor.execute("ALTER TABLE reservations ADD COLUMN forfeited_at TEXT DEFAULT ''")

        conn.commit()

    # Seed data if newly created
    seed_initial_data(db_path)

def seed_initial_data(db_path=DEFAULT_DB_PATH):
    """Populates standard parking rates and 24 diverse parking bays if empty."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        
        # Check rates
        cursor.execute("SELECT COUNT(*) FROM rates")
        if cursor.fetchone()[0] == 0:
            initial_rates = [
                ("Bike", 20.00, 20.00, "Two-wheelers / Motorcycles / Scooters"),
                ("Car", 50.00, 50.00, "Standard Sedans / Hatchbacks / Crossovers"),
                ("SUV", 70.00, 70.00, "Full-size SUVs / Minivans / Pickups"),
                ("EV", 60.00, 60.00, "Electric Vehicles (Dedicated Charger Stall)"),
                ("Handicap", 30.00, 30.00, "Accessible Bays near Elevators/Entrance")
            ]
            cursor.executemany(
                "INSERT INTO rates (vehicle_type, hourly_rate, min_charge, description) VALUES (?, ?, ?, ?)",
                initial_rates
            )

        # Check slots
        cursor.execute("SELECT COUNT(*) FROM slots")
        if cursor.fetchone()[0] == 0:
            slots_data = [
                # Zone A - Ground Floor (Quick in/out, EV Charging, Accessible)
                ("A-01", "Zone A (Ground)", 0, "Handicap", "Available", "Near main entrance door"),
                ("A-02", "Zone A (Ground)", 0, "Handicap", "Available", "Wheelchair accessible ramp access"),
                ("A-03", "Zone A (Ground)", 0, "EV", "Available", "50kW DC Fast Charger Level 2"),
                ("A-04", "Zone A (Ground)", 0, "EV", "Available", "22kW AC Type-2 Charger"),
                ("A-05", "Zone A (Ground)", 0, "EV", "Available", "22kW AC Type-2 Charger"),
                ("A-06", "Zone A (Ground)", 0, "Car", "Available", "Priority Bay"),
                ("A-07", "Zone A (Ground)", 0, "Car", "Available", "Standard Bay"),
                ("A-08", "Zone A (Ground)", 0, "Car", "Available", "Standard Bay"),

                # Zone B - Floor 1 (Compact Cars & Two-Wheelers / Bikes)
                ("B-01", "Zone B (Level 1)", 1, "Bike", "Available", "Motorcycle designated bay"),
                ("B-02", "Zone B (Level 1)", 1, "Bike", "Available", "Motorcycle designated bay"),
                ("B-03", "Zone B (Level 1)", 1, "Bike", "Available", "Motorcycle designated bay"),
                ("B-04", "Zone B (Level 1)", 1, "Bike", "Available", "Scooter designated bay"),
                ("B-05", "Zone B (Level 1)", 1, "Car", "Available", "Compact car bay"),
                ("B-06", "Zone B (Level 1)", 1, "Car", "Available", "Compact car bay"),
                ("B-07", "Zone B (Level 1)", 1, "Car", "Available", "Compact car bay"),
                ("B-08", "Zone B (Level 1)", 1, "Car", "Available", "Compact car bay"),

                # Zone C - Floor 2 (SUV & Long Stay / Premium)
                ("C-01", "Zone C (Level 2)", 2, "SUV", "Available", "Extra wide bay for large SUVs"),
                ("C-02", "Zone C (Level 2)", 2, "SUV", "Available", "Extra wide bay for large SUVs"),
                ("C-03", "Zone C (Level 2)", 2, "SUV", "Available", "Extra wide bay for large SUVs"),
                ("C-04", "Zone C (Level 2)", 2, "Car", "Available", "Standard covered bay"),
                ("C-05", "Zone C (Level 2)", 2, "Car", "Available", "Standard covered bay"),
                ("C-06", "Zone C (Level 2)", 2, "Car", "Available", "Standard covered bay"),
                ("C-07", "Zone C (Level 2)", 2, "Car", "Available", "Standard covered bay"),
                ("C-08", "Zone C (Level 2)", 2, "Car", "Available", "Standard covered bay"),
            ]
            cursor.executemany(
                "INSERT INTO slots (slot_number, zone, floor, slot_type, status, notes) VALUES (?, ?, ?, ?, ?, ?)",
                slots_data
            )
            conn.commit()

def reset_to_clean_production(db_path=None):
    """Resets the facility to a clean production state (all bays Available, zero mock data)."""
    target_paths = [db_path] if db_path else (["parking.db", "data/parking.db"] if os.path.exists("data/parking.db") else [DEFAULT_DB_PATH])
    for p in target_paths:
        if os.path.exists(p):
            with get_connection(p) as conn:
                conn.execute("DELETE FROM tickets")
                conn.execute("DELETE FROM reservations")
                conn.execute("UPDATE slots SET status = 'Available'")
                conn.commit()

# --- HELPER QUERIES ---

def get_slots(db_path=DEFAULT_DB_PATH, zone=None, slot_type=None, status=None):
    """Fetches slots with optional filtering and joined active vehicle details."""
    query = """
        SELECT 
            s.*,
            t.ticket_id,
            t.vehicle_number,
            t.entry_time,
            t.driver_name
        FROM slots s
        LEFT JOIN tickets t ON s.id = t.slot_id AND t.is_active = 1
        WHERE 1=1
    """
    params = []
    if zone:
        query += " AND s.zone = ?"
        params.append(zone)
    if slot_type:
        query += " AND s.slot_type = ?"
        params.append(slot_type)
    if status:
        query += " AND s.status = ?"
        params.append(status)
    query += " ORDER BY s.floor ASC, s.slot_number ASC"
    
    with get_connection(db_path) as conn:
        return [dict(r) for r in conn.execute(query, params).fetchall()]

def get_slot(slot_id, db_path=DEFAULT_DB_PATH):
    """Fetches a single slot by ID."""
    with get_connection(db_path) as conn:
        row = conn.execute("SELECT * FROM slots WHERE id = ?", (slot_id,)).fetchone()
        return dict(row) if row else None

def get_slot_by_number(slot_number, db_path=DEFAULT_DB_PATH):
    """Fetches a slot by its unique bay number."""
    with get_connection(db_path) as conn:
        row = conn.execute("SELECT * FROM slots WHERE slot_number = ?", (slot_number,)).fetchone()
        return dict(row) if row else None

def set_slot_status(slot_id, status, db_path=DEFAULT_DB_PATH):
    """Updates the status of a parking slot."""
    with get_connection(db_path) as conn:
        conn.execute("UPDATE slots SET status = ? WHERE id = ?", (status, slot_id))
        conn.commit()

def add_slot(slot_number, zone, floor, slot_type, notes="", status="Available", db_path=DEFAULT_DB_PATH):
    """Inserts a new parking slot."""
    clean_num = str(slot_number).strip().upper()
    if not clean_num:
        raise ValueError("Bay number cannot be empty.")
    clean_type = str(slot_type).strip()
    if clean_type.upper() in ["EV", "SUV"]:
        clean_type = clean_type.upper()
    else:
        clean_type = clean_type.capitalize()
    
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        existing = cursor.execute("SELECT id FROM slots WHERE slot_number = ?", (clean_num,)).fetchone()
        if existing:
            raise ValueError(f"Bay number '{clean_num}' already exists.")
        cursor.execute(
            "INSERT INTO slots (slot_number, zone, floor, slot_type, status, notes) VALUES (?, ?, ?, ?, ?, ?)",
            (clean_num, str(zone).strip(), int(floor), clean_type, str(status).strip(), str(notes).strip())
        )
        conn.commit()
        return cursor.lastrowid

def update_slot(slot_id, slot_number=None, zone=None, floor=None, slot_type=None, status=None, notes=None, db_path=DEFAULT_DB_PATH):
    """Updates an existing parking slot."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        existing = cursor.execute("SELECT * FROM slots WHERE id = ?", (slot_id,)).fetchone()
        if not existing:
            raise ValueError(f"Slot ID {slot_id} not found.")
        
        cur = dict(existing)
        new_num = str(slot_number).strip().upper() if slot_number is not None and str(slot_number).strip() else cur["slot_number"]
        new_zone = str(zone).strip() if zone is not None and str(zone).strip() else cur["zone"]
        new_floor = int(floor) if floor is not None else cur["floor"]
        new_type = str(slot_type).strip() if slot_type is not None and str(slot_type).strip() else cur["slot_type"]
        if new_type.upper() in ["EV", "SUV"]:
            new_type = new_type.upper()
        else:
            new_type = new_type.capitalize()
            
        new_status = str(status).strip() if status is not None and str(status).strip() else cur["status"]
        new_notes = str(notes).strip() if notes is not None else cur["notes"]

        if new_num != cur["slot_number"]:
            dup = cursor.execute("SELECT id FROM slots WHERE slot_number = ? AND id != ?", (new_num, slot_id)).fetchone()
            if dup:
                raise ValueError(f"Bay number '{new_num}' is already in use by another slot.")

        cursor.execute("""
            UPDATE slots
            SET slot_number = ?, zone = ?, floor = ?, slot_type = ?, status = ?, notes = ?
            WHERE id = ?
        """, (new_num, new_zone, new_floor, new_type, new_status, new_notes, slot_id))
        conn.commit()
        return get_slot(slot_id, db_path)

def delete_slot(slot_id, db_path=DEFAULT_DB_PATH):
    """Deletes a parking slot if it is not currently occupied or reserved."""
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        slot = cursor.execute("SELECT * FROM slots WHERE id = ?", (slot_id,)).fetchone()
        if not slot:
            raise ValueError(f"Slot ID {slot_id} not found.")
        if slot["status"] == "Occupied":
            raise ValueError(f"Cannot delete Bay {slot['slot_number']}: currently occupied by a parked vehicle.")
        if slot["status"] == "Reserved":
            raise ValueError(f"Cannot delete Bay {slot['slot_number']}: currently reserved for an upcoming booking.")
        
        cursor.execute("DELETE FROM slots WHERE id = ?", (slot_id,))
        conn.commit()
        return True

def get_rates(db_path=DEFAULT_DB_PATH):
    """Returns rate mapping by vehicle type."""
    with get_connection(db_path) as conn:
        rows = conn.execute("SELECT * FROM rates").fetchall()
        return {r["vehicle_type"]: dict(r) for r in rows}

def update_rate(vehicle_type, hourly_rate, min_charge, db_path=DEFAULT_DB_PATH):
    """Updates rates for a specific vehicle type."""
    with get_connection(db_path) as conn:
        conn.execute(
            "UPDATE rates SET hourly_rate = ?, min_charge = ? WHERE vehicle_type = ?",
            (hourly_rate, min_charge, vehicle_type)
        )
        conn.commit()

def get_active_tickets(db_path=DEFAULT_DB_PATH):
    """Returns all currently parked vehicle tickets."""
    with get_connection(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM tickets WHERE is_active = 1 ORDER BY entry_time DESC"
        ).fetchall()
        return [dict(r) for r in rows]

def get_ticket_by_id(ticket_id, db_path=DEFAULT_DB_PATH):
    """Fetches ticket by ticket_id."""
    with get_connection(db_path) as conn:
        row = conn.execute("SELECT * FROM tickets WHERE ticket_id = ?", (ticket_id,)).fetchone()
        return dict(row) if row else None

def find_active_ticket_by_vehicle(vehicle_number, db_path=DEFAULT_DB_PATH):
    """Finds active ticket by vehicle registration number."""
    with get_connection(db_path) as conn:
        row = conn.execute(
            "SELECT * FROM tickets WHERE UPPER(vehicle_number) = UPPER(?) AND is_active = 1",
            (vehicle_number.strip(),)
        ).fetchone()
        return dict(row) if row else None

def find_active_reservation_by_vehicle(vehicle_number, db_path=DEFAULT_DB_PATH):
    """Finds active reservation by vehicle registration number."""
    if not vehicle_number or not vehicle_number.strip():
        return None
    clean_v = vehicle_number.strip().upper().replace("-", "").replace(" ", "")
    with get_connection(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM reservations WHERE status = 'Active' ORDER BY created_at DESC"
        ).fetchall()
        for r in rows:
            r_clean = r["vehicle_number"].strip().upper().replace("-", "").replace(" ", "")
            if r_clean == clean_v:
                return dict(r)
        return None

def get_all_tickets(db_path=DEFAULT_DB_PATH, limit=100):
    """Returns ticket history (active & completed)."""
    with get_connection(db_path) as conn:
        rows = conn.execute(
            "SELECT * FROM tickets ORDER BY entry_time DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]
