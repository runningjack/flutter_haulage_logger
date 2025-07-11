class HaulageLog {
  int? id;
  String transactionId;
  String shiftId;
  String vehicle;
  String driver;
  String project;
  String loadingSite;
  String cycle;
  DateTime cycleStartTime;
  double cycleStartOdometer;
  double loadingTonnage;
  String dumpingSite;
  DateTime arrivalTime;
  double arrivalOdometer;
  DateTime dumpingTime;
  double dumpingTonnage;
  DateTime departureTime;
  double cycleEndOdometer;
  DateTime cycleEndTime;
  bool synced;

  HaulageLog({
    this.id,
    required this.transactionId,
    required this.shiftId,
    required this.vehicle,
    required this.driver,
    required this.project,
    required this.loadingSite,
    required this.cycle,
    required this.cycleStartTime,
    required this.cycleStartOdometer,
    required this.loadingTonnage,
    required this.dumpingSite,
    required this.arrivalTime,
    required this.arrivalOdometer,
    required this.dumpingTime,
    required this.dumpingTonnage,
    required this.departureTime,
    required this.cycleEndOdometer,
    required this.cycleEndTime,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'shiftId': shiftId,
    'vehicle': vehicle,
    'driver': driver,
    'project': project,
    'loadingSite': loadingSite,
    'cycle': cycle,
    'cycleStartTime': cycleStartTime.toIso8601String(),
    'cycleStartOdometer': cycleStartOdometer,
    'loadingTonnage': loadingTonnage,
    'dumpingSite': dumpingSite,
    'arrivalTime': arrivalTime.toIso8601String(),
    'arrivalOdometer': arrivalOdometer,
    'dumpingTime': dumpingTime.toIso8601String(),
    'dumpingTonnage': dumpingTonnage,
    'departureTime': departureTime.toIso8601String(),
    'cycleEndOdometer': cycleEndOdometer,
    'cycleEndTime': cycleEndTime.toIso8601String(),
    'synced': synced ? 1 : 0
  };
  

  factory HaulageLog.fromMap(Map<String, dynamic> map) {
    return HaulageLog(
      id: map['id'],
      transactionId: map['transactionId'],
      shiftId: map['shiftId'],
      vehicle: map['vehicle'],
      driver: map['driver'],
      project: map['project'],
      loadingSite: map['loadingSite'],
      cycle: map['cycle'],
      cycleStartTime: DateTime.parse(map['cycleStartTime']),
      cycleStartOdometer: map['cycleStartOdometer'],
      loadingTonnage: map['loadingTonnage'],
      dumpingSite: map['dumpingSite'],
      arrivalTime: DateTime.parse(map['arrivalTime']),
      arrivalOdometer: map['arrivalOdometer'],
      dumpingTime: DateTime.parse(map['dumpingTime']),
      dumpingTonnage: map['dumpingTonnage'],
      departureTime: DateTime.parse(map['departureTime']),
      cycleEndOdometer: map['cycleEndOdometer'],
      cycleEndTime: DateTime.parse(map['cycleEndTime']),
      synced: map['synced'] == 1,
    );
  }
} 