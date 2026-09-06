import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/parking_view_model.dart';
import 'bay_visualizer_view.dart';
import 'check_in_view.dart';
import 'check_out_view.dart';
import 'advance_booking_view.dart';
import 'vehicle_locator_view.dart';
import 'analytics_rates_view.dart';

import 'components/server_config_dialog.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  final List<Widget> _views = const [
    BayVisualizerView(),
    AdvanceBookingView(),
    CheckInView(),
    CheckOutView(),
    VehicleLocatorView(),
    AnalyticsRatesView(),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ParkingViewModel>();

    return Scaffold(
      body: IndexedStack(
        index: vm.currentTabIndex < _views.length ? vm.currentTabIndex : 0,
        children: _views,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: vm.currentTabIndex < 5 ? vm.currentTabIndex : 0,
          onDestinationSelected: (idx) => vm.setTabIndex(idx),
          indicatorColor: const Color(0xFF2563EB).withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Text('🚗', style: TextStyle(fontSize: 20)),
              selectedIcon: Text('🚗', style: TextStyle(fontSize: 22)),
              label: 'Bays',
            ),
            NavigationDestination(
              icon: Text('📅', style: TextStyle(fontSize: 20)),
              selectedIcon: Text('📅', style: TextStyle(fontSize: 22)),
              label: 'Reserve',
            ),
            NavigationDestination(
              icon: Text('🎟️', style: TextStyle(fontSize: 20)),
              selectedIcon: Text('🎟️', style: TextStyle(fontSize: 22)),
              label: 'Pass',
            ),
            NavigationDestination(
              icon: Text('💳', style: TextStyle(fontSize: 20)),
              selectedIcon: Text('💳', style: TextStyle(fontSize: 22)),
              label: 'Exit',
            ),
            NavigationDestination(
              icon: Text('🔍', style: TextStyle(fontSize: 20)),
              selectedIcon: Text('🔍', style: TextStyle(fontSize: 22)),
              label: 'Locate',
            ),
          ],
        ),
      ),
    );
  }
}
