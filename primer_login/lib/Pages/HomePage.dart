import 'package:flutter/material.dart';
import '../Services/drive_service.dart';
import '../Services/tracker_service.dart';
import '../Pages/searchPage.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  final String folderId;

  const HomePage({super.key, required this.folderId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List<Map<String, String>>? files;
  bool isLoading = true;
  final DriveService _driveService = DriveService();
  final TrackerService _trackerService = TrackerService();
  String username = "usuario1"; // Puedes obtener esto del login, por ejemplo
  Map<String, bool> filesShare = {}; // Map con estado de archivos compartidos

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // CARGA DE ARCHIVOS
  Future<void> _loadFiles() async {
    final fileList = await _driveService.listFilesInFolder(widget.folderId);

    setState(() {
      files = fileList;
      isLoading = false;
    });
  }

  Future<void> _toggleShare(String fileId) async {
    setState(() {
      filesShare[fileId] = !(filesShare[fileId] ?? false);
    });

    // Obtenemos audio y su nombre
    final file = files!.firstWhere((f) => f['id'] == fileId);
    final fileName = file['name'] ?? 'nameless_audio.mp3';

    if (filesShare[fileId] == true) {
      print("Archivo compartido: $fileId");
      // Aquí puedes llamar a la función para hacer público el archivo en Drive
      await _trackerService.registerUser(username, "register", fileId, fileName);  // Nos registramos en el Tracker
    } else {
      print("Archivo dejado de compartir: $fileId");
      // Aquí puedes llamar a la función para revocar permisos
      await _trackerService.registerUser(username, "unregister", fileId, fileName);
    }
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio, // Solo permite archivos de audio
    );

    if (result != null && result.files.isNotEmpty) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      print("Archivo seleccionado: $fileName");

      String? fileId = await _driveService.uploadFile(widget.folderId, filePath, fileName);

      if (fileId != null) {
        print("Archivo subido con éxito: $fileId");
        _loadFiles(); // Refrescar la lista de archivos
      } else {
        print("Error al subir el archivo");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("P2P-Audio-Share"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),   // Icono de búsqueda
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            }
          ),
          /*IconButton(
            icon: const Icon(Icons.send),  // Icono para enviar
              onPressed: () {

              },
          ),*/
        ]),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : files == null || files!.isEmpty
            ? const Center(child: Text("Aún no tienes audios para compartir"))
            : ListView.builder(
              itemCount: files!.length,
              itemBuilder: (context, index) {
                final file = files![index];
                final fileId = file['id']!;
                // Actualizamos map con estado de cada archivo
                final isShared = filesShare[fileId] ?? false;

                return ListTile(
                  title: Text(file['name'] ?? "Archivo"),
                  leading: const Icon(Icons.music_note),
                  onTap: () {  // Acción al tocar un archivo (ejemplo: descargar)
                  },
                  trailing: ElevatedButton(
                    onPressed: () => _toggleShare(fileId),
                    child: Text(isShared ? "Dejar de compartir" : "Compartir"),
                  ),
                );
              },
          ),
      floatingActionButton: FloatingActionButton(   // Botón para subir audio
          onPressed: _pickAndUploadFile,
          tooltip: "Subir archivo",
          child: const Icon(Icons.upload),
      ),
    );
  }

}