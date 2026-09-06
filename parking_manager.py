import os
import re
import math
import random
import time
import threading
from datetime import datetime, timedelta
import pandas as pd
from database import (
    DEFAULT_DB_PATH,
    get_connection,
    get_slots,
    get_slot,
    get_slot_by_number,
    set_slot_status,
    add_slot,
    update_slot,
    delete_slot,
    get_rates,
    get_ticket_by_id,
    find_active_ticket_by_vehicle,
    get_active_tickets,
    get_all_tickets,
    find_active_reservation_by_vehicle
)

CURRENCY_SYMBOL = os.getenv("PARKFLOW_CURRENCY", "₹")
EV_CHARGING_FLAT_FEE = float(os.getenv("PARKFLOW_EV_FEE", "150.00"))  # Flat access fee for EV fast chargers (₹150)
TAX_RATE = float(os.getenv("PARKFLOW_TAX_RATE", "0.18"))              # 18% GST on parking facility services

import uuid

def validate_phone_number(phone_str, required=False):
    """
    Strict phone number validation:
    - Rejects any alphabetic characters (e.g. 'abc', 'xyz123').
    - Requires at least 10 numeric digits.
    - Allows standard international formats (10 to 15 digits).
    - Formats standard 10-digit numbers cleanly as +91 XXXXX XXXXX.
    """
    if phone_str is None:
        if required:
            raise ValueError("Contact phone number is required.")
        return ""

    clean = str(phone_str).strip()
    if not clean:
        if required:
            raise ValueError("Contact phone number is required.")
        return ""

    # Reject any alphabetic characters
    if any(c.isalpha() for c in clean):
        raise ValueError(f"Invalid phone number '{clean}'. Phone numbers cannot contain alphabetic letters.")

    # Extract digits only
    digits = re.sub(r"\D", "", clean)

    if len(digits) < 10:
        raise ValueError(f"Phone number '{clean}' is too short ({len(digits)} digits). Must contain at least 10 digits.")
    if len(digits) > 15:
        raise ValueError(f"Phone number '{clean}' is too long ({len(digits)} digits). Maximum 15 digits allowed.")

    if len(digits) == 10:
        return f"+91 {digits[:5]} {digits[5:]}"
    elif len(digits) == 12 and digits.startswith("91"):
        return f"+91 {digits[2:7]} {digits[7:]}"
    else:
        return clean

def generate_ticket_id():
    """Generates a unique readable ticket identifier."""
    now_str = datetime.now().strftime("%Y%m%d-%H%M%S")
    rand_hex = uuid.uuid4().hex[:4].upper()
    return f"TKT-{now_str}-{rand_hex}"

def generate_reservation_id():
    """Generates a unique reservation identifier."""
    now_str = datetime.now().strftime("%Y%m%d-%H%M%S")
    rand_hex = uuid.uuid4().hex[:4].upper()
    return f"RES-{now_str}-{rand_hex}"

def suggest_best_slot(vehicle_type, is_ev_charging=False, db_path=DEFAULT_DB_PATH):
    """
    Intelligent slot recommendation:
    Finds the optimal available slot based on vehicle type, charging needs, and proximity.
    """
    all_available = get_slots(db_path=db_path, status="Available")
    if not all_available:
        return None

    # Priority mapping
    if is_ev_charging or vehicle_type == "EV":
        preferred_types = ["EV", "Car"]
    elif vehicle_type == "Bike":
        preferred_types = ["Bike"]
    elif vehicle_type == "Handicap":
        preferred_types = ["Handicap", "Car"]
    elif vehicle_type == "SUV":
        preferred_types = ["SUV", "Car"]
    else:  # Car
        preferred_types = ["Car", "SUV"]

    for p_type in preferred_types:
        candidates = [s for s in all_available if s["slot_type"] == p_type]
        if candidates:
            # Sort by floor (lowest first) and slot number
            candidates.sort(key=lambda s: (s["floor"], s["slot_number"]))
            return candidates[0]

    # Fallback to any available if suitable
    if vehicle_type != "Bike":
        non_bike = [s for s in all_available if s["slot_type"] not in ("Bike", "Handicap")]
        if non_bike:
            non_bike.sort(key=lambda s: (s["floor"], s["slot_number"]))
            return non_bike[0]

    return None

