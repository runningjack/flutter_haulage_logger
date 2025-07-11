
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/haulage_log.dart';

class LocalDBService {
  static final LocalDBService _instance = LocalDBService._internal();
  factory LocalDBService() => _instance;
  LocalDBService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'haulage_logs.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE haulage_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transactionId TEXT,
            shiftId TEXT,
            vehicle TEXT,
            driver TEXT,
            project TEXT,
            loadingSite TEXT,
            cycle TEXT,
            cycleStartTime TEXT,
            cycleStartOdometer REAL,
            loadingTonnage REAL,
            dumpingSite TEXT,
            arrivalTime TEXT,
            arrivalOdometer REAL,
            dumpingTime TEXT,
            dumpingTonnage REAL,
            departureTime TEXT,
            cycleEndOdometer REAL,
            cycleEndTime TEXT,
            synced INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertLog(HaulageLog log) async {
    final db = await database;
    await db.insert('haulage_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HaulageLog>> getUnsyncedLogs() async {
    final db = await database;
    final result = await db.query('haulage_logs', where: 'synced = ?', whereArgs: [0]);
    return result.map((e) => HaulageLog.fromMap(e)).toList();
  }

  Future<void> markLogAsSynced(int id) async {
    final db = await database;
    await db.update('haulage_logs', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('haulage_logs');
  }

  Future<void> deleteLog(int id) async {
    final db = await database;
    await db.delete('haulage_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> transactionIdExists(String transactionId) async {
    final db = await database;
    final result = await db.query('haulage_logs', where: 'transactionId = ?', whereArgs: [transactionId]);
    return result.isNotEmpty;
  }
}