import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindmeds/main.dart';
import 'package:mindmeds/services/tts_service.dart';
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
  final TtsService _ttsService = TtsService();

  DateTime _baseDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<TimeOfDay?> _times = [];
  File? _imageFile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute
        .of(context)
        ?.settings
        .arguments;
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

  @override
  void initState() {
    super.initState();
    _ttsService.init();
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
                  await _ttsService.speak('Photo taken');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _getImage(ImageSource.gallery);
                  await _ttsService.speak('Photo selected');
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
    final savedImage = await File(pickedFile.path).copy(
        '${appDir.path}/$fileName');

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

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Information'),
        content: const Text('Are you sure the information is correct?'),

        actions: [
          TextButton(
            onPressed: () =>{ Navigator.of(ctx).pop(false),_ttsService.speak('Information not confirmed'),
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => {Navigator.of(ctx).pop(true), _ttsService.speak('Information confirmed')},
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      // Usuario canceló
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }
    final uid = user.uid;

    try {
      final storage = StorageService();
      final list = await storage.loadMedications(uid);
      final idBase = Uuid().v4();
      final history = await storage.loadMedicationHistory(uid);

      final notificationService = NotificationService();

      for (var i = 0; i < _times.length; i++) {
        final tod = _times[i];
        if (tod == null) continue;

        final medId = '$idBase-$i';

        Map<String, bool> takenDays = {};
        for (DateTime date = _startDate; !date.isAfter(_endDate);
        date = date.add(const Duration(days: 1))) {
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
          notes: _notesController.text
              .trim()
              .isEmpty
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

        await storage.saveMedicationHistory(history, uid);


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

          print(
              '[AddMedicationScreen] Scheduling notification for medication "${med
                  .name}" on $scheduledDate with id $notificationId');

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

          final alarmId = scheduledDateTime.millisecondsSinceEpoch.remainder(
              100000);

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

      await storage.saveMedications(list, uid);
      print(
          '[AddMedicationScreen] Medication saved and notifications scheduled.');
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Add medication',

            style: TextStyle(
              color: Color(0xFF001F3F), // Azul oscuro (equivale a Colors.blue[900])
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onBackground,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.volume_up, color: Color(0xFF001F3F)),
              onPressed: () {
                _ttsService.speak('Add medication');
              },
              tooltip: 'Listen title',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medication Info Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medication Info', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Medication Name',

                            prefixIcon: Icon(
                                Icons.medication, color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: 'Enter medication name',
                          ),
                          validator: (v) =>
                          v == null || v
                              .trim()
                              .isEmpty ? 'Enter name' : null,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _doseController,
                          decoration: InputDecoration(
                            labelText: 'Dose',
                            prefixIcon: Icon(Icons.local_hospital,
                                color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: 'e.g., 500 mg',
                          ),
                          validator: (v) =>
                          v == null || v
                              .trim()
                              .isEmpty ? 'Enter dose' : null,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Frequency & Times Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Frequency & Times', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _times.length > 0 ? _times.length : null,
                          decoration: InputDecoration(
                            labelText: 'Times per day',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: List.generate(10, (index) => index + 1)
                              .map((e) =>
                              DropdownMenuItem(
                                value: e,
                                child: Text('$e', style: textTheme.bodyMedium),
                              ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _updateTimesList(val.toString());
                          },
                          validator: (v) =>
                          (v == null || v <= 0)
                              ? 'Select frequency'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_times.length, (i) {
                          final label = 'Time #${i + 1}';
                          final subtitle = _times[i]?.format(context) ??
                              'Not set';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(label, style: textTheme.bodyMedium),
                            subtitle: Text(
                                subtitle, style: textTheme.bodySmall),
                            trailing: ElevatedButton(
                              onPressed: () => _pickTime(i),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Select'),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Date Range Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date Range', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme
                                      .onPrimaryContainer,
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(
                                  DateFormat('dd MMM yyyy').format(_startDate),
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium,
                                ),
                                onPressed: () => _pickDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme
                                      .onPrimaryContainer,
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(
                                  DateFormat('dd MMM yyyy').format(_endDate),
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium,
                                ),
                                onPressed: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Medication Photo Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medication Photo (optional)',
                            style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Center(
                          child: _imageFile == null
                              ? Text(
                              'No image selected.', style: textTheme.bodyMedium)
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, height: 150),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: Icon(Icons.photo_library,
                                color: colorScheme.onPrimary),
                            label: Text('Select Image',
                                style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onPrimary)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'Additional information',
                      ),
                      maxLines: 3,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveMedication,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: Text('Save Medication',
                        style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimary)),
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