def check_in_vehicle(
    vehicle_number,
    vehicle_type,
    driver_name="",
    driver_phone="",
    slot_id=None,
    is_ev_charging=False,
    fastag_id="",
    prepaid_deposit=0.0,
    reservation_id="",
    db_path=DEFAULT_DB_PATH
):
    """
    Executes vehicle check-in:
    - Validates no active ticket exists for vehicle
    - Allocates specified slot or best available
    - Updates slot status to 'Occupied'
    - Creates and returns ticket (stores optional FASTag RFID ID and prepaid reservation credit)
    """
    vehicle_clean = vehicle_number.strip().upper()
    if not vehicle_clean:
        raise ValueError("Vehicle registration plate number is required.")

    # Check for duplicate active entry
    existing = find_active_ticket_by_vehicle(vehicle_clean, db_path=db_path)
    if existing:
        raise ValueError(f"Vehicle '{vehicle_clean}' is already parked in Slot {existing['slot_number']} (Ticket: {existing['ticket_id']}).")

    # Validate driver phone number if provided
    clean_phone = validate_phone_number(driver_phone, required=False)

    # Determine slot
    if slot_id is not None:
        target_slot = get_slot(slot_id, db_path=db_path)
        if not target_slot:
            raise ValueError(f"Slot ID {slot_id} not found.")
        if target_slot["status"] == "Reserved" and not reservation_id:
            raise ValueError(f"Slot {target_slot['slot_number']} is currently Reserved for an advance booking.")
        if target_slot["status"] not in ("Available", "Reserved"):
            raise ValueError(f"Slot {target_slot['slot_number']} is currently {target_slot['status']}.")
        if target_slot["slot_type"] != vehicle_type and target_slot["slot_type"] in ("Bike", "EV", "Handicap"):
            raise ValueError(f"Slot {target_slot['slot_number']} is designated for '{target_slot['slot_type']}' only.")
    else:
        target_slot = suggest_best_slot(vehicle_type, is_ev_charging=is_ev_charging, db_path=db_path)
        if not target_slot:
            raise ValueError(f"No suitable parking slots available for {vehicle_type}.")

    # Fetch applicable rate
    rates = get_rates(db_path=db_path)
    rate_info = rates.get(vehicle_type, {"hourly_rate": 50.00, "min_charge": 50.00})
    hourly_rate = rate_info["hourly_rate"]
    ev_fee = EV_CHARGING_FLAT_FEE if is_ev_charging else 0.0

    ticket_id = generate_ticket_id()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with get_connection(db_path) as conn:
        conn.execute("""
            INSERT INTO tickets (
                ticket_id, vehicle_number, vehicle_type, driver_name, driver_phone,
                slot_id, slot_number, entry_time, rate_per_hour, is_ev_charging,
                ev_charging_fee, payment_status, is_active, fastag_id,
                prepaid_deposit, reservation_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending', 1, ?, ?, ?)
        """, (
            ticket_id, vehicle_clean, vehicle_type, driver_name.strip(), clean_phone,
            target_slot["id"], target_slot["slot_number"], now_str, hourly_rate,
            1 if is_ev_charging else 0, ev_fee, fastag_id.strip(),
            float(prepaid_deposit or 0.0), reservation_id.strip()
        ))

        # Mark slot Occupied
        conn.execute("UPDATE slots SET status = 'Occupied' WHERE id = ?", (target_slot["id"],))
        conn.commit()

    return get_ticket_by_id(ticket_id, db_path=db_path)

