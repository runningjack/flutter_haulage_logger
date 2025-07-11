import 'package:flutter/material.dart';
import '../models/user_credentials.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../models/haulage_log.dart';

class LogFormScreen extends StatefulWidget {
  final UserCredentials credentials;
  LogFormScreen({required this.credentials});

  @override
  _LogFormScreenState createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final SyncService _syncService = SyncService();
  final LocalDBService _dbService = LocalDBService();
  final Map<String, TextEditingController> controllers = {
    'transactionId': TextEditingController(),
    'shiftId': TextEditingController(),
    'vehicle': TextEditingController(),
    'driver': TextEditingController(),
    'project': TextEditingController(),
    'loadingSite': TextEditingController(),
    'cycle': TextEditingController(),
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

  

  void _triggerManualSync() async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Syncing...')));
    await _syncService.syncUnsyncedLogs(widget.credentials);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync complete.')));
  }


  Future<void> _saveLog() async {
    final transactionId = controllers['transactionId']!.text;
    final exists = await _dbService.transactionIdExists(transactionId);
    if (exists) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Duplicate Entry'),
          content: Text('A log with this Transaction ID already exists.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
        ),
      );
      return;
    }

    final log = HaulageLog(
      transactionId: transactionId,
      shiftId: controllers['shiftId']!.text,
      vehicle: controllers['vehicle']!.text,
      driver: controllers['driver']!.text,
      project: controllers['project']!.text,
      loadingSite: controllers['loadingSite']!.text,
      cycle: controllers['cycle']!.text,
      cycleStartTime: DateTime.parse(controllers['cycleStartTime']!.text),
      cycleStartOdometer: double.parse(controllers['cycleStartOdometer']!.text),
      loadingTonnage: double.parse(controllers['loadingTonnage']!.text),
      dumpingSite: controllers['dumpingSite']!.text,
      arrivalTime: DateTime.parse(controllers['arrivalTime']!.text),
      arrivalOdometer: double.parse(controllers['arrivalOdometer']!.text),
      dumpingTime: DateTime.parse(controllers['dumpingTime']!.text),
      dumpingTonnage: double.parse(controllers['dumpingTonnage']!.text),
      departureTime: DateTime.parse(controllers['departureTime']!.text),
      cycleEndOdometer: double.parse(controllers['cycleEndOdometer']!.text),
      cycleEndTime: DateTime.parse(controllers['cycleEndTime']!.text),
    );

    await _dbService.insertLog(log);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Log saved locally.')));
    controllers.values.forEach((c) => c.clear());
  }


  @override
  void dispose() {
    controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Haulage Log Entry'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _triggerManualSync,
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              for (var key in controllers.keys)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: controllers[key],
                    decoration: InputDecoration(
                      labelText: key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: key.contains('Odometer') || key.contains('Tonnage') ? TextInputType.number : TextInputType.text,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // TODO: Save to local DB and sync
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saving entry...')));
                  }
                },
                child: Text('Submit'),
              )
            ],
          ),
        ),
      ),
    );
  }
}