import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';

class CheckOutView extends StatefulWidget {
  const CheckOutView({Key? key}) : super(key: key);

  @override
  State<CheckOutView> createState() => _CheckOutViewState();
}

class _CheckOutViewState extends State<CheckOutView> {
  final _searchController = TextEditingController();
  String _paymentMethod = 'FASTag (NETC Auto-Debit)';
  String _billingModel = 'prorated_30min';
  Map<String, dynamic>? _lastReceipt;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();
    final occupiedBays = vm.bays.where((b) => b.isOccupied).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-Out & Settlement', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Occupied Vehicles Selector
            const Text('Select Parked Vehicle or Enter Plate/Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (occupiedBays.isNotEmpty)
              DropdownButtonFormField<String>(
                hint: const Text('Choose currently parked vehicle'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: occupiedBays.map((b) {
                  return DropdownMenuItem(
                    value: b.ticketId ?? b.vehicleNumber ?? '',
                    child: Text('${b.vehicleNumber} (Bay ${b.slotNumber}, ${b.slotType})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _searchController.text = val);
                },
              ),

            const SizedBox(height: 12),

            TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'License Plate or Ticket ID *',
                hintText: 'e.g. KA-01-AB-1234 or TKT-...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),

            const SizedBox(height: 16),

            // Billing Tariff Model
            const Text('Tariff Calculation Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _billingModel,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'prorated_30min', child: Text('Model B: 30-Min Slabs (Standard)')),
                DropdownMenuItem(value: 'hourly_block', child: Text('Model A: Full Hourly Block (Ceiling)')),
                DropdownMenuItem(value: 'exact_prorata', child: Text('Model C: Exact Per-Minute Pro-Rata')),
              ],
              onChanged: (val) => setState(() => _billingModel = val!),
            ),

            const SizedBox(height: 16),

            // Payment Mode
            const Text('Payment Settlement Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'FASTag (NETC Auto-Debit)', child: Text('FASTag (NETC Auto-Debit)')),
                DropdownMenuItem(value: 'UPI / QR Scan', child: Text('UPI / QR Scan')),
                DropdownMenuItem(value: 'Credit / Debit Card', child: Text('Credit / Debit Card')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              ],
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),

            const SizedBox(height: 12),

            if (_paymentMethod.contains('FASTag'))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.sensors_rounded, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Within 1-hr prepaid window: 100% deposit adjusted (₹0.00 debit). After 1 hr: extra duration debited automatically.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Process Settlement & Open Exit Barrier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: vm.isLoading
                    ? null
                    : () async {
                        final query = _searchController.text.trim();
                        if (query.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select or enter a parked vehicle')),
                          );
                          return;
                        }

                        final receipt = await vm.checkOut(
                          ticketId: query,
                          paymentMethod: _paymentMethod,
                          billingModel: _billingModel,
                        );

                        if (receipt != null && mounted) {
                          setState(() => _lastReceipt = receipt['receipt'] as Map<String, dynamic>? ?? receipt);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Checkout completed! Exit barrier open.'),
                              backgroundColor: Color(0xFF10B981),
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

            // Receipt Display Card
            if (_lastReceipt != null) ...[
              const Text('🧾 Exit Billing Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildReceiptCard(_lastReceipt!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> r) {
    final bill = r['bill_summary'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🅿️ PARKFLOW RECEIPT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Text('SETTLED', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: 20),
          _receiptRow('VEHICLE PLATE:', r['vehicle_number'] ?? 'N/A', isBold: true),
          _receiptRow('BAY CODE:', 'Bay ${r['slot_number'] ?? 'N/A'}'),
          _receiptRow('DWELL TIME:', bill != null ? bill['duration_formatted'] ?? '${bill['duration_minutes']}m' : 'Settled'),
          if (bill != null && (bill['prepaid_deposit'] ?? 0) > 0)
            _receiptRow('UPFRONT DEPOSIT ADJUSTED:', '-₹${(bill['prepaid_deposit'] as num).toStringAsFixed(2)}', color: const Color(0xFF10B981)),
          _receiptRow('TOTAL PAID:', '₹${(r['total_fee'] as num? ?? 0).toStringAsFixed(2)}', isBold: true, color: const Color(0xFF2563EB)),
          _receiptRow('PAYMENT METHOD:', r['payment_method'] ?? 'FASTag'),
          _receiptRow('EXIT TIMESTAMP:', r['exit_time'] ?? 'Just now'),
          const SizedBox(height: 10),
          const Center(
            child: Text('Thank you for visiting! Have a safe drive.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String key, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
