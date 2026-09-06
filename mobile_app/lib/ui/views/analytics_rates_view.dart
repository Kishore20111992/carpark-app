import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';
import 'components/server_config_dialog.dart';

class AnalyticsRatesView extends StatefulWidget {
  const AnalyticsRatesView({Key? key}) : super(key: key);

  @override
  State<AnalyticsRatesView> createState() => _AnalyticsRatesViewState();
}

class _AnalyticsRatesViewState extends State<AnalyticsRatesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchTicketController = TextEditingController();
  String _bayFilterType = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<ParkingViewModel>();
      vm.loadRates();
      vm.loadTickets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchTicketController.dispose();
    super.dispose();
  }

  void _showEditRateDialog(BuildContext context, String vehicleType, double currentRate, double currentMin) {
    final rateController = TextEditingController(text: currentRate.toStringAsFixed(1));
    final minController = TextEditingController(text: currentMin.toStringAsFixed(1));
    final vm = context.read<ParkingViewModel>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Tariff: $vehicleType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hourly Rate (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Base Minimum Fee (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newRate = double.tryParse(rateController.text.trim()) ?? currentRate;
              final newMin = double.tryParse(minController.text.trim()) ?? currentMin;
              Navigator.pop(ctx);
              final success = await vm.updateRate(vehicleType, newRate, newMin);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Updated tariff for $vehicleType!' : 'Failed to update tariff')),
                );
              }
            },
            child: const Text('Save Tariff'),
          ),
        ],
      ),
    );
  }

  void _confirmResetFacility(BuildContext context) {
    final vm = context.read<ParkingViewModel>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🧼 Reset Facility to Clean Production?'),
        content: const Text(
          'This will purge all mock / test tickets, release all occupied bays to "Available", and reset the facility to a 100% clean state. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await vm.resetCleanProduction();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Facility reset to 100% clean production state!' : 'Reset failed')),
                );
              }
            },
            child: const Text('Yes, Reset Facility'),
          ),
        ],
      ),
    );
  }

  void _showAddBayDialog(BuildContext context) {
    final numController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'Car';
    String selectedZone = 'Zone A (Ground)';
    int selectedFloor = 0;
    final vm = context.read<ParkingViewModel>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Add New Parking Bay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: numController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Bay / Slot Code *',
                    hintText: 'e.g. D-01 or A-09',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Category *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Car', child: Text('Car (Standard)')),
                    DropdownMenuItem(value: 'EV', child: Text('EV (Fast Charger Stall)')),
                    DropdownMenuItem(value: 'Bike', child: Text('Bike (Two-Wheeler)')),
                    DropdownMenuItem(value: 'SUV', child: Text('SUV (Extra Wide)')),
                    DropdownMenuItem(value: 'Handicap', child: Text('Handicap (Accessible)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedType = val ?? 'Car'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedZone,
                  decoration: const InputDecoration(
                    labelText: 'Facility Zone *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Zone A (Ground)', child: Text('Zone A (Ground Floor)')),
                    DropdownMenuItem(value: 'Zone B (Level 1)', child: Text('Zone B (Level 1)')),
                    DropdownMenuItem(value: 'Zone C (Level 2)', child: Text('Zone C (Level 2)')),
                    DropdownMenuItem(value: 'Zone D (Basement)', child: Text('Zone D (Basement)')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedZone = val ?? 'Zone A (Ground)';
                      if (selectedZone.contains('Ground')) selectedFloor = 0;
                      if (selectedZone.contains('Level 1')) selectedFloor = 1;
                      if (selectedZone.contains('Level 2')) selectedFloor = 2;
                      if (selectedZone.contains('Basement')) selectedFloor = -1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedFloor,
                  decoration: const InputDecoration(
                    labelText: 'Floor Level *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.stairs_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('Basement (-1)')),
                    DropdownMenuItem(value: 0, child: Text('Ground Floor (0)')),
                    DropdownMenuItem(value: 1, child: Text('Floor 1 (Level 1)')),
                    DropdownMenuItem(value: 2, child: Text('Floor 2 (Level 2)')),
                    DropdownMenuItem(value: 3, child: Text('Floor 3 (Level 3)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedFloor = val ?? 0),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Bay Notes / Equipment',
                    hintText: 'e.g. 50kW DC Fast Charger, Near Elevator',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final code = numController.text.trim().toUpperCase();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a bay code')));
                  return;
                }
                Navigator.pop(ctx);
                final ok = await vm.createBay(
                  slotNumber: code,
                  zone: selectedZone,
                  floor: selectedFloor,
                  slotType: selectedType,
                  notes: notesController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Bay $code created successfully!' : (vm.errorMessage ?? 'Failed to create bay'))),
                  );
                }
              },
              child: const Text('Create Bay'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBayDialog(BuildContext context, BayModel bay) {
    final numController = TextEditingController(text: bay.slotNumber);
    final notesController = TextEditingController(text: bay.notes ?? '');
    String selectedType = bay.slotType;
    String selectedZone = bay.zone;
    int selectedFloor = bay.floor;
    String selectedStatus = bay.status;
    final vm = context.read<ParkingViewModel>();

    final validTypes = ['Car', 'EV', 'Bike', 'SUV', 'Handicap'];
    if (!validTypes.contains(selectedType)) selectedType = 'Car';

    final validZones = ['Zone A (Ground)', 'Zone B (Level 1)', 'Zone C (Level 2)', 'Zone D (Basement)'];
    if (!validZones.contains(selectedZone)) selectedZone = validZones[0];

    final isLocked = bay.isOccupied || bay.isReserved;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text('Configure Bay ${bay.slotNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      '⚠️ This bay is currently ${bay.status}. Bay number and operational status are locked until the vehicle checks out.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                TextField(
                  controller: numController,
                  enabled: !isLocked,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Bay / Slot Code *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Category *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Car', child: Text('Car (Standard)')),
                    DropdownMenuItem(value: 'EV', child: Text('EV (Fast Charger Stall)')),
                    DropdownMenuItem(value: 'Bike', child: Text('Bike (Two-Wheeler)')),
                    DropdownMenuItem(value: 'SUV', child: Text('SUV (Extra Wide)')),
                    DropdownMenuItem(value: 'Handicap', child: Text('Handicap (Accessible)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedType = val ?? 'Car'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedZone,
                  decoration: const InputDecoration(
                    labelText: 'Facility Zone *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.layers_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Zone A (Ground)', child: Text('Zone A (Ground Floor)')),
                    DropdownMenuItem(value: 'Zone B (Level 1)', child: Text('Zone B (Level 1)')),
                    DropdownMenuItem(value: 'Zone C (Level 2)', child: Text('Zone C (Level 2)')),
                    DropdownMenuItem(value: 'Zone D (Basement)', child: Text('Zone D (Basement)')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedZone = val ?? 'Zone A (Ground)';
                      if (selectedZone.contains('Ground')) selectedFloor = 0;
                      if (selectedZone.contains('Level 1')) selectedFloor = 1;
                      if (selectedZone.contains('Level 2')) selectedFloor = 2;
                      if (selectedZone.contains('Basement')) selectedFloor = -1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: [-1, 0, 1, 2, 3].contains(selectedFloor) ? selectedFloor : 0,
                  decoration: const InputDecoration(
                    labelText: 'Floor Level *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.stairs_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('Basement (-1)')),
                    DropdownMenuItem(value: 0, child: Text('Ground Floor (0)')),
                    DropdownMenuItem(value: 1, child: Text('Floor 1 (Level 1)')),
                    DropdownMenuItem(value: 2, child: Text('Floor 2 (Level 2)')),
                    DropdownMenuItem(value: 3, child: Text('Floor 3 (Level 3)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedFloor = val ?? 0),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ['Available', 'Maintenance'].contains(selectedStatus) ? selectedStatus : (isLocked ? bay.status : 'Available'),
                  decoration: const InputDecoration(
                    labelText: 'Operational Status *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build_circle_rounded),
                  ),
                  items: isLocked
                      ? [DropdownMenuItem(value: bay.status, child: Text(bay.status))]
                      : const [
                          DropdownMenuItem(value: 'Available', child: Text('Available (Ready to Park)')),
                          DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance (Under Service)')),
                        ],
                  onChanged: isLocked ? null : (val) => setDialogState(() => selectedStatus = val ?? 'Available'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Bay Notes / Equipment',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await vm.updateBay(
                  slotId: bay.id,
                  slotNumber: isLocked ? null : numController.text.trim().toUpperCase(),
                  zone: selectedZone,
                  floor: selectedFloor,
                  slotType: selectedType,
                  status: isLocked ? null : selectedStatus,
                  notes: notesController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Bay ${bay.slotNumber} updated successfully!' : (vm.errorMessage ?? 'Failed to update bay'))),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteBayDialog(BuildContext context, BayModel bay) {
    final vm = context.read<ParkingViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Decommission Bay?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
          ],
        ),
        content: Text('Are you sure you want to permanently delete Bay ${bay.slotNumber} (${bay.zone}, Floor ${bay.floor})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await vm.deleteBay(bay.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Bay ${bay.slotNumber} deleted.' : (vm.errorMessage ?? 'Failed to delete bay'))),
                );
              }
            },
            child: const Text('Delete Bay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: () => showServerConfigDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              vm.loadRates();
              vm.loadTickets();
              vm.loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Overview'),
            Tab(icon: Icon(Icons.price_change_rounded), text: 'Tariffs'),
            Tab(icon: Icon(Icons.local_parking_rounded), text: 'Bay Setup'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, vm),
          _buildTariffsTab(context, vm),
          _buildBaySetupTab(context, vm),
          _buildAuditLedgerTab(context, vm),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, ParkingViewModel vm) {
    final summary = vm.summary;
    final total = summary?.totalBays ?? 24;
    final avail = summary?.availableBays ?? 0;
    final occ = summary?.occupiedBays ?? 0;
    final res = summary?.reservedBays ?? 0;
    final rev = summary?.todayRevenue ?? 0.0;
    final occRate = summary?.occupancyRatePct ?? 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        await vm.loadData();
        await vm.loadRates();
        await vm.loadTickets();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Highlights
            Row(
              children: [
                Expanded(child: _metricCard('TODAY REVENUE', '₹${rev.toStringAsFixed(2)}', const Color(0xFF10B981))),
                const SizedBox(width: 10),
                Expanded(child: _metricCard('OCCUPANCY', '${occRate.toStringAsFixed(1)}%', const Color(0xFF2563EB))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricCard('AVAILABLE', '$avail / $total', const Color(0xFF10B981))),
                const SizedBox(width: 10),
                Expanded(child: _metricCard('ACTIVE SESSIONS', '$occ Parked', const Color(0xFFEF4444))),
                const SizedBox(width: 10),
                Expanded(child: _metricCard('RESERVED', '$res Held', const Color(0xFFF59E0B))),
              ],
            ),

            const SizedBox(height: 24),
            const Text('🚗 Bay Status Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            _distributionBar('Available', avail, total, const Color(0xFF10B981)),
            _distributionBar('Occupied', occ, total, const Color(0xFFEF4444)),
            _distributionBar('Reserved', res, total, const Color(0xFFF59E0B)),

            const SizedBox(height: 24),
            const Text('🧹 Facility Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.sync_rounded, color: Color(0xFF2563EB)),
                    ),
                    title: const Text('Force Global Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Forces real-time sync across database and visualizers', style: TextStyle(fontSize: 12)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      onPressed: () async {
                        await vm.loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global sync complete!')));
                        }
                      },
                      child: const Text('Sync'),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.cleaning_services_rounded, color: Color(0xFFD97706)),
                    ),
                    title: const Text('Sweep Expired Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Forfeits reservations exceeding 1-hr prepaid window', style: TextStyle(fontSize: 12)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                      onPressed: () async {
                        final cnt = await vm.sweepExpiredReservations();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(cnt > 0 ? 'Swept & forfeited $cnt expired booking(s)!' : 'All bookings within window')),
                          );
                        }
                      },
                      child: const Text('Sweep'),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEE2E2),
                      child: Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
                    ),
                    title: const Text('Clean Production Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626))),
                    subtitle: const Text('Purges test tickets & restores all bays to Available', style: TextStyle(fontSize: 12)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                      onPressed: () => _confirmResetFacility(context),
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffsTab(BuildContext context, ParkingViewModel vm) {
    final rates = vm.rates?['rates'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('ℹ️ Active Tariff Policy (Standard Model B)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13)),
                SizedBox(height: 4),
                Text(
                  'The 1st hour is billed at the full base tariff. Parking duration beyond the 1st hour is billed in 30-minute prorated slabs (at 50% of hourly rate) + 18% GST. FASTag NETC auto-debit applies this standard automatically.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('⚙️ Vehicle Category Tariffs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          if (rates.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rates.length,
              itemBuilder: (ctx, i) {
                final type = rates.keys.elementAt(i);
                final item = rates[type] as Map<String, dynamic>;
                final hourly = (item['hourly_rate'] as num).toDouble();
                final minFee = (item['min_charge'] as num).toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(type.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                    title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('Tariff: ₹${hourly.toStringAsFixed(2)} / hr  •  Base Fee: ₹${minFee.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB)),
                      onPressed: () => _showEditRateDialog(context, type, hourly, minFee),
                    ),
                  ),
              },
            ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11)),
      ],
    );
  }

  Widget _buildBaySetupTab(BuildContext context, ParkingViewModel vm) {
    final bays = vm.bays;
    final total = bays.length;
    final avail = bays.where((b) => b.isAvailable).length;
    final occ = bays.where((b) => b.isOccupied).length;
    final maint = bays.where((b) => b.isMaintenance).length;

    final filteredBays = _bayFilterType == 'All'
        ? bays
        : bays.where((b) => b.slotType.toLowerCase() == _bayFilterType.toLowerCase()).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🅿️ FACILITY BAY DIRECTORY & SETUP', style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total', '$total', Colors.white),
                    _statItem('Available', '$avail', const Color(0xFF6EE7B7)),
                    _statItem('Occupied', '$occ', const Color(0xFFFCA5A5)),
                    _statItem('Maintenance', '$maint', const Color(0xFFFDE68A)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add Bay Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Parking Bay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showAddBayDialog(context),
            ),
          ),
          const SizedBox(height: 16),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Car', 'EV', 'Bike', 'SUV', 'Handicap'].map((cat) {
                final isSelected = _bayFilterType == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _bayFilterType = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Bay List
          if (filteredBays.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('No bays found matching filter.', style: TextStyle(color: Color(0xFF64748B))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBays.length,
              itemBuilder: (ctx, i) {
                final bay = filteredBays[i];
                Color statusColor = const Color(0xFF10B981);
                if (bay.isOccupied) statusColor = const Color(0xFFEF4444);
                if (bay.isReserved) statusColor = const Color(0xFFF59E0B);
                if (bay.isMaintenance) statusColor = const Color(0xFFF97316);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: statusColor.withOpacity(0.4), width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            bay.slotType == 'EV' ? '⚡' : (bay.slotType == 'Bike' ? '🏍️' : (bay.slotType == 'SUV' ? '🚙' : (bay.slotType == 'Handicap' ? '♿' : '🚗'))),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Bay ${bay.slotNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      bay.status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${bay.zone} • Floor ${bay.floor} • ${bay.slotType}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              if (bay.notes != null && bay.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '📝 ${bay.notes}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
                          tooltip: 'Configure Bay',
                          onPressed: () => _showEditBayDialog(context, bay),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: (bay.isOccupied || bay.isReserved) ? Colors.grey : const Color(0xFFDC2626),
                          ),
                          tooltip: (bay.isOccupied || bay.isReserved) ? 'Cannot delete active bay' : 'Decommission Bay',
                          onPressed: (bay.isOccupied || bay.isReserved) ? null : () => _showDeleteBayDialog(context, bay),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAuditLedgerTab(BuildContext context, ParkingViewModel vm) {
    final query = _searchTicketController.text.trim().toUpperCase();
    final allTickets = vm.tickets;
    final filtered = query.isEmpty
        ? allTickets
        : allTickets.where((t) {
            final plate = (t['vehicle_number'] ?? '').toString().toUpperCase();
            final tid = (t['ticket_id'] ?? '').toString().toUpperCase();
            return plate.contains(query) || tid.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchTicketController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by plate or ticket ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchTicketController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No transaction records found.', style: TextStyle(color: Color(0xFF64748B))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final t = filtered[i];
                    final isActive = t['is_active'] == 1;
                    final fee = (t['total_fee'] as num?)?.toDouble() ?? 0.0;
                    final method = t['payment_method'] ?? 'Pending';
                    final duration = t['duration_minutes'] != null ? '${t['duration_minutes']}m' : 'In Progress';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['vehicle_number'] ?? 'N/A',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'PAID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      color: isActive ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ticket: ${t['ticket_id']}  •  Bay: ${t['slot_number']} (${t['vehicle_type']})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Duration: $duration  •  $method', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                Text('₹${fee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _distributionBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              Text('$count bays (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
