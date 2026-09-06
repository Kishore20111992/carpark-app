import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';

class VehicleLocatorView extends StatefulWidget {
  const VehicleLocatorView({Key? key}) : super(key: key);

  @override
  State<VehicleLocatorView> createState() => _VehicleLocatorViewState();
}

class _VehicleLocatorViewState extends State<VehicleLocatorView> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _foundVehicle;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find My Car', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.near_me_rounded, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter your license plate number to get walking directions to your parked vehicle.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Plate or Ticket ID',
                      hintText: 'Enter plate number',
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
                    onPressed: _searching
                        ? null
                        : () async {
                            final q = _searchController.text.trim();
                            if (q.isEmpty) return;
                            setState(() => _searching = true);
                            final result = await vm.locate(q);
                            setState(() {
                              _foundVehicle = result;
                              _searching = false;
                            });
                            if (result == null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No active parked vehicle found for this plate/ticket')),
                              );
                            }
                          },
                    child: _searching
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Locate'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_foundVehicle != null) ...[
              Container(
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
                        Text(
                          '🚗 ${_foundVehicle!['vehicle_number']}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'BAY ${_foundVehicle!['slot_number']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _locRow('FLOOR LEVEL:', 'Floor ${_foundVehicle!['floor']} (${_foundVehicle!['zone']})'),
                    _locRow('DWELL DURATION:', _foundVehicle!['duration'] ?? 'N/A'),
                    _locRow('CURRENT ACCRUED BILL:', '₹${(_foundVehicle!['accrued_total'] as num? ?? 0).toStringAsFixed(2)}', color: const Color(0xFF2563EB), isBold: true),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.directions_walk_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _foundVehicle!['walking_directions'] ?? '',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locRow(String key, String value, {bool isBold = false, Color? color}) {
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