def calculate_parking_bill(ticket, exit_time_dt=None, billing_model="prorated_30min", db_path=DEFAULT_DB_PATH):
    """
    Computes duration and fee breakdown for a ticket.
    
    Billing Models:
    1. 'prorated_30min' (Model B - Standard / Default):
       - 1st hour: Full base hourly rate.
       - After 1 hour: Slabs of 30 minutes charged at 50% of the hourly rate.
    2. 'hourly_block' (Ceiling / Block Rate):
       - Full hour blocks: ceil(minutes / 60) * rate.
    3. 'exact_prorata' (Per-Minute Pro-Rata):
       - 1st hour full, then exact per-minute pro-rata.
    """
    if exit_time_dt is None:
        exit_time_dt = datetime.now()

    entry_time_dt = datetime.strptime(ticket["entry_time"], "%Y-%m-%d %H:%M:%S")
    delta = exit_time_dt - entry_time_dt
    total_seconds = max(0, int(delta.total_seconds()))
    duration_minutes = math.ceil(total_seconds / 60)
    rate_per_hour = ticket["rate_per_hour"]

    extra_mins = max(0, duration_minutes - 60)
    extra_slabs = 0
    slab_rate = round(rate_per_hour / 2.0, 2)
    extra_charge = 0.0

    if billing_model == "prorated_30min":
        if duration_minutes <= 60:
            billable_hours = 1.0
            subtotal = round(rate_per_hour, 2)
        else:
            extra_slabs = math.ceil(extra_mins / 30.0)
            extra_charge = round(extra_slabs * slab_rate, 2)
            billable_hours = round(1.0 + (extra_slabs * 0.5), 1)
            subtotal = round(rate_per_hour + extra_charge, 2)
    elif billing_model == "exact_prorata":
        if duration_minutes <= 60:
            billable_hours = 1.0
            subtotal = round(rate_per_hour, 2)
        else:
            billable_hours = round(1.0 + (extra_mins / 60.0), 2)
            extra_charge = round(extra_mins * (rate_per_hour / 60.0), 2)
            subtotal = round(rate_per_hour + extra_charge, 2)
    else:  # "hourly_block"
        hours = max(1, math.ceil(duration_minutes / 60))
        billable_hours = hours
        subtotal = round(hours * rate_per_hour, 2)

    ev_fee = ticket.get("ev_charging_fee", 0.0) or 0.0
    tax = round((subtotal + ev_fee) * TAX_RATE, 2)
    total_fee = round(subtotal + ev_fee + tax, 2)

    prepaid_deposit = float(ticket.get("prepaid_deposit", 0.0) or 0.0)
    net_payable = max(0.0, round(total_fee - prepaid_deposit, 2))
    res_id = ticket.get("reservation_id", "") or ""

    return {
        "duration_minutes": duration_minutes,
        "duration_formatted": f"{duration_minutes // 60}h {duration_minutes % 60}m",
        "billable_hours": billable_hours,
        "billing_model": billing_model,
        "rate_per_hour": rate_per_hour,
        "base_first_hour_fee": rate_per_hour,
        "extra_mins": extra_mins,
        "extra_slabs": extra_slabs,
        "slab_rate": slab_rate,
        "extra_charge": extra_charge,
        "subtotal": subtotal,
        "ev_charging_fee": ev_fee,
        "tax": tax,
        "total_fee": total_fee,
        "prepaid_deposit": prepaid_deposit,
        "net_payable": net_payable,
        "reservation_id": res_id,
        "currency": CURRENCY_SYMBOL,
        "entry_time": ticket["entry_time"],
        "exit_time": exit_time_dt.strftime("%Y-%m-%d %H:%M:%S")
    }

def check_out_vehicle(ticket_id_or_number, payment_method="Credit Card", billing_model="prorated_30min", exit_time_dt=None, db_path=DEFAULT_DB_PATH):
    """
    Processes check-out:
    - Resolves ticket
    - Computes charges using chosen billing model (default: Model B 30-min slabs)
    - Updates ticket to Paid and inactive
    - Sets slot to Available
    """
    ticket = get_ticket_by_id(ticket_id_or_number, db_path=db_path)
    if not ticket:
        ticket = find_active_ticket_by_vehicle(ticket_id_or_number, db_path=db_path)

    if not ticket:
        raise ValueError(f"No active parking ticket found for '{ticket_id_or_number}'.")

    if not ticket["is_active"]:
        raise ValueError(f"Ticket {ticket['ticket_id']} has already been checked out.")

    bill = calculate_parking_bill(ticket, exit_time_dt=exit_time_dt, billing_model=billing_model, db_path=db_path)

    with get_connection(db_path) as conn:
        conn.execute("""
            UPDATE tickets SET
                exit_time = ?,
                duration_minutes = ?,
                subtotal = ?,
                tax = ?,
                total_fee = ?,
                payment_status = 'Paid',
                payment_method = ?,
                is_active = 0,
                billing_model = ?
            WHERE ticket_id = ?
        """, (
            bill["exit_time"],
            bill["duration_minutes"],
            bill["subtotal"],
            bill["tax"],
            bill["total_fee"],
            payment_method,
            billing_model,
            ticket["ticket_id"]
        ))

        # Free the slot
        conn.execute("UPDATE slots SET status = 'Available' WHERE id = ?", (ticket["slot_id"],))
        conn.commit()

    updated_ticket = get_ticket_by_id(ticket["ticket_id"], db_path=db_path)
    updated_ticket["bill_summary"] = bill
    return updated_ticket

def detect_fastag_id(vehicle_number: str) -> str:
    """
    Simulates RFID EPC sensor detection of a vehicle's windshield FASTag tag ID.
    Produces a standardized NPCI NETC 24-character hexadecimal EPC identifier.
    """
    clean_vrn = "".join(c for c in vehicle_number.upper() if c.isalnum())
    tag_core = clean_vrn.ljust(8, '0')[:8]
    return f"34161FA8{tag_core}0001"

