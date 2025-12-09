import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driver.dart';
import '../models/haulage_log.dart'; // Ensure HaulageLog model has nullable fields for remaining parts
import '../models/project.dart';
import '../models/user_credentials.dart';
import '../models/vehicle.dart';
import '../services/frotcom_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

// Extension to capitalize the first letter of a string
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class LoadingForm extends StatefulWidget {
  final UserCredentials credentials;

  final HaulageLog?
  initialLog; // Changed to allow passing it, but logic assumes new log for defaults

  const LoadingForm({super.key, required this.credentials, this.initialLog});

  @override
  State<LoadingForm> createState() => _LoadingFormState();
}

class _LoadingFormState extends State<LoadingForm> {
  // Store the fetched dropdown data
  List<Vehicle> _vehicles = [];
  List<Driver> _drivers = [];
  List<Project> _projects = [];

  // Selected values for DropdownButtonFormField
  String? _selectedVehicleId;
  String? _selectedDriverId;
  String? _selectedProjectId;
  String? _selectedLoadingSiteId;
  String? _selectedDumpingSiteId;
  String? _selectedShift;
  String? _selectedCycle;

  bool _isLoadingOdometer = false; // New state variable for odometer fetching
  bool _isOnline = false; // New state variable for connectivity


  Vehicle? _selectedVehicle; // Changed from _selectedVehicleId
  Driver? _selectedDriver; // Changed from _selectedDriverId

  // Controllers for text input fields
  final Map<String, TextEditingController> _controllers = {
    'transactionId': TextEditingController(),
    'cycleStartTime': TextEditingController(),
    'cycleStartOdometer': TextEditingController(),
    'loadingTonnage': TextEditingController(),
  };

  final _formKey = GlobalKey<FormState>();
  final LocalDBService _dbService = LocalDBService.instance;
  final SyncService _syncService = SyncService.instance;
  final FrotcomService _frotcomService = FrotcomService();
  final Connectivity _connectivity = Connectivity(); // Instantiate Connectivity
  Stream<ConnectivityResult>? _connectivityStream; // To listen for connectivity changes

  bool _isLoadingDropdowns = true; // State for loading dropdown data
  bool _isSaving = false; // To show loading state during save

  // --- Hardcoded Project ID ---
  // The ID for "HAULAGE PLO TO TRT" is 2
  final String _defaultProjectId = '2'; // Assuming IDs are strings

