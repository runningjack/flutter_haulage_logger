class HaulageLogDto {
  final int? remoteId;
  final String dumpingSite;
  final DateTime arrivalTime;
  final double arrivalOdometer;
  final DateTime dumpingTime;
  final double dumpingTonnage;
  final DateTime departureTime;
  final double cycleEndOdometer;
  final DateTime cycleEndTime;

  HaulageLogDto({
    required this.remoteId,
    required this.dumpingSite,
    required this.arrivalTime,
    required this.arrivalOdometer,
    required this.dumpingTime,
    required this.dumpingTonnage,
    required this.departureTime,
    required this.cycleEndOdometer,
    required this.cycleEndTime,
  });

  Map<String, dynamic> toOdooMap() {
    return {
      'x_arrival_time': arrivalTime.toIso8601String(),
      'x_arrival_odo': arrivalOdometer,
      'x_dumping_time': dumpingTime.toIso8601String(),
      'x_tonnage_dumping_float': dumpingTonnage,
      'x_depature_time': departureTime.toIso8601String(),
      'x_odo_end': cycleEndOdometer,
      'x_cycle_end': cycleEndTime.toIso8601String(),
    };
  }
}
