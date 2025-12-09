// lib/services/local_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/driver.dart';
import '../models/haulage_log.dart';
import '../models/project.dart';
import '../models/vehicle.dart';

class LocalDBService {
  // Singleton pattern for LocalDBService
  static final LocalDBService _instance = LocalDBService._privateConstructor();
  // Make the instance getter public
  static LocalDBService get instance =>
      _instance; // Added this getter explicitly
  LocalDBService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'haulage_logger.db');

    // IMPORTANT: Increment the database version if you've added new tables or columns.
    // Since you added 'vehicles', 'drivers', 'projects' tables, you MUST increment the version.
    // If it was 1, change it to 2. If it was 2, change it to 3, and so on.
    // This forces onUpgrade to run.
    return await openDatabase(
      path,
      version: 3, // <--- **FIX: INCREMENT DATABASE VERSION HERE**
      onCreate: (db, version) async {
        // Create haulage_logs table
        await db.execute('''
          CREATE TABLE haulage_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remoteId INTEGER,
            transactionId TEXT UNIQUE,
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
            synced INTEGER DEFAULT 0,
            synced_at INTEGER  -- NEW: Add synced_at column
          )
        ''');

        // Create master data tables - use 'IF NOT EXISTS' for safety
        await db.execute('''
          CREATE TABLE IF NOT EXISTS vehicles(
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE,
            license_plate TEXT -- Added this based on your MasterDataService 'fields'
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS drivers(
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE,
            email TEXT, -- Added based on your MasterDataService 'fields'
            phone TEXT  -- Added based on your MasterDataService 'fields'
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS projects(
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE,
            code TEXT -- Added based on your MasterDataService 'fields'
          )
        ''');
        // Add loading_sites and dumping_sites as well, consistent with MasterDataService
        await db.execute('''
          CREATE TABLE IF NOT EXISTS loading_sites(
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS dumping_sites(
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // This block runs when `newVersion` is greater than `oldVersion`

        // Example: If upgrading from version 1 to 2, create new tables
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS vehicles(
              id INTEGER PRIMARY KEY,
              name TEXT UNIQUE,
              license_plate TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS drivers(
              id INTEGER PRIMARY KEY,
              name TEXT UNIQUE,
              email TEXT,
              phone TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS projects(
              id INTEGER PRIMARY KEY,
              name TEXT UNIQUE,
              code TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS loading_sites(
              id INTEGER PRIMARY KEY,
              name TEXT UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS dumping_sites(
              id INTEGER PRIMARY KEY,
              name TEXT UNIQUE
            )
          ''');
        }

        // Add more upgrade conditions for future versions
        // Migration for adding 'synced_at' column (from v2 to v3)
        if (oldVersion < 3) {
          print(
            'Upgrading from version $oldVersion to 3: Adding synced_at column to haulage_logs.',
          );
          try {
            // Use PRAGMA to check if column exists to prevent errors in case of repeated runs
            var tableInfo = await db.rawQuery(
              "PRAGMA table_info(haulage_logs);",
            );
            bool syncedAtExists = tableInfo.any(
              (column) => column['name'] == 'synced_at',
            );
            if (!syncedAtExists) {
              await db.execute(
                "ALTER TABLE haulage_logs ADD COLUMN synced_at INTEGER;",
              );
              print(
                "Added 'synced_at' column to haulage_logs table during upgrade.",
              );
            }
          } catch (e) {
            print("Error adding 'synced_at' column during upgrade: $e");
          }
        }
      },
    );
  }

  Future<int> insertLog(HaulageLog log) async {
    final db = await database;
    final int recordid = await db.insert(
      'haulage_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (recordid > 0) {
      log.id = recordid;
      return recordid; // Update the log with the new local ID
    } else {
      throw Exception("Failed to insert haulage log.");
    }
  }

  Future<void> deleteLog(int id) async {
    final db = await database;
    await db.delete('haulage_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateLog(HaulageLog log) async {
    final db = await database;
    await db.update(
      'haulage_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLogRemoteId(int localId, int remoteId) async {
    final db = await database;
    await db.update(
      'haulage_logs',
      {'remoteId': remoteId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markLogAsSynced(int id) async {
    final db = await database;
    await db.update(
      'haulage_logs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<HaulageLog>> getUnsyncedLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'haulage_logs',
      where: 'synced = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return HaulageLog.fromMap(maps[i]);
    });
  }

  Future<List<HaulageLog>> getAllLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('haulage_logs');
    return List.generate(maps.length, (i) {
      return HaulageLog.fromMap(maps[i]);
    });
  }

  // NEW METHOD: getRecentLogs
  Future<List<HaulageLog>> getRecentLogs({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'haulage_logs',
      orderBy: 'id DESC', // Order by ID descending to get most recent
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return HaulageLog.fromMap(maps[i]);
    });
  }

  Future<bool> transactionIdExists(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'haulage_logs',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.isNotEmpty;
  }

  Future<HaulageLog?> getLogByTransactionId(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'haulage_logs',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
      limit: 1, // We only expect one result for a unique transactionId
    );

    if (maps.isNotEmpty) {
      return HaulageLog.fromMap(maps.first);
    }
    return null; // Return null if no log found
  }

  // NEW METHOD: Update only the dumping data fields of an existing log
  Future<void> updateDumpingData(HaulageLog log) async {
    if (log.id == null) {
      throw Exception("Cannot update log: local ID is missing.");
    }
    final db = await database;
    await db.update(
      'haulage_logs',
      {
        'dumpingSite': log.dumpingSite,
        'arrivalTime': log.arrivalTime?.toIso8601String(),
        'arrivalOdometer': log.arrivalOdometer,
        'dumpingTime': log.dumpingTime?.toIso8601String(),
        'dumpingTonnage': log.dumpingTonnage,
        'departureTime': log.departureTime?.toIso8601String(),
        'cycleEndOdometer': log.cycleEndOdometer,
        'cycleEndTime': log.cycleEndTime?.toIso8601String(),
        'synced': 0, // Mark as unsynced after update
      },
      where: 'id = ?',
      whereArgs: [log.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- New Methods for Master Data ---
  // --- MODIFIED: Method to delete old synced logs based on cycle_start_time ---
  Future<int> deleteOldSyncedLogs() async {
    final db = await database;
    // Calculate timestamp 8 hours ago
    final eightHoursAgo = DateTime.now().subtract(const Duration(hours: 8));
    final eightHoursAgoMillis = eightHoursAgo.millisecondsSinceEpoch;

    print(
      'Attempting to delete logs with synced_at before: $eightHoursAgo',
    );

    final int deletedRows = await db.delete(
      'haulage_logs',
      // Delete if synced is true (1) AND cycle_start_time is not null AND cycle_start_time is older than 8 hours ago
      where: 'synced = ? AND synced_at IS NOT NULL AND synced_at < ?',
      whereArgs: [1, eightHoursAgoMillis],
    );
    print('Deleted $deletedRows old synced logs.');
    return deletedRows;
  }

  // Save multiple items (e.g., vehicles, drivers, projects)
  Future<void> saveMasterData<T>(
    String tableName,
    List<T> items,
    Map<String, dynamic> Function(T) toMapFunc,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var item in items) {
        await txn.insert(
          tableName,
          toMapFunc(item),
          conflictAlgorithm:
              ConflictAlgorithm.replace, // Replace if ID already exists
        );
      }
    });
  }

  // Get all vehicles
  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Vehicle.fromJson(maps[i]);
    });
  }

  // Get all drivers
  Future<List<Driver>> getDrivers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drivers',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Driver.fromJson(maps[i]);
    });
  }

  // Get all projects
  Future<List<Project>> getProjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) {
      return Project.fromJson(maps[i]);
    });
  }

  // Save vehicles
  Future<void> saveVehicles(List<Vehicle> vehicles) async {
    await saveMasterData('vehicles', vehicles, (vehicle) => vehicle.toJson());
  }

  // Save drivers
  Future<void> saveDrivers(List<Driver> drivers) async {
    await saveMasterData('drivers', drivers, (driver) => driver.toJson());
  }

  // Save projects
  Future<void> saveProjects(List<Project> projects) async {
    await saveMasterData('projects', projects, (project) => project.toJson());
  }

  Future<int?> getVehicleIdByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      where: 'name = ?', // Or 'license_plate = ?' if log.vehicle stores plate
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return null;
  }

  // Add similar methods for Driver, Project, LoadingSite, DumpingSite
  Future<int?> getDriverIdByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drivers',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return null;
  }

  Future<int?> getProjectIdByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'projects',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return null;
  }
}
