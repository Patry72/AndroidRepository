import 'dart:convert';
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


  // SUBIDA DE ARCHIVO
  Future<String?> uploadFile(String folderId, String filePath, String fileName) async {
    final googleUser = await _googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;

    if (googleAuth == null) {
      print("Usuario no autenticado");
      return null;
    }

    final accessToken = googleAuth.accessToken;
    final url = 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart';

    var file = File(filePath);
    var fileBytes = await file.readAsBytes();

    // Detectar el tipo MIME del archivo (ejemplo: audio/mpeg para MP3)
    String? mimeType = lookupMimeType(filePath); // ?? 'audio/mpeg';

    // Si el MIME no se detecta correctamente, lo forzamos a un tipo de audio válido
    if (mimeType == null || mimeType == "application/octet-stream") {
      print("⚠️ Tipo MIME no detectado, usando audio/mpeg por defecto");
      mimeType = "audio/mpeg"; // Asumimos MP3 por defecto
    }

    print("📂 Archivo: $fileName");
    print("📑 Tipo MIME detectado: $mimeType");

    var metadata = jsonEncode({
      'name': fileName,
      'parents': [folderId], // Subir el archivo a la carpeta especificada
      'mimeType': mimeType, // Especificar el tipo de contenido
    });

    var request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = 'multipart/related; boundary=boundary';
      /*..fields['metadata'] = jsonEncode(metadata)
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName, contentType: MediaType.parse(mimeType)));*/

    // Agregar los metadatos del archivo
    request.files.add(http.MultipartFile.fromString(
      'metadata',
      metadata,
      contentType: MediaType('application', 'json'),
    ));

    // Agregar el archivo como datos binarios con el tipo MIME correcto
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(mimeType), // Usa el tipo MIME detectado
    ));

    var response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      print("Archivo subido!, ID: ${jsonResponse['id']}");
      return jsonResponse['id']; // Devuelve el ID del archivo subido
    } else {
      print("Error al subir archivo: ${await response.stream.bytesToString()}");
      return null;
    }
  }

  // OBTENCIÓN DE ID DE CARPETA POR NOMBRE
  Future<String?> getFolderId(String folderName, final googleAuth) async {

    final accessToken = googleAuth.accessToken;
    final url =
        'https://www.googleapis.com/drive/v3/files?q=name="$folderName"+and+mimeType="application/vnd.google-apps.folder"+and+trashed=false&fields=files(id,name,parents)';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List files = data['files'];

      if (files.isNotEmpty) {
        for (var file in files) {
          print("Carpeta encontrada: ${file['name']} (ID: ${file['id']})");

          // Verificar si la carpeta realmente está en la raíz de Drive
          if (file.containsKey('parents')) {
            return file['id']; // Devuelve el ID si es una carpeta válida
          }
        }
      }
    } else {
      print("Error al buscar carpeta: ${response.body}");
    }

    return null; // Retorna null si no se encontró la carpeta
  }

  // CREACIÓN DE CARPETA
  Future<String?> createFolder(String folderName) async {
    final googleUser = await _googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;

    if (googleAuth == null) {
      print("Usuario no identificado");
      return null; // No autenticado
    }

    /*print('Mostrando carpetas actuales...');
    listAllFolders();*/

    print('Buscando carpeta...');

    // Primero, verificar si la carpeta ya existe
    String? existingFolderId = await getFolderId(folderName, googleAuth);
    if (existingFolderId != null) {
      print("La carpeta ya existe en Drive con ID: $existingFolderId");
      return existingFolderId; // Retorna el ID de la carpeta existente
    }

    print('Creando carpeta...');

    final accessToken = googleAuth.accessToken;
    final url = 'https://www.googleapis.com/drive/v3/files';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print("Carpeta creada, ID: ${data['id']}");
      /*print('Mostrando carpetas nuevas...');
      listAllFolders();*/
      return data['id']; // Retorna el ID de la carpeta creada
    } else {
      print("Error al crear carpeta: ${response.body}");
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
    final googleUser = await _googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;

    if (googleAuth == null) {
      print("Usuario no identificado");
      return null;
    }

    final accessToken = googleAuth.accessToken;
    final url = 'https://www.googleapis.com/drive/v3/files?q="$folderId"+in+parents&fields=files(id,name)';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List files = data['files'];

      return files.map((file) {
        return {
          'id': file['id'].toString(),
          'name': file['name'].toString(),
        };
      }).toList();
    } else {
      print("Error al obtener archivos: ${response.body}");
      return null;
    }
  }

  // OBTENCIÓN DE URL DE ARCHIVO
  Future<String> getFileUrl(String fileId) async {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  // HACER PÚBLICO UN ARCHIVO
  Future<void> makeFilePublic(String fileId) async {
    final headers = await getAuthHeaders();

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
      print("Archivo $fileId ahora es público.");
    } else {
      print("Error al hacer público el archivo: ${response.body}");
    }
  }

  // REVOCAR PERMISOS PÚBLICO DE UN ARCHIVO
  Future<void> revokePublicPermission(String fileId) async {
    final headers = await getAuthHeaders();

    // Paso 1: obtener todos los permisos del archivo
    final permissionsUrl = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId/permissions');
    final permissionsResp = await http.get(permissionsUrl, headers: headers);

    if (permissionsResp.statusCode != 200) {
      print("No se pudieron obtener los permisos: ${permissionsResp.body}");
      return;
    }

    final permissions = jsonDecode(permissionsResp.body);
    final permission = (permissions['permissions'] as List)
        .firstWhere((p) => p['type'] == 'anyone', orElse: () => null);

    if (permission == null) {
      print("No hay permiso público que revocar.");
      return;
    }

    final permissionId = permission['id'];

    // Paso 2: eliminar ese permiso
    final deleteUrl = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/permissions/$permissionId',
    );

    final deleteResp = await http.delete(deleteUrl, headers: headers);

    if (deleteResp.statusCode == 204) {
      print("Permiso público revocado correctamente.");
    } else {
      print("Error al revocar permiso: ${deleteResp.body}");
    }
  }


}
