// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_credentials.dart';

class AuthService {
  // Odoo XML-RPC login URL
  static const String _odooLoginUrl = 'https://mayfairtradingsl.com/jsonrpc';
  static const String _db = 'Mayfair_Trading'; // Your Odoo database name

  Future<UserCredentials?> login(String username, String password) async {
    try {
      // --- DEBUGGING PRINTS START ---
      final requestBody = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'common',
          'method':
              'login', // <--- FIX IS HERE: Changed from 'login' to 'authenticate'
          'args': [_db, username, password],
        },
        'id': 1,
      });
      print('Sending Odoo login request to: $_odooLoginUrl');
      print('Request Headers: {\'Content-Type\': \'application/json\'}');
      print('Request Body: $requestBody');
      // --- DEBUGGING PRINTS END ---

      final response = await http
          .post(
            Uri.parse(_odooLoginUrl),
            headers: {'Content-Type': 'application/json'},
            body:
                requestBody, // Use the pre-encoded body for logging consistency
          )
          .timeout(const Duration(seconds: 30)); // Added timeout for robustness

      // --- DEBUGGING PRINTS START ---
      print('HTTP Status Code: ${response.statusCode}');
      print('Raw Response Body Length: ${response.body.length}');
      print('Raw Response Body: "${response.body}"'); // Print the raw string
      // --- DEBUGGING PRINTS END ---

      // Only attempt to decode if the body is not empty and status is 200
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body.containsKey('result') && body['result'] != null) {
          // Odoo login successful, 'result' contains the UID
          // Note: Odoo's 'authenticate' method typically returns the UID directly as the result
          final int uid = body['result'];
          print('Login successful for user: $username, UID: $uid');
          return UserCredentials(
            username: username,
            password: password,
            uid: uid,
          );
        } else if (body.containsKey('error')) {
          print('Odoo login error: ${body['error']}');
          // You might want to extract more detailed error info from body['error']['message'] or body['error']['data']
          return null;
        } else {
          print('Unexpected Odoo login response structure: ${response.body}');
          return null;
        }
      } else {
        // Handle non-200 status codes or empty body
        print(
          'HTTP Error: Status Code ${response.statusCode}, Body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Network or parsing error during login: $e');
      return null;
    }
  }
}
