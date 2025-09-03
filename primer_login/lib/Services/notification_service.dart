import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> init() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
    );
    await plugin.initialize(settings);
  }
}