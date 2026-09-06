# 🅿️ ParkFlow - Smart Parking Bay Management System

An intuitive, interactive, full-featured **Parking Slot Management & Allocation Application** built with Python, Streamlit, and SQLite.

---

## 🌟 Key Features

1. **🗺️ Interactive Parking Bay Visualizer**:
   - Multi-floor and multi-zone parking layout:
     - **Zone A (Ground Floor)**: Fast turnaround, 50kW EV Fast Chargers, Accessible/Handicap bays.
     - **Zone B (Level 1)**: Compact car stalls & designated two-wheeler / motorcycle bays.
     - **Zone C (Level 2)**: Full-size SUV & long-stay covered parking bays.
   - Live color-coded status badges (🟢 Available, 🔴 Occupied, 🟡 Reserved, ⚪ Maintenance).
   - Real-time parked vehicle plate numbers and elapsed parking duration.

2. **🚗 Vehicle Check-In & Smart Bay Allocation**:
   - Input registration plate, vehicle category (`Car`, `EV`, `Bike`, `SUV`, `Handicap`), driver contact.
   - **Smart Recommendation Engine**: Automatically assigns the closest optimal bay matching vehicle specs and charging requirements.
   - Option for manual bay selection.
   - Instant **Digital Parking Pass** with ticket ID, assigned stall, timestamps, and barcode pass representation.

3. **💳 Cashier Check-Out & Billing Counter**:
   - Instant vehicle lookup by plate number or ticket ID.
   - Accurate duration tracking (hours & minutes) and dynamic tariff calculation.
   - EV fast-charging surcharge & facility tax calculation.
   - Multi-channel settlement: Credit/Debit Card, Cash, UPI / QR Scan, Apple/Google Pay.
   - Automatic slot release upon payment.

4. **🔍 Vehicle Finder (Lost Car Locator)**:
   - Search by license plate or ticket number.
   - Shows assigned bay, floor, zone, and walking directions.

5. **📅 Advance Slot Reservations**:
   - Reserve guaranteed parking bays for VIP guests or scheduled arrivals.
   - Direct one-click check-in or cancellation.

6. **📊 Analytics, Audit Logs & Rate Configuration**:
   - Occupancy percentage and revenue metrics.
   - Visual distribution of parking bay occupancy and vehicle categories.
   - Full transaction audit log with **One-Click CSV Export**.
   - Live editable hourly and base tariff settings per vehicle class.

---

## 🚀 Quickstart Guide

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run the Automated Test Suite
```bash
python test_parking.py
```

### 3. Launch the Application
```bash
python -m streamlit run app.py
```
Open your browser at `https://localhost:8501`.

---

## 🏗️ Project Structure

- `app.py`: Streamlit front-end UI with custom CSS styling, parking floor maps, check-in, check-out, and charts.
- `parking_manager.py`: Business logic (smart allocation, tariff calculator, reservation lifecycle, metrics).
- `database.py`: SQLite persistence layer (`parking.db`) with auto-initialization and seed data.
- `test_parking.py`: Comprehensive automated unit tests.
- `Dockerfile`: Production container build specification.
