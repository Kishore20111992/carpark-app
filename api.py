"""
ParkFlow REST API Backend
Provides JSON endpoints for Android and iOS mobile applications,
connecting directly to the SQLite database and core parking management engine.
"""

from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
import contextlib

from database import (
    init_db,
    get_slots,
    get_slot,
    get_slot_by_number,
    get_rates,
    get_active_tickets,
    get_all_tickets,
    get_ticket_by_id,
    find_active_ticket_by_vehicle,
    find_active_reservation_by_vehicle,
    DEFAULT_DB_PATH
)
from parking_manager import (
    suggest_best_slot,
    check_in_vehicle,
    calculate_parking_bill,
    check_out_vehicle,
    create_reservation,
    cancel_reservation,
    get_reservations,
    get_dashboard_metrics,
    process_fastag_payment,
    expire_no_show_reservations,
    check_in_from_reservation,
    detect_fastag_id,
    validate_phone_number,
    start_realtime_background_worker,
    CURRENCY_SYMBOL,
    TAX_RATE
)

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize DB schema
    init_db()
    # Start auto-sweep background worker (5s interval)
    start_realtime_background_worker(interval_seconds=5)
    yield

app = FastAPI(
    title="ParkFlow Smart Parking API",
    description="REST API backend powering the ParkFlow Android & iOS Mobile Applications",
    version="2.0.0",
    lifespan=lifespan
)

# Enable CORS for mobile apps and web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Pydantic Schemas ---

class CheckInRequest(BaseModel):
    vehicle_number: str = Field(..., description="Vehicle license registration plate")
    vehicle_type: str = Field(default="Car", description="Car, EV, Bike, SUV, Handicap")
    driver_name: Optional[str] = Field(default="", description="Driver full name")
    driver_phone: Optional[str] = Field(default="", description="Contact mobile number")
    slot_id: Optional[int] = Field(default=None, description="Specific bay ID, or None for smart recommendation")
    is_ev_charging: bool = Field(default=False, description="Enable EV fast charging")
    fastag_id: Optional[str] = Field(default="", description="RFID EPC tag ID (auto-detected if omitted)")

class CheckOutRequest(BaseModel):
    ticket_id: str = Field(..., description="Ticket ID or Vehicle Registration Plate")
    payment_method: str = Field(default="FASTag (NETC Auto-Debit)", description="Payment mode")
    billing_model: str = Field(default="prorated_30min", description="prorated_30min, hourly_block, exact_prorata")

class ReservationRequest(BaseModel):
    customer_name: str = Field(..., description="Customer full name")
    customer_phone: str = Field(..., description="Contact phone (min 10 digits)")
    vehicle_number: str = Field(..., description="Vehicle registration plate")
    vehicle_type: str = Field(..., description="Vehicle category: Car, EV, Bike, SUV, Handicap")
    slot_id: int = Field(..., description="Matching bay ID to reserve")
    reserved_for: str = Field(..., description="Scheduled arrival date & time (YYYY-MM-DD HH:MM:SS)")
    payment_method: str = Field(..., description="UPI / QR Scan, Credit / Debit Card, Net Banking")

# --- API Endpoints ---

@app.get("/api/health")
def health_check():
    return {"status": "online", "system": "ParkFlow Engine v2.0", "timestamp": datetime.now().isoformat()}

@app.get("/api/bays/summary")
def get_bay_summary():
    """Returns real-time facility metrics for mobile dashboard."""
    metrics = get_dashboard_metrics()
    return {
        "total_bays": metrics["total_slots"],
        "available_bays": metrics["available_count"],
        "occupied_bays": metrics["occupied_count"],
        "reserved_bays": metrics["reserved_count"],
        "maintenance_bays": metrics["maintenance_count"],
        "occupancy_rate_pct": metrics["occupancy_pct"],
        "today_revenue": metrics["today_revenue"],
        "currency": CURRENCY_SYMBOL
    }

@app.get("/api/bays")
def list_bays(
    zone: Optional[str] = Query(None, description="Filter by Zone: Zone A (Ground), Zone B (Level 1), Zone C (Level 2)"),
    slot_type: Optional[str] = Query(None, description="Filter by Category: Car, EV, Bike, SUV, Handicap"),
    status: Optional[str] = Query(None, description="Filter by Status: Available, Occupied, Reserved, Maintenance")
):
    """Returns list of parking bays with live status and occupied vehicle details."""
    slots = get_slots(zone=zone, slot_type=slot_type, status=status)
    return {"count": len(slots), "bays": slots}

@app.get("/api/bays/{slot_id}")
def get_bay_detail(slot_id: int):
    """Returns detailed information for a single bay."""
    slot = get_slot(slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail=f"Bay with ID {slot_id} not found.")
    return slot

@app.get("/api/rates")
def list_rates():
    """Returns tariff rates and EV surcharge info."""
    return {
        "rates": get_rates(),
        "ev_charging_flat_fee": 150.00,
        "tax_rate_pct": 18.0
    }