def process_fastag_payment(ticket_id_or_number, tag_id=None, billing_model="prorated_30min", exit_time_dt=None, db_path=DEFAULT_DB_PATH):
    """
    Simulates NETC FASTag Auto-Debit at exit:
    - If vehicle checked in with an advance reservation and exits within the 1st hour:
      The 1-hour upfront deposit 100% covers the parking fee.
      NET PAYABLE IS ₹0.00 -> NO DEBIT occurs from FASTag.
    - If parked duration exceeds 1 hour after check-in:
      Upfront deposit is adjusted/credited, and only the EXTRA amount beyond 1 hour is debited from FASTag.
    - If drive-up ticket without reservation:
      Full session fee is debited from FASTag.
    """
    ticket = get_ticket_by_id(ticket_id_or_number, db_path=db_path)
    if not ticket:
        ticket = find_active_ticket_by_vehicle(ticket_id_or_number, db_path=db_path)
    if not ticket:
        raise ValueError(f"Active ticket not found for '{ticket_id_or_number}'.")

    active_tag = tag_id or ticket.get("fastag_id")
    if not active_tag:
        active_tag = detect_fastag_id(ticket["vehicle_number"])

    bill = calculate_parking_bill(ticket, exit_time_dt=exit_time_dt, billing_model=billing_model, db_path=db_path)
    net_payable = bill["net_payable"]
    prepaid_deposit = bill["prepaid_deposit"]

    if prepaid_deposit > 0 and net_payable == 0.0:
        debit_status = "ZERO_DEBIT_UPFRONT_ADJUSTED"
        debited_amount = 0.0
        pay_method_label = "FASTag (NETC - Covered by Upfront Booking Deposit)"
        notes = (
            f"Within 1-hour prepaid window. Total fee of {CURRENCY_SYMBOL}{bill['total_fee']:.2f} 100% adjusted "
            f"with upfront booking deposit of {CURRENCY_SYMBOL}{prepaid_deposit:.2f}. Zero debit to FASTag wallet."
        )
    elif prepaid_deposit > 0 and net_payable > 0.0:
        debit_status = "EXTRA_DURATION_DEBIT_SUCCESS"
        debited_amount = net_payable
        pay_method_label = "FASTag (NETC - Extra Duration)"
        notes = (
            f"Stay exceeded 1st hour ({bill['extra_mins']} mins extra). Upfront deposit of {CURRENCY_SYMBOL}{prepaid_deposit:.2f} "
            f"adjusted. Extra amount of {CURRENCY_SYMBOL}{net_payable:.2f} debited from linked FASTag."
        )
    else:
        debit_status = "DEBIT_SUCCESS"
        debited_amount = net_payable
        pay_method_label = "FASTag (NETC)"
        notes = f"Full parking fee of {CURRENCY_SYMBOL}{net_payable:.2f} debited from FASTag."

    receipt = check_out_vehicle(
        ticket["ticket_id"],
        payment_method=pay_method_label,
        billing_model=billing_model,
        exit_time_dt=exit_time_dt,
        db_path=db_path
    )

    # Attach NETC Gateway Response Metadata
    receipt["fastag_meta"] = {
        "tag_id": active_tag,
        "netc_txn_id": f"NETC/NPCI/{datetime.now().strftime('%Y%m%d')}/TXN{random.randint(100000, 999999)}",
        "acquiring_bank": "NPCI NETC Partner Gateway",
        "debit_status": debit_status,
        "debited_amount": f"{CURRENCY_SYMBOL}{debited_amount:.2f}",
        "debited_amount_float": debited_amount,
        "upfront_deposit_adjusted": f"{CURRENCY_SYMBOL}{prepaid_deposit:.2f}",
        "upfront_deposit_adjusted_float": prepaid_deposit,
        "total_session_fee": f"{CURRENCY_SYMBOL}{bill['total_fee']:.2f}",
        "total_session_fee_float": bill["total_fee"],
        "extra_duration_mins": bill["extra_mins"],
        "duration_formatted": bill["duration_formatted"],
        "notes": notes,
        "timestamp": receipt["exit_time"]
    }
    return receipt

# --- RESERVATION HANDLERS ---

