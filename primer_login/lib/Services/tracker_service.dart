import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackerService {
  final String trackerUrl = "http://192.168.1.108:8080/register"; // IP del servidor Tracker

  Future<void> registerUser(String name, String action, String fileId, String fileName) async {
    try {
      final response = await http.post(
        Uri.parse(trackerUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "action": action,
          "fileId": fileId,
          "filename": fileName
        }),
      );

      if (response.statusCode == 200) {
        print("Respuesta del Tracker: ${response.body}");
      } else {
        print("Error al contactar con el Tracker: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción al registrar usuario: $e");
    }
  }
}
