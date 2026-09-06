class SummaryModel {
  final int totalBays;
  final int availableBays;
  final int occupiedBays;
  final int reservedBays;
  final int maintenanceBays;
  final double occupancyRatePct;
  final double todayRevenue;
  final String currency;

  SummaryModel({
    required this.totalBays,
    required this.availableBays,
    required this.occupiedBays,
    required this.reservedBays,
    required this.maintenanceBays,
    required this.occupancyRatePct,
    required this.todayRevenue,
    required this.currency,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    return SummaryModel(
      totalBays: json['total_bays'] as int,
      availableBays: json['available_bays'] as int,
      occupiedBays: json['occupied_bays'] as int,
      reservedBays: json['reserved_bays'] as int,
      maintenanceBays: json['maintenance_bays'] as int,
      occupancyRatePct: (json['occupancy_rate_pct'] as num).toDouble(),
      todayRevenue: (json['today_revenue'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
