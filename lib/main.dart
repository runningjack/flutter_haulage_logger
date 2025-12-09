import 'package:flutter/material.dart';
import 'package:flutter_haulage_logger/screens/login_screen.dart';
// No direct import of SyncService or UserCredentials here anymore for hardcoded usage
// These will be used within LoginScreen and DashboardScreen after login.

void main() {
  runApp(
    const HaulageLogApp(),
  ); // Add const for StatelessWidget/StatelessWidget
}

class HaulageLogApp extends StatelessWidget {
  // Changed to StatelessWidget
  const HaulageLogApp({super.key}); // Added const constructor and key

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haulage Log System',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(), // Start with the LoginScreen
    );
  }
}
