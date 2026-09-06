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
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _rates;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _latestTicket;
  Timer? _pollingTimer;

  int _currentTabIndex = 0;
  String? _prefilledPlateForCheckout;
  int? _preselectedSlotForCheckin;
  int? _preselectedSlotForReserve;

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
  List<Map<String, dynamic>> get tickets => _tickets;
  Map<String, dynamic>? get rates => _rates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get latestTicket => _latestTicket;
  String get categoryFilter => _categoryFilter;
  String get zoneFilter => _zoneFilter;

  int get currentTabIndex => _currentTabIndex;
  String? get prefilledPlateForCheckout => _prefilledPlateForCheckout;
  int? get preselectedSlotForCheckin => _preselectedSlotForCheckin;
  int? get preselectedSlotForReserve => _preselectedSlotForReserve;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void jumpToCheckOut(String vehiclePlate) {
    _prefilledPlateForCheckout = vehiclePlate;
    _currentTabIndex = 2; // Exit & Pay tab
    notifyListeners();
  }

  void jumpToCheckIn(int slotId) {
    _preselectedSlotForCheckin = slotId;
    _currentTabIndex = 1; // Check-In tab
    notifyListeners();
  }

  void jumpToReserve(int slotId) {
    _preselectedSlotForReserve = slotId;
    _currentTabIndex = 3; // Reserve tab
    notifyListeners();
  }

  void clearPrefills() {
    _prefilledPlateForCheckout = null;
    _preselectedSlotForCheckin = null;
    _preselectedSlotForReserve = null;
  }

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

  Future<Map<String, dynamic>?> previewBill(String ticketId, {String billingModel = 'prorated_30min'}) async {
    try {
      return await _repository.previewBill(ticketId, billingModel: billingModel);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<void> loadTickets({int limit = 100}) async {
    try {
      _tickets = await _repository.getTickets(limit: limit);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> loadRates() async {
    try {
      _rates = await _repository.getRates();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> updateRate(String vehicleType, double hourlyRate, double minCharge) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.updateRate(vehicleType, hourlyRate, minCharge);
      await loadRates();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getKpiDrilldown(String kpiType) async {
    try {
      return await _repository.getKpiDrilldown(kpiType);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> resetCleanProduction() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.resetCleanProduction();
      await loadData();
      await loadTickets();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelReservation(String reservationId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.cancelReservation(reservationId);
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

  Future<bool> checkInFromReservation(
    String reservationId, {
    String? fastagId,
    bool isEvCharging = false,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ticket = await _repository.checkInFromReservation(
        reservationId,
        fastagId: fastagId,
        isEvCharging: isEvCharging,
      );
      _latestTicket = ticket;
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

  Future<int> sweepExpiredReservations() async {
    try {
      final count = await _repository.sweepExpiredReservations();
      await refreshSilent();
      return count;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return 0;
    }
  }

  String get currentBaseUrl => _repository.apiService.baseUrl;

  Future<bool> testConnection([String? targetUrl]) => _repository.testConnection(targetUrl);

  void updateBackendUrl(String newUrl) {
    _repository.apiService.updateBaseUrl(newUrl);
    loadData();
  }
}
