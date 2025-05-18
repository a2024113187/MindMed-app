

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:mindmeds/screens/accessibility_settings_screen.dart';
import 'package:mindmeds/screens/add_medication_screen.dart';
import 'package:mindmeds/screens/history_screen.dart';
import 'package:mindmeds/screens/home_screen.dart';
import 'package:mindmeds/screens/login_screen.dart';
import 'package:mindmeds/screens/profile_screen.dart';
import 'package:mindmeds/screens/register_screen.dart';
import 'package:mindmeds/screens/reminder_popup.dart';
import 'package:mindmeds/services/notification_service.dart';
import 'package:mindmeds/services/permission_service.dart';
import 'package:mindmeds/services/storage_service.dart';
import 'package:mindmeds/services/tts_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:google_fonts/google_fonts.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar timezone y establecer zona local
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Lisbon'));

  // Inicializar Firebase
  await Firebase.initializeApp();

  // Configuración inicial de notificaciones
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Solicitar permiso para notificaciones en Android 13+
  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    final granted = await androidImplementation.requestPermission();
    print('Notification permission granted: $granted');
  }

  // Inicializar permisos adicionales si tienes (ejemplo)
  await requestNotificationPermission();

  // Inicializar Android Alarm Manager
  await AndroidAlarmManager.initialize();

  // Inicializar otros servicios
  await NotificationService().init();
  await TtsService().init();
  await StorageService().init();

  runApp(const MindMedsApp());
}

extension on AndroidFlutterLocalNotificationsPlugin {
  requestPermission() {}
}
class MindMedsApp extends StatelessWidget {
  const MindMedsApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindMeds',
      debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF4FC3F7), // Azul cielo brillante
            onPrimary: Colors.white,
            secondary: Color(0xFFBA68C8), // Lavanda / púrpura suave
            onSecondary: Colors.white,
            error: Color(0xFFD32F2F),
            onError: Colors.white,
            background: Color(0xFFF3F6F9), // Gris muy claro como fondo base
            onBackground: Color(0xFF1A1A1A),
            surface: Colors.white,
            onSurface: Color(0xFF1A1A1A),
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F6F9),
          textTheme: GoogleFonts.ralewayTextTheme().copyWith(
            bodyLarge: const TextStyle(fontSize: 18, height: 1.6, color: Color(0xFF1A1A1A)),
            bodyMedium: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF333333)),
            titleLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4FC3F7)),
            labelMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFBA68C8)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
            ),
            labelStyle: TextStyle(
              color: Color(0xFFBA68C8),
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
            ),
            prefixIconColor: Color(0xFFBA68C8),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4FC3F7),
              side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ),

      home: const AuthGate(),
      routes: {
        '/login': (c) => const LoginScreen(),
        '/register': (c) => const RegisterScreen(),
        '/home': (c) => const HomeScreen(),
        '/add_medication': (c) => const AddMedicationScreen(),
        '/reminder_popup': (c) => const ReminderPopupScreen(),
        '/history': (c) => const HistoryScreen(),
        '/profile': (c) => const ProfileScreen(),
        '/accessibility': (c) => const AccessibilitySettingsScreen(),
      },
    );
  }
}


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _showNotificationDialog(BuildContext context) async {
    await Future.delayed(Duration.zero); // Asegura que se ejecute después del build

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso de notificaciones'),
        content: const Text(
            'Necesitamos permiso para recordarte tomar tus medicamentos.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              requestNotificationPermission();
            },
            child: const Text('Permitir'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Loading
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          // Usuario logueado: ir a Home
          return const GlobalBackground(child: HomeScreen());
        } else {
          // No logueado: ir a Login
          return const GlobalBackground(child: LoginScreen());
        }
      },
    );
  }
}

class GlobalBackground extends StatelessWidget {
  final Widget child;
  const GlobalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF3F6F9), // Gris claro
            Color(0xFF4FC3F7), // Azul suave
            Color(0xFFBA68C8), // Lavanda calmante
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
