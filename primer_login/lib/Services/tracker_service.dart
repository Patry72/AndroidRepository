import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../Resources/SharedAudio.dart';

class TrackerService {
  final String trackerUrl;

  // CONSTRUCTOR que inicializa la url al tracker
  TrackerService(this.trackerUrl);

  /// ==========================
  ///    REGISTRAR UN USUARIO
  ///
  /// name: nombre del usuario
  /// action: acción de registro (register/unregister)
  /// fileId: ID del archivo a compartir
  /// fileName: nombre del archivo a compartir
  /// link: enlace de descarga temporal del archivo
  /// ==========================
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

  /// =================================================
  ///    ENVÍO DE UN ARCHIVO A ANÁLISIS DE COPYRIGHT
  ///
  /// filePath: dirección local del archivo
  /// fileName: nombre del archivo
  /// =================================================
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

  /// ==================================================
  ///    OBTENCIÓN DEL ID DE MIS ARCHIVOS COMPARTIDOS
  ///
  /// user: nombre del usuario
  /// ==================================================
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
      // Si hay error, mejor devolver lista vacía y loguear
      debugPrint('Error fetching shared IDs: ${resp.statusCode} ${resp.body}');
      return [];
    }
  }

  /// ============================
  ///    BÚSQUEDA DE UN ARCHIVO
  ///
  /// query: texto de búsqueda
  /// ============================
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

  /// ========================================
  ///    OBTENCIÓN DE LATENCIA A UN TRACKER
  /// ========================================
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