def create_reservation(
    customer_name,
    customer_phone,
    vehicle_number,
    vehicle_type,
    slot_id,
    reserved_for_str,
    payment_method="UPI",
    grace_period_mins=60,
    deposit_amount=None,
    db_path=DEFAULT_DB_PATH
):
    """
    Reserves a specific available bay for scheduled arrival.
    Collects a non-refundable 1-hour base tariff deposit (+ 18% GST).
    The bay is held for the 1-hour prepaid window (60 mins) from scheduled arrival.
    If the vehicle fails to check in during this 1st hour, the slot
    is automatically freed and the deposit is forfeited as non-refundable revenue.

    Note: FASTag is disabled for advance booking because FASTag RFID is unknown prior
    to physical arrival and is detected at the entry barrier during check-in.
    """
    # Reject FASTag and Cash/Counter deposit for advance bookings
    if "fastag" in payment_method.lower():
        raise ValueError(
            "FASTag cannot be selected for advance bookings because the vehicle's FASTag RFID is unknown prior to arrival. "
            "FASTag is automatically detected by entry sensors during check-in. Please pay the upfront deposit using UPI, Card, or Net Banking."
        )
    if any(k in payment_method.lower() for k in ["cash", "counter"]):
        raise ValueError(
            "Cash / Counter deposit cannot be selected for advance bookings because physical cash cannot be collected prior to arrival. "
            "To guarantee bay reservation and secure the non-refundable 1-hour deposit, please pay using an instant online method (UPI, Card, or Net Banking)."
        )

    # Validate required customer phone number
    clean_phone = validate_phone_number(customer_phone, required=True)

    slot = get_slot(slot_id, db_path=db_path)
    if not slot:
        raise ValueError("Selected slot does not exist.")
    if slot["status"] != "Available":
        raise ValueError(f"Slot {slot['slot_number']} is currently {slot['status']} and cannot be reserved.")

    # Enforce strict vehicle category matching (avoid reserving empty slots of different category)
    if slot["slot_type"] != vehicle_type:
        raise ValueError(
            f"Category Mismatch: Bay {slot['slot_number']} is designated for '{slot['slot_type']}' vehicles, "
            f"but booking was requested for '{vehicle_type}'. Only matching {vehicle_type} bays can be reserved."
        )

    # Calculate 1-hour base rate + 18% GST if not provided
    if deposit_amount is None:
        rates = get_rates(db_path=db_path)
        rate_info = rates.get(vehicle_type, {"hourly_rate": 50.00})
        base_rate = rate_info["hourly_rate"]
        deposit_amount = round(base_rate * (1.0 + TAX_RATE), 2)

    res_id = generate_reservation_id()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with get_connection(db_path) as conn:
        conn.execute("""
            INSERT INTO reservations (
                reservation_id, customer_name, customer_phone, vehicle_number,
                vehicle_type, slot_id, slot_number, reserved_for, created_at, status,
                deposit_amount, payment_method, payment_status, grace_period_mins, forfeited_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Active', ?, ?, 'Paid', ?, '')
        """, (
            res_id, customer_name.strip(), clean_phone,
            vehicle_number.strip().upper(), vehicle_type,
            slot["id"], slot["slot_number"], reserved_for_str, now_str,
            deposit_amount, payment_method, int(grace_period_mins)
        ))
        conn.execute("UPDATE slots SET status = 'Reserved' WHERE id = ?", (slot["id"],))
        conn.commit()

    return res_id

def expire_no_show_reservations(grace_period_mins=None, current_time=None, db_path=DEFAULT_DB_PATH):
    """
    Scans active reservations whose scheduled arrival + 1-hour prepaid window has elapsed.
    Automatically checks them out as 'NoShow_Forfeited', restores the bay to 'Available',
    and retains the upfront deposit as non-refundable facility revenue.
    """
    now = current_time if current_time is not None else datetime.now()
    now_str = now.strftime("%Y-%m-%d %H:%M:%S")
    forfeited = []

    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reservations WHERE status = 'Active'")
        active_list = [dict(r) for r in cursor.fetchall()]

        for res in active_list:
            try:
                arrival_dt = datetime.strptime(res["reserved_for"], "%Y-%m-%d %H:%M:%S")
            except ValueError:
                continue

            effective_window = grace_period_mins if grace_period_mins is not None else (res.get("grace_period_mins") or 60)
            cutoff_dt = arrival_dt + timedelta(minutes=effective_window)

            if now > cutoff_dt:
                # Mark reservation as NoShow_Forfeited
                cursor.execute("""
                    UPDATE reservations SET
                        status = 'NoShow_Forfeited',
                        forfeited_at = ?
                    WHERE reservation_id = ?
                """, (now_str, res["reservation_id"]))

                # Restore the bay to Available if it was Reserved
                cursor.execute("""
                    UPDATE slots SET status = 'Available'
                    WHERE id = ? AND status = 'Reserved'
                """, (res["slot_id"],))

                forfeited.append({
                    "reservation_id": res["reservation_id"],
                    "vehicle_number": res["vehicle_number"],
                    "slot_number": res["slot_number"],
                    "deposit_amount": res.get("deposit_amount", 0.0),
                    "reserved_for": res["reserved_for"],
                    "cutoff_time": cutoff_dt.strftime("%Y-%m-%d %H:%M:%S"),
                    "forfeited_at": now_str
                })

        conn.commit()

    return forfeited

