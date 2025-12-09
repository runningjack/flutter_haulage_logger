import 'package:flutter/material.dart';
import '../models/user_credentials.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../models/haulage_log.dart';
import '../models/vehicle.dart'; // Import new models
import '../models/driver.dart';
import '../models/project.dart';

class LogFormScreen extends StatefulWidget {
  final UserCredentials credentials;
  LogFormScreen({super.key, required this.credentials});

  @override
  _LogFormScreenState createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final SyncService _syncService = SyncService.instance;
  final LocalDBService _dbService =
      LocalDBService.instance; // Corrected: Use the singleton instance

  // Controllers for fields that remain text input
  final Map<String, TextEditingController> _controllers = {
    'transactionId': TextEditingController(),
    'loadingSite':
        TextEditingController(), // Still text input, or will this also be a dropdown?
    'cycleStartTime': TextEditingController(),
    'cycleStartOdometer': TextEditingController(),
    'loadingTonnage': TextEditingController(),
    'dumpingSite': TextEditingController(),
    'arrivalTime': TextEditingController(),
    'arrivalOdometer': TextEditingController(),
    'dumpingTime': TextEditingController(),
    'dumpingTonnage': TextEditingController(),
    'departureTime': TextEditingController(),
    'cycleEndOdometer': TextEditingController(),
    'cycleEndTime': TextEditingController(),
  };

  // Variables to hold selected dropdown values (names, as these are user-facing)
  String? _selectedShift;
  String? _selectedCycle;
  String? _selectedVehicleName; // Holds the selected vehicle's name
  String? _selectedDriverName; // Holds the selected driver's name
  String? _selectedProjectName; // Holds the selected project's name

  // Lists to populate the dropdowns
  List<Vehicle> _vehicles = [];
  List<Driver> _drivers = [];
  List<Project> _projects = [];

  bool _isSaving = false;
  bool _isLoadingDropdowns = false; // New loading state for dropdown data

  final List<DropdownMenuItem<String>> _shiftOptions = const [
    DropdownMenuItem(value: 'early', child: Text('Early')),
    DropdownMenuItem(value: 'late', child: Text('Late')),
    DropdownMenuItem(value: 'night', child: Text('Night')),
  ];

  final List<DropdownMenuItem<String>> _cycleOptions = const [
    DropdownMenuItem(value: 'first', child: Text('First Cycle')),
    DropdownMenuItem(value: 'second', child: Text('Second Cycle')),
    DropdownMenuItem(value: 'third', child: Text('Third Cycle')),
    DropdownMenuItem(value: 'fourth', child: Text('Fourth Cycle')),
  ];

