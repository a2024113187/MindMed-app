import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied ||
      await Permission.notification.isPermanentlyDenied) {
    final status = await Permission.notification.request();

    if (status.isDenied) {
      print('Permiso de notificación denegado');
    } else if (status.isGranted) {
      print('Permiso de notificación concedido');
    }
  }
}
