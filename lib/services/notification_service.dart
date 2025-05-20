import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void medicationAlarmCallback(int id) async {
  final now = DateTime.now();
  print("[$now] Medication alarm triggered! Alarm ID: $id");

  // Inicializa el plugin de notificaciones dentro del callback
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'med_channel',
    'Medication Reminders',
    channelDescription: 'Medication reminder notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
  NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id,
    'Medication Reminder',
    'It\'s time to take your medication!',
    notificationDetails,
  );
}
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }


  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    print('[NotificationService] Scheduling notification: id=$id, title="$title", body="$body", at $scheduledDate');

    const androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Channel for medication reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      // matchDateTimeComponents: DateTimeComponents.time, // si quieres repetir
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    print('[NotificationService] Showing immediate notification: id=$id, title="$title", body="$body"');

    const androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Channel for medication reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    print('[NotificationService] Cancelling notification: id=$id');
    await flutterLocalNotificationsPlugin.cancel(id);
  }


}
