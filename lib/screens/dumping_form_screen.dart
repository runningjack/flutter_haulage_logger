import 'package:flutter/material.dart';
import '../models/haulage_log.dart';
import '../models/user_credentials.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

class DumpingFormScreen extends StatefulWidget {
  final UserCredentials credentials;

  const DumpingFormScreen({super.key, required this.credentials});

  @override
  State<DumpingFormScreen> createState() => _DumpingFormScreenState();
}

class _DumpingFormScreenState extends State<DumpingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final LocalDBService _dbService = LocalDBService.instance;
  final SyncService _syncService = SyncService.instance;

  final TextEditingController _transactionIdController =
      TextEditingController();
  final Map<String, TextEditingController> _controllers = {
    'dumpingSite': TextEditingController(),
    'arrivalTime': TextEditingController(),
    'arrivalOdometer': TextEditingController(),
    'dumpingTime': TextEditingController(),
    'dumpingTonnage': TextEditingController(),
    'departureTime': TextEditingController(),
    'cycleEndOdometer': TextEditingController(),
    'cycleEndTime': TextEditingController(),
  };

  HaulageLog? _currentLog;

  @override
  void dispose() {
    _transactionIdController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
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

  Future<void> _loadLog() async {
    final transactionId = _transactionIdController.text.trim();
    if (transactionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Transaction ID')),
      );
      return;
    }

    setState(() {
      _currentLog = null; // Clear previous log details
      // Clear all dumping data fields
      _controllers.values.forEach((controller) => controller.clear());
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Searching for log...')));

    try {
      HaulageLog? log = await _dbService.getLogByTransactionId(transactionId);

      if (log == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log not found locally, fetching from server...'),
          ),
        );
        log = await _syncService.fetchLogFromServer(
          transactionId,
          widget.credentials,
        );
        if (log != null) {
          final bool localExists = await _dbService.transactionIdExists(
            transactionId,
          );
          if (!localExists) {
            await _dbService.insertLog(log);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Log fetched from server and saved locally.'),
              ),
            );
          } else {
            await _dbService.updateDumpingData(log);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Log fetched from server and updated locally.'),
              ),
            );
          }
        }
      }

      if (log != null) {
        setState(() {
          _currentLog = log;
          // Populate controllers with fetched data, handling nullability
          _controllers['dumpingSite']!.text = log!.dumpingSite!;
          _controllers['arrivalTime']!.text =
              log.arrivalTime?.toIso8601String() ?? '';
          _controllers['arrivalOdometer']!.text =
              log.arrivalOdometer?.toString() ?? ''; // FIXED
          _controllers['dumpingTime']!.text =
              log.dumpingTime?.toIso8601String() ?? '';
          _controllers['dumpingTonnage']!.text =
              log.dumpingTonnage?.toString() ?? '';
          _controllers['departureTime']!.text =
              log.departureTime?.toIso8601String() ?? '';
          _controllers['cycleEndOdometer']!.text =
              log.cycleEndOdometer?.toString() ?? ''; // FIXED
          _controllers['cycleEndTime']!.text =
              log.cycleEndTime?.toIso8601String() ?? '';
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log loaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction ID not found locally or on server.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading log: $e')));
      print('Error loading log: $e'); // For debugging
    }
  }

  Future<void> _saveUpdate() async {
    if (_formKey.currentState!.validate() && _currentLog != null) {
      // Update the current log object with form data
      // Ensure that if a text field is empty, the corresponding property is set to null
      _currentLog!
        
        
        ..arrivalTime = _controllers['arrivalTime']!.text.isEmpty
            ? null
            : DateTime.tryParse(_controllers['arrivalTime']!.text)
        ..arrivalOdometer = _controllers['arrivalOdometer']!.text.isEmpty
            ? null
            : double.tryParse(_controllers['arrivalOdometer']!.text)
        ..dumpingTime = _controllers['dumpingTime']!.text.isEmpty
            ? null
            : DateTime.tryParse(_controllers['dumpingTime']!.text)
        ..dumpingTonnage = _controllers['dumpingTonnage']!.text.isEmpty
            ? null
            : double.tryParse(_controllers['dumpingTonnage']!.text)
        ..departureTime = _controllers['departureTime']!.text.isEmpty
            ? null
            : DateTime.tryParse(_controllers['departureTime']!.text)
        ..cycleEndOdometer = _controllers['cycleEndOdometer']!.text.isEmpty
            ? null
            : double.tryParse(_controllers['cycleEndOdometer']!.text)
        ..cycleEndTime = _controllers['cycleEndTime']!.text.isEmpty
            ? null
            : DateTime.tryParse(_controllers['cycleEndTime']!.text)
        ..synced = false; // Mark as unsynced after local modification

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saving update locally...')));
      try {
        await _dbService.updateDumpingData(_currentLog!);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dumping data updated locally. Attempting to sync...',
            ),
          ),
        );

        await _syncService.syncLogUpdate(_currentLog!, widget.credentials);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dumping data updated and synced successfully.'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating/syncing: $e')));
        print('Error during save/sync: $e'); // For debugging
      }
    } else if (_currentLog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load a transaction ID first.')),
      );
    }
  }

  Widget _buildDateField(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: true,
        onTap: () async {
          final picked = await _pickDateTime(context);
          if (picked != null)
            _controllers[key]!.text = picked.toIso8601String();
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildField(String key, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: TextFormField(
          controller: _controllers[key],
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Required';
            }
            if (number) {
              if (double.tryParse(val) == null) {
                return 'Please enter a valid number';
              }
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dumping Form')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _transactionIdController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID',
                        border: OutlineInputBorder(),
                        hintText: 'Enter Transaction ID',
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (value) => _loadLog(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loadLog,
                    icon: const Icon(Icons.search),
                    label: const Text('Load Log'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_currentLog != null) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loaded Log Details:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transaction ID: ${_currentLog!.transactionId ?? 'N/A'}',
                        ), // Added ?? 'N/A'
                        Text('Vehicle: ${_currentLog!.vehicle ?? 'N/A'}'),
                        Text('Driver: ${_currentLog!.driver ?? 'N/A'}'),
                        Text('Project: ${_currentLog!.project ?? 'N/A'}'),
                        Text(
                          'Loading Site: ${_currentLog!.loadingSite ?? 'N/A'}',
                        ),
                        Text(
                          'Loading Tonnage: ${_currentLog!.loadingTonnage?.toStringAsFixed(2) ?? 'N/A'}',
                        ),
                        Text(
                          'Cycle Start Time: ${_currentLog!.cycleStartTime?.toIso8601String() ?? 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                ),
                _buildField('dumpingSite', 'Dumping Site'),
                _buildDateField('arrivalTime', 'Arrival Time'),
                _buildField(
                  'arrivalOdometer',
                  'Arrival Odometer',
                  number: true,
                ),
                _buildDateField('dumpingTime', 'Dumping Time'),
                _buildField('dumpingTonnage', 'Dumping Tonnage', number: true),
                _buildDateField('departureTime', 'Departure Time'),
                _buildField(
                  'cycleEndOdometer',
                  'Cycle End Odometer',
                  number: true,
                ),
                _buildDateField('cycleEndTime', 'Cycle End Time'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveUpdate,
                  child: const Text('Update Dumping Data'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Enter a Transaction ID and press "Load Log" to begin updating dumping data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
