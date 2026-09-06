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
    CheckInView(),
    CheckOutView(),
    AdvanceBookingView(),
    VehicleLocatorView(),
    AnalyticsRatesView(),
  ];

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
