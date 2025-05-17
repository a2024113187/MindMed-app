import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../main.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../models/medication.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Set<String> takenMedications = {}; // IDs de medicamentos marcados como tomados
  List<Medication> medications = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;



  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMedications();
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
    medications = await StorageService().loadMedications();
    setState(() {});
  }
  void _toggleTaken(String medId) {
    setState(() {
      if (takenMedications.contains(medId)) {
        takenMedications.remove(medId);
      } else {
        takenMedications.add(medId);
      }
    });
  }

  List<Medication> _eventsForDay(DateTime day) {
    return medications.where((m) {
      final start = DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
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

  Future<void> _navigateToAdd() async {
    final result = await Navigator.pushNamed(
      context,
      '/add_medication',
      arguments: _selectedDay,
    );
    if (result == true) _loadMedications();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
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
        title: Text(
          'MindMed',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF0D4F4F),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0D4F4F)),
        actions: [


          IconButton(
            icon: const Icon(Icons.timer_10),
            tooltip: 'Notify in 10 seconds',
            onPressed: _scheduleNotificationIn10Seconds,
          ),


          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.3),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.tealAccent.shade700.withOpacity(0.9),
                    size: 28,
                  ),
                  onPressed: () => NotificationService().showNotification(
                    id: 1,
                    title: 'Test Notification',
                    body: 'This is a test notification',
                    payload: 'TestPayload',
                  ),
                ),
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
    Image.asset('assets/icons/logo.webp', height: 80),
    const SizedBox(height: 16),

    Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 3,
    child: Padding(
    padding: const EdgeInsets.all(8),
    child: TableCalendar(
    firstDay: DateTime.now().subtract(const Duration(days: 365)),
    lastDay: DateTime.now().add(const Duration(days: 365)),
    focusedDay: _focusedDay,
    selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
    calendarStyle: const CalendarStyle(
    todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
    selectedDecoration: BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
    ),
    onDaySelected: (sel, foc) {
    setState(() {
    _selectedDay = sel;
    _focusedDay = foc;
    });
    },
    eventLoader: _eventsForDay,
    ),
    ),
    ),
    const SizedBox(height: 12),
    ],
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
    backgroundColor: Colors.teal.shade600,
    foregroundColor: Colors.white,
    onPressed: _navigateToAdd,
    label: const Text('Add Medication'),
    icon: const Icon(Icons.add),
    elevation: 4,
    ),
    );
  }

  Widget _buildMedCard(Medication med, Color accent) {
    final time = TimeOfDay.fromDateTime(med.time).format(context);
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
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.medication, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${med.dose} • $time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  if (med.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      med.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Aquí el toggle para marcar como tomado
            Switch(
              value: med.taken,
              onChanged: (bool value) async {
                setState(() {
                  med.taken = value;
                });
                // Guarda el cambio en almacenamiento
                await StorageService().saveMedications(medications);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () async {
                medications.remove(med);
                await StorageService().saveMedications(medications);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }


    Widget _buildDrawer(User? user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.email ?? ''),
            accountEmail: Text(user?.uid ?? ''),
          ),
          _drawerItem(Icons.add, 'Add Medication', '/add_medication'),
          _drawerItem(Icons.notification_important, 'Reminder Popup', '/reminder_popup'),
          _drawerItem(Icons.history, 'History', '/history'),
          _drawerItem(Icons.person, 'Profile', '/profile'),
          _drawerItem(Icons.accessibility, 'Accessibility', '/accessibility'),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        _navigate(route);
      },
    );
  }
}
