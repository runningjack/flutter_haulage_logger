// lib/services/master_data_service.dart

import 'dart:convert';
import 'package:flutter_haulage_logger/models/driver.dart';
import 'package:flutter_haulage_logger/models/project.dart';
import 'package:flutter_haulage_logger/models/vehicle.dart';
import 'package:http/http.dart' as http;
import '../models/user_credentials.dart';
import '../services/local_db_service.dart'; // Assuming you have a local database service

class MasterDataService {
  static final MasterDataService _instance =
      MasterDataService._privateConstructor();
  factory MasterDataService() => _instance;
  MasterDataService._privateConstructor();

  static const String _odooUrl = 'https://mayfairtradingsl.com/jsonrpc';
  static const String _db = 'Mayfair_Trading'; // database name

  final LocalDBService _localDbService =
      LocalDBService.instance; // Instance of your local DB service

  // Define the missing method
  Future<void> syncMasterData(UserCredentials credentials) async {
    try {
      print('Starting master data sync...');

      // --- Example: Fetching Trucks ---
      // Replace 'fleet.vehicle' with your actual Odoo model for trucks/vehicles
      // And specify the fields you need (e.g., 'name', 'license_plate')
      final List<Map<String, dynamic>> trucks = await _fetchOdooData(
        'fleet.vehicle',
        credentials,
        fields: ['id', 'name', 'license_plate'],
      ); // Example fields
      // FIX IS HERE: Convert each Map to a Vehicle object
      final List<Vehicle> vehicles = trucks
          .map((map) => Vehicle.fromJson(map))
          .toList();
      // Correct way to filter:
      final List<Vehicle> shacmanVehicles = vehicles
          .where(
            (v) =>
                v.name?.contains("SHACMAN") == true ||
                v.name?.contains("HOWO") == true ||
                v.name?.contains("SINOTRUCK") == true ||
                v.name?.contains("Daewoo") == true,
          ) // Use .where and null-safe access
          .toList(); // Convert the Iterable<Vehicle> to List<Vehicle>
      await _localDbService.saveVehicles(shacmanVehicles);
      print('Synced ${trucks.length} trucks.');

      // --- Example: Fetching Drivers ---
      // Replace 'res.partner' or a custom driver model
      final List<Map<String, dynamic>> drivers = await _fetchOdooData(
        'hr.employee',
        credentials,
        fields: ['id', 'name'],
      );
      final List<Driver> partners = drivers
          .map((map) => Driver.fromJson(map))
          .toList();
      await _localDbService.saveDrivers(partners);
      print('Synced ${drivers.length} drivers.');

      // --- Example: Fetching Projects ---
      // Replace 'project.project' or your actual project model
      final List<Map<String, dynamic>> projects = await _fetchOdooData(
        'project.project',
        credentials,
        fields: ['id', 'name'],
      );

      final List<Project> projs = projects
          .map((map) => Project.fromJson(map))
          .toList();
      await _localDbService.saveProjects(projs);
      print('Synced ${projects.length} projects.');

      print('Master data sync completed successfully.');
    } catch (e) {
      print('Error during master data sync: $e');
      rethrow; // Re-throw to be handled by the UI
    }
  }

  // Modified _fetchOdooData to accept optional domain and fields
  Future<List<Map<String, dynamic>>> _fetchOdooData(
    String model,
    UserCredentials credentials, {
    List<dynamic>? domain,
    List<String>? fields,
  }) async {
    try {
      final requestBody = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'object',
          'method': 'execute_kw',
          'args': [
            _db,
            credentials.uid,
            credentials.password,
            model,
            'search_read',
            domain ?? [],
            // FIX: Default fields should be generic. Specific fields like 'license_plate'
            // should be passed explicitly in the 'fields' argument when calling _fetchOdooData.
            {
              'fields': fields ?? ['id', 'name'],
            },
          ],
        },
        'id': 1,
      });

      print('Odoo Fetch Request for $model:');
      print('  URL: $_odooUrl');
      print('  Body: $requestBody');

      final response = await http
          .post(
            Uri.parse(_odooUrl),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30)); // FIX: Added timeout

      print('Odoo Fetch Response for $model:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body.containsKey('result') && body['result'] is List) {
          // This is the correct return type: List<Map<String, dynamic>>
          return List<Map<String, dynamic>>.from(body['result']);
        } else if (body.containsKey('error')) {
          print('Odoo RPC Error fetching $model: ${body['error']}');
          throw Exception(
            'Odoo RPC Error: ${body['error']['message'] ?? 'Unknown Odoo error'}',
          );
        }
      }
      print(
        'Failed to fetch $model. Status: ${response.statusCode}, Body: ${response.body}',
      );
      throw Exception(
        'Failed to get 200 OK or valid JSON result for $model from Odoo',
      );
    } catch (e, stacktrace) {
      // FIX: Captured stacktrace
      print('Network or parsing error fetching $model from Odoo: $e');
      print(
        'Stacktrace: $stacktrace',
      ); // FIX: Print stacktrace for better debugging
      rethrow;
    }
  }
}
