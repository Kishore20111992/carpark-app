import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import '../../data/models/bay_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkFlow Live Bays', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.loadData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.loadData(),
        child: CustomScrollView(
          slivers: [
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
                            _buildStatItem('${vm.summary!.availableBays}', 'Available', Colors.greenAccent),
                            _buildStatItem('${vm.summary!.occupiedBays}', 'Occupied', Colors.redAccent),
                            _buildStatItem('${vm.summary!.reservedBays}', 'Reserved', Colors.amberAccent),
                            _buildStatItem('${vm.summary!.occupancyRatePct}%', 'Occupancy', Colors.white),
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
                child: Center(child: Text('No bays match the selected filters.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bay = vm.filteredBays[index];
                      return _buildBayCard(context, bay);
                    },
                    childCount: vm.filteredBays.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildBayCard(BuildContext context, BayModel bay) {
    final statusColor = _getStatusColor(bay.status);
    final typeIcon = _getTypeIcon(bay.slotType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bay.slotNumber,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bay.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(typeIcon, size: 20, color: const Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                bay.slotType,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
          if (bay.isOccupied && bay.vehicleNumber != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bay.vehicleNumber!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '⏱️ Parked in ${bay.zone}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            )
          else if (bay.isReserved)
            const Text(
              '🟡 Held for Guest',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
            )
          else
            const Text(
              '🟢 Ready to Park',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
            ),
        ],
      ),
    );
  }
}
