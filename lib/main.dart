import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_haulage_logger/screens/login_screen.dart';
import 'services/sync_service.dart';
import 'models/user_credentials.dart';

void main() {
  runApp(HaulageLogApp());
}

class HaulageLogApp extends StatefulWidget {
  @override
  _HaulageLogAppState createState() => _HaulageLogAppState();
}

class _HaulageLogAppState extends State<HaulageLogApp> {
  final SyncService _syncService = SyncService();
  final Connectivity _connectivity = Connectivity();

  // Hardcoded credentials for now (you can replace this with login screen later)
  final UserCredentials credentials = UserCredentials(
    userId: 2,
    password: 'your_password',
  );

  @override
  void initState() {
    super.initState();
    _connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) async {
      if (result != ConnectivityResult.none) {
        await _syncService.syncUnsyncedLogs(credentials);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haulage Log System',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}
