import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:mindmeds/main.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_service.dart';

import '../models/medication.dart';
import '../services/storage_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({Key? key}) : super(key: key);

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _baseDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<TimeOfDay?> _times = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is DateTime) _baseDate = arg;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateTimesList(String value) {
    final n = int.tryParse(value) ?? 0;
    setState(() {
      if (n > _times.length) {
        _times.addAll(List.filled(n - _times.length, null));
      } else if (n < _times.length) {
        _times = _times.sublist(0, n);
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(int index) async {
    final now = TimeOfDay.now();
    final time = await showTimePicker(
      context: context,
      initialTime: _times[index] ?? now,
    );
    if (time != null) {
      setState(() {
        _times[index] = time;
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all times')),
      );
      return;
    }

    try {
      final storage = StorageService();
      final list = await storage.loadMedications();
      final idBase = Uuid().v4();

      final notificationService = NotificationService();

      for (var i = 0; i < _times.length; i++) {
        final tod = _times[i]!;

        final medId = '$idBase-$i';

        final med = Medication(
          id: medId,
          name: _nameController.text.trim(),
          dose: _doseController.text.trim(),
          frequencyPerDay: _times.length,
          time: DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            tod.hour,
            tod.minute,
          ),
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        list.add(med);

        for (DateTime date = _startDate;
        !date.isAfter(_endDate);
        date = date.add(const Duration(days: 1))) {
          final scheduledDate = tz.TZDateTime.local(
            date.year,
            date.month,
            date.day,
            tod.hour,
            tod.minute,
          );

          if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

          final notificationId = medId.hashCode ^ date.hashCode;

          print('[AddMedicationScreen] Scheduling notification for medication "${med.name}" on $scheduledDate with id $notificationId');

          await notificationService.scheduleNotification(
            id: notificationId,
            title: 'Time to take ${med.name}',
            body: '${med.dose} at ${tod.format(context)}',
            scheduledDate: scheduledDate,
          );

        }
      }
      for (var i = 0; i < _times.length; i++) {
        final tod = _times[i]!;

        for (DateTime date = _startDate;
        !date.isAfter(_endDate);
        date = date.add(const Duration(days: 1))) {
          final scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            tod.hour,
            tod.minute,
          );

          if (scheduledDateTime.isBefore(DateTime.now())) continue;

          final alarmId = scheduledDateTime.millisecondsSinceEpoch.remainder(100000);

          await AndroidAlarmManager.oneShotAt(
            scheduledDateTime,
            alarmId,
            medicationAlarmCallback,
            exact: true,
            wakeup: true,
            rescheduleOnReboot: true,
          );

          print('Alarma programada para $scheduledDateTime con id $alarmId');
        }
      }

      await storage.saveMedications(list);
      print('[AddMedicationScreen] Medication saved and notifications scheduled.');
      Navigator.pop(context, true);
    } catch (e) {
      print('[AddMedicationScreen] Error saving medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving medication: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Add Medication')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Nombre
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 16),

                // Dosis
                TextFormField(
                  controller: _doseController,
                  decoration: const InputDecoration(
                    labelText: 'Dose (e.g., 500 mg)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter dose' : null,
                ),
                const SizedBox(height: 16),

                // Frecuencia
                TextFormField(
                  controller: _frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Frequency per day',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: _updateTimesList,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter a positive integer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Multiple Time pickers
                ...List.generate(_times.length, (i) {
                  final label = 'Time #${i + 1}';
                  final subtitle = _times[i]?.format(context) ?? 'Not set';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    subtitle: Text(subtitle),
                    trailing: ElevatedButton(
                      onPressed: () => _pickTime(i),
                      child: const Text('Select'),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                // Intervalo fechas
                ListTile(
                  title: Text(
                      'Start Date: ${_startDate.toLocal().toString().split(' ')[0]}'),
                  trailing: ElevatedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: const Text('Select'),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(
                      'End Date:   ${_endDate.toLocal().toString().split(' ')[0]}'),
                  trailing: ElevatedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: const Text('Select'),
                  ),
                ),
                const SizedBox(height: 16),

                // Notas
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Guardar
                ElevatedButton(
                  onPressed: _saveMedication,
                  child: const Text('Save Medication'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
