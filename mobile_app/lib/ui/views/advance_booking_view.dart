import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';

class AdvanceBookingView extends StatefulWidget {
  const AdvanceBookingView({Key? key}) : super(key: key);

  @override
  State<AdvanceBookingView> createState() => _AdvanceBookingViewState();
}

class _AdvanceBookingViewState extends State<AdvanceBookingView> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Car';
  int? _selectedSlotId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _paymentMethod = 'UPI / QR Scan';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  double get _depositAmount {
    switch (_selectedCategory) {
      case 'EV':
        return 70.80; // 60 + 18% GST
      case 'SUV':
        return 82.60; // 70 + 18% GST
      case 'Bike':
        return 23.60; // 20 + 18% GST
      default:
        return 59.00; // 50 + 18% GST
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();
    final matchingAvailableBays = vm.bays
        .where((b) => b.isAvailable && b.slotType.toLowerCase() == _selectedCategory.toLowerCase())
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advance Reservation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: ['Car', 'EV', 'Bike', 'SUV', 'Handicap']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                    _selectedSlotId = null;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Bay Selector (Strictly Category Matched)
              const Text('Select Dedicated Bay *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (matchingAvailableBays.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    '⚠️ No available $_selectedCategory bays. Other categories cannot be booked.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  value: _selectedSlotId,
                  hint: Text('Select Bay (${matchingAvailableBays.length} available)'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: matchingAvailableBays
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('${b.slotNumber} - ${b.zone} (${b.slotType})'),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSlotId = val),
                  validator: (v) => v == null ? 'Please select a bay' : null,
                ),

              const SizedBox(height: 16),

              // Customer Details
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number * (10 Digits)',
                  hintText: 'Enter 10-digit mobile number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10) return 'Requires minimum 10 digits';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Registration Plate *',
                  hintText: 'Enter vehicle plate number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Plate number is required' : null,
              ),

              const SizedBox(height: 16),

              // Scheduled Date & Time
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(_selectedTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Upfront Payment Method (Strictly Digital: No Cash, No FASTag)
              const Text('Upfront Deposit Payment *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text(
                'Instant digital settlement. Cash and FASTag are disabled prior to arrival.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: ['UPI / QR Scan', 'Credit / Debit Card', 'Net Banking']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text('Pay ₹${_depositAmount.toStringAsFixed(2)} & Reserve Bay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: vm.isLoading || matchingAvailableBays.isEmpty
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate() && _selectedSlotId != null) {
                            final arrivalDateTime = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              _selectedTime.hour,
                              _selectedTime.minute,
                            );
                            final arrivalStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(arrivalDateTime);

                            final success = await vm.createReservation(
                              customerName: _nameController.text.trim(),
                              customerPhone: _phoneController.text.trim(),
                              vehicleNumber: _plateController.text.trim().toUpperCase(),
                              vehicleType: _selectedCategory,
                              slotId: _selectedSlotId!,
                              reservedFor: arrivalStr,
                              paymentMethod: _paymentMethod,
                            );

                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Bay Reserved! 1-Hour prepaid window active.'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                              _formKey.currentState!.reset();
                              _nameController.clear();
                              _phoneController.clear();
                              _plateController.clear();
                            } else if (mounted && vm.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
