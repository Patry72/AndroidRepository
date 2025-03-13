import 'package:flutter/material.dart';
import '../Services/drive_service.dart';
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
      appBar: AppBar(title: const Text("P2P-Audio-Share")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : files == null || files!.isEmpty
          ? const Center(child: Text("Aún no tienes audios para compartir"))
          : ListView.builder(
              itemCount: files!.length,
              itemBuilder: (context, index) {
                final file = files![index];
                return ListTile(
                  title: Text(file['name'] ?? "Archivo"),
                  leading: const Icon(Icons.insert_drive_file),
                  onTap: () {  // Acción al tocar un archivo (ejemplo: descargar)
                  },
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