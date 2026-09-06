import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/services/api_service.dart';
import 'data/repositories/parking_repository.dart';
import 'ui/view_models/parking_view_model.dart';
import 'ui/views/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParkFlowApp());
}

class ParkFlowApp extends StatelessWidget {
  const ParkFlowApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        ProxyProvider<ApiService, ParkingRepository>(
          update: (_, apiService, __) => ParkingRepository(apiService: apiService),
        ),
        ChangeNotifierProxyProvider<ParkingRepository, ParkingViewModel>(
          create: (context) => ParkingViewModel(
            repository: context.read<ParkingRepository>(),
          ),
          update: (_, repo, vm) => vm ?? ParkingViewModel(repository: repo),
        ),
      ],
      child: MaterialApp(
        title: 'ParkFlow Smart Parking',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A),
            primary: const Color(0xFF1E3A8A),
            secondary: const Color(0xFF10B981),
            surface: const Color(0xFFF8FAFC),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0F172A),
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}
