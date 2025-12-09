// lib/screens/dashboard_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_haulage_logger/models/driver.dart';
import 'package:flutter_haulage_logger/models/vehicle.dart';
import 'package:flutter_haulage_logger/screens/dumping_form_screen.dart';
import 'package:flutter_haulage_logger/screens/loading_form_screen.dart';
import 'package:flutter_haulage_logger/services/sync_service.dart';
import '../models/haulage_log.dart';
import '../models/user_credentials.dart';
import '../services/local_db_service.dart';
import '../services/master_data_service.dart';
import 'haulage_log_entry_list_screen.dart';
import 'log_form_screen.dart'; // Ensure this path is correct
// import 'haulage_log_entry_screen.dart'; // Not directly used for navigation in this file's provided code

class DashboardScreen extends StatefulWidget {
  final UserCredentials credentials;

  const DashboardScreen({super.key, required this.credentials});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalDBService _localDBService = LocalDBService.instance;
  final SyncService _syncService = SyncService.instance;
  final Connectivity _connectivity = Connectivity();
  final MasterDataService _masterDataService = MasterDataService();
  List<Vehicle> _vehicles = []; // List to hold vehicles, if needed
  List<Driver> _drivers = []; // List to hold drivers, if needed

  late Future<List<HaulageLog>> _recentLogs;
  bool _isMasterDataSyncing = false; // To show loading for master data sync
  bool _isLogSyncing = false; // NEW: To show loading for manual log sync
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription; // Optional: If you need to explicitly manage the subscription

  @override
  void initState() {
    super.initState();
    _initDashboardData();
    _setupConnectivityListener();
    _loadData(); // Load vehicles and drivers on startup
  }

  // Dispose of resources when the widget is removed
  @override
  void dispose() {
    // _connectivitySubscription?.cancel(); // Uncomment if you use the subscription variable
    super.dispose();
  }

