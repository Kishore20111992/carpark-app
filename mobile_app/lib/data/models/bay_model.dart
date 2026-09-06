class BayModel {
  final int id;
  final String slotNumber;
  final String zone;
  final int floor;
  final String slotType;
  final String status;
  final String? notes;
  final String? vehicleNumber;
  final String? ticketId;
  final String? driverName;
  final String? entryTime;

  BayModel({
    required this.id,
    required this.slotNumber,
    required this.zone,
    required this.floor,
    required this.slotType,
    required this.status,
    this.notes,
    this.vehicleNumber,
    this.ticketId,
    this.driverName,
    this.entryTime,
  });

  factory BayModel.fromJson(Map<String, dynamic> json) {
    return BayModel(
      id: json['id'] as int,
      slotNumber: json['slot_number'] as String,
      zone: json['zone'] as String,
      floor: json['floor'] as int,
      slotType: json['slot_type'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      ticketId: json['ticket_id'] as String?,
      driverName: json['driver_name'] as String?,
      entryTime: json['entry_time'] as String?,
    );
  }

  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isOccupied => status.toLowerCase() == 'occupied';
  bool get isReserved => status.toLowerCase() == 'reserved';
  bool get isMaintenance => status.toLowerCase() == 'maintenance';

  double get hourlyRate {
    switch (slotType.toLowerCase()) {
      case 'ev':
        return 60.0;
      case 'suv':
        return 70.0;
      case 'bike':
        return 20.0;
      case 'handicap':
        return 30.0;
      default:
        return 50.0;
    }
  }
}

