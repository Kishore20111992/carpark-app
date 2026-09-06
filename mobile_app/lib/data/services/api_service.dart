import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bay_model.dart';
import '../models/summary_model.dart';
import '../models/ticket_model.dart';
import '../models/reservation_model.dart';

class ApiService {
  late String baseUrl;

  ApiService({String? customUrl}) {
    if (customUrl != null && customUrl.isNotEmpty) {
      baseUrl = customUrl;
    } else if (kIsWeb) {
      baseUrl = 'https://localhost:8000';
    } else if (Platform.isAndroid) {
      baseUrl = 'https://10.9.240.129:8000'; // Default host PC Wi-Fi IP for physical mobile testing
    } else {
      baseUrl = 'https://10.9.240.129:8000'; // Default to host PC
    }
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
  }

  Future<bool> testConnection([String? targetUrl]) async {
    final urlToTest = (targetUrl != null && targetUrl.isNotEmpty) ? targetUrl : baseUrl;
    final cleanUrl = urlToTest.endsWith('/') ? urlToTest.substring(0, urlToTest.length - 1) : urlToTest;
    try {
      final uri = Uri.parse('$cleanUrl/api/bays/summary');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SummaryModel> fetchSummary() async {
    final uri = Uri.parse('$baseUrl/api/bays/summary');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return SummaryModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load summary: ${response.statusCode} ${response.body}');
  }

  Future<List<BayModel>> fetchBays({String? zone, String? slotType, String? status}) async {
    final queryParams = <String, String>{};
    if (zone != null) queryParams['zone'] = zone;
    if (slotType != null) queryParams['slot_type'] = slotType;
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/api/bays').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List baysJson = data['bays'] as List;
      return baysJson.map((j) => BayModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load bays: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> checkInVehicle({
    required String vehicleNumber,
    String vehicleType = 'Car',
    String? driverName,
    String? driverPhone,
    int? slotId,
    bool isEvCharging = false,
    String? fastagId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/checkin');
    final body = jsonEncode({
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'driver_name': driverName ?? '',
      'driver_phone': driverPhone ?? '',
      'slot_id': slotId,
      'is_ev_charging': isEvCharging,
      'fastag_id': fastagId ?? '',
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Check-in failed');
  }

  Future<Map<String, dynamic>> checkOutVehicle({
    required String ticketId,
    String paymentMethod = 'FASTag (NETC Auto-Debit)',
    String billingModel = 'prorated_30min',
  }) async {
    final uri = Uri.parse('$baseUrl/api/checkout');
    final body = jsonEncode({
      'ticket_id': ticketId,
      'payment_method': paymentMethod,
      'billing_model': billingModel,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Checkout failed');
  }

  Future<Map<String, dynamic>> createReservation({
    required String customerName,
    required String customerPhone,
    required String vehicleNumber,
    required String vehicleType,
    required int slotId,
    required String reservedFor,
    required String paymentMethod,
  }) async {
    final uri = Uri.parse('$baseUrl/api/reservations');
    final body = jsonEncode({
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'slot_id': slotId,
      'reserved_for': reservedFor,
      'payment_method': paymentMethod,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Reservation creation failed');
  }

  Future<List<ReservationModel>> fetchReservations({String? status}) async {
    final uri = Uri.parse('$baseUrl/api/reservations').replace(
      queryParameters: status != null ? {'status': status} : null,
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List resJson = data['reservations'] as List;
      return resJson.map((j) => ReservationModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load reservations: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> locateVehicle(String query) async {
    final uri = Uri.parse('$baseUrl/api/locator').replace(queryParameters: {'query': query});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Vehicle not found');
  }

  Future<Map<String, dynamic>> previewBill(String ticketId, {String billingModel = 'prorated_30min'}) async {
    final uri = Uri.parse('$baseUrl/api/checkout/preview').replace(
      queryParameters: {'ticket_id': ticketId, 'billing_model': billingModel},
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Failed to preview bill');
  }

  Future<List<Map<String, dynamic>>> fetchTickets({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/api/tickets').replace(queryParameters: {'limit': limit.toString()});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['tickets']);
    }
    throw Exception('Failed to load tickets: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchRates() async {
    final uri = Uri.parse('$baseUrl/api/rates');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load tariff rates: ${response.statusCode}');
  }

  Future<void> updateRate(String vehicleType, double hourlyRate, double minCharge) async {
    final uri = Uri.parse('$baseUrl/api/rates');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vehicle_type': vehicleType,
        'hourly_rate': hourlyRate,
        'min_charge': minCharge,
      }),
    );
    if (response.statusCode != 200) {
      final errData = jsonDecode(response.body);
      throw Exception(errData['detail'] ?? 'Failed to update rate');
    }
  }

  Future<Map<String, dynamic>> fetchKpiDrilldown(String kpiType) async {
    final uri = Uri.parse('$baseUrl/api/kpi/drilldown').replace(queryParameters: {'kpi_type': kpiType});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Failed to fetch KPI drilldown');
  }

  Future<void> resetCleanProduction() async {
    final uri = Uri.parse('$baseUrl/api/admin/reset');
    final response = await http.post(uri);
    if (response.statusCode != 200) {
      final errData = jsonDecode(response.body);
      throw Exception(errData['detail'] ?? 'Failed to reset facility');
    }
  }

  Future<void> cancelReservation(String reservationId) async {
    final uri = Uri.parse('$baseUrl/api/reservations/$reservationId/cancel');
    final response = await http.post(uri);
    if (response.statusCode != 200) {
      final errData = jsonDecode(response.body);
      throw Exception(errData['detail'] ?? 'Failed to cancel reservation');
    }
  }

  Future<Map<String, dynamic>> checkInFromReservation(
    String reservationId, {
    String? fastagId,
    bool isEvCharging = false,
  }) async {
    final queryParams = <String, String>{
      'is_ev_charging': isEvCharging.toString(),
    };
    if (fastagId != null && fastagId.isNotEmpty) {
      queryParams['fastag_id'] = fastagId;
    }
    final uri = Uri.parse('$baseUrl/api/reservations/$reservationId/checkin').replace(queryParameters: queryParams);
    final response = await http.post(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Check-in from reservation failed');
  }

  Future<int> sweepExpiredReservations() async {
    final uri = Uri.parse('$baseUrl/api/reservations/sweep');
    final response = await http.post(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['forfeited_count'] as int? ?? 0;
    }
    throw Exception('Failed to sweep expired bookings');
  }

  Future<Map<String, dynamic>> createBay({
    required String slotNumber,
    required String zone,
    required int floor,
    required String slotType,
    String notes = '',
    String status = 'Available',
  }) async {
    final uri = Uri.parse('$baseUrl/api/bays');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'slot_number': slotNumber,
        'zone': zone,
        'floor': floor,
        'slot_type': slotType,
        'notes': notes,
        'status': status,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Failed to create bay');
  }

  Future<Map<String, dynamic>> updateBay({
    required int slotId,
    String? slotNumber,
    String? zone,
    int? floor,
    String? slotType,
    String? status,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/bays/$slotId');
    final Map<String, dynamic> body = {};
    if (slotNumber != null) body['slot_number'] = slotNumber;
    if (zone != null) body['zone'] = zone;
    if (floor != null) body['floor'] = floor;
    if (slotType != null) body['slot_type'] = slotType;
    if (status != null) body['status'] = status;
    if (notes != null) body['notes'] = notes;

    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final errData = jsonDecode(response.body);
    throw Exception(errData['detail'] ?? 'Failed to update bay');
  }

  Future<void> deleteBay(int slotId) async {
    final uri = Uri.parse('$baseUrl/api/bays/$slotId');
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      final errData = jsonDecode(response.body);
      throw Exception(errData['detail'] ?? 'Failed to delete bay');
    }
  }
}


