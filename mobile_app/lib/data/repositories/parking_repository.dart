import '../models/bay_model.dart';
import '../models/summary_model.dart';
import '../models/reservation_model.dart';
import '../services/api_service.dart';

class ParkingRepository {
  final ApiService _apiService;

  ParkingRepository({required ApiService apiService}) : _apiService = apiService;

  ApiService get apiService => _apiService;

  Future<SummaryModel> getSummary() => _apiService.fetchSummary();

  Future<List<BayModel>> getBays({String? zone, String? slotType, String? status}) =>
      _apiService.fetchBays(zone: zone, slotType: slotType, status: status);

  Future<Map<String, dynamic>> checkIn({
    required String vehicleNumber,
    String vehicleType = 'Car',
    String? driverName,
    String? driverPhone,
    int? slotId,
    bool isEvCharging = false,
    String? fastagId,
  }) => _apiService.checkInVehicle(
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        driverName: driverName,
        driverPhone: driverPhone,
        slotId: slotId,
        isEvCharging: isEvCharging,
        fastagId: fastagId,
      );

  Future<Map<String, dynamic>> checkOut({
    required String ticketId,
    String paymentMethod = 'FASTag (NETC Auto-Debit)',
    String billingModel = 'prorated_30min',
  }) => _apiService.checkOutVehicle(
        ticketId: ticketId,
        paymentMethod: paymentMethod,
        billingModel: billingModel,
      );

  Future<Map<String, dynamic>> reserve({
    required String customerName,
    required String customerPhone,
    required String vehicleNumber,
    required String vehicleType,
    required int slotId,
    required String reservedFor,
    required String paymentMethod,
  }) => _apiService.createReservation(
        customerName: customerName,
        customerPhone: customerPhone,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        slotId: slotId,
        reservedFor: reservedFor,
        paymentMethod: paymentMethod,
      );

  Future<List<ReservationModel>> getReservations({String? status}) =>
      _apiService.fetchReservations(status: status);

  Future<Map<String, dynamic>> locate(String query) => _apiService.locateVehicle(query);

  Future<Map<String, dynamic>> previewBill(String ticketId, {String billingModel = 'prorated_30min'}) =>
      _apiService.previewBill(ticketId, billingModel: billingModel);

  Future<List<Map<String, dynamic>>> getTickets({int limit = 100}) =>
      _apiService.fetchTickets(limit: limit);

  Future<Map<String, dynamic>> getRates() => _apiService.fetchRates();

  Future<void> updateRate(String vehicleType, double hourlyRate, double minCharge) =>
      _apiService.updateRate(vehicleType, hourlyRate, minCharge);

  Future<Map<String, dynamic>> getKpiDrilldown(String kpiType) =>
      _apiService.fetchKpiDrilldown(kpiType);

  Future<void> resetCleanProduction() => _apiService.resetCleanProduction();

  Future<void> cancelReservation(String reservationId) =>
      _apiService.cancelReservation(reservationId);

  Future<Map<String, dynamic>> checkInFromReservation(
    String reservationId, {
    String? fastagId,
    bool isEvCharging = false,
  }) =>
      _apiService.checkInFromReservation(
        reservationId,
        fastagId: fastagId,
        isEvCharging: isEvCharging,
      );

  Future<int> sweepExpiredReservations() => _apiService.sweepExpiredReservations();
}
