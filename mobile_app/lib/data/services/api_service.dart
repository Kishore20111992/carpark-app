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
      baseUrl = 'https://10.0.2.2:8000'; // Default Android Emulator host bridge
    } else {
      baseUrl = 'https://localhost:8000'; // iOS Simulator & desktop
    }
  }

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
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
}
