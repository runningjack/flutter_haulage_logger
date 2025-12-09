import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io'; // Import for Directory check (optional, for debugging)

class LocalDBService {
  static Database? _database;

  LocalDBService._privateConstructor();
  static final LocalDBService instance = LocalDBService._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'haulage_logs.db');

    print('Database path: $path');
    print('Database directory: $databasePath');

    // Optional: Check if the directory exists (for debugging)
    final dir = Directory(databasePath);
    if (await dir.exists()) {
      print('Database directory exists!');
    } else {
      print('Database directory DOES NOT exist (sqflite should create it)!');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        print('Creating database tables...');
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
            synced INTEGER DEFAULT 0
          )
        ''');
        print('Database tables created successfully!');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
        // Add your migration logic here if you increment the version
      },
      onOpen: (db) {
        print('Database opened successfully!');
      },
    );
  }
}
