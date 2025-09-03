import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'drive_service.dart';
import 'notification_service.dart';

class DownloadService {
  final DriveService _driveService = DriveService();

  Future<void> downloadAndNotify({
    required String fileId,
    required String link,
    required String name,
    required Function(String) onStart,
    required Function(String) onComplete,
    required Function(String) onError,
  }) async {
    onStart(fileId);

    try {
      final String? destinationFolderId =
      await _driveService.getFolderId("P2P-Audio-Share");

      final String? downloaded = await _driveService.uploadFileFromLink(
        link,
        name,
        destinationFolderId!,
      );

      if (downloaded != null) {
        onComplete(fileId);
        await _showNotification(name);
      } else {
        onError(fileId);
      }
    } catch (e) {
      onError(fileId);
    }
  }

  Future<void> _showNotification(String fileName) async {
    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Descargas',
      channelDescription: 'Notificaciones de descarga de audio',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await NotificationService.plugin.show(
      0,
      'Descarga completada',
      'El archivo $fileName se ha descargado correctamente.',
      notificationDetails,
    );
  }
}
