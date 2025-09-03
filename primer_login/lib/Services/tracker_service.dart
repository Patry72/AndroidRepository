import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../Resources/SharedAudio.dart';

class TrackerService {
  //final String trackerUrl = "http://34.175.164.1:8080"; // IP del servidor Tracker en la VM de Google Cloud Console tracker-vm: 34.175.220.81 tracker-vm-2: 34.175.127.228
  final String trackerUrl;

  // CONSTRUCTOR que inicializa la url al tracker
  TrackerService(this.trackerUrl);

  // REGISTER AN USER
  Future<void> registerUser(String name, String action, String fileId, String fileName, String link) async {
    try {
      final response = await http.post(
        Uri.parse('$trackerUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "action": action,
          "fileId": fileId,
          "filename": fileName,
          "link": link
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Respuesta del Tracker: ${response.body}");
      } else {
        debugPrint("Error al contactar con el Tracker: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Excepción al registrar usuario: $e");
    }
  }

  Future<String> sendToServerForAnalysis(String filePath, /*String fileId,*/ String fileName) async {
      final uri = Uri.parse('$trackerUrl/api/analyze');  // MODIFICAR
      final request = http.MultipartRequest('POST', uri)
      // Opcional: enviamos también el fileId para rastrear
        //..fields['fileId'] = fileId!  // Se ha incluido ! para checkear nulidad
      // Adjuntamos el fichero
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
          contentType: MediaType('audio', fileName.split('.').last),
        ));

      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode == 200) {
        debugPrint('Análisis iniciado correctamente en el servidor');

        // El cuerpo es texto plano con el informe de coincidencias
        final report = resp.body;
        //ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Análisis completado:\n$report')),);
        debugPrint('REPORT: $report');
        return report;
      } else {
        debugPrint('Error al iniciar análisis: ${resp.statusCode}');
        //ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en análisis: ${resp.statusCode}')),);
        return '';
      }

  }

  Future<List<String>> getMySharedAudiosId(String user) async {
    final uri = Uri.parse('$trackerUrl/shared') // Probar a cambiar a myShared para no confundir con el siguiente método
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
      debugPrint('Error fetching shared IDs: ${resp.statusCode} ${resp.body}');
      return [];
    }
  }

  // GET ALL SHARED AUDIOS IN NETWORK --> SE PODRÍA ELIMINAR
  Future<List<SharedAudio>> getSharedAudios() async {
    final response = await http.get(Uri.parse('$trackerUrl/shared'));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      debugPrint("Audios compartidos obtenidos");
      return data.map((e) => SharedAudio.fromJson(e)).toList();
    } else {
      debugPrint("Error al obtener audios compartidos: ${response.body}");
      return [];
    }
  }

  // SEARCH AUDIOS
  Future<List<SharedAudio>> searchAudios(String query) async {
    debugPrint("Buscando audios en tracker...");

    final uri = Uri.parse('$trackerUrl/search2?query=$query');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List/*<dynamic>*/ body = jsonDecode(response.body);
      debugPrint("resul de shared2: ${body.toString()}");
      return body.map((json) => SharedAudio.fromJson(json)).toList();
    } else {
      throw Exception('Error al buscar audios');
    }
  }

  // PING A TRACKER
  Future<int> findTracker() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('Iniciando ping a $trackerUrl ...');
    try {
      final response = await http.get(Uri.parse('$trackerUrl/health')).timeout(Duration(milliseconds: 500));
      stopwatch.stop();
      if (response.statusCode == 200) {
        debugPrint('Ping correcto!');
        return stopwatch.elapsedMilliseconds;
      } else {
        debugPrint('⚠️ Error haciendo ping a $trackerUrl');
        // Si no responde 200, devolvemos un valor grande
        return 9999;
      }
    } catch (_) {
      stopwatch.stop();
      return 9999;
    }
  }
}

