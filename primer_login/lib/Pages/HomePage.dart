import 'package:flutter/material.dart';
import '../Services/drive_service.dart';
import '../Services/tracker_service.dart';
import '../Pages/searchPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Para MediaType

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
  int currentAudioIdx = -1;
  bool isPlaying = false;
  List<Map<String, String>>? files;
  bool isLoading = true;
  final DriveService _driveService = DriveService();
  final TrackerService _trackerService = TrackerService();
  Map<String, bool> filesShare = {}; // Map con estado de archivos compartidos
  Map<String, bool> filesLike = {};  // Map con estado de archivos con Me gusta
  Duration duration = Duration.zero;  // Para el panel de reproducción
  Duration position = Duration.zero;  // Para el panel de reproducción
  bool panelHide = false;  // Para ocultar o no el panel de reproducción

  // TO FREE RESOURCES FROM AUDIO PLAYER
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    username = widget.username;

    // Cargamos los audios disponibles en Drive
    _loadFiles();

    // Escucha cambios de duración y posición
    player.durationStream.listen((dur) {
      if (dur != null) setState(() => duration = dur);
    });
    player.positionStream.listen((pos) {
      setState(() => position = pos);
    });
  }

  // CARGA DE AUDIOS PERSONALES DE DRIVE
  Future<void> _loadFiles() async {
    setState(() => isLoading = true);

    // Listamos audios de la carpeta de Drive
    final fileList = await _driveService.listFilesInFolder(widget.folderId);

    // Obtenemos los audios que tenemos compartiendo
    final sharedIds = await _trackerService.getMySharedAudiosId(username);

    setState(() {
      files = fileList;
      isLoading = false;

      // Inicializamos los mapas según lo recuperado
      for (var file in files!) {
        final id = file['id']!;
        filesShare[id] = sharedIds.contains(id);
        filesLike.putIfAbsent(id, () => false); // Asegura que cada id tiene un valor
      }
    });
  }

  // CHANGE FROM LIKED TO NO LIKED
  void _toggleLike(String fileId) {
    setState(() {
      filesLike[fileId] = !(filesLike[fileId] ?? false);
    });

    // IMPLEMENTACIÓN FUTURA //
  }


  // CHANGE FROM SHARED TO NOT SHARED
  Future<void> _toggleShare(String fileId) async {
    setState(() {
      filesShare[fileId] = !(filesShare[fileId] ?? false);
    });

    // Obtenemos audio y su nombre
    final file = files!.firstWhere((f) => f['id'] == fileId);
    final fileName = file['name'] ?? 'nameless_audio.mp3';

    // Enviamos petición al Tracker según si compartimos o dejamos de compartir un audio
    if (filesShare[fileId] == true) {
      debugPrint("Archivo compartido: $fileId");
      await _trackerService.registerUser(username, "register", fileId, fileName);
    } else {
      debugPrint("Archivo dejado de compartir: $fileId");
      await _trackerService.registerUser(username, "unregister", fileId, fileName);
    }
  }

  // UPLOAD AUDIO FROM LOCAL STORAGE
  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio, // Solo permite archivos de audio
    );

    if (result != null && result.files.isNotEmpty) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;

      debugPrint("Archivo seleccionado: $fileName");

      String? fileId = await _driveService.uploadFile(widget.folderId, filePath, fileName);

      if (fileId != null) {
        debugPrint("Archivo subido con éxito: $fileId");
        _loadFiles(); // Refrescar la lista de archivos
      } else {
        debugPrint("Error al subir el archivo");
      }

      // Enviamos el audio al servidor para análisis
      try {
        final uri = Uri.parse('http://34.175.220.81:8080/api/analyze');  // MODIFICAR
        final request = http.MultipartRequest('POST', uri)
        // Opcional: enviamos también el fileId para rastrear
          ..fields['fileId'] = fileId!  // Se ha incluido ! para checkear nulidad
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Análisis completado:\n$report')),);
        } else {
          debugPrint('Error al iniciar análisis: ${resp.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en análisis: ${resp.statusCode}')),);
        }
      } catch (e) {
        debugPrint('Excepción enviando audio al servidor: $e');
      }

    }

    // Refrescamos lista de audios cuando acabe el análisis
    await _loadFiles();

  }

  // PLAY A SELECTED AUDIO
  void _playAudio(int index) async {
    debugPrint("Reproduciendo...");

    final file = files![index];
    final fileId = file['id']!;
    final fileName = file['name'] ?? 'Audio';

    // Si seleccionamos el mismo no hace nada
    if (currentAudioIdx == index) return;

    // En otro caso, actualizamos índice
    setState(() {
      currentAudioIdx = index;
      selectedAudio = fileName;
    });

    try {
      // Hacemos el archivo público si no lo es
      await _driveService.makeFilePublic(fileId);

      // Reproducimos audio por streaming
      final url = await _driveService.getFileUrl(fileId);
      await player.setUrl(url);
      await player.play();
      setState(() => isPlaying = true);

      // Revocar permisos cuando acabe la reproucción del audio
      player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          print("Reproducción finalizada. Revocando permiso...");
          await _driveService.revokePublicPermission(fileId);
        }
      });
    } catch (e) {
      debugPrint("Error en reproducción por streaming: $e");
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

  // SWITCH TO PLAY/PAUSE
  void _togglePlayPause() {
    if (isPlaying) {
      player.pause();
      //isPlaying = false;
    } else {
      player.play();
      //isPlaying = true;
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  // PLAY NEXT AUDIO
  void _playNext() {
    if (files == null || files!.isEmpty) return;
    // Acotamos índice (Round Robbin)
    int nextIndex = (currentAudioIdx + 1) % files!.length;
    _playAudio(nextIndex);
  }

  // PLAY PREVIOUS AUDIO
  void _playPrevious() {
    if (files == null || files!.isEmpty) return;
    // Acotamos índice (Round Robbin)
    int prevIndex = (currentAudioIdx - 1 + files!.length) % files!.length;
    _playAudio(prevIndex);
  }

  // RESET A DURATION AS mm:ss
  String _formatDuration(Duration d) {
    final twoDigits = (int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("P2P-Audio-Share"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),   // Icono de búsqueda
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
              _loadFiles();
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,  // reduce el padding horizontal por defecto
                  ),
                  title: Text(file['name'] ?? "Archivo"),
                  leading: const Icon(Icons.music_note),
                  onTap: () => _playAudio(index),
                  trailing: Row(
                      mainAxisSize: MainAxisSize.min,  // muy importante para no obligar al Row a ocupar todo el ancho
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 20.0),  // espacio extra al botón
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => _toggleShare(fileId),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(36, 36),
                                shape: const CircleBorder(),
                              ),
                              child: Icon(
                                isShared ? Icons.public_off : Icons.public_sharp,
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        // Botón de Like
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              filesLike[fileId]! ? Icons.favorite : Icons.favorite_border,
                              color: filesLike[fileId]! ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => _toggleLike(fileId),
                          ),
                        ),
                      ],
                  ),
                );
              },
            ),
            // PANEL DE REPRODUCCIÓN
            if (selectedAudio != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  //width: MediaQuery.of(context).size.width * 0.8, // ocupa 80% del ancho
                  duration: const Duration(milliseconds: 200),
                  height: panelHide ? 120 : 48,
                  color: Colors.green,
                  //padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              panelHide ? Icons.expand_more : Icons.expand_less,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                panelHide = !panelHide;
                              });
                            },
                          ),
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
                      if (panelHide) ...[
                        Row(
                          children: [
                            // Tiempo transcurrido
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                activeColor: Colors.white,
                                inactiveColor: Colors.white38,
                                min: 0,
                                max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                                value: position.inMilliseconds
                                    .clamp(0, duration.inMilliseconds)
                                    .toDouble(),
                                onChanged: (value) {
                                  setState(() {
                                    position = Duration(milliseconds: value.toInt());
                                  });
                                },
                                onChangeEnd: (value) {
                                  player.seek(Duration(milliseconds: value.toInt()));
                                },
                              ),
                            ),
                            // Duración total
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120.0),
        child: FloatingActionButton(   // Botón para subir audio
          onPressed: _pickAndUploadFile,
          tooltip: "Subir archivo",
          child: const Icon(Icons.upload),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }

}