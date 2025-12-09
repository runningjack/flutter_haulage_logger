// lib/services/frotcom_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrotcomService {
  static final FrotcomService _instance = FrotcomService._internal();
  factory FrotcomService() => _instance;
  FrotcomService._internal();

  final String _baseUrl = 'https://v2api.frotcom.com/v2';
  final String _username = "5HAqhDWL4wGX3Be"; // Provided Frotcom Username
  final String _password =
      "svs1v9MyTiy5gVgcgSZ7fagOHdgT"; // Provided Frotcom Password

  String? _apiKey;
  DateTime? _apiKeyExpiry; // API key expires after 20 minutes

  // Keys for SharedPreferences
  static const String _apiKeyPrefKey = 'frotcom_api_key';
  static const String _apiKeyExpiryPrefKey = 'frotcom_api_key_expiry';

  /// Authenticates with Frotcom API to obtain an API key.
  /// The key is stored and automatically refreshed if expired.
  Future<String> _authenticate() async {
    print('Attempting to authenticate with Frotcom...');
    final url = Uri.parse('$_baseUrl/authorize');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "provider": "thirdparty",
      "username": _username,
      "password": _password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _apiKey = data['token'] as String?;
        // API key expires in 20 minutes
        _apiKeyExpiry = DateTime.now().add(
          const Duration(minutes: 19),
        ); // Use 19 mins to be safe

        // Persist the API key and expiry time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_apiKeyPrefKey, _apiKey!);
        await prefs.setString(
          _apiKeyExpiryPrefKey,
          _apiKeyExpiry!.toIso8601String(),
        );

        print('Frotcom authentication successful. API Key obtained.');
        return _apiKey!;
      } else {
        print(
          'Frotcom authentication failed. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception(
          'Frotcom authentication failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error during Frotcom authentication: $e');
      throw Exception('Network error during Frotcom authentication: $e');
    }
  }

  /// Ensures a valid API key is available, refreshing it if necessary.
  Future<String> _ensureAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from preferences if not already in memory
    if (_apiKey == null || _apiKeyExpiry == null) {
      _apiKey = prefs.getString(_apiKeyPrefKey);
      final expiryString = prefs.getString(_apiKeyExpiryPrefKey);
      if (expiryString != null) {
        _apiKeyExpiry = DateTime.parse(expiryString);
      }
    }

    // Check if API key is still valid
    if (_apiKey != null &&
        _apiKeyExpiry != null &&
        DateTime.now().isBefore(_apiKeyExpiry!)) {
      print('Using cached Frotcom API key.');
      return _apiKey!;
    } else {
      // API key is missing or expired, re-authenticate
      return await _authenticate();
    }
  }

  /// Fetches the current odometer reading for a specific vehicle.
  /// Returns the odometer in kilometers (double) or null if not found/error.
  // lib/services/frotcom_service.dart

  // ... (other parts of the class)

  Future<double?> getVehicleOdometer(String vehicleLicensePlate) async {
    try {
      final apiKey = await _ensureAuthenticated();
      final url = Uri.parse('$_baseUrl/vehicles?api_key=$apiKey');

      final response = await http.get(url);

      // The /vehicles endpoint should return 200 OK for success
      if (response.statusCode == 200) {
        final List<dynamic> vehiclesData = jsonDecode(response.body);

        // We check all vehicles for a match and the odometer data
        for (var vehicle in vehiclesData) {
          if (vehicle.containsKey('odometerGps') &&
              vehicle['odometerGps'] != null) {
            final frotcomLicensePlate = vehicle['licensePlate']
                ?.toString()
                .toUpperCase();

            // Check if the provided license plate has a dash
            if (vehicleLicensePlate.contains('-')) {
              // Split the provided license plate and match the first part
              List<String> parts = vehicleLicensePlate.split('-');
              if (parts.length > 1) {
                String firstPart = parts[0].toUpperCase();
                if (frotcomLicensePlate?.contains(firstPart) == true) {
                  // Found a match based on the first part of the license plate
                  return (vehicle['odometerGps'] as num).toDouble();
                }
              }
            } else {
              // No dash, perform an exact match
              if (frotcomLicensePlate == vehicleLicensePlate.toUpperCase()) {
                // Found a match based on the full license plate
                return (vehicle['odometerGps'] as num).toDouble();
              }
            }
          }
        }

        // If the loop completes without returning, no match was found
        print(
          'Vehicle "$vehicleLicensePlate" not found in Frotcom data or odometer is missing.',
        );
        return null;
      } else if (response.statusCode == 401) {
        // Token expired or invalid for data request, re-authenticate and retry
        print(
          'Frotcom API key unauthorized, re-authenticating and retrying...',
        );
        _apiKey = null; // Invalidate current key
        _apiKeyExpiry = null;
        await clearApiKey(); // Clear from shared preferences too
        return await getVehicleOdometer(
          vehicleLicensePlate,
        ); // Recursive call to retry
      } else {
        print(
          'Failed to fetch vehicle data from Frotcom. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception(
          'Failed to fetch vehicle data from Frotcom: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching vehicle odometer: $e');
      // Ensure the function returns null on any error in the catch block
      return null;
    }
  }

  /// Clears stored API key (e.g., on logout)
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPrefKey);
    await prefs.remove(_apiKeyExpiryPrefKey);
    _apiKey = null;
    _apiKeyExpiry = null;
    print('Frotcom API key cleared from storage.');
  }
}
