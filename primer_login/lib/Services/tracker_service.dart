import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Resources/SharedAudio.dart';

class TrackerService {
  final String trackerUrl = "http://34.175.220.81:8080"; // IP del servidor Tracker en la VM de Google Cloud Console

  // REGISTER AN USER
  Future<void> registerUser(String name, String action, String fileId, String fileName) async {
    try {
      final response = await http.post(
        Uri.parse('$trackerUrl/register'),
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

  Future<List<String>> getMySharedAudiosId(String user) async {
    final uri = Uri.parse('$trackerUrl/shared')
        .replace(queryParameters: {'owner': user});

    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      // Cada elemento es un SharedAudio JSON, extraemos el fileId
      return list
          .map((e) => e['fileId'] as String)
          .toList();
    } else {
      // Si hay error, mejor devolver lista vacía y loguear:
      print('Error fetching shared IDs: ${resp.statusCode} ${resp.body}');
      return [];
    }
  }

  // GET ALL SHARED AUDIOS IN NETWORK
  Future<List<SharedAudio>> getSharedAudios() async {
    final response = await http.get(Uri.parse('$trackerUrl/shared'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      print("Audios compartidos obtenidos");
      return data.map((e) => SharedAudio.fromJson(e)).toList();
    } else {
      print("Error al obtener audios compartidos: ${response.body}");
      return [];
    }
  }
}

