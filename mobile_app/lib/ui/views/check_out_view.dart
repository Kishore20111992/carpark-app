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
  Map<String, dynamic>? _billPreview;
  Map<String, dynamic>? _lastReceipt;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<ParkingViewModel>();
      if (vm.prefilledPlateForCheckout != null) {
        _searchController.text = vm.prefilledPlateForCheckout!;
        _fetchBillPreview(vm.prefilledPlateForCheckout!);
        vm.clearPrefills();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchBillPreview(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    setState(() => _loadingPreview = true);
    final vm = context.read<ParkingViewModel>();
    final preview = await vm.previewBill(clean, billingModel: _billingModel);
    setState(() {
      _billPreview = preview;
      _loadingPreview = false;
    });
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
                  if (val != null) {
                    setState(() => _searchController.text = val);
                    _fetchBillPreview(val);
                  }
                },
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'License Plate or Ticket ID *',
                      hintText: 'e.g. KA-01-AB-1234 or TKT-...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loadingPreview ? null : () => _fetchBillPreview(_searchController.text),
                    child: _loadingPreview
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Calculate'),
                  ),
                ),
              ],
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
              onChanged: (val) {
                if (val != null) {
                  setState(() => _billingModel = val);
                  if (_searchController.text.isNotEmpty) {
                    _fetchBillPreview(_searchController.text);
                  }
                }
              },
            ),

            const SizedBox(height: 16),

            // Live Bill Preview Card if loaded
            if (_billPreview != null) ...[
              _buildBillPreviewCard(_billPreview!),
              const SizedBox(height: 16),
            ],

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
                        'FASTag auto-debit: within 1-hr prepaid window, 100% deposit adjusted (₹0.00 debit). Excess duration debited automatically.',
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
                          setState(() {
                            _lastReceipt = receipt['receipt'] as Map<String, dynamic>? ?? receipt;
                            _billPreview = null;
                            _searchController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settlement complete! Exit barrier opened.')),
                          );
                        } else if (vm.errorMessage != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(vm.errorMessage!)),
                          );
                        }
                      },
              ),
            ),

            const SizedBox(height: 24),

            // Receipt Display
            if (_lastReceipt != null) ...[
              const Text('🧾 Official Tax Invoice Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildReceiptCard(_lastReceipt!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillPreviewCard(Map<String, dynamic> preview) {
    final bill = preview['bill'] as Map<String, dynamic>? ?? {};
    final ticket = preview['ticket'] as Map<String, dynamic>? ?? {};
    final duration = bill['duration_formatted'] ?? 'N/A';
    final baseTariff = (bill['base_tariff'] as num?)?.toDouble() ?? 0.0;
    final extraSlabs = (bill['extra_duration_charge'] as num?)?.toDouble() ?? 0.0;
    final evFee = (bill['ev_charging_fee'] as num?)?.toDouble() ?? 0.0;
    final tax = (bill['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final deposit = (bill['prepaid_deposit'] as num?)?.toDouble() ?? 0.0;
    final totalFee = (bill['total_fee'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🚗 ${ticket['vehicle_number'] ?? 'Vehicle'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Text('Bay ${ticket['slot_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12)),
            ],
          ),
          const Divider(height: 16),
          _previewRow('Elapsed Duration:', duration, isBold: true),
          _previewRow('Base 1st Hour Tariff:', '₹${baseTariff.toStringAsFixed(2)}'),
          if (extraSlabs > 0) _previewRow('Extra 30-Min Slabs:', '₹${extraSlabs.toStringAsFixed(2)}'),
          if (evFee > 0) _previewRow('EV Fast Charging:', '₹${evFee.toStringAsFixed(2)}', color: const Color(0xFF10B981)),
          _previewRow('GST (18%):', '₹${tax.toStringAsFixed(2)}'),
          if (deposit > 0) _previewRow('Advance Deposit Credit:', '-₹${deposit.toStringAsFixed(2)}', color: const Color(0xFF10B981), isBold: true),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NET PAYABLE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
              Text('₹${totalFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
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
              const Text('🅿️ TAX INVOICE', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Text('SETTLED & PAID', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: 20),
          _receiptRow('INVOICE / RECEIPT ID:', r['receipt_id'] ?? r['ticket_id'] ?? 'N/A', isBold: true),
          _receiptRow('VEHICLE NUMBER:', r['vehicle_number'] ?? 'N/A', isBold: true),
          _receiptRow('PARKING BAY:', 'Bay ${r['slot_number'] ?? 'N/A'}'),
          _receiptRow('TOTAL DURATION:', r['duration_formatted'] ?? '${r['duration_minutes'] ?? 0} mins'),
          _receiptRow('PAYMENT METHOD:', r['payment_method'] ?? 'FASTag'),
          if (r['fastag_id'] != null) _receiptRow('FASTag EPC:', r['fastag_id']),
          const Divider(height: 16),
          _receiptRow(
            'TOTAL AMOUNT PAID:',
            '₹${(r['total_fee'] as num? ?? 0).toStringAsFixed(2)}',
            isBold: true,
            color: const Color(0xFF10B981),
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String key, String value, {bool isBold = false, Color? color, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
