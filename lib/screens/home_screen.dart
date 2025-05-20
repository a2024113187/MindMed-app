import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../main.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../models/medication.dart';
import 'package:photo_view/photo_view.dart';
import '../services/tts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Set<String> takenMedications = {
  }; // IDs de medicamentos marcados como tomados
  List<Medication> medications = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<String>> takenMedicationsByDate = {};


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMedications();
    _loadTakenMedications();
  }

  Future<void> _speakMedications() async {
    if (medications.isEmpty) {
      await TtsService().speak('You have no medications scheduled for today.');
      return;
    }

    final medsToday = _eventsForDay(_selectedDay!);

    if (medsToday.isEmpty) {
      await TtsService().speak('You have no medications scheduled for today.');
      return;
    }

    String speechText = 'Today, you have ${medsToday
        .length} medications to take. ';

    for (var med in medsToday) {
      final timeFormatted = TimeOfDay.fromDateTime(med.time).format(context);
      speechText += 'Take ${med.dose} of ${med.name} at $timeFormatted. ';
    }

    await TtsService().speak(speechText);
  }


  Future<void> _loadTakenMedications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    takenMedicationsByDate =
    await StorageService().loadTakenMedicationsByDate(uid);
    setState(() {});
  }

  bool _isTaken(String medId) {
    final dateKey = _selectedDay!.toIso8601String().split('T')[0];
    final takenList = takenMedicationsByDate[dateKey] ?? [];
    return takenList.contains(medId);
  }

  Future<void> _toggleTaken(String medId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    final uid = user.uid;

    final dateKey = _selectedDay!.toIso8601String().split('T')[0];
    final takenList = takenMedicationsByDate[dateKey] ?? [];
    final history = await StorageService().loadMedicationHistory(uid);

    setState(() {
      if (takenList.contains(medId)) {
        takenList.remove(medId);
      } else {
        takenList.add(medId);
      }
      takenMedicationsByDate[dateKey] = takenList;
    });

    await StorageService().saveTakenMedicationsByDate(
        takenMedicationsByDate, uid);

    // Actualizar historial
    await StorageService().saveTakenMedicationsByDate(
        takenMedicationsByDate, uid);

    // Buscar la medicación en el historial
    final medHistoryIndex = history.indexWhere((h) => h['medId'] == medId);
    if (medHistoryIndex != -1) {
      final medHistory = history[medHistoryIndex];
      final takenDays = Map<String, dynamic>.from(
          medHistory['takenDays'] ?? {});

      // Actualizar el día actual
      takenDays[dateKey] = takenList.contains(medId);

      medHistory['takenDays'] = takenDays;
      history[medHistoryIndex] = medHistory;
    } else {
      // Si no existe, crear una nueva entrada (opcional)
      // Para esto necesitarías info de la medicación (nombre, dosis, fechas)
    }

    await StorageService().saveMedicationHistory(history, uid);
  }

  Color _getMedicationStatusColor(Medication med, DateTime day) {
    final now = DateTime.now();
    final dateKey = day.toIso8601String().split('T')[0];
    final takenList = takenMedicationsByDate[dateKey] ?? [];
    final isTaken = takenList.contains(med.id);

    if (isTaken) {
      return Colors.green; // Verde: tomado
    } else {
      final medDate = DateTime(day.year, day.month, day.day);
      final today = DateTime(now.year, now.month, now.day);

      if (medDate.isBefore(today)) {
        return Colors.red; // Fecha pasada y no tomada → rojo urgente
      } else if (medDate.isAfter(today)) {
        return Colors.yellow[700]!; // Fecha futura → amarillo pendiente
      } else {
        final medDateTime = DateTime(
          day.year,
          day.month,
          day.day,
          med.time.hour,
          med.time.minute,
        );

        if (now.isAfter(medDateTime)) {
          return Colors.red; // Hora pasada y no tomada → rojo urgente
        } else {
          return Colors.yellow[700]!; // Hora futura → amarillo pendiente
        }
      }
    }
  }


  Future<void> _scheduleNotificationInOneMinute() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(const Duration(minutes: 1));

    await NotificationService().scheduleNotification(
      id: 10001,
      title: 'Test Notification 1 Minute',
      body: 'This notification should appear in 1 minute',
      scheduledDate: scheduled,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification scheduled in 1 minute')),
    );
  }

  Future<void> _scheduleNotificationIn10Seconds() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(const Duration(seconds: 10));

    await NotificationService().scheduleNotification(
      id: 10002,
      title: 'Test Notification 10 Seconds',
      body: 'This notification should appear in 10 seconds',
      scheduledDate: scheduled,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification scheduled in 10 seconds')),
    );
  }

  Future<void> _loadMedications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Manejar usuario no autenticado
      return;
    }
    final uid = user.uid;
    medications = await StorageService().loadMedications(uid);
    takenMedications =
        medications.where((m) => m.taken).map((m) => m.id).toSet();
    setState(() {});

    // Llama a TTS para leer las medicaciones
    await _speakMedications();
  }


  List<Medication> _eventsForDay(DateTime day) {
    return medications.where((m) {
      final start = DateTime(
          m.startDate.year, m.startDate.month, m.startDate.day);
      final end = DateTime(m.endDate.year, m.endDate.month, m.endDate.day);
      final current = DateTime(day.year, day.month, day.day);
      return current.isAtSameMomentAs(start) ||
          current.isAtSameMomentAs(end) ||
          (current.isAfter(start) && current.isBefore(end));
    }).toList();
  }

  Future<void> _navigate(String route) async {
    final result = await Navigator.pushNamed(context, route);
    if (result == true) _loadMedications();
  }

  Future<void> _navigateToAdd({Medication? medication}) async {
    final result = await Navigator.pushNamed(
      context,
      '/add_medication',
      arguments: medication ?? _selectedDay,
    );
    if (result == true) _loadMedications();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }
  String _getTimeSection(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    if (totalMinutes >= 5 * 60 && totalMinutes < 12 * 60) {
      return 'Morning';
    } else if (totalMinutes >= 12 * 60 && totalMinutes < 18 * 60) {
      return 'Afternoon';
    } else if (totalMinutes >= 18 * 60 && totalMinutes < 22 * 60) {
      return 'Evening';
    } else {
      return 'Night';
    }
  }


  Widget _buildLegendDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primaryContainer.withOpacity(0.25);

    return Scaffold(

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/icons/logo.webp',
          height: 40,
        ),


        // Ajusta el tamaño según prefiera),
        iconTheme: const IconThemeData(color: Color(0xFF0D4F4F)),
        actions: [


          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.3),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            onEnd: () {
              // Optional: Loop or reverse if desired
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      drawer: _buildDrawer(user),
      body: GlobalBackground(
        child: CustomScrollView(
          slivers: [


            // 1) Logo y calendario
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [


                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TableCalendar(
                          firstDay: DateTime.now().subtract(const Duration(days: 365)),
                          lastDay: DateTime.now().add(const Duration(days: 365)),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.tealAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          eventLoader: _eventsForDay,
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isEmpty) {
                                return const SizedBox();
                              }

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: events.map((event) {
                                  if (event is Medication) {
                                    final color = _getMedicationStatusColor(event, day);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medication Status Legend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildLegendDot(Colors.green),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Taken')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildLegendDot(Colors.yellow.shade700),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Pending')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildLegendDot(Colors.red),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Overdue')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),


            // 2) Si no hay eventos, mostramos mensaje (también deslizable):
            if (_eventsForDay(_selectedDay!).isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No medications on this day.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
            // 3) Lista de tarjetas como SliverList
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final med = _eventsForDay(_selectedDay!)[index];
                      return _buildMedCard(med, accent);
                    },
                    childCount: _eventsForDay(_selectedDay!).length,
                  ),
                ),
              ),

            // 4) Un pequeño padding al final
            SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),


      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primary,
        foregroundColor: Theme
            .of(context)
            .colorScheme
            .onPrimary,
        onPressed: _navigateToAdd,
        label: const Text('Add Medication'),
        icon: const Icon(Icons.add),
        elevation: 4,
      ),
    );
  }

  Widget _buildMedCard(Medication med, Color accent) {
    final timeOfDay = TimeOfDay.fromDateTime(med.time);
    final timeSection = _getTimeSection(timeOfDay);
    final timeFormatted = timeOfDay.format(context);

    final taken = _isTaken(med.id);

    Widget avatar;

    if (med.imagePath != null && med.imagePath!.isNotEmpty) {
      avatar = GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              final theme = Theme.of(context);
              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: theme.appBarTheme.backgroundColor ??
                      theme.colorScheme.primary,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    med.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary),
                  ),
                  centerTitle: true,
                ),
                body: Center(
                  child: Hero(
                    tag: med.id,
                    child: PhotoView(
                      imageProvider: FileImage(File(med.imagePath!)),
                      backgroundDecoration: BoxDecoration(color: theme
                          .scaffoldBackgroundColor),
                      loadingBuilder: (context, event) =>
                          Center(
                            child: CircularProgressIndicator(
                                color: theme.colorScheme.primary),
                          ),
                      errorBuilder: (context, error, stackTrace) =>
                          Center(
                            child: Icon(Icons.broken_image, size: 100,
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.3)),
                          ),
                    ),
                  ),
                ),
              );
            },
          ));
        },
        child: Hero(
          tag: med.id,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.file(
              File(med.imagePath!),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme
                      .of(context)
                      .colorScheme
                      .primary,
                  child: const Icon(
                      Icons.medication, color: Colors.white, size: 28),
                );
              },
            ),
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: 28,
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primary,
        child: const Icon(Icons.medication, color: Colors.white, size: 28),
      );
    }
    final statusColor = _getMedicationStatusColor(med, _selectedDay!);

    return Card(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 16),
            // Indicador de estado
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${med.dose} • $timeFormatted • $timeSection',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  if (med.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      med.notes!,
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: taken,
              onChanged: (value) async {
                final message = taken
                    ? 'Are you sure you want to mark the medication as not taken?'
                    : 'Are you sure you have taken the medication?';

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      AlertDialog(
                        title: const Text('Confirm'),
                        content: Text(message),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                );

                if (confirmed == true) {
                  await _toggleTaken(med.id);
                }
              },
            ),

            IconButton(
              icon: const Icon(
                  Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                final uid = user.uid;
                medications.remove(med);
                await StorageService().saveMedications(medications, uid);
                setState(() {});
              },
            ),

          ],
        ),
      ),
    );
  }


  Widget _buildDrawer(User? user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Drawer(
      child: FutureBuilder<String?>(
        future: user != null ? StorageService().getUserProfileImagePath(
            user.uid) : Future.value(null),
        builder: (context, snapshot) {
          String? imagePath = snapshot.data;
          bool hasImage = false;

          if (imagePath != null) {
            final file = File(imagePath);
            hasImage = file.existsSync();
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  user?.displayName ?? user?.email ?? '',
                  style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary),
                ),
                accountEmail: Text(
                  user?.email ?? '',
                  style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary),
                ),
                currentAccountPicture: hasImage
                    ? CircleAvatar(
                  backgroundImage: FileImage(File(imagePath!)),
                )
                    : (user?.photoURL != null
                    ? CircleAvatar(
                  backgroundImage: NetworkImage(user!.photoURL!),
                )
                    : CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  child: Icon(
                      Icons.person, size: 40, color: colorScheme.onPrimary),
                )),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                ),
              ),
              _drawerItem(
                  context, Icons.add, 'Add Medication', '/add_medication'),
              _drawerItem(
                  context, Icons.phone, 'Emergency Contacts',
                  '/reminder_popup'),
              _drawerItem(context, Icons.history, 'History', '/history'),
              _drawerItem(context, Icons.person, 'Profile', '/profile'),
              _drawerItem(context, Icons.accessibility, 'Accessibility',
                  '/accessibility'),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label,
      String route) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(label, style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onBackground)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}