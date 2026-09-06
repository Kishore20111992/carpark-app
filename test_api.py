import os
import unittest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from api import app
from database import init_db, reset_to_clean_production, DEFAULT_DB_PATH

class TestParkingAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        reset_to_clean_production()
        cls.client = TestClient(app)

    def setUp(self):
        reset_to_clean_production()

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

if __name__ == "__main__":
    unittest.main()
