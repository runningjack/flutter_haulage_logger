// lib/services/sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/haulage_log.dart';
import '../models/user_credentials.dart';
import 'local_db_service.dart';
import 'odoo_service.dart';

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._privateConstructor();
  final LocalDBService _localDBService = LocalDBService.instance;
  final OdooService _odooService = OdooService.instance;
  // Public getter to access the singleton instance
  /*factory SyncService() {
    // Factory constructor returns the singleton instance
    return _instance;
  }*/
  static SyncService get instance => _instance;
  SyncService._privateConstructor();

  static const String _odooUrl = 'https://mayfairtradingsl.com/jsonrpc';
  static const String _db = 'Mayfair_Trading';
  static const String _odooModel = 'x_haulage_log';

  Future<void> syncUnsyncedLogs(UserCredentials credentials) async {
    print('Attempting to sync all unsynced logs...');
    try {
      final List<HaulageLog> unsyncedLogs = await LocalDBService.instance
          .getUnsyncedLogs();

      if (unsyncedLogs.isEmpty) {
        print('No unsynced logs found.');
        return;
      }

      for (var log in unsyncedLogs) {
        bool success = false;
        if (log.remoteId != null) {
          print(
            'Attempting to update existing log ${log.transactionId} (Remote ID: ${log.remoteId})...',
          );
          success = await _updateOnOdoo(log, credentials);
        } else {
          print('Attempting to create new log ${log.transactionId} on Odoo...');
          success = await _createOnOdoo(log, credentials);
        }

        if (success) {
          // Corrected: Use LocalDBService.instance
          await LocalDBService.instance.markLogAsSynced(log.id!);
          print(
            'Log ${log.transactionId} synced successfully and marked as synced locally.',
          );
        } else {
          print('Failed to sync log ${log.transactionId}. Will retry later.');
        }
      }
    } catch (e) {
      print('Error during bulk sync: $e');
      rethrow;
    }
  }

  // Sync a single new log (e.g., after initial creation)
  Future<void> syncLog(HaulageLog log, UserCredentials credentials) async {
    print(
      'Attempting to sync single log ${log.transactionId} (ID: ${log.id})...',
    );
    try {
      bool success = await _createOnOdoo(log, credentials);
      if (success) {
        // Corrected: Use LocalDBService.instance
        await LocalDBService.instance.markLogAsSynced(log.id!);
        print('Single log ${log.transactionId} synced successfully.');
      } else {
        throw Exception('Failed to create log ${log.transactionId} on Odoo.');
      }
    } catch (e) {
      print('Error syncing single log: $e');
      rethrow;
    }
  }

  // Sync a single updated log (e.g., after dumping data is added)
  Future<void> syncLogUpdate(
    HaulageLog log,
    UserCredentials credentials,
  ) async {
    print(
      'Attempting to sync update for log ${log.transactionId} (ID: ${log.id})...',
    );
    if (log.remoteId == null) {
      print(
        'Warning: Log ${log.transactionId} does not have a remote ID. Cannot update on Odoo.',
      );
      //throw Exception('Log missing remote ID for update.');
    }
    try {
      bool success = await _updateOnOdoo(log, credentials);
      if (success) {
        // Corrected: Use LocalDBService.instance
        await LocalDBService.instance.markLogAsSynced(log.id!);
        print('Log update for ${log.transactionId} synced successfully.');
      } else {
        throw Exception('Failed to update log ${log.transactionId} on Odoo.');
      }
    } catch (e) {
      print('Error syncing log update: $e');
      rethrow;
    }
  }

  /*Future<void> syncLogUpdate(HaulageLog log, UserCredentials credentials) async {
    if (log.remoteId == null) {
      // Log does not have a remote ID, attempt to create it on Odoo
      await _createOnOdoo(log, credentials);
    } else {
      // Log has a remote ID, attempt to update it on Odoo
      await _updateOnOdoo(log, credentials);
    }
  }*/

  // Helper method to send data to Odoo (CREATE)
  Future<bool> _createOnOdoo(
    HaulageLog log,
    UserCredentials credentials,
  ) async {
    try {
      // --- Look up IDs from local DB ---
      int? vehicleId;
      if (log.vehicle != null) {
        vehicleId = await LocalDBService.instance.getVehicleIdByName(
          log.vehicle!,
        );
        if (vehicleId == null) {
          print(
            'Warning: Could not find vehicle ID for name: ${log.vehicle}. This field might be unset in Odoo.',
          );
        }
      }

      int? driverId;
      if (log.driver != null) {
        driverId = await LocalDBService.instance.getDriverIdByName(log.driver!);
        if (driverId == null) {
          print(
            'Warning: Could not find driver ID for name: ${log.driver}. This field might be unset in Odoo.',
          );
        }
      }

      int? projectId;
      if (log.project != null) {
        projectId = await LocalDBService.instance.getProjectIdByName(
          log.project!,
        );
        if (projectId == null) {
          print(
            'Warning: Could not find project ID for name: ${log.project}. This field might be unset in Odoo.',
          );
        }
      }

      final DateFormat odooDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

      final Map<String, dynamic> odooData = {
        'x_trans': log.transactionId,
        'x_shift': log.shiftId,
        'x_vehicle': vehicleId ?? int.parse(log.vehicle ?? '0'),
        'x_driver': driverId ?? int.parse(log.driver ?? '0'),
        'x_project': projectId ?? int.parse(log.project ?? '0'),
        'x_cycle': log.cycle,
        'x_cycle_start': log.cycleStartTime != null
            ? odooDateTimeFormat.format(log.cycleStartTime!)
            : false,
        'x_odo_start': log.cycleStartOdometer ?? 0.0,
        'x_tonnage_float': log.loadingTonnage ?? 0.0,
        'x_arrival_time': log.arrivalTime != null
            ? odooDateTimeFormat.format(log.arrivalTime!)
            : false,
        'x_arrival_odo': log.arrivalOdometer ?? 0.0,
        'x_dumping_time': log.dumpingTime != null
            ? odooDateTimeFormat.format(log.dumpingTime!)
            : false,
        'x_tonnage_dumping_float': log.dumpingTonnage ?? 0.0,
        'x_depature_time': log.departureTime != null
            ? odooDateTimeFormat.format(log.departureTime!)
            : false,
        'x_odo_end': log.cycleEndOdometer ?? 0.0,
        'x_cycle_end': log.cycleEndTime != null
            ? odooDateTimeFormat.format(log.cycleEndTime!)
            : false,
        'activity_user_id':
            credentials.uid, // Optional: Track who created the log
      };
      final resultOdoo = await _odooService.createRecord(
        credentials,
        _odooModel,
        odooData,
      );

      if (resultOdoo.containsKey('id') && resultOdoo['id'] != null) {
        log.remoteId = resultOdoo['id'] as int;
        ; // Update local log with Odoo's remote ID
        log.synced = true; // Mark as synced
        log.syncedAt = DateTime.now(); // NEW: Set syncedAt on successful update
        if (log.id != null) {
          await LocalDBService.instance.updateLogRemoteId(
            log.id!,
            resultOdoo['id'] as int,
          );
          //await LocalDBService.instance.markLogAsSynced(log.id!);

          print(
            'Log ${log.transactionId} created on Odoo with remote ID: $log.remoteId',
          );
          return true;
        }
      }
    } catch (e) {
      print(
        'Network or parsing error during Odoo CREATE for ${log.transactionId}: $e',
      );
    }
    return false;
  }

  // Helper method to send data to Odoo (UPDATE)
  Future<bool> _updateOnOdoo(
    HaulageLog log,
    UserCredentials credentials,
  ) async {
    if (log.remoteId == null) {
      print('Cannot update log without a remoteId: ${log.transactionId}');
      return false;
    }
    log.syncedAt = DateTime.now();
    try {
      final Map<String, dynamic> odooData = {
        'x_arrival_time': log.arrivalTime?.toIso8601String() ?? false,
        'x_arrival_odo': log.arrivalOdometer ?? 0.0,
        'x_dumping_time': log.dumpingTime?.toIso8601String() ?? false,
        'x_tonnage_dumping_float': log.dumpingTonnage ?? 0.0,
        'x_depature_time': log.departureTime?.toIso8601String() ?? false,
        'x_odo_end': log.cycleEndOdometer ?? 0.0,
        'x_cycle_end': log.cycleEndTime?.toIso8601String() ?? false,
      };

      final response = await http.post(
        Uri.parse(_odooUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'service': 'object',
            'method': 'execute_kw',
            'args': [
              _db,
              credentials.uid,
              credentials.password,
              _odooModel,
              'write',
              [
                [log.remoteId],
                odooData,
              ],
            ],
          },
          'id': 1,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          body.containsKey('result') &&
          body['result'] == true) {
        log.synced = true;
        log.syncedAt = DateTime.now(); // NEW: Set syncedAt on successful update
        await _localDBService.updateLog(log); // Save updated status
        print(
          'Log update for ${log.transactionId} (Remote ID: ${log.remoteId}) successful on Odoo.',
        );
        return true;
      } else if (body.containsKey('error')) {
        print('Odoo UPDATE error for ${log.transactionId}: ${body['error']}');
      } else {
        print(
          'Unexpected Odoo UPDATE response for ${log.transactionId}: ${response.body}',
        );
      }
    } catch (e) {
      print(
        'Network or parsing error during Odoo UPDATE for ${log.transactionId}: $e',
      );
    }
    return false;
  }

  Future<HaulageLog?> fetchLogFromServer(
    String transactionId,
    UserCredentials credentials,
  ) async {
    final body = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _db,
          credentials.uid,
          credentials.password,
          _odooModel,
          "search_read",
          [
            [
              ["x_trans", "=", transactionId],
            ],
          ],
          {
            "fields": [
              "id",
              "x_trans",
              "x_shift",
              "x_vehicle",
              "x_driver",
              "x_project",
              "x_cycle",
              "x_cycle_start",
              "x_odo_start",
              "x_tonnage_float",
              "x_arrival_time",
              "x_arrival_odo",
              "x_dumping_time",
              "x_tonnage_dumping_float",
              "x_depature_time",
              "x_odo_end",
              "x_cycle_end",
            ],
          },
        ],
      },
      "id": 1,
    };

    try {
      final response = await http.post(
        Uri.parse(_odooUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse.containsKey("result") &&
            jsonResponse["result"] is List &&
            jsonResponse["result"].isNotEmpty) {
          final data = jsonResponse["result"][0];

          return HaulageLog(
            id: null,
            remoteId: data["id"] as int?,
            transactionId: data["x_trans"] as String? ?? '',
            shiftId: data["x_shift"] as String? ?? '',
            vehicle: data["x_vehicle"] as String? ?? '',
            driver: data["x_driver"] as String? ?? '',
            project: data["x_project"] as String? ?? '',
            cycle: data["x_cycle"] as String? ?? '',
            cycleStartTime: DateTime.tryParse(
              data["x_cycle_start"] as String? ?? '',
            ),
            cycleStartOdometer: double.tryParse(
              data["x_odo_start"]?.toString() ?? '',
            ),
            loadingTonnage: double.tryParse(
              data["x_tonnage_float"]?.toString() ?? '',
            ),
            arrivalTime: DateTime.tryParse(
              data["x_arrival_time"] as String? ?? '',
            ),
            arrivalOdometer: double.tryParse(
              data["x_arrival_odo"]?.toString() ?? '',
            ),
            dumpingTime: DateTime.tryParse(
              data["x_dumping_time"] as String? ?? '',
            ),
            dumpingTonnage: double.tryParse(
              data["x_tonnage_dumping_float"]?.toString() ?? '',
            ),
            departureTime: DateTime.tryParse(
              data["x_depature_time"] as String? ?? '',
            ),
            cycleEndOdometer: double.tryParse(
              data["x_odo_end"]?.toString() ?? '',
            ),
            // Ensure x_cycle_end is handled as a String for DateTime.tryParse
            cycleEndTime: DateTime.tryParse(
              data["x_cycle_end"] as String? ?? '',
            ),
            synced: true,
          );
        } else if (jsonResponse.containsKey('error')) {
          print('Odoo SEARCH_READ error: ${jsonResponse['error']}');
        }
      } else {
        print(
          'HTTP Error fetching log: ${response.statusCode}, ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching log: $e');
    }
    return null;
  }

  Future<void> syncSingleHaulageLog(
    UserCredentials credentials,
    HaulageLog log,
  ) async {
    print(
      'Attempting to sync single log ${log.transactionId} (ID: ${log.id})...',
    );
    try {
      // 1. Prepare data for Odoo
      Map<String, dynamic> odooData = {};

      // Required fields
      odooData['x_trans'] = log.transactionId;
      odooData['x_cycle'] = log.cycle;
      odooData['x_cycle_start'] = log.cycleStartTime!.toIso8601String();
      ;
      odooData['x_driver'] = log.driver;
      odooData['x_shift'] = log.shiftId;
      odooData['x_vehicle'] = log.vehicle;
      odooData['x_tonnage_float'] = log.loadingTonnage;
      //odooData['x_depature_time'] = log.departureTime;
      odooData['x_project'] = log.departureTime;
      odooData['x_odo_start'] = log.cycleStartOdometer;

      // Convert DateTime to ISO 8601 String for Odoo
      // Log the final Odoo data map before sending
      print('Final Odoo data map for CREATE: ${odooData}');

      // 2. Call Odoo's create method
      final Map<String, dynamic> createResult = await _odooService.createRecord(
        credentials,
        'x_haulage_log', // Replace with your actual Odoo model name (e.g., 'x_haulage_log', 'haulage.log')
        odooData,
      );

      // 3. Update local log with Odoo's remote ID and sync status
      int newOdooId = createResult['id'] as int;
      log.remoteId = newOdooId;
      log.synced = true;
      //await _localDBService.saveHaulageLog(log);

      print(
        'Successfully synced log ${log.transactionId} to Odoo. New Odoo ID: $newOdooId',
      );
    } catch (e) {
      print('Error syncing single log ${log.transactionId}: $e');
      rethrow; // Re-throw to propagate the error up to the UI/caller
    }
  }
}
