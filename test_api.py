import os
import unittest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from api import app
from database import init_db, reset_to_clean_production, update_rate, DEFAULT_DB_PATH

class TestParkingAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        reset_to_clean_production()
        cls.client = TestClient(app)

    def setUp(self):
        reset_to_clean_production()
        update_rate("Car", 50.0, 50.0)
        update_rate("EV", 60.0, 60.0)
        update_rate("SUV", 70.0, 70.0)
        update_rate("Bike", 20.0, 20.0)
        update_rate("Handicap", 30.0, 30.0)

    def test_1_health_and_summary(self):
        res = self.client.get("/api/health")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["status"], "online")

        res_sum = self.client.get("/api/bays/summary")
        self.assertEqual(res_sum.status_code, 200)
        data = res_sum.json()
        self.assertEqual(data["total_bays"], 24)
        self.assertEqual(data["available_bays"], 24)
        self.assertEqual(data["occupied_bays"], 0)

    def test_2_list_and_filter_bays(self):
        res = self.client.get("/api/bays")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["count"], 24)

        # Filter by EV
        res_ev = self.client.get("/api/bays?slot_type=EV")
        self.assertEqual(res_ev.status_code, 200)
        self.assertTrue(all(b["slot_type"] == "EV" for b in res_ev.json()["bays"]))

    def test_3_checkin_and_checkout_flow(self):
        # Check in a vehicle
        payload = {
            "vehicle_number": "KA-01-AB-9090",
            "vehicle_type": "Car",
            "driver_name": "Test Driver",
            "driver_phone": "+91-98765-43210"
        }
        res_in = self.client.post("/api/checkin", json=payload)
        self.assertEqual(res_in.status_code, 201)
        ticket = res_in.json()["ticket"]
        self.assertEqual(ticket["vehicle_number"], "KA-01-AB-9090")
        self.assertFalse(res_in.json()["is_advance_booking"])

        # Check locator
        res_loc = self.client.get("/api/locator?query=KA-01-AB-9090")
        self.assertEqual(res_loc.status_code, 200)
        self.assertEqual(res_loc.json()["vehicle_number"], "KA-01-AB-9090")

        # Checkout
        res_out = self.client.post("/api/checkout", json={
            "ticket_id": ticket["ticket_id"],
            "payment_method": "FASTag (NETC Auto-Debit)",
            "billing_model": "prorated_30min"
        })
        self.assertEqual(res_out.status_code, 200)
        self.assertEqual(res_out.json()["receipt"]["payment_status"], "Paid")

    def test_4_advance_booking_rejections_and_fulfillment(self):
        # 1. Reject Cash
        res_cash = self.client.post("/api/reservations", json={
            "customer_name": "Cash Person",
            "customer_phone": "+91-98765-43211",
            "vehicle_number": "KA-02-CD-1111",
            "vehicle_type": "Car",
            "slot_id": 6,
            "reserved_for": (datetime.now() + timedelta(minutes=15)).strftime("%Y-%m-%d %H:%M:%S"),
            "payment_method": "Cash / Counter Deposit"
        })
        self.assertEqual(res_cash.status_code, 400)
        self.assertIn("Cash / Counter deposit cannot be selected", res_cash.json()["detail"])

        # 2. Reject FASTag
        res_fastag = self.client.post("/api/reservations", json={
            "customer_name": "FASTag Person",
            "customer_phone": "+91-98765-43212",
            "vehicle_number": "KA-02-CD-2222",
            "vehicle_type": "Car",
            "slot_id": 6,
            "reserved_for": (datetime.now() + timedelta(minutes=15)).strftime("%Y-%m-%d %H:%M:%S"),
            "payment_method": "FASTag (Auto-Debit)"
        })
        self.assertEqual(res_fastag.status_code, 400)
        self.assertIn("FASTag cannot be selected for advance bookings", res_fastag.json()["detail"])

        # 3. Create valid advance booking via UPI
        res_valid = self.client.post("/api/reservations", json={
            "customer_name": "Online User",
            "customer_phone": "+91-98765-43213",
            "vehicle_number": "KA-02-CD-3333",
            "vehicle_type": "Car",
            "slot_id": 6,
            "reserved_for": (datetime.now() + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S"),
            "payment_method": "UPI / QR Scan"
        })
        self.assertEqual(res_valid.status_code, 201)
        res_obj = res_valid.json()["reservation"]
        self.assertEqual(res_obj["vehicle_number"], "KA-02-CD-3333")
        self.assertEqual(res_obj["deposit_amount"], 59.0)

        # 4. Check-in with that plate -> automatically detects booking!
        res_auto_checkin = self.client.post("/api/checkin", json={
            "vehicle_number": "KA-02-CD-3333",
            "vehicle_type": "Car"
        })
        self.assertEqual(res_auto_checkin.status_code, 201)
        data = res_auto_checkin.json()
        self.assertTrue(data["is_advance_booking"])
        self.assertEqual(data["deposit_credited"], 59.0)
        self.assertEqual(data["ticket"]["slot_number"], "A-06")

    def test_5_tickets_history_and_kpi_drilldown(self):
        # 1. Tickets endpoint
        res = self.client.get("/api/tickets?limit=10")
        self.assertEqual(res.status_code, 200)
        self.assertIn("tickets", res.json())

        # 2. KPI drilldown endpoints
        for kpi in ["capacity", "available", "occupied", "occupancy", "revenue"]:
            r_kpi = self.client.get(f"/api/kpi/drilldown?kpi_type={kpi}")
            self.assertEqual(r_kpi.status_code, 200)
            self.assertIn("kpi", r_kpi.json())

    def test_6_rates_update_and_admin_reset(self):
        # 1. Update rate
        res = self.client.post("/api/rates", json={
            "vehicle_type": "Car",
            "hourly_rate": 65.0,
            "min_charge": 65.0
        })
        self.assertEqual(res.status_code, 200)

        # Verify rate changed
        res_rates = self.client.get("/api/rates")
        self.assertEqual(res_rates.status_code, 200)
        self.assertEqual(res_rates.json()["rates"]["Car"]["hourly_rate"], 65.0)

        # Restore rate back to 50.0
        self.client.post("/api/rates", json={
            "vehicle_type": "Car",
            "hourly_rate": 50.0,
            "min_charge": 50.0
        })

        # 2. Admin Reset
        res_reset = self.client.post("/api/admin/reset")
        self.assertEqual(res_reset.status_code, 200)
        self.assertIn("Facility successfully reset", res_reset.json()["message"])

    def test_7_direct_reservation_checkin(self):
        # Create a booking (Slot 7 is a Car bay)
        res_valid = self.client.post("/api/reservations", json={
            "customer_name": "Direct User",
            "customer_phone": "+91-98765-43219",
            "vehicle_number": "KA-05-XY-9999",
            "vehicle_type": "Car",
            "slot_id": 7,
            "reserved_for": (datetime.now() + timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S"),
            "payment_method": "UPI / QR Scan"
        })
        self.assertEqual(res_valid.status_code, 201)
        res_id = res_valid.json()["reservation"]["reservation_id"]

        # Directly check in from reservation
        res_checkin = self.client.post(f"/api/reservations/{res_id}/checkin?fastag_id=FASTAG-9999")
        self.assertEqual(res_checkin.status_code, 200)
    def test_8_parking_bay_crud(self):
        # 1. Create new bay
        res_create = self.client.post("/api/bays", json={
            "slot_number": "D-01",
            "zone": "Zone D (Basement)",
            "floor": -1,
            "slot_type": "Car",
            "notes": "Premium covered bay",
            "status": "Available"
        })
        self.assertEqual(res_create.status_code, 201)
        bay = res_create.json()["bay"]
        self.assertEqual(bay["slot_number"], "D-01")
        self.assertEqual(bay["floor"], -1)
        bay_id = bay["id"]

        # 2. Reject duplicate
        res_dup = self.client.post("/api/bays", json={
            "slot_number": "D-01",
            "zone": "Zone D (Basement)",
            "floor": -1,
            "slot_type": "Car"
        })
        self.assertEqual(res_dup.status_code, 400)

        # 3. Update bay
        res_update = self.client.put(f"/api/bays/{bay_id}", json={
            "status": "Maintenance",
            "notes": "Undergoing repaint"
        })
        self.assertEqual(res_update.status_code, 200)
        self.assertEqual(res_update.json()["bay"]["status"], "Maintenance")
        self.assertEqual(res_update.json()["bay"]["notes"], "Undergoing repaint")

        # 4. Delete bay
        res_del = self.client.delete(f"/api/bays/{bay_id}")
        self.assertEqual(res_del.status_code, 200)

        # 5. Verify 404 after deletion
        res_get = self.client.get(f"/api/bays/{bay_id}")
        self.assertEqual(res_get.status_code, 404)

if __name__ == "__main__":
    unittest.main()

