// lib/models/haulage_log.dart

class HaulageLog {
  int? id; // Local database ID
  int? remoteId; // Odoo ID
  String
  transactionId; // This should probably remain final if it's a unique identifier
  String? shiftId; // Make non-final
  String? vehicle; // Make non-final
  String? driver; // Make non-final
  String? project; // Make non-final
  String? loadingSite; // Make non-final
  String? cycle; // Make non-final
  DateTime? cycleStartTime; // Make non-final
  double? cycleStartOdometer; // Make non-final
  double? loadingTonnage; // Make non-final

  // Make all dumping-related fields non-final (remove 'final' keyword)
  String? dumpingSite;
  DateTime? arrivalTime;
  double? arrivalOdometer;
  DateTime? dumpingTime;
  double? dumpingTonnage;
  DateTime? departureTime;
  double? cycleEndOdometer;
  DateTime? cycleEndTime;
  bool synced; // Make non-final
  DateTime? syncedAt; // NEW: Timestamp when the log was last synced

  HaulageLog({
    this.id,
    this.remoteId,
    required this.transactionId,
    this.shiftId,
    this.vehicle,
    this.driver,
    this.project,
    this.loadingSite,
    this.cycle,
    this.cycleStartTime,
    this.cycleStartOdometer,
    this.loadingTonnage,
    this.dumpingSite,
    this.arrivalTime,
    this.arrivalOdometer,
    this.dumpingTime,
    this.dumpingTonnage,
    this.departureTime,
    this.cycleEndOdometer,
    this.cycleEndTime,
    this.synced = false,
    this.syncedAt, // NEW: Include in constructor
  });

  // Convert HaulageLog object to a Map for database insertion/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'transactionId': transactionId,
      'shiftId': shiftId,
      'vehicle': vehicle,
      'driver': driver,
      'project': project,
      'loadingSite': loadingSite,
      'cycle': cycle,
      'cycleStartTime': cycleStartTime?.toIso8601String(),
      'cycleStartOdometer': cycleStartOdometer,
      'loadingTonnage': loadingTonnage,
      'dumpingSite': dumpingSite,
      'arrivalTime': arrivalTime?.toIso8601String(),
      'arrivalOdometer': arrivalOdometer,
      'dumpingTime': dumpingTime?.toIso8601String(),
      'dumpingTonnage': dumpingTonnage,
      'departureTime': departureTime?.toIso8601String(),
      'cycleEndOdometer': cycleEndOdometer,
      'cycleEndTime': cycleEndTime?.toIso8601String(),
      'synced': synced ? 1 : 0,
      'synced_at': syncedAt?.millisecondsSinceEpoch,
    };
  }

  // Create a HaulageLog object from a Map (e.g., from database query)
  factory HaulageLog.fromMap(Map<String, dynamic> map) {
    return HaulageLog(
      id: map['id'],
      remoteId: map['remoteId'],
      transactionId: map['transactionId'],
      shiftId: map['shiftId'],
      vehicle: map['vehicle'],
      driver: map['driver'],
      project: map['project'],
      loadingSite: map['loadingSite'],
      cycle: map['cycle'],
      cycleStartTime: map['cycleStartTime'] != null
          ? DateTime.tryParse(map['cycleStartTime'])
          : null,
      cycleStartOdometer: map['cycleStartOdometer'],
      loadingTonnage: map['loadingTonnage'],
      dumpingSite: map['dumpingSite'],
      arrivalTime: map['arrivalTime'] != null
          ? DateTime.tryParse(map['arrivalTime'])
          : null,
      arrivalOdometer: map['arrivalOdometer'],
      dumpingTime: map['dumpingTime'] != null
          ? DateTime.tryParse(map['dumpingTime'])
          : null,
      dumpingTonnage: map['dumpingTonnage'],
      departureTime: map['departureTime'] != null
          ? DateTime.tryParse(map['departureTime'])
          : null,
      cycleEndOdometer: map['cycleEndOdometer'],
      cycleEndTime: map['cycleEndTime'] != null
          ? DateTime.tryParse(map['cycleEndTime'])
          : null,
      synced: map['synced'] == 1,
      syncedAt: map['synced_at'] != null // NEW: Parse from milliseconds
          ? DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int)
          : null,
    );
  }

  // Optional: A copyWith method is useful for immutable objects,
  // but if you make fields non-final, direct assignment is possible.
  // If you decide to keep fields final and create new objects, you'd use this.
  HaulageLog copyWith({
    int? id,
    int? remoteId,
    String? transactionId,
    String? shiftId,
    String? vehicle,
    String? driver,
    String? project,
    String? loadingSite,
    String? cycle,
    DateTime? cycleStartTime,
    double? cycleStartOdometer,
    double? loadingTonnage,
    String? dumpingSite,
    DateTime? arrivalTime,
    double? arrivalOdometer,
    DateTime? dumpingTime,
    double? dumpingTonnage,
    DateTime? departureTime,
    double? cycleEndOdometer,
    DateTime? cycleEndTime,
    bool? synced,
  }) {
    return HaulageLog(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      transactionId: transactionId ?? this.transactionId,
      shiftId: shiftId ?? this.shiftId,
      vehicle: vehicle ?? this.vehicle,
      driver: driver ?? this.driver,
      project: project ?? this.project,
      loadingSite: loadingSite ?? this.loadingSite,
      cycle: cycle ?? this.cycle,
      cycleStartTime: cycleStartTime ?? this.cycleStartTime,
      cycleStartOdometer: cycleStartOdometer ?? this.cycleStartOdometer,
      loadingTonnage: loadingTonnage ?? this.loadingTonnage,
      dumpingSite: dumpingSite ?? this.dumpingSite,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      arrivalOdometer: arrivalOdometer ?? this.arrivalOdometer,
      dumpingTime: dumpingTime ?? this.dumpingTime,
      dumpingTonnage: dumpingTonnage ?? this.dumpingTonnage,
      departureTime: departureTime ?? this.departureTime,
      cycleEndOdometer: cycleEndOdometer ?? this.cycleEndOdometer,
      cycleEndTime: cycleEndTime ?? this.cycleEndTime,
      synced: synced ?? this.synced,
    );
  }
}
