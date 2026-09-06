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
}
