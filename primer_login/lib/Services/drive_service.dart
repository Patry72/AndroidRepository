import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_sign_in/google_sign_in.dart';  // Para autenticacióncon Google
import 'package:mime/mime.dart';                      // Para detectar MIME types
import 'auth_service.dart';

class DriveService {
  //final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/drive.file',]);
  final AuthService _authService = AuthService();

  /// === OBTENCIÓN DE TOKEN (PARA ACCESO A ARCHIVO) --> NO LO USO ===
  Future<Map<String, String>> getAuthHeaders() async {
    final GoogleSignInAccount? account = await GoogleSignIn().signIn();
    final auth = await account?.authentication;
    final accessToken = auth?.accessToken;

    return {
      'Authorization': 'Bearer $accessToken',
    };
  }

  /// ===========================================
  ///    OBTENCIÓN DE ID DE CARPETA POR NOMBRE
  ///
  /// folderName: nombre de la carpeta a buscar
  /// ===========================================
  Future<String?> getFolderId(String folderName/*, final googleAuth*/) async {
    // Obtenemos headers para autenticación
    final headers = await _authService.getAuthHeaders2();

    // Construimos la petición para buscar carpetas cuyo nombre coincida con "folderName" y no estén en la Papelera
    final query = Uri.encodeComponent('name = "$folderName" and mimeType = "application/vnd.google-apps.folder" and trashed = false');
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name, parents)');

    // Enviamos la petición
    final response = await http.get(
      url,
      headers: {
        //'Authorization': 'Bearer $accessToken',
        ...headers,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // Si tenemos éxito pasamos la respuesta a JSON
      final data = jsonDecode(response.body);

      // Guardamos los ficheros (carpetas) que encuentra la petición
      final List files = data['files'];

      if (files.isNotEmpty) {
        for (var file in files) {
          debugPrint("✅ Carpeta encontrada: ${file['name']} (ID: ${file['id']})");

          // Verificar si la carpeta realmente está en la raíz de Drive
          if (file.containsKey('parents')) {
            debugPrint("id: ${file['id']}");

            // Devolvemos el ID de la carpeta encontrada
            return file['id'];
          }
        }
      }
    }

    // Si no tenemos éxito devolvemos null
    debugPrint("❌ Error al buscar carpeta: ${response.body}");

    return null;
  }

