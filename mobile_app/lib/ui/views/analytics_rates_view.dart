import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import 'components/server_config_dialog.dart';

class AnalyticsRatesView extends StatefulWidget {
  const AnalyticsRatesView({Key? key}) : super(key: key);

  @override
  State<AnalyticsRatesView> createState() => _AnalyticsRatesViewState();
}

class _AnalyticsRatesViewState extends State<AnalyticsRatesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchTicketController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.price_change_rounded), text: 'Tariff Rates'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, vm),
          _buildTariffsTab(context, vm),
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
