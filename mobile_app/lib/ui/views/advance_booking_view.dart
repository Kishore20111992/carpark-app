import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';
import '../../data/models/reservation_model.dart';

class AdvanceBookingView extends StatefulWidget {
  const AdvanceBookingView({Key? key}) : super(key: key);

  @override
  State<AdvanceBookingView> createState() => _AdvanceBookingViewState();
}

class _AdvanceBookingViewState extends State<AdvanceBookingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Car';
  int? _selectedSlotId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _paymentMethod = 'UPI / QR Scan';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  String _ledgerFilter = 'All';

  double get _depositAmount {
    switch (_selectedCategory) {
      case 'EV':
        return 70.80; // 60 + 18% GST
      case 'SUV':
        return 82.60; // 70 + 18% GST
      case 'Bike':
        return 23.60; // 20 + 18% GST
      case 'Handicap':
        return 35.40; // 30 + 18% GST
      default:
        return 59.00; // 50 + 18% GST
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<ParkingViewModel>();
      if (vm.preselectedSlotForReserve != null) {
        setState(() => _selectedSlotId = vm.preselectedSlotForReserve);
        vm.clearPrefills();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advance Reservations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.loadData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline_rounded), text: 'New Booking'),
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Bookings Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewBookingTab(context, vm),
          _buildLedgerTab(context, vm),
        ],
      ),
    );
  }

  Widget _buildNewBookingTab(BuildContext context, ParkingViewModel vm) {
    final matchingAvailableBays = vm.bays
        .where((b) => b.isAvailable && b.slotType.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Policy Notice Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF991B1B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '1-Hour Prepaid Policy: A non-refundable 1st-hour deposit of ₹${_depositAmount.toStringAsFixed(2)} is collected upfront. Bay is held exclusively for 1 hour from scheduled arrival.',
                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Category Selector
            const Text('Vehicle Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ['Car', 'EV', 'Bike', 'SUV', 'Handicap']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                    _selectedSlotId = null;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Bay Selector
            const Text('Select Dedicated Parking Bay *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (matchingAvailableBays.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text('No available bays for $_selectedCategory right now.', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedSlotId,
                hint: const Text('Choose a vacant bay'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: matchingAvailableBays.map((b) {
                  return DropdownMenuItem<int>(
                    value: b.id,
                    child: Text('Bay ${b.slotNumber} - ${b.zone} (Floor ${b.floor})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSlotId = val),
                validator: (val) => val == null ? 'Please select a parking bay' : null,
              ),

            const SizedBox(height: 16),

            // Customer Name & Phone
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Customer Full Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact Mobile (+91) *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit phone' : null,
            ),
            const SizedBox(height: 12),

            // Vehicle Plate
            TextFormField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle License Plate *',
                hintText: 'e.g. KA-01-AB-1234',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter license plate' : null,
            ),

            const SizedBox(height: 16),

            // Date & Time Picker
            const Text('Scheduled Arrival Time *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_rounded, size: 18),
                    label: Text(_selectedTime.format(context)),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Payment method (Rejects Cash & FASTag upfront)
            const Text('Upfront Deposit Payment *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'UPI / QR Scan', child: Text('UPI / QR Scan')),
                DropdownMenuItem(value: 'Credit / Debit Card', child: Text('Credit / Debit Card')),
                DropdownMenuItem(value: 'Net Banking', child: Text('Net Banking')),
              ],
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),

            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_rounded),
                label: Text('Pay Deposit ₹${_depositAmount.toStringAsFixed(2)} & Reserve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: vm.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_selectedSlotId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bay')));
                          return;
                        }

                        final arrivalDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _selectedTime.hour,
                          _selectedTime.minute,
                        );

                        final formattedDateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(arrivalDateTime);

                        final success = await vm.createReservation(
                          customerName: _nameController.text.trim(),
                          customerPhone: _phoneController.text.trim(),
                          vehicleNumber: _plateController.text.trim().toUpperCase(),
                          vehicleType: _selectedCategory,
                          slotId: _selectedSlotId!,
                          reservedFor: formattedDateStr,
                          paymentMethod: _paymentMethod,
                        );

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Reservation confirmed! Bay held for 1 hour.')),
                          );
                          _plateController.clear();
                          _nameController.clear();
                          _phoneController.clear();
                          setState(() => _selectedSlotId = null);
                          _tabController.animateTo(1); // Switch to ledger tab
                        } else if (vm.errorMessage != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTab(BuildContext context, ParkingViewModel vm) {
    final allRes = vm.reservations;
    final filtered = _ledgerFilter == 'All'
        ? allRes
        : allRes.where((r) => r.status.toLowerCase() == _ledgerFilter.toLowerCase()).toList();

    return Column(
      children: [
        // Top Toolbar with Filter & Sweep Button
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'CheckedIn', 'NoShow_Forfeited'].map((status) {
                      final isSelected = _ledgerFilter == status;
                      final label = status == 'CheckedIn'
                          ? 'Checked-In'
                          : (status == 'NoShow_Forfeited' ? 'No-Show' : status);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _ledgerFilter = status),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sweep Expired Bookings',
                icon: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFD97706)),
                onPressed: () async {
                  final cnt = await vm.sweepExpiredReservations();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(cnt > 0 ? 'Swept $cnt expired booking(s)!' : 'All bookings within window')),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => vm.loadData(),
            child: filtered.isEmpty
                ? const Center(child: Text('No reservation records found', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final r = filtered[i];
                      return _buildReservationCard(context, vm, r);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(BuildContext context, ParkingViewModel vm, ReservationModel r) {
    Color borderColor;
    Color badgeColor;
    Color badgeTextColor;
    String statusText;

    if (r.isActive) {
      borderColor = const Color(0xFFF59E0B);
      badgeColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFF92400E);
      statusText = 'ACTIVE RESERVATION';
    } else if (r.status == 'NoShow_Forfeited') {
      borderColor = const Color(0xFFEF4444);
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFF991B1B);
      statusText = 'NO-SHOW (DEPOSIT FORFEITED)';
    } else if (r.status == 'CheckedIn') {
      borderColor = const Color(0xFF10B981);
      badgeColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF166534);
      statusText = 'CHECKED-IN (DEPOSIT CREDITED)';
    } else {
      borderColor = const Color(0xFF94A3B8);
      badgeColor = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
      statusText = r.status.toUpperCase();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.reservationId, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusText, style: TextStyle(color: badgeTextColor, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('👤 ${r.customerName} (${r.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text('🚗 ${r.vehicleNumber} (${r.vehicleType}) • Bay ${r.slotNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 2),
            Text('⏰ Scheduled: ${r.reservedFor} (1-Hr Window)', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('💰 Deposit: ₹${r.depositAmount.toStringAsFixed(2)} (${r.paymentMethod})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),

            if (r.isActive) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Check-In (Credit Deposit)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final ok = await vm.checkInFromReservation(r.reservationId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Checked in ${r.vehicleNumber}!' : 'Check-in failed')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                    label: const Text('Cancel', style: TextStyle(color: Color(0xFFDC2626))),
                    onPressed: () async {
                      final ok = await vm.cancelReservation(r.reservationId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Reservation cancelled. Bay freed.' : 'Cancel failed')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
