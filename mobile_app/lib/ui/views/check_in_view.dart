import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/reservation_model.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({Key? key}) : super(key: key);

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  final _plateController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _vehicleType = 'Car';
  bool _isEvCharging = false;
  ReservationModel? _detectedReservation;

  @override
  void dispose() {
    _plateController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPlateChanged(String value, List<ReservationModel> activeReservations) {
    final cleanInput = value.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (cleanInput.isEmpty) {
      setState(() => _detectedReservation = null);
      return;
    }

    final match = activeReservations.firstWhere(
      (r) => r.isActive && r.vehicleNumber.replaceAll('-', '').replaceAll(' ', '').toUpperCase() == cleanInput,
      orElse: () => ReservationModel(
        reservationId: '',
        customerName: '',
        customerPhone: '',
        vehicleNumber: '',
        vehicleType: '',
        slotNumber: '',
        reservedFor: '',
        depositAmount: 0,
        paymentMethod: '',
        status: '',
      ),
    );

    setState(() {
      if (match.reservationId.isNotEmpty) {
        _detectedReservation = match;
        _vehicleType = match.vehicleType;
        _nameController.text = match.customerName;
        _phoneController.text = match.customerPhone;
      } else {
        _detectedReservation = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Check-In & Pass', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boom Barrier Sensor Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('GATE BOOM BARRIER ACTIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A))),
                        Text('FASTag RFID sensor & advance booking auto-detection enabled.', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // License Plate Field
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle Registration Plate *',
                hintText: 'Enter vehicle license plate',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car_rounded),
              ),
              onChanged: (val) => _onPlateChanged(val, vm.reservations),
            ),

            const SizedBox(height: 14),

            // Advance Booking Banner
            if (_detectedReservation != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🎉 ADVANCE BOOKING VERIFIED',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                          child: const Text('PREPAID', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Booking Ref: ${_detectedReservation!.reservationId}', style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                    Text('Designated Bay: Bay ${_detectedReservation!.slotNumber} (${_detectedReservation!.vehicleType})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    Text('Upfront Deposit Paid: ₹${_detectedReservation!.depositAmount.toStringAsFixed(2)} (Will be credited)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                  ],
                ),
              ),

            // Vehicle Category Dropdown
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Category',
                border: OutlineInputBorder(),
              ),
              items: ['Car', 'EV', 'Bike', 'SUV', 'Handicap']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: _detectedReservation != null ? null : (val) => setState(() => _vehicleType = val!),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Driver Name (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Driver Phone (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),

            if (_vehicleType == 'EV') ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Plug-in for EV Fast Charging (+₹150 surcharge)'),
                value: _isEvCharging,
                onChanged: (val) => setState(() => _isEvCharging = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(
                  _detectedReservation != null
                      ? 'Check-In from Booking (Bay ${_detectedReservation!.slotNumber})'
                      : 'Complete Check-In & Issue Pass',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: vm.isLoading
                    ? null
                    : () async {
                        final plate = _plateController.text.trim().toUpperCase();
                        if (plate.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a vehicle license plate number')),
                          );
                          return;
                        }

                        final success = await vm.checkIn(
                          vehicleNumber: plate,
                          vehicleType: _vehicleType,
                          driverName: _nameController.text.trim(),
                          driverPhone: _phoneController.text.trim(),
                          isEvCharging: _isEvCharging,
                        );

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Vehicle $plate Checked In! Digital Pass Generated.'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        } else if (mounted && vm.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(vm.errorMessage!), backgroundColor: Colors.red),
                          );
                        }
                      },
              ),
            ),

            const SizedBox(height: 24),

            // Digital Pass Display Card if generated
            if (vm.latestTicket != null) ...[
              const Text('🎫 Generated Digital Parking Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildDigitalPass(vm.latestTicket!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalPass(Map<String, dynamic> ticketData) {
    final ticket = ticketData['ticket'] as Map<String, dynamic>? ?? ticketData;
    final isAdv = ticketData['is_advance_booking'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🅿️ PARKFLOW PASS', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A), fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Text('ACTIVE SESSION', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: 20),
          _passRow('TICKET ID:', ticket['ticket_id'] ?? 'N/A', isBold: true),
          _passRow('VEHICLE PLATE:', ticket['vehicle_number'] ?? 'N/A', isBold: true),
          _passRow('ASSIGNED BAY:', 'Bay ${ticket['slot_number'] ?? 'N/A'}', color: const Color(0xFF10B981), isBold: true),
          _passRow('CATEGORY:', ticket['vehicle_type'] ?? 'Car'),
          _passRow('FASTag RFID:', ticket['fastag_id'] ?? 'Auto-Linked'),
          if (isAdv || (ticket['prepaid_deposit'] ?? 0) > 0)
            _passRow('DEPOSIT CREDITED:', '₹${(ticket['prepaid_deposit'] as num).toStringAsFixed(2)}', color: const Color(0xFF10B981)),
          _passRow('ENTRY TIME:', ticket['entry_time'] ?? 'Just now'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: const Center(
              child: Text(
                'Present pass or vehicle RFID at exit boom barrier for contactless checkout',
                style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passRow(String key, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