@app.post("/api/checkin", status_code=status.HTTP_201_CREATED)
def vehicle_check_in(req: CheckInRequest):
    """
    Checks in a vehicle.
    - If plate has an active advance reservation, automatically checks in from booking,
      links FASTag RFID, and credits upfront deposit.
    - Otherwise, allocates specified bay or best available slot.
    """
    clean_plate = req.vehicle_number.strip().upper()
    if not clean_plate:
        raise HTTPException(status_code=400, detail="Vehicle plate number is required.")

    # Check for active advance booking
    active_res = find_active_reservation_by_vehicle(clean_plate)
    detected_tag = req.fastag_id or detect_fastag_id(clean_plate)

    try:
        if active_res:
            ticket = check_in_from_reservation(
                reservation_id=active_res["reservation_id"],
                is_ev_charging=req.is_ev_charging,
                fastag_id=detected_tag
            )
            return {
                "message": f"Checked in vehicle {clean_plate} from advance booking {active_res['reservation_id']}!",
                "is_advance_booking": True,
                "reservation_id": active_res["reservation_id"],
                "deposit_credited": float(active_res["deposit_amount"]),
                "ticket": ticket
            }
        else:
            ticket = check_in_vehicle(
                vehicle_number=clean_plate,
                vehicle_type=req.vehicle_type,
                driver_name=req.driver_name or "",
                driver_phone=req.driver_phone or "",
                slot_id=req.slot_id,
                is_ev_charging=req.is_ev_charging,
                fastag_id=detected_tag
            )
            return {
                "message": f"Checked in vehicle {clean_plate} into Bay {ticket['slot_number']}!",
                "is_advance_booking": False,
                "ticket": ticket
            }
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

@app.post("/api/checkout")
def vehicle_check_out(req: CheckOutRequest):
    """
    Settles payment and executes checkout.
    - FASTag: Automatic debit with upfront deposit adjustment.
    - Other methods: Settles net payable.
    """
    ticket = get_ticket_by_id(req.ticket_id)
    if not ticket:
        ticket = find_active_ticket_by_vehicle(req.ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail=f"No active parked vehicle found for '{req.ticket_id}'.")

    try:
        if "fastag" in req.payment_method.lower():
            receipt = process_fastag_payment(
                ticket_id_or_number=ticket["ticket_id"],
                billing_model=req.billing_model
            )
        else:
            receipt = check_out_vehicle(
                ticket_id=ticket["ticket_id"],
                payment_method=req.payment_method,
                billing_model=req.billing_model
            )
        return {
            "message": f"Vehicle {ticket['vehicle_number']} checked out successfully!",
            "receipt": receipt
        }
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

@app.get("/api/checkout/preview")
def preview_bill(ticket_id: str, billing_model: str = "prorated_30min"):
    """Returns live bill breakdown and accrued fee for an active parked vehicle."""
    ticket = get_ticket_by_id(ticket_id)
    if not ticket:
        ticket = find_active_ticket_by_vehicle(ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail=f"No active parked vehicle found for '{ticket_id}'.")

    bill = calculate_parking_bill(ticket, billing_model=billing_model)
    return {
        "ticket": ticket,
        "bill": bill
    }

@app.post("/api/reservations", status_code=status.HTTP_201_CREATED)
def create_advance_booking(req: ReservationRequest):
    """
    Creates advance reservation.
    - Requires 1-hour upfront non-refundable deposit.
    - Rejects Cash and FASTag prior to physical arrival.
    - Strictly validates category matching.
    """
    try:
        res_id = create_reservation(
            customer_name=req.customer_name,
            customer_phone=req.customer_phone,
            vehicle_number=req.vehicle_number,
            vehicle_type=req.vehicle_type,
            slot_id=req.slot_id,
            reserved_for_str=req.reserved_for,
            payment_method=req.payment_method,
            grace_period_mins=60
        )
        reservations = get_reservations()
        created = next((r for r in reservations if r["reservation_id"] == res_id), None)
        return {
            "message": f"Reservation confirmed! Bay reserved for 1 hour from scheduled arrival.",
            "reservation": created
        }
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

@app.get("/api/reservations")
def list_reservations(status: Optional[str] = Query(None, description="Active, CheckedIn, NoShow_Forfeited, Cancelled")):
    """Returns reservations list."""
    res = get_reservations(status=status)
    return {"count": len(res), "reservations": res}

@app.post("/api/reservations/{reservation_id}/cancel")
def cancel_booking(reservation_id: str):
    """Cancels reservation and restores bay to Available. Deposit retained."""
    try:
        success = cancel_reservation(reservation_id)
        if not success:
            raise HTTPException(status_code=404, detail=f"Reservation '{reservation_id}' not found or already closed.")
        return {"message": f"Reservation {reservation_id} cancelled. Bay restored to Available."}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

@app.post("/api/reservations/sweep")
def trigger_no_show_sweep():
    """Manually triggers sweep for expired 1-hour no-show reservations."""
    forfeited = expire_no_show_reservations()
    return {"forfeited_count": len(forfeited), "forfeited_bookings": forfeited}

@app.get("/api/locator")
def locate_vehicle(query: str = Query(..., description="Vehicle Plate or Ticket ID")):
    """Locates parked vehicle and returns walking directions and current bill."""
    ticket = find_active_ticket_by_vehicle(query)
    if not ticket:
        ticket = get_ticket_by_id(query)
    if not ticket or not ticket["is_active"]:
        raise HTTPException(status_code=404, detail=f"No active parked vehicle found matching '{query}'.")

    slot = get_slot(ticket["slot_id"])
    bill = calculate_parking_bill(ticket)
    return {
        "vehicle_number": ticket["vehicle_number"],
        "ticket_id": ticket["ticket_id"],
        "slot_number": slot["slot_number"],
        "zone": slot["zone"],
        "floor": slot["floor"],
        "duration": bill["duration_formatted"],
        "accrued_total": bill["total_fee"],
        "walking_directions": f"Proceed to {slot['zone']} on Floor {slot['floor']}. Spot: {slot['slot_number']} ({slot['notes'] or 'Standard Bay'})."
    }