  @override
  void initState() {
    super.initState();
    _loadDropdownData(); // Load data when the screen initializes
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  String _determineCurrentShift() {
    final now = DateTime.now();
    final hour = now.hour;

    // Prioritize Night shift first due to spanning midnight
    if (hour >= 22 || hour < 6) {
      // 22:00 to 05:59
      return 'night';
    }
    // Then Late shift
    else if (hour >= 13 && hour < 22) {
      // 13:00 to 21:59
      return 'late';
    }
    // Finally, Early shift
    else if (hour >= 6 && hour < 13) {
      // 06:00 to 12:59
      return 'early';
    }
    // Fallback, though ideally one of the above should always match
    return 'early'; // Default to early if none match (shouldn't happen with these ranges)
  }

  // New method to load data for dropdowns from local DB
  Future<void> _loadDropdownData() async {
    setState(() {
      _isLoadingDropdowns = true;
    });
    try {
      _selectedShift = _determineCurrentShift();
      _vehicles = await _dbService.getVehicles();
      _drivers = await _dbService.getDrivers();
      _projects = await _dbService.getProjects();
    } catch (e) {
      print('Error loading dropdown data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dropdown data: $e')),
      );
    } finally {
      setState(() {
        _isLoadingDropdowns = false;
      });
    }
  }

  Future<DateTime?> _showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _selectDateTime(String field) async {
    final dateTime = await _showDateTimePicker(context);
    if (dateTime != null) {
      _controllers[field]!.text = dateTime.toIso8601String();
    }
  }

  void _triggerManualSync() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Syncing unsynced logs...')));
    try {
      await _syncService.syncUnsyncedLogs(widget.credentials);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync complete.')));
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final transactionId = _controllers['transactionId']!.text.trim();

    try {
      final exists = await _dbService.transactionIdExists(transactionId);
      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: A log with this Transaction ID already exists.',
            ),
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final HaulageLog log = HaulageLog(
        transactionId: transactionId,
        shiftId: _selectedShift!,
        vehicle: _selectedVehicleName!, // Use selected name
        driver: _selectedDriverName!, // Use selected name
        project: _selectedProjectName!, // Use selected name
        loadingSite: _controllers['loadingSite']!.text,
        cycle: _selectedCycle ?? '',
        cycleStartTime: DateTime.tryParse(_controllers['cycleStartTime']!.text),
        cycleStartOdometer: double.tryParse(
          _controllers['cycleStartOdometer']!.text,
        ),
        loadingTonnage: double.tryParse(_controllers['loadingTonnage']!.text),

        dumpingSite: _controllers['dumpingSite']!.text.isNotEmpty
            ? _controllers['dumpingSite']!.text
            : null,
        arrivalTime: _controllers['arrivalTime']!.text.isNotEmpty
            ? DateTime.tryParse(_controllers['arrivalTime']!.text)
            : null,
        arrivalOdometer: _controllers['arrivalOdometer']!.text.isNotEmpty
            ? double.tryParse(_controllers['arrivalOdometer']!.text)
            : null,
        dumpingTime: _controllers['dumpingTime']!.text.isNotEmpty
            ? DateTime.tryParse(_controllers['dumpingTime']!.text)
            : null,
        dumpingTonnage: _controllers['dumpingTonnage']!.text.isNotEmpty
            ? double.tryParse(_controllers['dumpingTonnage']!.text)
            : null,
        departureTime: _controllers['departureTime']!.text.isNotEmpty
            ? DateTime.tryParse(_controllers['departureTime']!.text)
            : null,
        cycleEndOdometer: _controllers['cycleEndOdometer']!.text.isNotEmpty
            ? double.tryParse(_controllers['cycleEndOdometer']!.text)
            : null,
        cycleEndTime: _controllers['cycleEndTime']!.text.isNotEmpty
            ? DateTime.tryParse(_controllers['cycleEndTime']!.text)
            : null,
        synced: false,
      );

      if (log.cycleStartTime == null ||
          log.cycleStartOdometer == null ||
          log.loadingTonnage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Please ensure required loading date/time and number fields are valid.',
            ),
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final int recordId = await _dbService.insertLog(log);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log saved locally. Attempting to sync...'),
        ),
      );
      log.id = recordId; // Set the local ID after saving

      await _syncService.syncLog(log, widget.credentials);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log saved and synced successfully!')),
      );

      _controllers.values.forEach((c) => c.clear());
      setState(() {
        _selectedShift = null;
        _selectedCycle = null;
        _selectedVehicleName = null; // Clear selections
        _selectedDriverName = null;
        _selectedProjectName = null;
        _isSaving = false;
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving or syncing log: $e')),
      );
      print('Error saving/syncing log: $e');
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildTextField(
    String key,
    String label, {
    bool isNumber = false,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: isNumber
            ? TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) {
            return 'Required';
          }
          if (isNumber && val != null && val.isNotEmpty) {
            if (double.tryParse(val) == null) {
              return 'Please enter a valid number';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateTimeField(
    String key,
    String label, {
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: true,
        onTap: () => _selectDateTime(key),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? selectedValue,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool isRequired = true,
    bool isLoading = false, // Add loading indicator for dropdowns
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: selectedValue,
        items: isLoading
            ? [const DropdownMenuItem(value: null, child: Text('Loading...'))]
            : items,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: isLoading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : null,
        ),
        onChanged: isLoading ? null : onChanged, // Disable when loading
        validator: (val) => isRequired && val == null ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Haulage Log Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isSaving ? null : _triggerManualSync,
            tooltip: 'Sync Unsynced Logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Loading Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildTextField('transactionId', 'Transaction ID'),
              _buildDropdown<String>(
                label: 'Shift',
                selectedValue: _selectedShift,
                items: _shiftOptions,
                onChanged: (val) => setState(() => _selectedShift = val),
              ),
              // New Dropdowns for Vehicle, Driver, Project
              _buildDropdown<String>(
                label: 'Vehicle',
                selectedValue: _selectedVehicleName,
                items: _vehicles.map<DropdownMenuItem<String>>((v) {
                  return DropdownMenuItem<String>(
                    value: v.name,
                    child: Text(v.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedVehicleName = val),
                isLoading: _isLoadingDropdowns,
              ),
              _buildDropdown<String>(
                label: 'Driver',
                selectedValue: _selectedDriverName,
                items: _drivers.map<DropdownMenuItem<String>>((d) {
                  return DropdownMenuItem<String>(
                    value: d.name,
                    child: Text(d.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDriverName = val),
                isLoading: _isLoadingDropdowns,
              ),
              _buildDropdown<String>(
                label: 'Project',
                selectedValue: _selectedProjectName,
                items: _projects.map<DropdownMenuItem<String>>((p) {
                  return DropdownMenuItem<String>(
                    value: p.name,
                    child: Text(p.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedProjectName = val),
                isLoading: _isLoadingDropdowns,
              ),

              _buildTextField('loadingSite', 'Loading Site'),
              _buildDropdown<String>(
                label: 'Cycle',
                selectedValue: _selectedCycle,
                items: _cycleOptions,
                onChanged: (val) => setState(() => _selectedCycle = val),
              ),
              _buildDateTimeField('cycleStartTime', 'Cycle Start Time'),
              _buildTextField(
                'cycleStartOdometer',
                'Cycle Start Odometer',
                isNumber: true,
              ),
              _buildTextField(
                'loadingTonnage',
                'Loading Tonnage',
                isNumber: true,
              ),

              const SizedBox(height: 20),
              const Text(
                'Dumping Information (Optional)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _buildTextField('dumpingSite', 'Dumping Site', isRequired: false),
              _buildDateTimeField(
                'arrivalTime',
                'Arrival Time',
                isRequired: false,
              ),
              _buildTextField(
                'arrivalOdometer',
                'Arrival Odometer',
                isNumber: true,
                isRequired: false,
              ),
              _buildDateTimeField(
                'dumpingTime',
                'Dumping Time',
                isRequired: false,
              ),
              _buildTextField(
                'dumpingTonnage',
                'Dumping Tonnage',
                isNumber: true,
                isRequired: false,
              ),
              _buildDateTimeField(
                'departureTime',
                'Departure Time',
                isRequired: false,
              ),
              _buildTextField(
                'cycleEndOdometer',
                'Cycle End Odometer',
                isNumber: true,
                isRequired: false,
              ),
              _buildDateTimeField(
                'cycleEndTime',
                'Cycle End Time',
                isRequired: false,
              ),

              const SizedBox(height: 20),
              _isSaving || _isLoadingDropdowns
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveLog,
                      child: const Text('Submit Haulage Log'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