def check_in_from_reservation(reservation_id, is_ev_charging=False, fastag_id="", db_path=DEFAULT_DB_PATH):
    """
    Checks in a vehicle that holds an active advance reservation:
    - Verifies arrival is within the 1-hour prepaid window
    - Credits the non-refundable 1-hour upfront deposit to the ticket
    - Updates reservation status to 'CheckedIn'
    - Occupies the reserved bay
    """
    with get_connection(db_path) as conn:
        row = conn.execute(
            "SELECT * FROM reservations WHERE reservation_id = ?", (reservation_id,)
        ).fetchone()
        if not row:
            raise ValueError(f"Reservation '{reservation_id}' not found.")
        res = dict(row)
        if res["status"] != "Active":
            raise ValueError(f"Reservation {reservation_id} is '{res['status']}' and cannot be checked in.")

        # Check if the 1-hour prepaid reservation window has elapsed
        try:
            arrival_dt = datetime.strptime(res["reserved_for"], "%Y-%m-%d %H:%M:%S")
            window_mins = res.get("grace_period_mins") or 60
            cutoff_dt = arrival_dt + timedelta(minutes=window_mins)
            if datetime.now() > cutoff_dt:
                expire_no_show_reservations(db_path=db_path)
                raise ValueError(
                    f"Reservation {reservation_id} has expired! The 1-hour prepaid arrival window ended at "
                    f"{cutoff_dt.strftime('%Y-%m-%d %H:%M:%S')}. Bay {res['slot_number']} has been restored to "
                    f"Available and the 1st hour deposit of {CURRENCY_SYMBOL}{float(res['deposit_amount'] or 0.0):.2f} is non-refundable."
                )
        except (ValueError, KeyError) as err:
            if "has expired" in str(err):
                raise

        deposit = float(res["deposit_amount"] or 0.0)

    # Auto-detect FASTag RFID tag at check-in gate if not explicitly provided
    active_fastag = fastag_id.strip() if fastag_id else detect_fastag_id(res["vehicle_number"])

    # If this vehicle has a lingering stale ticket from an unclosed previous session, auto-close it
    stale_ticket = find_active_ticket_by_vehicle(res["vehicle_number"], db_path=db_path)
    if stale_ticket:
        check_out_vehicle(stale_ticket["ticket_id"], payment_method="System Auto-Close / Advance Check-In", db_path=db_path)

    ticket = check_in_vehicle(
        vehicle_number=res["vehicle_number"],
        vehicle_type=res["vehicle_type"],
        driver_name=res["customer_name"],
        driver_phone=res["customer_phone"],
        slot_id=res["slot_id"],
        is_ev_charging=is_ev_charging,
        fastag_id=active_fastag,
        prepaid_deposit=deposit,
        reservation_id=res["reservation_id"],
        db_path=db_path
    )

    with get_connection(db_path) as conn:
        conn.execute(
            "UPDATE reservations SET status = 'CheckedIn' WHERE reservation_id = ?",
            (reservation_id,)
        )
        conn.commit()

    return ticket

def cancel_reservation(reservation_id, db_path=DEFAULT_DB_PATH):
    """
    Cancels an active reservation and frees the slot.
    Note: Under facility policy, advance deposits are non-refundable.
    """
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with get_connection(db_path) as conn:
        res = conn.execute(
            "SELECT * FROM reservations WHERE reservation_id = ?", (reservation_id,)
        ).fetchone()
        if not res:
            raise ValueError("Reservation not found.")
        
        conn.execute("""
            UPDATE reservations SET
                status = 'Cancelled',
                forfeited_at = ?
            WHERE reservation_id = ?
        """, (now_str, reservation_id))
        conn.execute("UPDATE slots SET status = 'Available' WHERE id = ?", (res["slot_id"],))
        conn.commit()

def get_reservations(db_path=DEFAULT_DB_PATH, active_only=False, status=None):
    """Fetches reservations with status filter."""
    query = "SELECT * FROM reservations"
    params = []
    if status is not None:
        query += " WHERE status = ?"
        params.append(status)
    elif active_only:
        query += " WHERE status = 'Active'"
    query += " ORDER BY reserved_for DESC"
    with get_connection(db_path) as conn:
        return [dict(r) for r in conn.execute(query, tuple(params)).fetchall()]

# --- METRICS & REPORTING ---

