import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:mindmeds/main.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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
  File? _imageFile;

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

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 600);
    if (pickedFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(pickedFile.path);
    final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

    setState(() {
      _imageFile = savedImage;
    });
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
    if (_times.isEmpty || _times.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all times')),
      );
      return;
    }

    try {
      final storage = StorageService();
      final list = await storage.loadMedications();
      final idBase = Uuid().v4();
      final history = await storage.loadMedicationHistory();

      final notificationService = NotificationService();

      for (var i = 0; i < _times.length; i++) {
        final tod = _times[i];
        if (tod == null) continue;

        final medId = '$idBase-$i';

        Map<String, bool> takenDays = {};
        for (DateTime date = _startDate; !date.isAfter(_endDate); date = date.add(const Duration(days: 1))) {
          final key = date.toIso8601String().split('T')[0];
          takenDays[key] = false;
        }



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
          imagePath: _imageFile?.path,

        );
        list.add(med);


        history.add({
          'medId': medId,
          'name': _nameController.text.trim(),
          'dose': _doseController.text.trim(),
          'startDate': _startDate.toIso8601String(),
          'endDate': _endDate.toIso8601String(),
          'takenDays': takenDays,
          'notes': _notesController.text.trim(),
        });

        await storage.saveMedicationHistory(history);


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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
          key: _formKey,
          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección: Información básica
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medication Info', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Medication Name',
                          prefixIcon: Icon(Icons.medication),
                          border: OutlineInputBorder(),
                          hintText: 'Enter medication name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _doseController,
                        decoration: const InputDecoration(
                          labelText: 'Dose',
                          prefixIcon: Icon(Icons.local_hospital),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 500 mg',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter dose' : null,
                      ),
                    ],
                  ),
                ),
              ),


              const SizedBox(height: 16),

              // Sección: Frecuencia y horarios
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency & Times', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _times.length > 0 ? _times.length : null,
                        decoration: const InputDecoration(
                          labelText: 'Times per day',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(10, (index) => index + 1)
                            .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) _updateTimesList(val.toString());
                        },
                        validator: (v) => (v == null || v <= 0) ? 'Select frequency' : null,
                      ),
                      const SizedBox(height: 12),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sección: Fechas
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text('Start Date: ${_startDate.toLocal().toString().split(' ')[0]}'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDate(isStart: true),
                          child: const Text('Select'),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text('End Date: ${_endDate.toLocal().toString().split(' ')[0]}'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDate(isStart: false),
                          child: const Text('Select'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sección: Imagen
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medication Photo (optional)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Center(
                        child: _imageFile == null
                            ? const Text('No image selected.')
                            : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, height: 150),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Select Image'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sección: Notas
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Additional information',
                    ),
                    maxLines: 3,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMedication,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.teal.shade600,
                  ),
                  child: const Text('Save Medication', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
