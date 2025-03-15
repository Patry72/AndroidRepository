import 'package:flutter/material.dart';
import '../Services/drive_service.dart';
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

  void _toggleShare(String fileId) {
    setState(() {
      filesShare[fileId] = !(filesShare[fileId] ?? false);
    });

    if (filesShare[fileId] == true) {
      print("Archivo compartido: $fileId");
      // Aquí puedes llamar a la función para hacer público el archivo en Drive
    } else {
      print("Archivo dejado de compartir: $fileId");
      // Aquí puedes llamar a la función para revocar permisos
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
          )
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
      floatingActionButton: FloatingActionButton(
          onPressed: _pickAndUploadFile,
          tooltip: "Subir archivo",
          child: const Icon(Icons.upload),
      ),
    );
  }

}