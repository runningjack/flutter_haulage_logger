// lib/screens/haulage_log_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_haulage_logger/models/driver.dart';
import 'package:flutter_haulage_logger/models/project.dart';
import 'package:flutter_haulage_logger/models/vehicle.dart';
import '../models/haulage_log.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart'; // If you're syncing right after saving
import '../models/user_credentials.dart'; // If you need credentials here for sync

class HaulageLogEntryScreen extends StatefulWidget {
  final HaulageLog? logToEdit; // Optional parameter for editing

  const HaulageLogEntryScreen({super.key, this.logToEdit});

  @override
  State<HaulageLogEntryScreen> createState() => _HaulageLogEntryScreenState();
}

class _HaulageLogEntryScreenState extends State<HaulageLogEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for your form fields
  late TextEditingController _transactionIdController;
  late TextEditingController
  _shiftIdController; // Example, if using TextEditingController
  late TextEditingController _vehicleController;
  late TextEditingController _driverController;
  late TextEditingController _projectController;
  late TextEditingController _loadingSiteController;
  late TextEditingController _cycleController;
  late TextEditingController _cycleStartTimeController;
  late TextEditingController _cycleStartOdometerController;
  late TextEditingController _loadingTonnageController;
  late TextEditingController _dumpingSiteController;
  late TextEditingController _arrivalTimeController;
  late TextEditingController _arrivalOdometerController;
  late TextEditingController _dumpingTimeController;
  late TextEditingController _dumpingTonnageController;
  late TextEditingController _departureTimeController;
  late TextEditingController _cycleEndOdometerController;
  late TextEditingController _cycleEndTimeController;

  // For simplicity, let's assume direct mapping for dropdown values if applicable
  String? _selectedShift;
  String? _selectedVehicleId; // To store the ID from master data
  String? _selectedDriverId;
  String? _selectedProjectId;

  List<Vehicle> _vehicles = [];
  List<Driver> _drivers = [];
  List<Project> _projects = [];

  final LocalDBService _localDbService = LocalDBService.instance;
  final SyncService _syncService =
      SyncService.instance; // For optional sync after save

  @override
  void initState() {
    super.initState();
    _transactionIdController = TextEditingController();
    _shiftIdController = TextEditingController(); // Or use a dropdown for shift
    _vehicleController =
        TextEditingController(); // Or use a dropdown for vehicle
    _driverController = TextEditingController();
    _projectController = TextEditingController();
    _loadingSiteController = TextEditingController();
    _cycleController = TextEditingController();
    _cycleStartTimeController = TextEditingController();
    _cycleStartOdometerController = TextEditingController();
    _loadingTonnageController = TextEditingController();
    _dumpingSiteController = TextEditingController();
    _arrivalTimeController = TextEditingController();
    _arrivalOdometerController = TextEditingController();
    _dumpingTimeController = TextEditingController();
    _dumpingTonnageController = TextEditingController();
    _departureTimeController = TextEditingController();
    _cycleEndOdometerController = TextEditingController();
    _cycleEndTimeController = TextEditingController();

    _loadMasterData();

    // If editing an existing log, pre-populate fields
    if (widget.logToEdit != null) {
      _transactionIdController.text = widget.logToEdit!.transactionId;
      _selectedShift = widget.logToEdit!.shiftId; // Use if shift is a dropdown
      // For ID-based fields, you'd set the _selected...Id
      _selectedVehicleId =
          widget.logToEdit!.vehicle; // Assuming vehicle stores the ID string
      _selectedDriverId = widget.logToEdit!.driver;
      _selectedProjectId = widget.logToEdit!.project;

      _cycleController.text = widget.logToEdit!.cycle ?? '';
      _cycleStartTimeController.text =
          widget.logToEdit!.cycleStartTime?.toIso8601String() ?? '';
      _cycleStartOdometerController.text =
          widget.logToEdit!.cycleStartOdometer?.toString() ?? '';
      _loadingTonnageController.text =
          widget.logToEdit!.loadingTonnage?.toString() ?? '';
      _arrivalTimeController.text =
          widget.logToEdit!.arrivalTime?.toIso8601String() ?? '';
      _arrivalOdometerController.text =
          widget.logToEdit!.arrivalOdometer?.toString() ?? '';
      _dumpingTimeController.text =
          widget.logToEdit!.dumpingTime?.toIso8601String() ?? '';
      _dumpingTonnageController.text =
          widget.logToEdit!.dumpingTonnage?.toString() ?? '';
      _departureTimeController.text =
          widget.logToEdit!.departureTime?.toIso8601String() ?? '';
      _cycleEndOdometerController.text =
          widget.logToEdit!.cycleEndOdometer?.toString() ?? '';
      _cycleEndTimeController.text =
          widget.logToEdit!.cycleEndTime?.toIso8601String() ?? '';
    }
  }

  Future<void> _loadMasterData() async {
    _vehicles = await _localDbService.getVehicles();
    _drivers = await _localDbService.getDrivers();
    _projects = await _localDbService.getProjects();
    setState(() {}); // Rebuild UI with loaded data
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _shiftIdController.dispose();
    _vehicleController.dispose();
    _driverController.dispose();
    _projectController.dispose();
    _loadingSiteController.dispose();
    _cycleController.dispose();
    _cycleStartTimeController.dispose();
    _cycleStartOdometerController.dispose();
    _loadingTonnageController.dispose();
    _dumpingSiteController.dispose();
    _arrivalTimeController.dispose();
    _arrivalOdometerController.dispose();
    _dumpingTimeController.dispose();
    _dumpingTonnageController.dispose();
    _departureTimeController.dispose();
    _cycleEndOdometerController.dispose();
    _cycleEndTimeController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Determine if it's a new log or an existing one being edited
      HaulageLog log;
      if (widget.logToEdit != null) {
        // Editing existing log
        log = widget.logToEdit!;
        log.transactionId = _transactionIdController.text;
        log.shiftId = _selectedShift;
        log.vehicle = _selectedVehicleId; // Assign ID
        log.driver = _selectedDriverId;
        log.project = _selectedProjectId;
        //log.loadingSite = _selectedLoadingSiteId;
        //log.dumpingSite = _selectedDumpingSiteId;

        log.cycle = _cycleController.text;
        log.cycleStartTime = DateTime.tryParse(_cycleStartTimeController.text);
        log.cycleStartOdometer = double.tryParse(
          _cycleStartOdometerController.text,
        );
        log.loadingTonnage = double.tryParse(_loadingTonnageController.text);
        log.arrivalTime = DateTime.tryParse(_arrivalTimeController.text);
        log.arrivalOdometer = double.tryParse(_arrivalOdometerController.text);
        log.dumpingTime = DateTime.tryParse(_dumpingTimeController.text);
        log.dumpingTonnage = double.tryParse(_dumpingTonnageController.text);
        log.departureTime = DateTime.tryParse(_departureTimeController.text);
        log.cycleEndOdometer = double.tryParse(
          _cycleEndOdometerController.text,
        );
        log.cycleEndTime = DateTime.tryParse(_cycleEndTimeController.text);

        log.synced = false; // Mark as unsynced after edit
      } else {
        // Creating new log
        log = HaulageLog(
          transactionId: _transactionIdController.text,
          shiftId: _selectedShift,
          vehicle: _selectedVehicleId, // Assign ID
          driver: _selectedDriverId,
          project: _selectedProjectId,
          //loadingSite: _selectedLoadingSiteId,
          //dumpingSite: _selectedDumpingSiteId,
          cycle: _cycleController.text,
          cycleStartTime: DateTime.tryParse(_cycleStartTimeController.text),
          cycleStartOdometer: double.tryParse(
            _cycleStartOdometerController.text,
          ),
          loadingTonnage: double.tryParse(_loadingTonnageController.text),
          arrivalTime: DateTime.tryParse(_arrivalTimeController.text),
          arrivalOdometer: double.tryParse(_arrivalOdometerController.text),
          dumpingTime: DateTime.tryParse(_dumpingTimeController.text),
          dumpingTonnage: double.tryParse(_dumpingTonnageController.text),
          departureTime: DateTime.tryParse(_departureTimeController.text),
          cycleEndOdometer: double.tryParse(_cycleEndOdometerController.text),
          cycleEndTime: DateTime.tryParse(_cycleEndTimeController.text),
          synced: false,
        );
      }

      try {
        final int generatedId = await _localDbService.insertLog(log);
        // Only assign if it was a new log, otherwise the ID is already present
        if (widget.logToEdit == null) {
          log.id = generatedId;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log saved locally (ID: ${log.id})!')),
        );

        // Optional: Trigger immediate sync if user is logged in
        // (You'll need a way to get UserCredentials here, e.g., from a login service)
        // final UserCredentials? credentials = await _authService.getCurrentUserCredentials();
        // if (credentials != null) {
        //   _syncService.syncSingleHaulageLog(credentials, log); // Non-blocking sync
        // }

        Navigator.of(
          context,
        ).pop(true); // Indicate success and pop back to list
      } catch (e) {
        print('Error saving log: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save log: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.logToEdit == null ? 'New Haulage Log' : 'Edit Haulage Log',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _transactionIdController,
                decoration: const InputDecoration(labelText: 'Transaction ID'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a transaction ID';
                  }
                  return null;
                },
              ),
              // Example Dropdown for Shift
              DropdownButtonFormField<String>(
                value: _selectedShift,
                decoration: const InputDecoration(labelText: 'Shift'),
                items: ['early', 'late']
                    .map(
                      (shift) =>
                          DropdownMenuItem(value: shift, child: Text(shift)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedShift = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a shift';
                  }
                  return null;
                },
              ),
              // Example Dropdown for Vehicle (using ID for internal value)
              DropdownButtonFormField<String>(
                value: _selectedVehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: _vehicles
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id.toString(), // Use ID as value
                        child: Text(vehicle.name as String), // Display name
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicleId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a vehicle';
                  }
                  return null;
                },
              ),
              // ... Add similar DropdownButtonFormField for Driver, Project, LoadingSite, DumpingSite
              // ... Add TextFormField for other log fields (cycle, odometer, tonnage, times)
              // Ensure they have controllers and validators
              TextFormField(
                controller: _cycleController,
                decoration: const InputDecoration(labelText: 'Cycle'),
                // No validator if optional
              ),
              TextFormField(
                controller: _cycleStartTimeController,
                decoration: const InputDecoration(
                  labelText: 'Cycle Start Time (YYYY-MM-DD HH:MM:SS)',
                ),
                // You might want a date/time picker here
              ),
              TextFormField(
                controller: _cycleStartOdometerController,
                decoration: const InputDecoration(
                  labelText: 'Cycle Start Odometer',
                ),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _loadingTonnageController,
                decoration: const InputDecoration(labelText: 'Loading Tonnage'),
                keyboardType: TextInputType.number,
              ),

              // ... Add remaining fields
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveLog,
                child: Text(
                  widget.logToEdit == null ? 'Save Log' : 'Update Log',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
