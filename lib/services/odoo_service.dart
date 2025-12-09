import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_credentials.dart';

class OdooService {
  
  static const String _odooUrl = 'https://mayfairtradingsl.com/jsonrpc';
  static const String _db = 'Mayfair_Trading'; // database name

  OdooService._privateConstructor();
  static final OdooService _instance = OdooService._privateConstructor();
  static OdooService get instance => _instance;

  // This method creates a new record in Odoo
  // 'model' is the Odoo model name (e.g., 'fleet.vehicle')
  Future<Map<String, dynamic>> createRecord(
    UserCredentials credentials,
    String model,
    Map<String, dynamic> recordData, // The data of the log to create
  ) async {
    try {
      print('--- Odoo CREATE Call Debug Info ---');
      print('  Model: $model');
      print('  User UID: ${credentials.uid}');
      print('  Record Data to Create: $recordData'); // Log the data being sent
      print('  Target URL: $_odooUrl');
      print('  Database: $_db');

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
            'create', // This is the Odoo API method for creating records
            [recordData], // Odoo 'create' expects a list of dictionaries, even for a single record
          ],
        },
        'id': 1,
      });

      print('  Full CREATE Request Body: $requestBody');

      final response = await http.post(
        Uri.parse(_odooUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 45)); // Increased timeout for create/write operations

      print('--- Odoo CREATE Response Debug Info ---');
      print('  Model: $model');
      print('  HTTP Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}'); // THIS IS THE MOST IMPORTANT LINE FOR YOUR ERROR

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body.containsKey('result') && body['result'] != null) {
          // Odoo 'create' usually returns the ID of the newly created record
          print('  Successfully created record. New Odoo ID: ${body['result']}');
          return {'id': body['result']}; // Return the new Odoo ID
        } else if (body.containsKey('error')) {
          final error = body['error'];
          print('  Odoo RPC Error during CREATE for $model:');
          print('    Code: ${error['code']}');
          print('    Message: ${error['message']}');
          print('    Data: ${error['data']}');
          throw Exception('Odoo RPC Error during CREATE: ${error['message'] ?? 'Unknown Odoo error'}. Details: ${error['data']['message'] ?? ''}');
        } else {
          print('  Unexpected successful response format for Odoo CREATE for $model.');
          throw Exception('Unexpected Odoo response format for CREATE: Missing "result" or "error".');
        }
        
      } else {
        String errorMessage = 'Failed to create record for $model.';
        if (response.statusCode != 200) {
          errorMessage += ' HTTP Status: ${response.statusCode}.';
        }
        if (response.body.isEmpty) {
          errorMessage += ' Response body was empty. This caused FormatException.';
        }
        print('  Error details: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stacktrace) {
      print('--- Error during Odoo CREATE API Call for $model ---');
      print('  Exception: $e');
      print('  Stacktrace: $stacktrace');
      rethrow;
    } finally {
      print('--- End Odoo CREATE Call Debug Info for $model ---');
    }
  }

  // This method fetches data from Odoo, typically used for reading records
  Future<List<Map<String, dynamic>>> fetchMasterData( 
    UserCredentials credentials,
    String model,
    List<String> fields, // Made fields required as they are crucial for what to fetch
    {List<dynamic>? domain}) async { // Domain is optional
    try {
      print('--- Odoo API Call Debug Info ---');
      print('  Calling Model: $model');
      print('  Method: search_read');
      print('  Target URL: $_odooUrl');
      print('  Database: $_db');
      print('  User UID: ${credentials.uid}');
      // For sensitive debugging, you might log part of the password:
      // print('  Password (partial): ${credentials.password.substring(0, 3)}...');
      print('  Requested Fields: ${fields.join(', ')}');
      print('  Search Domain: ${domain ?? []}');

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
            {'fields': fields}
          ],
        },
        'id': 1,
      });

      print('  Full Request Body: $requestBody');

      final response = await http.post(
        Uri.parse(_odooUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      print('--- Odoo API Response Debug Info ---');
      print('  Model: $model');
      print('  HTTP Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body.containsKey('result') && body['result'] is List) {
          print('  Successfully received ${body['result'].length} records for $model.');
          return List<Map<String, dynamic>>.from(body['result']);
        } else if (body.containsKey('error')) {
          final error = body['error'];
          print('  Odoo RPC Error for $model:');
          print('    Code: ${error['code']}');
          print('    Message: ${error['message']}');
          print('    Data: ${error['data']}');
          throw Exception('Odoo RPC Error: ${error['message'] ?? 'Unknown Odoo error'}. Details: ${error['data']['message'] ?? ''}');
        } else {
          print('  Unexpected successful response format for $model.');
          throw Exception('Unexpected Odoo response format for $model: Missing "result" or "error".');
        }
      } else {
        String errorMessage = 'Failed to fetch $model data.';
        if (response.statusCode != 200) {
          errorMessage += ' HTTP Status: ${response.statusCode}.';
        }
        if (response.body.isEmpty) {
          errorMessage += ' Response body was empty.';
        }
        print('  Error details: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stacktrace) {
      print('--- Error during Odoo API Call for $model ---');
      print('  Exception: $e');
      print('  Stacktrace: $stacktrace');
      rethrow;
    } finally {
      print('--- End Odoo API Call Debug Info for $model ---');
    }
  }

  
}