  @override
  void initState() {
    super.initState();
    _initData(); // Loads dropdown data asynchronously
    _checkConnectivityAndListen();
    // Set default values for NEW logs:
    // This block runs if initialLog is null, which is the case for new entries
    if (widget.initialLog == null) {
      // 1. Set default Shift based on current time
      _selectedShift = _determineCurrentShift();

      // 2. Set default Cycle Start Time to current system date/time
      _controllers['cycleStartTime']!.text = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.now());
    } else {
      // If editing an existing log, pre-fill with its data
      _selectedShift = widget.initialLog!.shiftId;
      _controllers['transactionId']!.text = widget.initialLog!.transactionId;
      _controllers['cycleStartTime']!.text =
          widget.initialLog!.cycleStartTime != null
          ? DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(widget.initialLog!.cycleStartTime!)
          : '';
      _controllers['cycleStartOdometer']!.text =
          widget.initialLog!.cycleStartOdometer?.toString() ?? '';
      _controllers['loadingTonnage']!.text =
          widget.initialLog!.loadingTonnage?.toString() ?? '';

      _selectedVehicleId = widget.initialLog!.vehicle;
      _selectedDriverId = widget.initialLog!.driver;
      _selectedProjectId = widget.initialLog!.project;
      _selectedLoadingSiteId = widget.initialLog!.loadingSite;
      _selectedDumpingSiteId = widget.initialLog!.dumpingSite;
      _selectedCycle = widget.initialLog!.cycle;
    }
  }

  Future<void> _initData() async {
    await _loadDropdownDataFromLocalDB();
  }

  Future<void> _loadDropdownDataFromLocalDB() async {
    setState(() {
      _isLoadingDropdowns = true;
    });
    try {
      _vehicles = await _dbService.getVehicles();
      _drivers = await _dbService.getDrivers();
      _projects = await _dbService.getProjects();

      print(
        'Dropdown data loaded from local DB. Vehicles: ${_vehicles.length}, Drivers: ${_drivers.length}, Projects: ${_projects.length}',
      );
    } catch (e) {
      print('Error loading dropdown data from local DB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load local data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
        });
      }
    }
  }

  // NEW: Function to set initial selected Vehicle and Driver objects
  void _setInitialSelectedObjects() {
    if (widget.initialLog != null) {
      if (widget.initialLog!.vehicle != null) {
        _selectedVehicle = _vehicles.firstWhere(
          (v) => v.id.toString() == widget.initialLog!.vehicle,
          orElse: () => Vehicle(id: 0, name: 'Unknown'), // Fallback
        );
      }
      if (widget.initialLog!.driver != null) {
        _selectedDriver = _drivers.firstWhere(
          (d) => d.id.toString() == widget.initialLog!.driver,
          orElse: () => Driver(id: 0, name: 'Unknown'), // Fallback
        );
      }
      // Set the fixed project display name
      _controllers['projectDisplay']!.text = _projects
          .firstWhere(
            (p) => p.id.toString() == _defaultProjectId,
            orElse: () => Project(id: 0, name: 'Unknown Project'),
          )
          .name;
    } else {
      // For new logs, set the fixed project display name
      _controllers['projectDisplay']!.text = _projects
          .firstWhere(
            (p) => p.id.toString() == _defaultProjectId,
            orElse: () => Project(id: 0, name: 'Unknown Project'),
          )
          .name;
    }
    setState(() {}); // Trigger rebuild to reflect selected objects/display text
  }

  // --- Dropdown Options Lists ---
  // Using List<String> for consistency with _buildDropdown helper
  final List<String> shiftOptions = ['early', 'late', 'night'];
  final List<String> cycleOptions = ['first', 'second', 'third', 'fourth'];

  // Helper method to determine the current shift (Freetown local time implied)
  String _determineCurrentShift() {
    final now = DateTime.now(); // This will be the device's current time
    final hour = now.hour;

    // Prioritize Night shift first due to spanning midnight
    if (hour >= 22 || hour < 6) {
      // 22:00 (10 PM) to 05:59 (5:59 AM)
      return 'night';
    }
    // Then Late shift
    else if (hour >= 13 && hour < 22) {
      // 13:00 (1 PM) to 21:59 (9:59 PM)
      return 'late';
    }
    // Finally, Early shift
    else if (hour >= 6 && hour < 13) {
      // 06:00 (6 AM) to 12:59 (12:59 PM)
      return 'early';
    }
    return 'early'; // Fallback, though ideally one of the above should always match
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _saveLoadingLog() async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop if form is not valid
    }

    setState(() {
      _isSaving = true; // Show loading indicator
    });

    final transactionId = _controllers['transactionId']!.text.trim();

    try {
      // Only check for existence if it's a new log
      if (widget.initialLog == null) {
        final exists = await _dbService.transactionIdExists(transactionId);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Transaction ID already exists.'),
              ),
            );
            setState(() {
              _isSaving = false;
            });
          }
          return;
        }
      }

      // Parse numerical and datetime fields safely
      final cycleStartTime = DateTime.tryParse(
        _controllers['cycleStartTime']!.text.replaceAll(' ', 'T'),
      ); // Convert to ISO format
      final cycleStartOdometer = double.tryParse(
        _controllers['cycleStartOdometer']!.text,
      );
      final loadingTonnage = double.tryParse(
        _controllers['loadingTonnage']!.text,
      );

      // Basic validation for parsed values
      if (cycleStartTime == null ||
          cycleStartOdometer == null ||
          loadingTonnage == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Please ensure all date/time and number fields are valid.',
              ),
            ),
          );
          setState(() {
            _isSaving = false;
          });
        }
        return;
      }

      HaulageLog log;
      if (widget.initialLog != null) {
        // Update existing log
        log = widget.initialLog!;
        log.transactionId = transactionId;
        log.shiftId = _selectedShift;
        log.vehicle = _selectedVehicleId;
        log.driver = _selectedDriverId;
        log.project = widget.initialLog!.project;
        // log.project = _selectedProjectId;
        log.project = _defaultProjectId; // <-- HERE
        log.loadingSite = _selectedLoadingSiteId;
        log.dumpingSite =
            _selectedDumpingSiteId; // Keep existing if not changed
        log.cycle = _selectedCycle;
        log.cycleStartTime = cycleStartTime;
        log.cycleStartOdometer = cycleStartOdometer;
        log.loadingTonnage = loadingTonnage;
        log.synced = false; // Mark as unsynced after edit
      } else {
        // Create new log
        log = HaulageLog(
          transactionId: transactionId,
          shiftId: _selectedShift,
          vehicle: _selectedVehicle?.id.toString(),
          driver: _selectedDriver?.id.toString(),
          //project: _selectedProjectId,
          project: _defaultProjectId,
          cycle: _selectedCycle,
          cycleStartTime: cycleStartTime,
          cycleStartOdometer: cycleStartOdometer,
          loadingTonnage: loadingTonnage,
          synced: false,
          arrivalTime:
              null, // Initializing subsequent fields to null for a loading form
          arrivalOdometer: null,
          dumpingTime: null,
          dumpingTonnage: null,
          departureTime: null,
          cycleEndOdometer: null,
          cycleEndTime: null,
        );
      }

      final int logId = await _dbService.insertLog(log);
      log.id = logId; // Ensure the log object has its ID for syncing

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Log saved locally (ID: $logId). Attempting to sync...',
            ),
          ),
        );
      }

      // Attempt to sync immediately after saving locally
      await _syncService.syncLog(log, widget.credentials);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide previous snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log saved and synced successfully!')),
        );

        // Clear form after successful save and sync if it was a new log
        if (widget.initialLog == null) {
          _controllers.values.forEach((c) => c.clear());
          // Re-set defaults for new entry
          _selectedShift = _determineCurrentShift();
          _controllers['cycleStartTime']!.text = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(DateTime.now());

          _selectedVehicleId = null;
          _selectedDriverId = null;
          _selectedProjectId = null;
          _selectedLoadingSiteId = null;
          _selectedDumpingSiteId = null;
          _selectedCycle = null;
        }

        setState(() {
          _isSaving = false; // Reset loading state
        });

        // Pop with a result to notify the Dashboard to refresh
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide any current snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving or syncing log: $e')),
        );
        print('Error saving/syncing log: $e'); // For debugging
        setState(() {
          _isSaving = false; // Reset loading state on error
        });
      }
    }
  }

  // New: Check and listen for connectivity changes
  void _checkConnectivityAndListen() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = (result != ConnectivityResult.none);
    });
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isOnline = (result != ConnectivityResult.none);
        // Automatically try to fetch odometer if connection is regained and vehicle is selected
        if (_isOnline && _selectedVehicle != null && _controllers['cycleStartOdometer']!.text.isEmpty) {
           _fetchOdometerForVehicle(_selectedVehicle!.license_plate ?? '');
        }
      });
    });
  }

  // New: Fetch odometer for a specific vehicle
  Future<void> _fetchOdometerForVehicle(String vehicleLicensePlate) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please enter odometer manually.')),
      );
      return;
    }

    setState(() {
      _isLoadingOdometer = true;
    });

    try {
      final odometer = await _frotcomService.getVehicleOdometer(vehicleLicensePlate);
      if (mounted) {
        if (odometer != null) {
          _controllers['cycleStartOdometer']!.text = odometer.toStringAsFixed(2); // Display with 2 decimal places
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odometer fetched successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not fetch odometer for this vehicle. Please enter manually.')),
          );
        }
      }
    } catch (e) {
      print('Error fetching odometer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching odometer: $e. Please enter manually.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOdometer = false;
        });
      }
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // Generic helper for TextFields
  Widget _buildTextField(
    String key,
    String label, {
    bool isNumber = false,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        readOnly: readOnly,
        validator:
            validator ??
            (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  // Generic helper for Date/Time TextFields with pickers
  Widget _buildDateTimeField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: true, // Make it read-only as value is set by picker
        onTap: () async {
          // Prevent keyboard from appearing
          FocusScope.of(context).requestFocus(FocusNode());
          final picked = await _pickDateTime();
          if (picked != null) {
            _controllers[key]!.text = DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(picked);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  // Generic helper for DropdownButtonFormField using List<T> as items
  Widget _buildDropdown<T>({
    required String label,
    required T? selectedValue,
    required List<T>
    items, // Now expects a List of your actual data types (e.g., String, Vehicle)
    required String Function(T)
    itemLabelMapper, // Function to get display string from item
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: selectedValue,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabelMapper(item)),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: validator ?? (val) => val == null ? 'Required' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialLog == null ? 'New Loading Log' : 'Edit Loading Log',
        ),
      ),
      body: _isLoadingDropdowns
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Show loading for dropdowns
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField(
                      'transactionId',
                      'Transaction ID',
                      readOnly:
                          widget.initialLog != null, // Read-only if editing
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Transaction ID is required';
                        }
                        return null;
                      },
                    ),
                    _buildDropdown<String>(
                      label: 'Shift',
                      selectedValue: _selectedShift,
                      items: shiftOptions,
                      itemLabelMapper: (shift) =>
                          shift.capitalize(), // Use capitalize extension
                      onChanged: (val) => setState(() => _selectedShift = val),
                    ),
                    _buildDropdown<String>(
                      label: 'Cycle',
                      selectedValue: _selectedCycle,
                      items: cycleOptions,
                      itemLabelMapper: (cycle) => cycle.capitalize(),
                      onChanged: (val) => setState(() => _selectedCycle = val),
                    ),
                    // Set the controller's text for project display before building the widget
                    (() {
                      final projectName = _projects
                          .firstWhere(
                            (p) => p.id.toString() == _defaultProjectId,
                            orElse: () =>
                                Project(id: 0, name: 'Unknown Project'),
                          )
                          .name;
                      _controllers.putIfAbsent(
                        'projectDisplay',
                        () => TextEditingController(),
                      );
                      _controllers['projectDisplay']!.text = projectName;
                      return _buildTextField(
                        'projectDisplay', // A new key for display purposes
                        'Project',
                        readOnly: true, // Make it read-only
                        validator: (val) => null,
                      );
                    })(),
                    _buildDateTimeField('cycleStartTime', 'Cycle Start Time'),
                    
                    /* _buildDropdown<String>(
                      label: 'Vehicle',
                      selectedValue: _selectedVehicleId,
                      items: _vehicles
                          .map((v) => v.id.toString())
                          .toList(), // Assuming Vehicle has an ID property
                      itemLabelMapper: (id) => _vehicles
                          .firstWhere((v) => v.id.toString() == id)
                          .name, // Map ID back to name for display
                      onChanged: (val) =>
                          setState(() => _selectedVehicleId = val),
                    ),
                    _buildDropdown<String>(
                      label: 'Driver',
                      selectedValue: _selectedDriverId,
                      items: _drivers
                          .map((d) => d.id.toString())
                          .toList(), // Assuming Driver has an ID property
                      itemLabelMapper: (id) => _drivers
                          .firstWhere((d) => d.id.toString() == id)
                          .name, // Map ID back to name for display
                      onChanged: (val) =>
                          setState(() => _selectedDriverId = val),
                    ), */
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Autocomplete<Vehicle>(
                        initialValue: TextEditingValue(
                          text: _selectedVehicle?.name ?? '',
                        ), // Pre-fill for editing
                        displayStringForOption: (Vehicle option) => option.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Vehicle>.empty();
                          }
                          return _vehicles.where((Vehicle option) {
                            return option.name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (Vehicle selection) {
                          setState(() {
                            _selectedVehicle = selection;
                          });
                          print('You selected the vehicle ${selection.name}');
                        },
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // Manually manage the controller if initialValue logic causes issues
                              if (_selectedVehicle != null &&
                                  textEditingController.text.isEmpty) {
                                textEditingController.text =
                                    _selectedVehicle!.name;
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle',
                                  suffixIcon: _isLoadingOdometer
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_isOnline && _selectedVehicle != null)
                          ? IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _fetchOdometerForVehicle(_selectedVehicle!.license_plate ?? '' ),
                              tooltip: 'Fetch Odometer',
                            )
                          : null,
                
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vehicle is required';
                                  }
                                  // Optionally, check if the entered text matches a valid option
                                  // This can be complex, often 'onSelected' handles the final valid state
                                  if (_selectedVehicle == null ||
                                      _selectedVehicle!.name != value) {
                                    // If the text doesn't match a selected option, or no option selected
                                    // you might want to force selection, or allow free text.
                                    // For strict selection, uncomment this:
                                    // return 'Please select a valid vehicle from the list.';
                                  }
                                  return null;
                                },
                              );
                            },
                        optionsViewBuilder:
                            (
                              BuildContext context,
                              AutocompleteOnSelected<Vehicle> onSelected,
                              Iterable<Vehicle> options,
                            ) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 200,
                                      maxWidth:
                                          MediaQuery.of(context).size.width -
                                          32,
                                    ), // Adjust width as needed
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final Vehicle option = options
                                                .elementAt(index);
                                            return ListTile(
                                              title: Text(option.name),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                    _buildTextField(
                      'cycleStartOdometer',
                      'Cycle Start Odometer',
                      isNumber: true,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Autocomplete<Driver>(
                        initialValue: TextEditingValue(
                          text: _selectedDriver?.name ?? '',
                        ), // Pre-fill for editing
                        displayStringForOption: (Driver option) => option.name,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Driver>.empty();
                          }
                          return _drivers.where((Driver option) {
                            return option.name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (Driver selection) {
                          setState(() {
                            _selectedDriver = selection;
                          });
                          print('You selected the driver ${selection.name}');
                        },
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // Manually manage the controller if initialValue logic causes issues
                              if (_selectedDriver != null &&
                                  textEditingController.text.isEmpty) {
                                textEditingController.text =
                                    _selectedDriver!.name;
                              }
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Driver',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Driver is required';
                                  }
                                  // For strict selection, uncomment this:
                                  // if (_selectedDriver == null || _selectedDriver!.name != value) {
                                  //   return 'Please select a valid driver from the list.';
                                  // }
                                  return null;
                                },
                              );
                            },
                        optionsViewBuilder:
                            (
                              BuildContext context,
                              AutocompleteOnSelected<Driver> onSelected,
                              Iterable<Driver> options,
                            ) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 200,
                                      maxWidth:
                                          MediaQuery.of(context).size.width -
                                          32,
                                    ), // Adjust width as needed
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final Driver option = options
                                                .elementAt(index);
                                            return ListTile(
                                              title: Text(option.name),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                      ),
                    ),

                    /*_buildDropdown<String>(
                      label: 'Project',
                      selectedValue: _selectedProjectId,
                      items: _projects
                          .map((p) => p.id.toString())
                          .toList(), // Assuming Project has an ID property
                      itemLabelMapper: (id) => _projects
                          .firstWhere((p) => p.id.toString() == id)
                          .name, // Map ID back to name for display
                      onChanged: (val) =>
                          setState(() => _selectedProjectId = val),
                    ),
                    */
                    _buildTextField(
                      'loadingTonnage',
                      'Loading Tonnage',
                      isNumber: true,
                    ),

                    const SizedBox(height: 16),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _saveLoadingLog();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Submit'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
