// lib/screens/haulage_log_entry_list_screen.dart

import 'package:flutter/material.dart';
import '../models/driver.dart';
import '../models/haulage_log.dart';
import '../models/vehicle.dart';
import '../services/local_db_service.dart';
import 'haulage_log_entry_screen.dart'; // Assuming your log entry/edit screen
// You might need to import your UserCredentials if you pass them down for sync on edit

class HaulageLogEntryListScreen extends StatefulWidget {
  const HaulageLogEntryListScreen({super.key});

  @override
  State<HaulageLogEntryListScreen> createState() =>
      _HaulageLogEntryListScreenState();
}

class _HaulageLogEntryListScreenState extends State<HaulageLogEntryListScreen> {
  late Future<List<HaulageLog>> _allLogsFuture;
  List<Vehicle> _vehicles = []; // List to hold vehicles, if needed
  List<Driver> _drivers = []; // List to hold drivers, if needed
  final LocalDBService _localDBService = LocalDBService.instance;

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
    _loadData(); // Load vehicles and drivers
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

  // Fetches all logs from the local database
  void _fetchAllLogs() {
    setState(() {
      //_allLogsFuture = LocalDBService.instance.getAllLogs(syncedStatus: null); // Get all logs, regardless of sync status
      _allLogsFuture = LocalDBService.instance
          .getAllLogs(); // Get all logs, regardless of sync status
    });
  }

  // Function to handle deleting a log (copied from Dashboard/HaulageLogListScreen for consistency)
  Future<void> _deleteLog(int id) async {
    final bool confirmDelete =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
              'Are you sure you want to delete this log? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmDelete) {
      try {
        await LocalDBService.instance.deleteLog(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log deleted successfully!')),
          );
        }
        _fetchAllLogs(); // Refresh the list
      } catch (e) {
        print('Error deleting log: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete log: $e')));
        }
      }
    }
  }

  // Function to handle editing a log (copied from Dashboard/HaulageLogListScreen for consistency)
  void _editLog(HaulageLog log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            HaulageLogEntryScreen(logToEdit: log), // Pass the log to edit
      ),
    );

    // If the edit screen indicates a change (e.g., by returning true)
    if (result == true) {
      _fetchAllLogs(); // Refresh the list after editing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log updated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Haulage Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllLogs,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: FutureBuilder<List<HaulageLog>>(
        future: _allLogsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No haulage logs found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final log = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction ID: ${log.transactionId}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Vehicle: ${_vehicles.firstWhere((v) => v.id == log.vehicle).license_plate ?? 'N/A'}',
                        ),
                        Text(
                          'Driver: ${_drivers.firstWhere((v) => v.id == log.driver).name ?? 'N/A'}',
                        ),
                        Text('Project: ${log.project ?? 'N/A'}'),
                        Text('Synced: ${log.synced ? 'Yes' : 'No'}'),
                        if (log.remoteId != null)
                          Text('Odoo ID: ${log.remoteId}'),

                        // Add more log details here as needed
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editLog(log),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteLog(log.id!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
