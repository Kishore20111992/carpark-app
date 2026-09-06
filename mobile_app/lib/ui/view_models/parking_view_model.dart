import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/bay_model.dart';
import '../../data/models/summary_model.dart';
import '../../data/models/reservation_model.dart';
import '../../data/repositories/parking_repository.dart';

class ParkingViewModel extends ChangeNotifier {
  final ParkingRepository _repository;

  SummaryModel? _summary;
  List<BayModel> _bays = [];
  List<ReservationModel> _reservations = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _latestTicket;
  Timer? _pollingTimer;

  String _categoryFilter = 'All';
  String _zoneFilter = 'All';

  ParkingViewModel({required ParkingRepository repository}) : _repository = repository {
    loadData();
    // Auto-poll live facility state every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => refreshSilent());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  SummaryModel? get summary => _summary;
  List<BayModel> get bays => _bays;
  List<ReservationModel> get reservations => _reservations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get latestTicket => _latestTicket;
  String get categoryFilter => _categoryFilter;
  String get zoneFilter => _zoneFilter;

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setZoneFilter(String zone) {
    _zoneFilter = zone;
    notifyListeners();
  }

  List<BayModel> get filteredBays {
    return _bays.where((b) {
      final matchesCat = _categoryFilter == 'All' || b.slotType.toLowerCase() == _categoryFilter.toLowerCase();
      final matchesZone = _zoneFilter == 'All' || b.zone.contains(_zoneFilter);
      return matchesCat && matchesZone;
    }).toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sumFuture = _repository.getSummary();
      final baysFuture = _repository.getBays();
      final resFuture = _repository.getReservations();

      final results = await Future.wait([sumFuture, baysFuture, resFuture]);
      _summary = results[0] as SummaryModel;
      _bays = results[1] as List<BayModel>;
      _reservations = results[2] as List<ReservationModel>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSilent() async {
    try {
      final sum = await _repository.getSummary();
      final baysList = await _repository.getBays();
      final resList = await _repository.getReservations();
      _summary = sum;
      _bays = baysList;
      _reservations = resList;
      notifyListeners();
    } catch (_) {
      // Keep existing state on transient background poll failure
    }
  }

  Future<bool> checkIn({
    required String vehicleNumber,
    required String vehicleType,
    String? driverName,
    String? driverPhone,
    int? slotId,
    bool isEvCharging = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.checkIn(
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        driverName: driverName,
        driverPhone: driverPhone,
        slotId: slotId,
        isEvCharging: isEvCharging,
      );
      _latestTicket = result;
      await refreshSilent();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkOut({
    required String ticketId,
    String paymentMethod = 'FASTag (NETC Auto-Debit)',
    String billingModel = 'prorated_30min',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final receipt = await _repository.checkOut(
        ticketId: ticketId,
        paymentMethod: paymentMethod,
        billingModel: billingModel,
      );
      await refreshSilent();
      return receipt;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createReservation({
    required String customerName,
    required String customerPhone,
    required String vehicleNumber,
    required String vehicleType,
    required int slotId,
    required String reservedFor,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.reserve(
        customerName: customerName,
        customerPhone: customerPhone,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        slotId: slotId,
        reservedFor: reservedFor,
        paymentMethod: paymentMethod,
      );
      await refreshSilent();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> locate(String query) async {
    try {
      return await _repository.locate(query);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  void updateBackendUrl(String newUrl) {
    _repository.apiService.updateBaseUrl(newUrl);
    loadData();
  }
}
