import os
import unittest
from datetime import datetime, timedelta
from database import (
    init_db,
    get_slots,
    get_rates,
    get_slot_by_number,
    find_active_ticket_by_vehicle
)
from parking_manager import (
    suggest_best_slot,
    check_in_vehicle,
    calculate_parking_bill,
    check_out_vehicle,
    create_reservation,
    cancel_reservation,
    get_dashboard_metrics,
    process_fastag_payment,
    expire_no_show_reservations,
    check_in_from_reservation,
    get_reservations,
    validate_phone_number
)

TEST_DB = "test_parking.db"

class TestParkingSystem(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.path.exists(TEST_DB):
            os.remove(TEST_DB)
        init_db(TEST_DB)

    @classmethod
    def tearDownClass(cls):
        if os.path.exists(TEST_DB):
            try:
                os.remove(TEST_DB)
            except Exception:
                pass

    def test_1_database_initialization(self):
        """Verify database tables and seeded slots/rates."""
        slots = get_slots(db_path=TEST_DB)
        self.assertEqual(len(slots), 24, "Expected 24 pre-configured parking bays")

        rates = get_rates(db_path=TEST_DB)
        self.assertIn("Car", rates)
        self.assertIn("EV", rates)
        self.assertIn("Bike", rates)
        self.assertIn("SUV", rates)
        self.assertIn("Handicap", rates)

    def test_2_smart_slot_allocation(self):
        """Test intelligent slot recommendation based on vehicle type."""
        ev_slot = suggest_best_slot("EV", is_ev_charging=True, db_path=TEST_DB)
        self.assertIsNotNone(ev_slot)
        self.assertEqual(ev_slot["slot_type"], "EV")

        bike_slot = suggest_best_slot("Bike", db_path=TEST_DB)
        self.assertIsNotNone(bike_slot)
        self.assertEqual(bike_slot["slot_type"], "Bike")

        suv_slot = suggest_best_slot("SUV", db_path=TEST_DB)
        self.assertIsNotNone(suv_slot)
        self.assertEqual(suv_slot["slot_type"], "SUV")

    def test_3_check_in_and_duplicate_prevention(self):
        """Test parking check-in workflow and duplicate plate validation."""
        test_plate = "TEST-CAR-101"
        ticket = check_in_vehicle(
            vehicle_number=test_plate,
            vehicle_type="Car",
            driver_name="Bruce Wayne",
            driver_phone="+91-98765-43210",
            db_path=TEST_DB
        )
        self.assertIsNotNone(ticket)
        self.assertEqual(ticket["vehicle_number"], test_plate)
        self.assertEqual(ticket["is_active"], 1)

        # Slot should now be occupied
        slot = get_slot_by_number(ticket["slot_number"], db_path=TEST_DB)
        self.assertEqual(slot["status"], "Occupied")

        # Attempting duplicate check-in should raise ValueError
        with self.assertRaises(ValueError):
            check_in_vehicle(
                vehicle_number=test_plate,
                vehicle_type="Car",
                db_path=TEST_DB
            )

    def test_4_bill_calculation_and_checkout(self):
        """Test parking fee calculation and check-out process."""
        test_plate = "TEST-EV-202"
        ticket = check_in_vehicle(
            vehicle_number=test_plate,
            vehicle_type="EV",
            is_ev_charging=True,
            db_path=TEST_DB
        )
        slot_number = ticket["slot_number"]

        # Simulate 2 hours 15 mins parking duration
        simulated_exit = datetime.now() + timedelta(hours=2, minutes=15)
        bill = calculate_parking_bill(ticket, exit_time_dt=simulated_exit, db_path=TEST_DB)
        
        # Under Model B (Standard): 2h 15m (135 min) = 1st hr (₹60) + 3 slabs of 30m @ ₹30 (₹90) = ₹150 subtotal
        # EV surcharge: ₹150 -> Net: ₹300 + 18% GST (₹54) = ₹354.00 (2.5 billable hours)
        self.assertEqual(bill["billable_hours"], 2.5)
        self.assertEqual(bill["ev_charging_fee"], 150.00)
        self.assertEqual(bill["subtotal"], 150.00)
        self.assertAlmostEqual(bill["total_fee"], 354.00, places=2)

        # Check-out
        receipt = check_out_vehicle(ticket["ticket_id"], payment_method="Credit Card", db_path=TEST_DB)
        self.assertEqual(receipt["payment_status"], "Paid")
        self.assertEqual(receipt["is_active"], 0)

        # Slot should now be Available again
        slot_after = get_slot_by_number(slot_number, db_path=TEST_DB)
        self.assertEqual(slot_after["status"], "Available")

    def test_5_reservation_flow(self):
        """Test reserving a slot and cancelling it."""
        available_slots = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")
        self.assertTrue(len(available_slots) > 0)
        target_slot = available_slots[0]

        res_id = create_reservation(
            customer_name="Diana Prince",
            customer_phone="+91-98765-43211",
            vehicle_number="TEST-RES-888",
            vehicle_type="Car",
            slot_id=target_slot["id"],
            reserved_for_str="2026-09-05 18:00:00",
            db_path=TEST_DB
        )
        self.assertTrue(res_id.startswith("RES-"))

        # Slot should now be Reserved
        slot_check = get_slot_by_number(target_slot["slot_number"], db_path=TEST_DB)
        self.assertEqual(slot_check["status"], "Reserved")

        # Cancel reservation
        cancel_reservation(res_id, db_path=TEST_DB)
        slot_after_cancel = get_slot_by_number(target_slot["slot_number"], db_path=TEST_DB)
        self.assertEqual(slot_after_cancel["status"], "Available")

    def test_6_dashboard_metrics(self):
        """Test metric computations."""
        metrics = get_dashboard_metrics(db_path=TEST_DB)
        self.assertEqual(metrics["total_slots"], 24)
        self.assertTrue(metrics["available_count"] >= 0)
        self.assertTrue(metrics["occupied_count"] >= 0)
        self.assertTrue(0 <= metrics["occupancy_pct"] <= 100)

    def test_7_prorata_and_fastag(self):
        """Test pro-rata billing models (30-min slabs, exact per-minute) and FASTag payment."""
        test_plate = "FASTAG-CAR-999"
        ticket = check_in_vehicle(
            vehicle_number=test_plate,
            vehicle_type="Car",
            fastag_id="34161FA8999990001",
            db_path=TEST_DB
        )
        
        # Simulate 1 hr 15 mins parking (rate = 50.00/hr)
        simulated_exit = datetime.now() + timedelta(hours=1, minutes=15)
        
        # 1. Hourly block ceiling (1h 15m -> 2 hrs = 100.00 + 18% GST = 118.00)
        bill_block = calculate_parking_bill(ticket, exit_time_dt=simulated_exit, billing_model="hourly_block", db_path=TEST_DB)
        self.assertEqual(bill_block["subtotal"], 100.00)
        self.assertEqual(bill_block["total_fee"], 118.00)

        # 2. 30-min slabs (1h + 1 slab of 30m @ 25.00 = 75.00 + 18% GST = 88.50)
        bill_slab = calculate_parking_bill(ticket, exit_time_dt=simulated_exit, billing_model="prorated_30min", db_path=TEST_DB)
        self.assertEqual(bill_slab["subtotal"], 75.00)
        self.assertEqual(bill_slab["total_fee"], 88.50)

        # 3. Exact pro-rata (1h @ 50 + 15m @ 12.50 = 62.50 + 18% GST (11.25) = 73.75)
        bill_exact = calculate_parking_bill(ticket, exit_time_dt=simulated_exit, billing_model="exact_prorata", db_path=TEST_DB)
        self.assertEqual(bill_exact["subtotal"], 62.50)
        self.assertEqual(bill_exact["total_fee"], 73.75)

        # 4. FASTag payment processing
        receipt = process_fastag_payment(ticket["ticket_id"], billing_model="prorated_30min", db_path=TEST_DB)
        self.assertEqual(receipt["payment_method"], "FASTag (NETC)")
        self.assertEqual(receipt["payment_status"], "Paid")
        self.assertIn("fastag_meta", receipt)
        self.assertEqual(receipt["fastag_meta"]["debit_status"], "DEBIT_SUCCESS")
        self.assertTrue(receipt["fastag_meta"]["netc_txn_id"].startswith("NETC/NPCI/"))

    def test_8_reservation_deposit_noshow_and_credit(self):
        """Test upfront 1-hour deposit collection, no-show auto-forfeiture, and prepaid check-in credit."""
        avail_slots = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")
        self.assertTrue(len(avail_slots) >= 2)
        slot_noshow = avail_slots[0]
        slot_arriving = avail_slots[1]

        # 1. Booking 1: Vehicle will NOT show up (Scheduled 75 mins ago, past the 1-hour prepaid window)
        past_arrival = (datetime.now() - timedelta(minutes=75)).strftime("%Y-%m-%d %H:%M:%S")
        res_id_noshow = create_reservation(
            customer_name="Ghost Driver",
            customer_phone="+91-90000-00001",
            vehicle_number="NOSHOW-CAR-01",
            vehicle_type="Car",
            slot_id=slot_noshow["id"],
            reserved_for_str=past_arrival,
            payment_method="UPI",
            grace_period_mins=60,
            db_path=TEST_DB
        )
        
        # Verify slot is Reserved and deposit was recorded (₹50 base + 18% GST = ₹59.00)
        s_check = get_slot_by_number(slot_noshow["slot_number"], db_path=TEST_DB)
        self.assertEqual(s_check["status"], "Reserved")
        res_obj = [r for r in get_reservations(db_path=TEST_DB) if r["reservation_id"] == res_id_noshow][0]
        self.assertEqual(res_obj["deposit_amount"], 59.00)
        self.assertEqual(res_obj["status"], "Active")

        # 2. Trigger auto-expiry sweep
        forfeited = expire_no_show_reservations(db_path=TEST_DB)
        self.assertTrue(any(f["reservation_id"] == res_id_noshow for f in forfeited))
        
        # Slot MUST now be Available again
        s_after = get_slot_by_number(slot_noshow["slot_number"], db_path=TEST_DB)
        self.assertEqual(s_after["status"], "Available")
        
        # Reservation status is NoShow_Forfeited
        res_after = [r for r in get_reservations(db_path=TEST_DB) if r["reservation_id"] == res_id_noshow][0]
        self.assertEqual(res_after["status"], "NoShow_Forfeited")
        self.assertEqual(res_after["deposit_amount"], 59.00)

        # Attempting to check in an expired reservation should raise ValueError
        with self.assertRaises(ValueError) as ctx:
            check_in_from_reservation(res_id_noshow, db_path=TEST_DB)
        self.assertIn("cannot be checked in", str(ctx.exception))

        # Booking 1b: Active reservation that has passed the 1-hour window without a background sweep yet
        past_arrival_active = (datetime.now() - timedelta(minutes=70)).strftime("%Y-%m-%d %H:%M:%S")
        res_id_expired_active = create_reservation(
            customer_name="Late Driver",
            customer_phone="+91-90000-00003",
            vehicle_number="LATE-CAR-01",
            vehicle_type="Car",
            slot_id=slot_noshow["id"],
            reserved_for_str=past_arrival_active,
            payment_method="UPI",
            grace_period_mins=60,
            db_path=TEST_DB
        )
        with self.assertRaises(ValueError) as ctx2:
            check_in_from_reservation(res_id_expired_active, db_path=TEST_DB)
        self.assertIn("has expired", str(ctx2.exception))

        # 3. Booking 2: Vehicle DOES show up on time
        future_arrival = (datetime.now() + timedelta(minutes=20)).strftime("%Y-%m-%d %H:%M:%S")
        res_id_arriving = create_reservation(
            customer_name="Arriving Guest",
            customer_phone="+91-90000-00002",
            vehicle_number="ARRIVE-CAR-02",
            vehicle_type="Car",
            slot_id=slot_arriving["id"],
            reserved_for_str=future_arrival,
            payment_method="UPI",
            grace_period_mins=60,
            db_path=TEST_DB
        )
        
        # Guest arrives: Check-in from reservation
        ticket = check_in_from_reservation(res_id_arriving, db_path=TEST_DB)
        self.assertEqual(ticket["vehicle_number"], "ARRIVE-CAR-02")
        self.assertEqual(ticket["prepaid_deposit"], 59.00)
        self.assertEqual(ticket["reservation_id"], res_id_arriving)
        
        # Slot is now Occupied, Reservation is CheckedIn
        s_arr_check = get_slot_by_number(slot_arriving["slot_number"], db_path=TEST_DB)
        self.assertEqual(s_arr_check["status"], "Occupied")
        res_arr_obj = [r for r in get_reservations(db_path=TEST_DB) if r["reservation_id"] == res_id_arriving][0]
        self.assertEqual(res_arr_obj["status"], "CheckedIn")

        # 4. Guest exits after 1 hr 15 mins (Total fee under Model B = ₹88.50)
        # Net balance due = ₹88.50 - ₹59.00 prepaid deposit = ₹29.50!
        sim_exit = datetime.now() + timedelta(hours=1, minutes=15)
        bill = calculate_parking_bill(ticket, exit_time_dt=sim_exit, billing_model="prorated_30min", db_path=TEST_DB)
        self.assertEqual(bill["total_fee"], 88.50)
        self.assertEqual(bill["prepaid_deposit"], 59.00)
        self.assertEqual(bill["net_payable"], 29.50)

        # Check out
        receipt = check_out_vehicle(ticket["ticket_id"], billing_model="prorated_30min", exit_time_dt=sim_exit, db_path=TEST_DB)
        self.assertEqual(receipt["payment_status"], "Paid")
        self.assertEqual(receipt["bill_summary"]["net_payable"], 29.50)
        
        # Slot is now Available again
        s_final = get_slot_by_number(slot_arriving["slot_number"], db_path=TEST_DB)
        self.assertEqual(s_final["status"], "Available")

    def test_9_phone_number_strict_validation(self):
        """Test strict validation of phone numbers: reject letters, reject <10 digits, format 10-digits."""
        # 1. Reject alphabetic characters
        with self.assertRaises(ValueError) as ctx:
            validate_phone_number("98765abcde", required=True)
        self.assertIn("cannot contain alphabetic letters", str(ctx.exception))

        with self.assertRaises(ValueError) as ctx:
            validate_phone_number("abcdefghij", required=True)
        self.assertIn("cannot contain alphabetic letters", str(ctx.exception))

        # 2. Reject fewer than 10 digits
        with self.assertRaises(ValueError) as ctx:
            validate_phone_number("12345", required=True)
        self.assertIn("too short", str(ctx.exception))

        with self.assertRaises(ValueError) as ctx:
            validate_phone_number("+91-1234", required=True)
        self.assertIn("too short", str(ctx.exception))

        # 3. Reject excessive length (> 15 digits)
        with self.assertRaises(ValueError) as ctx:
            validate_phone_number("1234567890123456", required=True)
        self.assertIn("too long", str(ctx.exception))

        # 4. Accept valid 10-digit number and format
        clean_formatted = validate_phone_number("9876543210", required=True)
        self.assertEqual(clean_formatted, "+91 98765 43210")

        # 5. Optional empty phone
        self.assertEqual(validate_phone_number("", required=False), "")
        self.assertEqual(validate_phone_number(None, required=False), "")

        # 6. Required empty phone raises
        with self.assertRaises(ValueError):
            validate_phone_number("", required=True)

    def test_10_category_matching_and_filter(self):
        """Test that reservations and bay queries strictly isolate bays by vehicle category."""
        # Query Bike slots: must all have slot_type == 'Bike'
        bike_slots = get_slots(db_path=TEST_DB, status="Available", slot_type="Bike")
        self.assertTrue(len(bike_slots) > 0)
        for bs in bike_slots:
            self.assertEqual(bs["slot_type"], "Bike")

        # Query Car slots: must all have slot_type == 'Car'
        car_slots = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")
        self.assertTrue(len(car_slots) > 0)
        for cs in car_slots:
            self.assertEqual(cs["slot_type"], "Car")

        # Reserving a Bike bay for a Car must raise Category Mismatch ValueError
        bike_slot = bike_slots[0]
        with self.assertRaises(ValueError) as ctx:
            create_reservation(
                customer_name="Mismatched User",
                customer_phone="+91-98765-43212",
                vehicle_number="MISMATCH-CAR-1",
                vehicle_type="Car",
                slot_id=bike_slot["id"],
                reserved_for_str="2026-09-05 20:00:00",
                db_path=TEST_DB
            )
        self.assertIn("Category Mismatch", str(ctx.exception))

        # Reserving a Car bay for a Car must succeed
        car_slot = car_slots[0]
        res_id = create_reservation(
            customer_name="Matched User",
            customer_phone="+91-98765-43213",
            vehicle_number="MATCH-CAR-1",
            vehicle_type="Car",
            slot_id=car_slot["id"],
            reserved_for_str="2026-09-05 20:00:00",
            db_path=TEST_DB
        )
        self.assertTrue(res_id.startswith("RES-"))
        cancel_reservation(res_id, db_path=TEST_DB)

    def test_advance_booking_disallows_fastag(self):
        """Advance reservations must reject FASTag as RFID is only scanned upon physical arrival."""
        car_slot = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")[0]
        with self.assertRaises(ValueError) as ctx:
            create_reservation(
                customer_name="FASTag Reject Test",
                customer_phone="+91-98765-43214",
                vehicle_number="FTAG-DISALLOW",
                vehicle_type="Car",
                slot_id=car_slot["id"],
                reserved_for_str="2026-09-05 21:00:00",
                payment_method="FASTag (Auto-Debit)",
                db_path=TEST_DB
            )
        self.assertIn("FASTag cannot be selected for advance bookings", str(ctx.exception))

    def test_reservation_checkin_fastag_auto_detection_and_within_1hr_zero_debit(self):
        """
        Tests:
        1. Checking in from reservation auto-detects FASTag RFID.
        2. Exiting within 1 hour: Net payable is ₹0.00, ZERO debit to FASTag, 100% adjusted with upfront deposit.
        """
        car_slot = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")[0]
        arrival_time = (datetime.now() + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")

        res_id = create_reservation(
            customer_name="Within One Hour User",
            customer_phone="+91-98765-43215",
            vehicle_number="KA-03-HA-1111",
            vehicle_type="Car",
            slot_id=car_slot["id"],
            reserved_for_str=arrival_time,
            payment_method="UPI / QR Scan",
            db_path=TEST_DB
        )

        # Check-in: FASTag must be auto-detected
        ticket = check_in_from_reservation(res_id, db_path=TEST_DB)
        self.assertTrue(ticket["fastag_id"].startswith("34161FA8"))
        self.assertEqual(ticket["prepaid_deposit"], 59.00)

        # Exit at 40 minutes (within 1 hour)
        sim_exit_40m = datetime.now() + timedelta(minutes=40)
        bill = calculate_parking_bill(ticket, exit_time_dt=sim_exit_40m, billing_model="prorated_30min", db_path=TEST_DB)
        self.assertEqual(bill["total_fee"], 59.00)
        self.assertEqual(bill["prepaid_deposit"], 59.00)
        self.assertEqual(bill["net_payable"], 0.00)

        # FASTag Auto-Debit at exit: Must debit ₹0.00 and adjust 100%
        receipt = process_fastag_payment(ticket["ticket_id"], billing_model="prorated_30min", exit_time_dt=sim_exit_40m, db_path=TEST_DB)
        self.assertEqual(receipt["payment_status"], "Paid")
        self.assertEqual(receipt["fastag_meta"]["debit_status"], "ZERO_DEBIT_UPFRONT_ADJUSTED")
        self.assertEqual(receipt["fastag_meta"]["debited_amount_float"], 0.0)
        self.assertEqual(receipt["fastag_meta"]["upfront_deposit_adjusted_float"], 59.00)

    def test_reservation_checkin_fastag_after_1hr_extra_debit(self):
        """
        Tests:
        Vehicle checks in from reservation and exits after 1 hour (e.g. 1 hr 45 mins).
        Upfront deposit of ₹59.00 is adjusted, and ONLY the extra duration amount (₹59.00) is debited from FASTag!
        """
        car_slot = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")[0]
        arrival_time = (datetime.now() + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")

        res_id = create_reservation(
            customer_name="Extra Time User",
            customer_phone="+91-98765-43216",
            vehicle_number="TN-09-XY-2222",
            vehicle_type="Car",
            slot_id=car_slot["id"],
            reserved_for_str=arrival_time,
            payment_method="Credit / Debit Card",
            db_path=TEST_DB
        )

        ticket = check_in_from_reservation(res_id, db_path=TEST_DB)
        self.assertEqual(ticket["prepaid_deposit"], 59.00)

        # Exit at 1 hour 45 minutes (105 minutes -> 1 hr base + 2 slabs of 30 mins)
        # Base: ₹50.00, Slabs: 2 * ₹25.00 = +₹50.00. Subtotal: ₹100.00 + 18% GST (₹18.00) = ₹118.00.
        # Upfront deposit adjusted: ₹59.00.
        # Net extra amount to debit: ₹118.00 - ₹59.00 = ₹59.00!
        sim_exit_105m = datetime.now() + timedelta(hours=1, minutes=45)
        bill = calculate_parking_bill(ticket, exit_time_dt=sim_exit_105m, billing_model="prorated_30min", db_path=TEST_DB)
        self.assertEqual(bill["total_fee"], 118.00)
        self.assertEqual(bill["prepaid_deposit"], 59.00)
        self.assertEqual(bill["net_payable"], 59.00)

        # FASTag Auto-Debit: Debits exactly ₹59.00 from FASTag
        receipt = process_fastag_payment(ticket["ticket_id"], billing_model="prorated_30min", exit_time_dt=sim_exit_105m, db_path=TEST_DB)
        self.assertEqual(receipt["payment_status"], "Paid")
        self.assertEqual(receipt["fastag_meta"]["debit_status"], "EXTRA_DURATION_DEBIT_SUCCESS")
        self.assertEqual(receipt["fastag_meta"]["debited_amount_float"], 59.00)
        self.assertEqual(receipt["fastag_meta"]["upfront_deposit_adjusted_float"], 59.00)
        self.assertEqual(receipt["fastag_meta"]["total_session_fee_float"], 118.00)

    def test_advance_booking_disallows_cash_and_counter(self):
        """Advance reservations must reject Cash/Counter payment since physical cash cannot be collected prior to arrival."""
        car_slot = get_slots(db_path=TEST_DB, status="Available", slot_type="Car")[0]
        arrival_time = (datetime.now() + timedelta(minutes=15)).strftime("%Y-%m-%d %H:%M:%S")

        with self.assertRaises(ValueError) as ctx:
            create_reservation(
                customer_name="Cash User",
                customer_phone="+91-98765-43217",
                vehicle_number="KA-05-NO-CASH",
                vehicle_type="Car",
                slot_id=car_slot["id"],
                reserved_for_str=arrival_time,
                payment_method="Cash / Counter Deposit",
                db_path=TEST_DB
            )
        self.assertIn("Cash / Counter deposit cannot be selected", str(ctx.exception))

if __name__ == "__main__":
    unittest.main()