  /// ========================================
  ///    SUBIDA DE UN ARCHIVO A UNA CARPETA
  ///
  /// folderId: ID de la carpeta destino
  /// filePath: path local al archivo de audio
  /// fileName: nombre del archivo de audio
  /// ========================================
  Future<String?> uploadFile(String folderId, String filePath, String fileName) async {
    // Obtenemos headers para autenticación
    final headers = await _authService.getAuthHeaders2();

    // Construimos la petición para subir un archivo de tipo multipart
    // Multipart es un tipo de medio definido en HTTP para subir archivos u otros datos
    final url = 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart';

    // Obtenemos el archivo y su tamaño en bytes
    var file = File(filePath);
    var fileBytes = await file.readAsBytes();

    // Detectamos el tipo MIME del archivo (ejemplo: audio/mpeg para MP3)
    String? mimeType = lookupMimeType(filePath); // ?? 'audio/mpeg';

    // Si el MIME no se detecta correctamente, lo forzamos a un tipo de audio válido
    if (mimeType == null || mimeType == "application/octet-stream") {
      debugPrint("⚠️ Tipo MIME no detectado, usando audio/mpeg por defecto");
      mimeType = "audio/mpeg"; // Asumimos MP3 por defecto
    }

    debugPrint("Archivo: $fileName");
    debugPrint("Tipo MIME detectado: $mimeType");

    // Contruimos JSON con los metadatos necesarios
    var metadata = jsonEncode({
      'name': fileName,       // Nombre del archivo
      'parents': [folderId],  // ID de la carpeta destino
      'mimeType': mimeType,   // Especificar el tipo de contenido
    });

    // Contruimos la petición para subir el archivo
    var request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll({
        ...headers,
        'Content-Type': 'multipart/related; boundary=boundary',
      })

      // Añadimos los metadatos del archivo
      ..files.add(http.MultipartFile.fromString(
        'metadata',
        metadata,
        contentType: MediaType('application', 'json'),
      ))

      // Añadimos el archivo como datos binarios con el tipo MIME correcto
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType), // Usa el tipo MIME detectado
      ));

    // Enviamos la petición
    var response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Si tenemos éxito obtenemos la respuesta en String y pasamos a JSON y devolvemos el ID del archivo
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      debugPrint("✅ Archivo subido!, ID: ${jsonResponse['id']}");

      return jsonResponse['id'] as String;
    } else {
      // Si no tenemos éxito devolvemos null
      debugPrint("❌ Error al subir archivo: ${await response.stream.bytesToString()}");

      return null;
    }
  }

  /// ============================================
  ///    SUBIDA DE ARCHIVO DESDE ENLACE PÚBLICO
  ///
  /// downloadUrl: enlace público al archivo
  /// newFileName: nombre que tendrá el archivo una vez subido
  /// destFolderId: ID de la carpeta de destino
  /// ============================================
  Future<String?> uploadFileFromLink(String downloadUrl, String newFileName, String destFolderId,) async {
    // Descargamos el archivo como bytes
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      debugPrint('Error al descargar el archivo: ${response.body}');
      return null;
    }

    // Obtenemos autenticación para la subida
    final headers = await _authService.getAuthHeaders2();
    final authToken = headers['Authorization'];

    // Creamos el cuerpo multipart para la subida
    final metadata = {
      'name': newFileName,
      'parents': [destFolderId],
    };

    final boundary = 'boundary123456';
    final body = <int>[]
      ..addAll(utf8.encode('--$boundary\r\n'))
      ..addAll(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..addAll(utf8.encode(jsonEncode(metadata)))
      ..addAll(utf8.encode('\r\n--$boundary\r\n'))
      ..addAll(utf8.encode('Content-Type: audio/mpeg\r\n\r\n'))
      ..addAll(response.bodyBytes)
      ..addAll(utf8.encode('\r\n--$boundary--'));

    // Enviamos la petición de subida
    final uploadResponse = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {
        'Authorization': authToken!,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (uploadResponse.statusCode == 200) {
      // Si tenemos éxito devolvemos el id del archivo
      final data = jsonDecode(uploadResponse.body);

      debugPrint('✅ Archivo subido con éxito');

      return data['id'];
    } else {
      // Si ni tenemos éxito devolvemos null
      debugPrint('❌ Error al subir archivo: ${uploadResponse.body}');

      return null;
    }
  }

  /// =====================================
  ///    OBTENCIÓN DE ENLACE DE DESCARGA
  ///
  /// fileId: ID del archivo de destino
  /// =====================================
  Future<String?> getDownloadLink(String fileId) async {
    // Obtenemos headers para autenticación
    final headers = await _authService.getAuthHeaders2();

    final url = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId?fields=webContentLink,webViewLink');

    // Enviamos la petición de descarga
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Si tenemos éxito devolvemos el enlace público del archivo
      final data = jsonDecode(response.body);
      debugPrint('✅ Enlace obtenido con éxito!');

      return data['webContentLink'];  // webContentLink: para descarga directa, webViewLink: para abrir en navegador
    } else {
      // Si no tenemos éxito devolvemos null
      debugPrint('❌ Error al obtener enlace: ${response.body}');

      return null;
    }
  }

  /// =========================
  ///    CREACIÓN DE CARPETA
  ///
  /// folderName: nombre de la carpeta destino
  /// =========================
  Future<String?> createFolder(String folderName) async {
    debugPrint('Buscando carpeta...');

    // Primero, verificamos si la carpeta ya existe
    String? existingFolderId = await getFolderId(folderName);

    if (existingFolderId != null) {
      debugPrint("La carpeta ya existe en Drive con ID: $existingFolderId");

      return existingFolderId; // Retorna el ID de la carpeta existente
    }

    //debugPrint('Creando carpeta...');

    // Obtenemos los headers para la autenticación
    final headers = await _authService.getAuthHeaders2();

    final url = Uri.parse('https://www.googleapis.com/drive/v3/files');

    // Enviamos la petición de creación
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
      // Si tenemos éxito pasamos la respuesta a JSON y devolvemos el ID de la carpeta
      final data = jsonDecode(response.body);

      debugPrint("✅ Carpeta creada, ID: ${data['id']}");

      return data['id'];
    } else {
      // Si no tenemos éxito devolvemos null
      debugPrint("❌ Error al crear carpeta: ${response.body}");
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

  /// ==========================
  ///    LISTADO DE ARCHIVOS
  ///
  /// folderId: ID de la carpeta de archivos
  /// ==========================
  Future<List<Map<String, String>>?> listFilesInFolder(String folderId) async {
    // Obtenemos headers para la autenticación
    final headers = await _authService.getAuthHeaders2();

    final query = Uri.encodeComponent('"$folderId" in parents and trashed = false');
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)');

    // Enviamos la petición de listado
    final response = await http.get(
      url,
      headers: {
        ...headers,  //'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // Si tenemos éxito pasamos la respuesta a JSON y devolvemos una lista con los archivos
      final data = jsonDecode(response.body);
      final List files = data['files'] as List;

      debugPrint('✅ Archivos encontrados en carpeta con éxito!');

      return files.map((file) {
        return {
          // Devolvemos el ID y el nombre
          'id': file['id'].toString(),
          'name': file['name'].toString(),
        };
      }).toList();
    } else {
      // Si no tenemos éxito devolvemos null
      debugPrint("❌ Error al obtener archivos: ${response.body}");
      return null;
    }
  }

  /// =======================================
  ///    OBTENCIÓN DE LA URL DE UN ARCHIVO
  ///
  /// fileId: ID del archivo de destino
  /// =======================================
  Future<String> getFileUrl(String fileId) async {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  /// ==============================
  ///    HACER PÚBLICO UN ARCHIVO
  ///
  /// fileId: ID del archivo de destino
  /// ==============================
  Future<void> makeFilePublic(String fileId) async {
    // Obtenemos headers para la autenticación
    final headers = await _authService.getAuthHeaders2();

    // Enviamos la petición de publicación
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
      debugPrint("⚠️ Error al hacer público el archivo: ${response.body}");
    }
  }

  /// =============================================
  ///    REVOCAR PERMISOS PÚBLICOS DE UN ARCHIVO
  ///
  /// fileId: ID del archivo de destino
  /// =============================================
  Future<void> revokePublicPermission(String fileId) async {
    // Obtenemos headers para la autenticación
    final headers = await _authService.getAuthHeaders2();

    // Enviamos la petición para obtener los permisos
    final permissionsUrl = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/permissions');
    final permissionsResp = await http.get(permissionsUrl, headers: headers);

    if (permissionsResp.statusCode != 200) {
      debugPrint("⚠️ No se pudieron obtener los permisos: ${permissionsResp.body}");
      return;
    }

    final permissions = jsonDecode(permissionsResp.body);
    final permission = (permissions['permissions'] as List)
        .firstWhere((p) => p['type'] == 'anyone', orElse: () => null);

    if (permission == null) {
      debugPrint("No hay permiso público que revocar.");
      return;
    }

    // Buscamos el id del permiso
    final permissionId = permission['id'];

    // Eliminar ese permiso
    final deleteUrl = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/permissions/$permissionId',
    );
    final deleteResp = await http.delete(deleteUrl, headers: headers);

    if (deleteResp.statusCode == 204) {
      debugPrint("Permiso público revocado correctamente.");
    } else {
      debugPrint("⚠️ Error al revocar permiso: ${deleteResp.body}");
    }
  }

  /// ===============================================
  ///    TRANSFERENCIA DE AUDIO A CARPETA DE DRIVE
  ///
  /// fileId: ID del archivo a copiar
  /// destFolderId: ID de la carpeta destino (P2P-Audio-Share)
  /// newName: nombre final del archivo
  /// ===============================================
  Future<String?> copyFile(String fileId, String? destFolderId, String newName) async {
    // Obtenemos headers para la autenticación
    final headers = await _authService.getAuthHeaders2();


    final url = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/copy');
    final body = jsonEncode({
      'name': newName,
      'parents': [destFolderId],
    });

    // Enviamos la petición de copia
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
      debugPrint('⚠️ Error al copiar archivo: ${response.body}');
      return null;
    }
  }

  /// ===============================
  ///    ELIMINACIÓN DE UN ARCHIVO
  ///
  /// fileId: ID del archivo destino
  /// ===============================
  Future<void> deleteFile(String fileId) async {
    // Obtenemos headers para la autenticación
    final headers = await _authService.getAuthHeaders2();

    // Enviamos la petición de eliminación
    final response = await http.delete(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 204) {
      throw Exception('⚠️ Error borrando archivo: ${response.body}');
    } else {
      debugPrint('Se ha eliminado correctamente el audio');
    }
  }
}