  /// Initializes all necessary data for the dashboard on startup.
  /// This includes master data sync and loading recent logs.
  Future<void> _initDashboardData() async {
    // Set loading state for master data sync
    setState(() {
      _isMasterDataSyncing = true;
    });

    try {
      print('Performing initial master data sync...');
      await _masterDataService.syncMasterData(widget.credentials);
      print('Initial master data sync complete.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master data synced successfully!')),
        );
      }
    } catch (e) {
      print('Initial master data sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync master data: $e')),
        );
      }
    } finally {
      // Always refresh logs and set loading to false
      _refreshRecentLogs(); // Refresh logs after master data is potentially updated

      setState(() {
        _isMasterDataSyncing = false;
      });
    }

    // Trigger deletion of old logs after initial data load/sync
    await _localDBService.deleteOldSyncedLogs();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _localDBService.getVehicles(),
        _localDBService.getDrivers(),
      ]);
      setState(() {
        _vehicles = (results[0] as List).cast<Vehicle>();
        _drivers = (results[1] as List).cast<Driver>();
      });
    } catch (e, st) {
      debugPrint('Error loading data: $e\n$st');
    }
  }

  // Helper to safely look up a vehicle’s plate
  String? _getVehiclePlate(String vehicleId) {
    try {
      return _vehicles
          .firstWhere((v) => v.id == vehicleId)
          .license_plate; // or .licensePlate, depending on your model
    } catch (_) {
      return 'N/A';
    }
  }

  // Helper to safely look up a driver’s name
  String _getDriverName(String driverId) {
    try {
      return _drivers.firstWhere((d) => d.id == driverId).name;
    } catch (_) {
      return 'N/A';
    }
  }

  /// Sets up a listener for network connectivity changes to trigger log sync.
  void _setupConnectivityListener() {
    // Only set up the listener once.
    // _connectivitySubscription = // Optional: assign to variable if you need to cancel later
    _connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) async {
      // If there's no ongoing manual sync and connectivity is regained
      if (result != ConnectivityResult.none && !_isLogSyncing) {
        print('Connectivity regained, attempting to sync unsynced logs...');
        setState(() {
          _isLogSyncing = true; // Set sync state to true for automated sync
        });
        try {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connectivity regained. Syncing offline logs...'),
              ),
            );
          }
          await _syncService.syncUnsyncedLogs(widget.credentials);
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline logs synced successfully!'),
              ),
            );
          }
          _refreshRecentLogs(); // Refresh the log list after a successful sync
        } catch (e) {
          print('Error during connectivity-triggered sync: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to sync offline logs: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLogSyncing = false; // Reset sync state
            });
          }
        }
      }
    });
  }

  /// Manual trigger to sync all pending unsynced logs to the remote server.
  Future<void> _manualSyncLogs() async {
    if (_isLogSyncing)
      return; // Prevent multiple clicks while sync is in progress

    setState(() {
      _isLogSyncing = true; // Set sync state to true
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide any existing snackbars
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attempting to manually sync logs...')),
        );
      }
      await _syncService.syncUnsyncedLogs(widget.credentials);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide previous sync message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All pending logs synced successfully!'),
          ),
        );
      }
      _refreshRecentLogs(); // Refresh the log list after successful sync
      await _localDBService.deleteOldSyncedLogs();
    } catch (e) {
      print('Error during manual sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide previous sync message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to manually sync logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLogSyncing = false; // Reset sync state
        });
      }
    }
  }

  /// Fetches and updates the list of recent haulage logs.
  void _refreshRecentLogs() {
    setState(() {
      _recentLogs = _localDBService.getRecentLogs(
        limit: 10,
      ); // Use getRecentHaulageLogs
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isMasterDataSyncing
                ? null
                : _initDashboardData, // Disable if master data is syncing
            tooltip: 'Refresh All Data (Master Data & Logs)',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Haulage Logger',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: ${widget.credentials.uid}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    'Username: ${widget.credentials.username}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            /*ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Haulage Log'),
              onTap: () async {
                Navigator.pop(context); // Close the drawer
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LogFormScreen(credentials: widget.credentials),
                  ),
                );
                if (result == true) {
                  _refreshRecentLogs(); // Refresh logs if a new one was added
                }
              },
            ),*/
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('View All Logs'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const HaulageLogEntryListScreen(), // Navigate to dedicated list screen
                  ),
                ).then((_) async {
                  // Refresh logs when returning from the full list screen
                  _refreshRecentLogs();
                  await _localDBService.deleteOldSyncedLogs();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Loading Entry'),
              onTap: () async {
                Navigator.pop(context); // Close the drawer
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LoadingForm(credentials: widget.credentials),
                  ),
                );
                if (result == true) {
                  _refreshRecentLogs(); // Refresh logs if a new one was added
                }
              },
            ),

            /* ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Dumping Entry'),
              onTap: () async {
                Navigator.pop(context); // Close the drawer
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DumpingFormScreen(credentials: widget.credentials),
                  ),
                );
                if (result == true) {
                  _refreshRecentLogs(); // Refresh logs if a new one was added
                }
              },
            ),*/
            const Divider(), // Separator
            // NEW: Manual Sync Logs Button
            ListTile(
              leading: _isLogSyncing
                  ? const SizedBox(
                      // Use SizedBox with CircularProgressIndicator for consistent sizing
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: Text(
                _isLogSyncing ? 'Syncing Logs...' : 'Sync Pending Logs',
              ),
              onTap: _isLogSyncing
                  ? null
                  : () async {
                      // Disable button while syncing
                      Navigator.pop(context); // Close the drawer
                      await _manualSyncLogs();
                    },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // Implement proper logout logic here (e.g., clear credentials from storage)
                Navigator.pushReplacementNamed(
                  context,
                  '/login',
                ); // Go back to login screen
              },
            ),
          ],
        ),
      ),
      body: _isMasterDataSyncing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing master data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Recent Haulage Logs Section ---
                  const Text(
                    'Recent Haulage Logs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<HaulageLog>>(
                    future: _recentLogs,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text('Error loading logs: ${snapshot.error}'),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No haulage logs found. Start by adding a new one!',
                            ),
                          ),
                        );
                      } else {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final log = snapshot.data![index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(
                                  'Transaction ID: ${log.transactionId}',
                                ),
                                subtitle: Text(
                                  'Vehicle: ${_getVehiclePlate(log.vehicle ?? 'N/A')}\n'
                                  'Driver:  ${_getDriverName(log.driver ?? 'N/A')}\n'
                                  'Tonnage: ${log.loadingTonnage ?? 'N/A'}\n'
                                  'Synced:  ${log.synced ? 'Yes' : 'No'} '
                                  '(Remote ID: ${log.remoteId ?? 'N/A'})',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  print('Tapped on log: ${log.transactionId}');
                                  // Optional: Navigate to a detailed view or edit screen of the log
                                },
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
