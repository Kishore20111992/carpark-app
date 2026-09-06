import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';
import 'components/server_config_dialog.dart';

class BayVisualizerView extends StatelessWidget {
  const BayVisualizerView({Key? key}) : super(key: key);

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'ev':
        return Icons.electric_bolt_rounded;
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'suv':
        return Icons.directions_car_filled_rounded;
      case 'handicap':
        return Icons.accessible_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF10B981);
      case 'occupied':
        return const Color(0xFFEF4444);
      case 'reserved':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showKpiDrilldown(BuildContext context, String kpiType) async {
    final vm = context.read<ParkingViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: vm.getKpiDrilldown(kpiType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('Unable to load inspection data')),
              );
            }

            final title = data['title'] ?? 'KPI Details';
            final zones = data['zone_summary'] as Map<String, dynamic>? ?? data['zone_counts'] as Map<String, dynamic>? ?? {};
            final types = data['type_summary'] as Map<String, dynamic>? ?? data['type_counts'] as Map<String, dynamic>? ?? {};

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (zones.isNotEmpty) ...[
                    const Text('Floor / Zone Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    ...zones.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontSize: 13)),
                              Text('${e.value} Bays', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (types.isNotEmpty) ...[
                    const Text('Vehicle Category Allocation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    ...types.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontSize: 13)),
                              Text('${e.value} Bays', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBayDetails(BuildContext context, BayModel bay) {
    final vm = context.read<ParkingViewModel>();
    final statusColor = _getStatusColor(bay.status);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bay ${bay.slotNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(bay.status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),
              _detailRow('Zone / Floor:', '${bay.zone} (Floor ${bay.floor})'),
              _detailRow('Designated Category:', bay.slotType),
              _detailRow('Hourly Tariff:', '₹${bay.hourlyRate.toStringAsFixed(2)} / hr'),
              if (bay.notes != null && bay.notes!.isNotEmpty) _detailRow('Location Notes:', bay.notes!),

              if (bay.isOccupied && bay.vehicleNumber != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🚗 Parked Vehicle: ${bay.vehicleNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                      if (bay.driverName != null && bay.driverName!.isNotEmpty)
                        Text('👤 Driver: ${bay.driverName}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                      if (bay.entryTime != null)
                        Text('⏰ Entry Time: ${bay.entryTime}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Check-Out & Settle This Vehicle'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      vm.jumpToCheckOut(bay.vehicleNumber!);
                    },
                  ),
                ),
              ] else if (bay.isAvailable) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Check-In Here'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            vm.jumpToCheckIn(bay.id);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: const Text('Reserve Bay'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            vm.jumpToReserve(bay.id);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (bay.isReserved) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Check-In from Reservation'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      vm.setTabIndex(1); // Check-In tab
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkFlow Live Bays', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
            onPressed: () => showServerConfigDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => vm.loadData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.loadData(),
        child: CustomScrollView(
          slivers: [
            // Server Connection Warning Banner
            if (vm.errorMessage != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cannot connect to backend server',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                            ),
                            Text(
                              'Server: ${vm.currentBaseUrl}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => showServerConfigDialog(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Change IP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

            // KPI Metrics Header Card
            if (vm.summary != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.3),
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
                            const Text(
                              'LIVE FACILITY OCCUPANCY',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('● LIVE 2s', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem(context, '${vm.summary!.availableBays}', 'Available', Colors.greenAccent, 'available'),
                            _buildStatItem(context, '${vm.summary!.occupiedBays}', 'Occupied', Colors.redAccent, 'occupied'),
                            _buildStatItem(context, '${vm.summary!.reservedBays}', 'Reserved', Colors.amberAccent, 'capacity'),
                            _buildStatItem(context, '${vm.summary!.occupancyRatePct}%', 'Occupancy', Colors.white, 'occupancy'),
                            _buildStatItem(context, '₹${vm.summary!.todayRevenue.toStringAsFixed(0)}', 'Revenue', Colors.amber, 'revenue'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: ['All', 'Car', 'EV', 'SUV', 'Bike', 'Handicap'].map((cat) {
                    final isSelected = vm.categoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => vm.setCategoryFilter(cat),
                        selectedColor: const Color(0xFF2563EB).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF2563EB),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 2D Bay Grid
            if (vm.isLoading && vm.bays.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (vm.filteredBays.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No parking bays found matching filters')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bay = vm.filteredBays[index];
                      return _BayCard(
                        bay: bay,
                        typeIcon: _getTypeIcon(bay.slotType),
                        statusColor: _getStatusColor(bay.status),
                        onTap: () => _showBayDetails(context, bay),
                      );
                    },
                    childCount: vm.filteredBays.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, Color color, String kpiType) {
    return InkWell(
      onTap: () => _showKpiDrilldown(context, kpiType),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _BayCard extends StatelessWidget {
  final BayModel bay;
  final IconData typeIcon;
  final Color statusColor;
  final VoidCallback onTap;

  const _BayCard({
    Key? key,
    required this.bay,
    required this.typeIcon,
    required this.statusColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.5), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bay.slotNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bay.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(typeIcon, size: 18, color: const Color(0xFF475569)),
                const SizedBox(width: 4),
                Text(
                  bay.slotType,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ],
            ),
            if (bay.isOccupied && bay.vehicleNumber != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bay.vehicleNumber!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '⏱️ Parked in ${bay.zone}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                  ),
                ],
              )
            else if (bay.isReserved)
              const Text(
                '🟡 Held for Guest',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              )
            else
              const Text(
                '🟢 Tap for Actions',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
          ],
        ),
      ),
    );
  }
}
