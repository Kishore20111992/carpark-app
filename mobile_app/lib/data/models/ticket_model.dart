class TicketModel {
  final String ticketId;
  final String vehicleNumber;
  final String vehicleType;
  final String slotNumber;
  final String entryTime;
  final double ratePerHour;
  final bool isEvCharging;
  final String? fastagId;
  final double prepaidDeposit;
  final String paymentStatus;

  TicketModel({
    required this.ticketId,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.slotNumber,
    required this.entryTime,
    required this.ratePerHour,
    required this.isEvCharging,
    this.fastagId,
    required this.prepaidDeposit,
    required this.paymentStatus,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      ticketId: json['ticket_id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      slotNumber: json['slot_number'] as String,
      entryTime: json['entry_time'] as String,
      ratePerHour: (json['rate_per_hour'] as num).toDouble(),
      isEvCharging: (json['is_ev_charging'] as int? ?? 0) == 1,
      fastagId: json['fastag_id'] as String?,
      prepaidDeposit: (json['prepaid_deposit'] as num? ?? 0.0).toDouble(),
      paymentStatus: json['payment_status'] as String,
    );
  }
}
