import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import 'bay_visualizer_view.dart';
import 'check_in_view.dart';
import 'check_out_view.dart';
import 'advance_booking_view.dart';
import 'vehicle_locator_view.dart';
import 'analytics_rates_view.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  final List<Widget> _views = const [
    BayVisualizerView(),
    CheckInView(),
    CheckOutView(),
    AdvanceBookingView(),
    VehicleLocatorView(),
    AnalyticsRatesView(),
  ];

  void _showServerSettings(BuildContext context) {
    final vm = context.read<ParkingViewModel>();
    final controller = TextEditingController(text: 'https://localhost:8000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your computer\'s Wi-Fi IP address so your mobile phone can connect to the FastAPI server:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'e.g. https://10.9.240.129:8000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                vm.updateBackendUrl(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      body: IndexedStack(
        index: vm.currentTabIndex,
        children: _views,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: vm.currentTabIndex,
        onDestinationSelected: (idx) => vm.setTabIndex(idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_parking_outlined),
            selectedIcon: Icon(Icons.local_parking_rounded, color: Color(0xFF2563EB)),
            label: 'Bays',
          ),
          NavigationDestination(
            icon: Icon(Icons.login_outlined),
            selectedIcon: Icon(Icons.login_rounded, color: Color(0xFF2563EB)),
            label: 'Check-In',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment_rounded, color: Color(0xFF2563EB)),
            label: 'Exit & Pay',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
            label: 'Reserve',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me_rounded, color: Color(0xFF2563EB)),
            label: 'Find Car',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
