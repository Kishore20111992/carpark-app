# 📱 ParkFlow Mobile Application (Android & iOS)

A cross-platform smart parking management mobile application built with **Flutter (Dart)** and backed by the **ParkFlow FastAPI REST Engine**.

---

## 🌟 Key Features

1. **Live 2D Bay Visualizer Grid**:
   - Real-time updates every 2 seconds: 🟢 Available, 🔴 Occupied, 🟡 Reserved.
   - Filter by vehicle category: Car, EV (with charger icon), SUV, Bike, Handicap.
   - Live parking dwell duration timer on occupied bays.
2. **Advance Reservation & Upfront Online Payment**:
   - Reserve dedicated category bays ahead of arrival.
   - 1-hour upfront non-refundable deposit calculation (₹59.00).
   - Strict online payment methods: **UPI / QR Scan, Credit / Debit Card, Net Banking**.
   - Cash and FASTag are strictly disabled prior to arrival.
3. **Smart Check-In & Gate Boom Barrier Pass**:
   - Automatic detection of active advance reservations when typing or scanning a plate.
   - Windshield FASTag RFID EPC sensor auto-detection.
   - Digital Parking Pass with QR code for barrier reader.
4. **Checkout & Contactless FASTag Settlement**:
   - Model B (1st hr base + 30m prorated slabs).
   - Within 1-hr prepaid arrival window: 100% deposit adjusted, ₹0.00 FASTag debit.
   - After 1 hour: Extra duration fee automatically debited from FASTag wallet.
5. **Find My Car (Floor Locator)**:
   - Search by license plate or ticket ID.
   - Displays exact assigned bay, floor level, zone, accrued bill, and walking directions.

---

## 🏗️ Architecture (MVVM)

```text
lib/
├── main.dart
├── data/
│   ├── models/         # BayModel, SummaryModel, TicketModel, ReservationModel
│   ├── services/       # ApiService (HTTP client)
│   └── repositories/   # ParkingRepository (Data abstraction layer)
└── ui/
    ├── view_models/    # ParkingViewModel (ChangeNotifier state container)
    └── views/          # 5 primary screens: Bays, Reserve, Check-In, Check-Out, Locator
```

---

## 🚀 How to Run & Build

### Prerequisites
1. Ensure the ParkFlow FastAPI backend is running:
   ```bash
   python -m uvicorn api:app --host 0.0.0.0 --port 8000
   ```
2. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.2.0 or higher).

### Run on Android Emulator or Physical Device
```bash
cd mobile_app
flutter pub get
flutter run -d android
```
> **Note**: Android emulators automatically route `https://10.0.2.2:8000` to your computer's `localhost:8000`. For physical Android phones over Wi-Fi, change the server URL to your machine's LAN IP (e.g. `https://10.9.240.129:8000`).

### Build Production Android APK
```bash
flutter build apk --release
# Generated APK: build/app/outputs/flutter-apk/app-release.apk
```

### Run on iOS Simulator or iPhone (macOS)
```bash
cd mobile_app
flutter pub get
cd ios && pod install && cd ..
flutter run -d ios
```

### Build Production iOS Archive / IPA
```bash
flutter build ipa --release
```
