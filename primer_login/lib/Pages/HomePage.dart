import 'package:flutter/material.dart';
import '../Services/drive_service.dart';
import '../Services/tracker_service.dart';
import '../Pages/searchPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final String folderId;
  final String username;

  const HomePage({super.key, required this.folderId, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late String username;
  final player = AudioPlayer();   // Instancia de reproductor de audio
  String? selectedAudio;
  int currentIdx = -1;
  bool isPlaying = false;
  List<Map<String, String>>? files;
  bool isLoading = true;
  final DriveService _driveService = DriveService();
  final TrackerService _trackerService = TrackerService();
  Map<String, bool> filesShare = {}; // Map con estado de archivos compartidos

  // Para liberar recursos del reproductor de audio
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    username = widget.username;
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
  void _playAudio(int index) async {
    print("Reproduciendo...");

    final file = files![index];
    final fileId = file['id']!;
    final fileName = file['name'] ?? 'Audio';

    if (currentIdx == index) return;

    setState(() {
      currentIdx = index;
      selectedAudio = fileName;
    });

    try {
      // 1. Hacer el archivo público si no lo es
      await _driveService.makeFilePublic(fileId);

      // 2. Reproducir por streaming
      final url = await _driveService.getFileUrl(fileId);
      await player.setUrl(url);
      await player.play();
      setState(() => isPlaying = true);

      // 3. Escuchar cuándo termina la reproducción y revocar permiso
      player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          print("Reproducción finalizada. Revocando permiso...");
          await _driveService.revokePublicPermission(fileId);
        }
      });
    } catch (e) {
      print("Error en reproducción por streaming: $e");
    }

    /*final file = files![index];
    final fileUrl = await _driveService.getFileUrl(file['id']!);

    if (currentIdx == index) return;

    setState(() {
      currentIdx = index;
      selectedAudio = file['name'];
    });

    player.playbackEventStream.listen((event) {
      // Opcional: debug del estado
    }, onError: (e, stackTrace) {
      print("Error reproduciendo el audio: $e");
    });


    await player.setUrl(fileUrl);
    //await player.setUrl("https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3");   // PRUEBA
    player.play();
    setState(() => isPlaying = true);

    player.playerStateStream.listen((state) {
      setState(() => isPlaying = state.playing);
    });*/
  }

  void _togglePlayPause() {
    if (isPlaying) {
      player.pause();
      //isPlaying = false;
    } else {
      player.play();
      //isPlaying = true;
    }
  }

  void _playNext() {
    if (files == null || files!.isEmpty) return;
    int nextIndex = (currentIdx + 1) % files!.length;
    _playAudio(nextIndex);
  }

  void _playPrevious() {
    if (files == null || files!.isEmpty) return;
    int prevIndex = (currentIdx - 1 + files!.length) % files!.length;
    _playAudio(prevIndex);
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
      body: Stack(
          children: [
            isLoading ? const Center(child: CircularProgressIndicator())
                : files == null || files!.isEmpty ? const Center(child: Text("Aún no tienes audios para compartir"))
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
                  onTap: () => _playAudio(index),
                  trailing: ElevatedButton(
                    onPressed: () => _toggleShare(fileId),
                    child: Text(isShared ? "Dejar de compartir" : "Compartir"),
                  ),
                );
              },
            ),
            if (selectedAudio != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedAudio!,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white),
                        onPressed: _playPrevious,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: _playNext,
                      ),
                    ],
                  ),
                ),
              ),
          ],
      ),
      floatingActionButton: FloatingActionButton(   // Botón para subir audio
          onPressed: _pickAndUploadFile,
          tooltip: "Subir archivo",
          child: const Icon(Icons.upload),
      ),
    );
  }

}