class ReservationModel {
  final String reservationId;
  final String customerName;
  final String customerPhone;
  final String vehicleNumber;
  final String vehicleType;
  final String slotNumber;
  final String reservedFor;
  final double depositAmount;
  final String paymentMethod;
  final String status;

  ReservationModel({
    required this.reservationId,
    required this.customerName,
    required this.customerPhone,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.slotNumber,
    required this.reservedFor,
    required this.depositAmount,
    required this.paymentMethod,
    required this.status,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      reservationId: json['reservation_id'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      slotNumber: json['slot_number'] as String,
      reservedFor: json['reserved_for'] as String,
      depositAmount: (json['deposit_amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCheckedIn => status.toLowerCase() == 'checkedin';
  bool get isForfeited => status.toLowerCase() == 'noshow_forfeited';
}
