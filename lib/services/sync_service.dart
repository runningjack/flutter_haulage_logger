
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/haulage_log.dart';
import '../models/user_credentials.dart';
import 'local_db_service.dart';

class SyncService {
  static const String odooUrl = 'https://mayfairtradingsl.com/jsonrpc';
  static const String db = 'Mayfair_Trading';
  static const int uid = 6; // replace with actual user ID
  static const String password = '12345';

  Future<void> syncUnsyncedLogs(UserCredentials credentials) async {
    final List<HaulageLog> unsyncedLogs = await LocalDBService().getUnsyncedLogs();

    for (var log in unsyncedLogs) {
      final success = await _sendToOdoo(log);
      if (success) {
        await LocalDBService().markLogAsSynced(log.id!);
      }
    }
  }

  Future<bool> _sendToOdoo(HaulageLog log) async {
    try {
      final response = await http.post(
        Uri.parse(odooUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'service': 'object',
            'method': 'execute_kw',
            'args': [
              db,
              uid,
              password,
              'haulage_log_entry',
              'create',
              [log.toMap()]
            ]
          },
          'id': 1
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return body.containsKey('result');
      }
    } catch (e) {
      print('Sync error: $e');
    }
    return false;
  }
}