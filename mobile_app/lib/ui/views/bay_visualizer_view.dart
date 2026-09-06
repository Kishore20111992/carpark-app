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
                        Text('👤 Customer: ${bay.driverName}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: TextButton.icon(
                    icon: const Icon(Icons.build_rounded, size: 16, color: Color(0xFFF97316)),
                    label: const Text('Mark Under Maintenance', style: TextStyle(color: Color(0xFFF97316), fontSize: 13)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await vm.updateBay(slotId: bay.id, status: 'Maintenance');
                    },
                  ),
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
                      vm.setTabIndex(2); // Pass / Check-In tab
                    },
                  ),
                ),
              ] else if (bay.isMaintenance) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.build_circle_rounded),
                    label: const Text('Restore Bay to Available'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await vm.updateBay(slotId: bay.id, status: 'Available');
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
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'SMART PARKING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF93C5FD), letterSpacing: 0.8),
            ),
            SizedBox(height: 1),
            Text(
              '🅿️ ParkFlow Mobile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Server Settings',
            onPressed: () => showServerConfigDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
            tooltip: 'Analytics & Tariffs',
            onPressed: () => vm.setTabIndex(5),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: () => vm.loadData(),
          ),
          Container(
            margin: const EdgeInsets.only(right: 14, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
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
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cannot connect to backend server',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Change IP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),

            // Top Summary Card: "LIVE BAY AVAILABILITY"
            if (vm.summary != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIVE BAY AVAILABILITY',
                          style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem(context, '${vm.summary!.availableBays}', 'Available', const Color(0xFF6EE7B7), 'available'),
                            _buildStatItem(context, '${vm.summary!.occupiedBays}', 'Occupied', const Color(0xFFFCA5A5), 'occupied'),
                            _buildStatItem(context, '${vm.summary!.reservedBays}', 'Reserved', const Color(0xFFFDE68A), 'capacity'),
                            _buildStatItem(context, '${vm.summary!.occupancyRatePct}%', 'Occupancy', Colors.white, 'occupancy'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Action Shortcuts (Advance Book & FASTag Exit)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => vm.setTabIndex(1), // Reserve tab
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Text('📅', style: TextStyle(fontSize: 24)),
                              SizedBox(height: 4),
                              Text(
                                'Advance Book',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '1-Hr ₹59 Deposit',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => vm.setTabIndex(3), // Exit & Pay tab
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Text('📡', style: TextStyle(fontSize: 24)),
                              SizedBox(height: 4),
                              Text(
                                'FASTag Exit',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Zero-Debit Settle',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section Header: "FACILITY BAYS OVERVIEW"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FACILITY BAYS OVERVIEW',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.5),
                    ),
                    // Quick category selector popup
                    PopupMenuButton<String>(
                      initialValue: vm.categoryFilter,
                      tooltip: 'Filter Category',
                      onSelected: (cat) => vm.setCategoryFilter(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              vm.categoryFilter == 'All' ? 'All Bays' : vm.categoryFilter,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                      itemBuilder: (ctx) => ['All', 'Car', 'EV', 'SUV', 'Bike', 'Handicap'].map((cat) {
                        return PopupMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // 3-Column Bay Grid
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
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bay = vm.filteredBays[index];
                      return _BayCard(
                        bay: bay,
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
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _BayCard extends StatelessWidget {
  final BayModel bay;
  final VoidCallback onTap;

  const _BayCard({
    Key? key,
    required this.bay,
    required this.onTap,
  }) : super(key: key);

  Color get _statusColor {
    switch (bay.status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              bay.slotNumber,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              bay.slotType,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              bay.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