def get_dashboard_metrics(db_path=DEFAULT_DB_PATH):
    """Calculates live occupancy rates and financial statistics including non-refundable deposits."""
    slots = get_slots(db_path=db_path)
    total_slots = len(slots)
    occupied_count = sum(1 for s in slots if s["status"] == "Occupied")
    available_count = sum(1 for s in slots if s["status"] == "Available")
    reserved_count = sum(1 for s in slots if s["status"] == "Reserved")
    maintenance_count = sum(1 for s in slots if s["status"] == "Maintenance")
    occupancy_pct = round((occupied_count / total_slots * 100), 1) if total_slots > 0 else 0.0

    all_tickets = get_all_tickets(db_path=db_path, limit=500)
    today_str = datetime.now().strftime("%Y-%m-%d")
    
    today_ticket_revenue = sum(
        t["total_fee"] for t in all_tickets
        if t["payment_status"] == "Paid" and t["exit_time"] and t["exit_time"].startswith(today_str)
    )
    all_time_ticket_revenue = sum(t["total_fee"] for t in all_tickets if t["payment_status"] == "Paid")

    # Include forfeited / cancelled non-refundable advance deposits
    with get_connection(db_path) as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COALESCE(SUM(deposit_amount), 0.0)
            FROM reservations
            WHERE status IN ('NoShow_Forfeited', 'Cancelled')
              AND (forfeited_at LIKE ? OR created_at LIKE ?)
        """, (f"{today_str}%", f"{today_str}%"))
        today_forfeited_revenue = cursor.fetchone()[0]

        cursor.execute("""
            SELECT COALESCE(SUM(deposit_amount), 0.0)
            FROM reservations
            WHERE status IN ('NoShow_Forfeited', 'Cancelled')
        """)
        all_time_forfeited_revenue = cursor.fetchone()[0]

    today_revenue = today_ticket_revenue + today_forfeited_revenue
    all_time_revenue = all_time_ticket_revenue + all_time_forfeited_revenue

    return {
        "total_slots": total_slots,
        "occupied_count": occupied_count,
        "available_count": available_count,
        "reserved_count": reserved_count,
        "maintenance_count": maintenance_count,
        "occupancy_pct": occupancy_pct,
        "today_revenue": round(today_revenue, 2),
        "all_time_revenue": round(all_time_revenue, 2),
        "active_vehicles_count": occupied_count
    }

# ==============================================================================
# REAL-TIME BACKGROUND SWEEP DAEMON
# ==============================================================================
_realtime_worker_thread = None
_realtime_worker_lock = threading.Lock()

def start_realtime_background_worker(interval_seconds=5, db_path=DEFAULT_DB_PATH):
    """
    Spawns a persistent background daemon thread that continuously sweeps expired
    reservations in real-time without blocking web requests or user interactions.
    """
    global _realtime_worker_thread
    with _realtime_worker_lock:
        if _realtime_worker_thread is not None and _realtime_worker_thread.is_alive():
            return
        
        def _sweep_loop():
            while True:
                try:
                    expire_no_show_reservations(db_path=db_path)
                except Exception:
                    pass
                time.sleep(interval_seconds)

        _realtime_worker_thread = threading.Thread(
            target=_sweep_loop,
            daemon=True,
            name="ParkFlowRealtimeAutoSweep"
        )
        _realtime_worker_thread.start()

def get_kpi_drilldown_data(kpi_type, db_path=DEFAULT_DB_PATH):
    """
    Fetches detailed operational records for the selected KPI card:
    - 'capacity': full slots list, zone breakdown, vehicle type breakdown
    - 'available': list of available slots with tariffs and categories
    - 'occupied': active tickets with live calculated bills and vehicle info
    - 'occupancy': zone-by-zone utilization percentages and density metrics
    - 'revenue': today's settled tickets, forfeited deposits, payment methods
    """
    today_str = datetime.now().strftime("%Y-%m-%d")
    rates = get_rates(db_path=db_path)

    if kpi_type in ("capacity", "total_capacity"):
        all_slots = get_slots(db_path=db_path)
        zone_summary = {}
        type_summary = {}
        for s in all_slots:
            z = s["zone"]
            t = s["slot_type"]
            zone_summary[z] = zone_summary.get(z, 0) + 1
            type_summary[t] = type_summary.get(t, 0) + 1

        return {
            "kpi": "capacity",
            "title": "Facility Total Capacity Breakdown",
            "total_slots": len(all_slots),
            "slots": all_slots,
            "zone_summary": zone_summary,
            "type_summary": type_summary
        }

    elif kpi_type in ("available", "available_bays"):
        avail_slots = get_slots(db_path=db_path, status="Available")
        type_counts = {}
        zone_counts = {}
        for s in avail_slots:
            t = s["slot_type"]
            z = s["zone"]
            type_counts[t] = type_counts.get(t, 0) + 1
            zone_counts[z] = zone_counts.get(z, 0) + 1

        enriched = []
        for s in avail_slots:
            s_dict = dict(s)
            s_dict["hourly_rate"] = rates.get(s["slot_type"], {}).get("hourly_rate", 50.0)
            enriched.append(s_dict)

        return {
            "kpi": "available",
            "title": "Available Parking Bays (Ready to Park)",
            "available_count": len(avail_slots),
            "slots": enriched,
            "type_counts": type_counts,
            "zone_counts": zone_counts
        }

    elif kpi_type in ("occupied", "occupied_bays"):
        active_tickets = get_active_tickets(db_path=db_path)
        enriched = []
        for t in active_tickets:
            bill = calculate_parking_bill(t, db_path=db_path)
            t_dict = dict(t)
            t_dict["duration_formatted"] = bill["duration_formatted"]
            t_dict["duration_minutes"] = bill["duration_minutes"]
            t_dict["accrued_total"] = bill["total_fee"]
            t_dict["subtotal"] = bill["subtotal"]
            t_dict["tax"] = bill["tax"]
            t_dict["ev_charging_fee"] = bill["ev_charging_fee"]
            t_dict["net_payable"] = bill["net_payable"]
            enriched.append(t_dict)

        return {
            "kpi": "occupied",
            "title": "Active Parked Vehicles & Occupied Bays",
            "occupied_count": len(active_tickets),
            "active_vehicles": enriched
        }

    elif kpi_type in ("occupancy", "occupancy_rate"):
        all_slots = get_slots(db_path=db_path)
        zone_stats = {}
        type_stats = {}

        for s in all_slots:
            z = s["zone"]
            t = s["slot_type"]
            st_val = s["status"]

            if z not in zone_stats:
                zone_stats[z] = {"total": 0, "occupied": 0, "available": 0, "reserved": 0, "maintenance": 0}
            zone_stats[z]["total"] += 1
            zone_stats[z][st_val.lower()] = zone_stats[z].get(st_val.lower(), 0) + 1

            if t not in type_stats:
                type_stats[t] = {"total": 0, "occupied": 0, "available": 0, "reserved": 0, "maintenance": 0}
            type_stats[t]["total"] += 1
            type_stats[t][st_val.lower()] = type_stats[t].get(st_val.lower(), 0) + 1

        for z, d in zone_stats.items():
            d["occupancy_pct"] = round((d["occupied"] / d["total"]) * 100, 1) if d["total"] > 0 else 0.0

        for t, d in type_stats.items():
            d["occupancy_pct"] = round((d["occupied"] / d["total"]) * 100, 1) if d["total"] > 0 else 0.0

        metrics = get_dashboard_metrics(db_path=db_path)

        return {
            "kpi": "occupancy",
            "title": "Facility Occupancy & Space Utilization Analysis",
            "overall_occupancy_pct": metrics["occupancy_pct"],
            "zone_stats": zone_stats,
            "type_stats": type_stats
        }

    elif kpi_type in ("revenue", "today_revenue"):
        with get_connection(db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM tickets
                WHERE is_active = 0 AND (exit_time LIKE ? OR exit_time IS NULL)
                ORDER BY exit_time DESC
            """, (f"{today_str}%",))
            settled_tickets = [dict(r) for r in cursor.fetchall()]

            cursor.execute("""
                SELECT * FROM reservations
                WHERE status IN ('NoShow_Forfeited', 'Cancelled')
                  AND (forfeited_at LIKE ? OR created_at LIKE ?)
                ORDER BY created_at DESC
            """, (f"{today_str}%", f"{today_str}%"))
            forfeited_res = [dict(r) for r in cursor.fetchall()]

        ticket_revenue = sum(float(t.get("total_fee") or 0.0) for t in settled_tickets)
        deposit_revenue = sum(float(r.get("deposit_amount") or 0.0) for r in forfeited_res)
        total_today = ticket_revenue + deposit_revenue

        ev_revenue = sum(float(t.get("ev_charging_fee") or 0.0) for t in settled_tickets)
        gst_collected = sum(float(t.get("tax") or 0.0) for t in settled_tickets)

        pay_methods = {}
        for t in settled_tickets:
            pm = t.get("payment_method") or "Cash / Counter"
            pay_methods[pm] = pay_methods.get(pm, 0.0) + float(t.get("total_fee") or 0.0)

        for r in forfeited_res:
            pm = f"{r.get('payment_method') or 'UPI'} (Deposit Forfeiture)"
            pay_methods[pm] = pay_methods.get(pm, 0.0) + float(r.get("deposit_amount") or 0.0)

        return {
            "kpi": "revenue",
            "title": "Today's Financial Revenue & Audit Statement",
            "total_today_revenue": round(total_today, 2),
            "ticket_revenue": round(ticket_revenue, 2),
            "deposit_revenue": round(deposit_revenue, 2),
            "ev_revenue": round(ev_revenue, 2),
            "gst_collected": round(gst_collected, 2),
            "payment_methods": {k: round(v, 2) for k, v in pay_methods.items()},
            "settled_tickets": settled_tickets,
            "forfeited_reservations": forfeited_res
        }

    return None
