import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mime/mime.dart'; // Agregar esta importación para detectar MIME types

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [
    'https://www.googleapis.com/auth/drive.file',
  ]);

  // OBTENCIÓN DE TOKEN (PARA ACCESO A ARCHIVO)
  Future<Map<String, String>> getAuthHeaders() async {
    final GoogleSignInAccount? account = await GoogleSignIn().signIn();
    final auth = await account?.authentication;
    final accessToken = auth?.accessToken;

    return {
      'Authorization': 'Bearer $accessToken',
    };
  }

  // OBTENCIÓN DE HEADERS DE AUTENTICACIÓN
  Future<Map<String, String>> getAuthHeaders2() async {
    final account = await _googleSignIn.signIn();
    final auth = await account?.authentication;
    return {
      'Authorization': 'Bearer ${auth?.accessToken}'
    };
  }

  // OBTENCIÓN DE ID DE CARPETA POR NOMBRE
  Future<String?> getFolderId(String folderName/*, final googleAuth*/) async {
    final headers = await getAuthHeaders2();
    final query = Uri.encodeComponent('name = "$folderName" and mimeType = "application/vnd.google-apps.folder" and trashed = false');
    //final url = 'https://www.googleapis.com/drive/v3/files?q=name="$folderName"+and+mimeType="application/vnd.google-apps.folder"+and+trashed=false&fields=files(id,name,parents)';
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name, parents)');

    final response = await http.get(
      url,
      headers: {
        //'Authorization': 'Bearer $accessToken',
        ...headers,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List files = data['files'];

      if (files.isNotEmpty) {
        for (var file in files) {
          debugPrint("Carpeta encontrada: ${file['name']} (ID: ${file['id']})");

          // Verificar si la carpeta realmente está en la raíz de Drive
          if (file.containsKey('parents')) {
            debugPrint("id: ${file['id']}");
            return file['id']; // Devuelve el ID si es una carpeta válida
          }
        }
      }
    }

    debugPrint("Error al buscar carpeta: ${response.body}");

    return null; // Retorna null si no se encontró la carpeta
  }

  // SUBIDA DE ARCHIVO
  Future<String?> uploadFile(String folderId, String filePath, String fileName) async {
    final url = 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart';
    final headers = await getAuthHeaders2();

    var file = File(filePath);
    var fileBytes = await file.readAsBytes();

    // Detectar el tipo MIME del archivo (ejemplo: audio/mpeg para MP3)
    String? mimeType = lookupMimeType(filePath); // ?? 'audio/mpeg';

    // Si el MIME no se detecta correctamente, lo forzamos a un tipo de audio válido
    if (mimeType == null || mimeType == "application/octet-stream") {
      debugPrint("⚠️ Tipo MIME no detectado, usando audio/mpeg por defecto");
      mimeType = "audio/mpeg"; // Asumimos MP3 por defecto
    }

    debugPrint("📂 Archivo: $fileName");
    debugPrint("📑 Tipo MIME detectado: $mimeType");

    var metadata = jsonEncode({
      'name': fileName,
      'parents': [folderId], // Subir el archivo a la carpeta especificada
      'mimeType': mimeType, // Especificar el tipo de contenido
    });

    var request = http.MultipartRequest('POST', Uri.parse(url))
      /*..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = 'multipart/related; boundary=boundary';*/
      /*..fields['metadata'] = jsonEncode(metadata)
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName, contentType: MediaType.parse(mimeType)));*/
      ..headers.addAll({
        ...headers,
        'Content-Type': 'multipart/related; boundary=boundary',
      })

      // Agregar los metadatos del archivo
      ..files.add(http.MultipartFile.fromString(
        'metadata',
        metadata,
        contentType: MediaType('application', 'json'),
      ))

      // Agregar el archivo como datos binarios con el tipo MIME correcto
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType), // Usa el tipo MIME detectado
      ));

    var response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      debugPrint("Archivo subido!, ID: ${jsonResponse['id']}");
      return jsonResponse['id'] as String; // Devuelve el ID del archivo subido
    } else {
      debugPrint("Error al subir archivo: ${await response.stream.bytesToString()}");
      return null;
    }
  }

  // CREACIÓN DE CARPETA
  Future<String?> createFolder(String folderName) async {
    debugPrint('Buscando carpeta...');

    // Primero, verificar si la carpeta ya existe
    String? existingFolderId = await getFolderId(folderName);
    if (existingFolderId != null) {
      debugPrint("La carpeta ya existe en Drive con ID: $existingFolderId");
      return existingFolderId; // Retorna el ID de la carpeta existente
    }

    debugPrint('Creando carpeta...');

    //final accessToken = googleAuth.accessToken;
    //final url = 'https://www.googleapis.com/drive/v3/files';

    final headers = await getAuthHeaders2();
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files');

    final response = await http.post(
      url,
      headers: {
        //'Authorization': 'Bearer $accessToken',
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      //folderId = data['id'];
      debugPrint("Carpeta creada, ID: ${data['id']}");
      /*print('Mostrando carpetas nuevas...');
      listAllFolders();*/
      return data['id']; // Retorna el ID de la carpeta creada
    } else {
      debugPrint("Error al crear carpeta: ${response.body}");
      return null;
    }
  }

  // LISTADO DE TODAS LAS CARPETAS DE DRIVE (CUIDADO!! INCLUSO LAS DE LA PAPELERA)
  /*Future<void> listAllFolders() async {
    final googleUser = await _googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;

    if (googleAuth == null) {
      print("Usuario no autenticado");
      return;
    }

    final accessToken = googleAuth.accessToken;
    final url =
        'https://www.googleapis.com/drive/v3/files?q=mimeType="application/vnd.google-apps.folder"&fields=files(id,name,parents)';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("Carpetas encontradas en Drive: ${data['files']}");
    } else {
      print("Error al listar carpetas: ${response.body}");
    }
  }*/


  // LISTADO DE ARCHIVOS
  Future<List<Map<String, String>>?> listFilesInFolder(String folderId) async {

    final headers = await getAuthHeaders2();
    //final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q="$folderId"+in+parents&fields=files(id,name)');
    final query = Uri.encodeComponent('"$folderId" in parents and trashed = false');
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)');

    final response = await http.get(
      url,
      headers: {
        ...headers,  //'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List files = data['files'] as List;

      return files.map((file) {
        return {
          'id': file['id'].toString(),
          'name': file['name'].toString(),
        };
      }).toList();
    } else {
      debugPrint("Error al obtener archivos: ${response.body}");
      return null;
    }
  }

  // OBTENCIÓN DE URL DE ARCHIVO
  Future<String> getFileUrl(String fileId) async {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  // HACER PÚBLICO UN ARCHIVO
  Future<void> makeFilePublic(String fileId) async {
    final headers = await getAuthHeaders2();

    final response = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/permissions'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "role": "reader",
        "type": "anyone"
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      debugPrint("Archivo $fileId ahora es público.");
    } else {
      debugPrint("Error al hacer público el archivo: ${response.body}");
    }
  }

  // REVOCAR PERMISOS PÚBLICO DE UN ARCHIVO
  Future<void> revokePublicPermission(String fileId) async {
    final headers = await getAuthHeaders2();

    // Paso 1: obtener todos los permisos del archivo
    final permissionsUrl = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/permissions');
    final permissionsResp = await http.get(permissionsUrl, headers: headers);

    if (permissionsResp.statusCode != 200) {
      debugPrint("No se pudieron obtener los permisos: ${permissionsResp.body}");
      return;
    }

    final permissions = jsonDecode(permissionsResp.body);
    final permission = (permissions['permissions'] as List)
        .firstWhere((p) => p['type'] == 'anyone', orElse: () => null);

    if (permission == null) {
      debugPrint("No hay permiso público que revocar.");
      return;
    }

    final permissionId = permission['id'];

    // Paso 2: eliminar ese permiso
    final deleteUrl = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/permissions/$permissionId',
    );

    final deleteResp = await http.delete(deleteUrl, headers: headers);

    if (deleteResp.statusCode == 204) {
      debugPrint("Permiso público revocado correctamente.");
    } else {
      debugPrint("Error al revocar permiso: ${deleteResp.body}");
    }
  }

  // TRANSFERENCIA DE AUDIO A MI CARPETA DE DRIVE
  // fileId: ID del audio
  // destFolderId: ID de la carpeta destino (P2P-Audio-Share)
  // newName: nombre del audio
  Future<String?> copyFile(String fileId, String? destFolderId, String newName) async {
    final headers = await getAuthHeaders2();
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/copy');
    final body = jsonEncode({
      'name': newName,
      'parents': [destFolderId],
    });

    final response = await http.post(
      url,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('Se ha descargado correctamente el audio');
      return data['id'] as String;
    } else {
      debugPrint('Error al copiar archivo: ${response.body}');
      return null;
    }
  }

  // ELIMINACIÓN DE UN AUDIO
  Future<void> deleteFile(String fileId) async {
    final headers = await getAuthHeaders2();
    final response = await http.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 204) {
      throw Exception('Error borrando archivo: ${response.body}');
    }
  }
}
