import 'package:flutter/material.dart';
//import 'package:flutter_widgets/Pages/LoginPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Pages/LoginPage.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'Services/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = NotificationService();
  await notificationService.init();

  await notificationService.requestNotificationPermission(); // si es Android 13+

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      // Primera página que se ejecutará será la de login
      home: LoginPage(),
    );
  }
}
