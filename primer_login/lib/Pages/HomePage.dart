import 'package:flutter/material.dart';
import 'package:primer_login/Pages/LoginPage.dart';
import '../Services/drive_service.dart';
import '../Services/tracker_service.dart';
import '../Services/auth_service.dart';
import '../Pages/searchPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Para MediaType
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String folderId;
  final String username;

  const HomePage({super.key, required this.folderId, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late String username;           // Nombre de usuario de Google
  String? selectedAudio;          // Audio seleccionado actualmente
  int currentAudioIdx = -1;       // Índice del audio sonando actualmente
  bool isPlaying = false;         // Audio sonando
  bool isLoading = true;          // Para carga de la página
  bool panelHide = false;         // Para ocultar o no el panel de reproducción
  final player = AudioPlayer();   // Instancia de reproductor de audio

  ValueNotifier<bool> downloadedNotifier = ValueNotifier(false);  // Para notificar cuando se ha descargado un audio

  Duration duration = Duration.zero;  // Para el panel de reproducción
  Duration position = Duration.zero;  // Para el panel de reproducción

  final DriveService _driveService = DriveService();
  final AuthService _authService = AuthService();
  //final TrackerService _tracker1Service = TrackerService("http://34.175.220.81:8080");
  //final TrackerService _tracker2Service = TrackerService("http://34.175.164.1:8080");

  //List<TrackerService> trackers = [TrackerService("http://34.175.220.81:8080"), TrackerService("http://34.175.164.1:8080")];
  late List<TrackerService> trackers;
  List<Map<String, String>>? files;     // Lista de archivos
  Map<String, bool> filesShare = {};    // Map con estado de archivos compartidos
  Map<String, bool> filesLike = {};     // Map con estado de archivos con Me gusta
  Map<String, int> filesInTracker = {}; // Map con número de tracker de los archivos (0: ninguno, 1: tracker-1, 2: tracker-2)

  @override
  void initState() {
    super.initState();
    // Inicializamos el nombre de usuario y la lista de trackers
    username = widget.username;
    trackers = [TrackerService("http://34.175.220.81:8080"), TrackerService("http://34.175.164.1:8080")];

    // Restaura estado previo
    _loadPrevState();

    // Cargamos los audios disponibles en Drive
    //_loadFiles();
    downloadedNotifier.addListener(() {
      if (downloadedNotifier.value == true) {
        debugPrint('Notifier true, cargando audios...');
        _loadFiles();
        downloadedNotifier.value = false;  // Resetear
      }
    });

    // Escucha cambios de duración y posición
    player.durationStream.listen((dur) {
      if (dur != null) setState(() => duration = dur);
    });
    player.positionStream.listen((pos) {
      setState(() => position = pos);
      // Guardamos la posición para próximo inicio
      _savePrevPosition(pos);
    });

    // No he añadido cambios de estado (play/pause) de ChatGPT
  }

  // TO FREE RESOURCES FROM AUDIO PLAYER
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  // CARGA DE AUDIOS PERSONALES DE DRIVE
  Future<void> _loadFiles() async {
    setState(() => isLoading = true);

    // Listamos audios de la carpeta de Drive
    final fileList = await _driveService.listFilesInFolder(widget.folderId);

    // Obtenemos los audios que tenemos compartiendo
    final sharedIds1 = await trackers[0].getMySharedAudiosId(username);
    final sharedIds2 = await trackers[1].getMySharedAudiosId(username);

    setState(() {
      files = fileList;
      isLoading = false;

      // Inicializamos los mapas según lo recuperado
      for (var file in files!) {
        final id = file['id']!;
        final inTracker1 = sharedIds1.contains(id);
        final inTracker2 = sharedIds2.contains(id);
        filesShare[id] = inTracker1 || inTracker2;
        filesLike.putIfAbsent(id, () => false); // Asegura que cada id tiene un valor

        if (inTracker1) {
          filesInTracker[id] = 1;
        } else if (inTracker2) {
          filesInTracker[id] = 2;
        } else {
          filesInTracker[id] = 0;
        }
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


  Future<void> _toggleShare(String fileId, String fileName) async {
    final int state = filesInTracker[fileId] ?? 0;

    final link = await _driveService.getDownloadLink(fileId);

    debugPrint('link de descarga: $link');

    // Si aún no está registrado en ningún tracker, pregunta
    if (state == 0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("¿A qué tracker registrar este audio?"),
            //content: const Text("Selecciona Tracker-1 o Tracker-2"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _registerToTracker(fileId, fileName, link!, 1);
                  _driveService.makeFilePublic(fileId);
                },
                child: const Text("Tracker-1"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _registerToTracker(fileId, fileName, link!, 2);
                  _driveService.makeFilePublic(fileId);
                },
                child: const Text("Tracker-2"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cancelar
                },
                child: const Text("Cancelar"),
              ),
            ],
          );
        },
      );
    // Si está registrado en tracker-1, lo desregistramos de tracker-1
    } else if (state == 1) {
      _unregisterFromTracker(fileId, fileName, link!, 1);
      _driveService.revokePublicPermission(fileId);
    // Si está registrado en tracker-2, lo desregistramos de tracker-2
    } else if (state == 2) {
      _unregisterFromTracker(fileId, fileName, link!, 2);
      _driveService.revokePublicPermission(fileId);
    }
  }

  Future<void> _registerToTracker(String fileId, String fileName, String link, int trackerNumber) async {
    //final servicio = (trackerNumber == 1) ? _tracker1Service : _tracker2Service;
    final servicio = trackers[trackerNumber - 1];
    //final servicio = _tracker1Service;
    // Llamamos a _sendToTracker, que hará registerUser con action="register"
    await _sendToTracker(fileId, fileName, link, servicio);
    setState(() {
      filesInTracker[fileId] = trackerNumber;
      filesShare[fileId] = true;
    });
  }

  Future<void> _unregisterFromTracker(String fileId, String fileName, String link, int trackerNumber) async {
    //final servicio = (trackerNumber == 1) ? _tracker1Service : _tracker2Service;
    final servicio = trackers[trackerNumber - 1];
    //final servicio = _tracker1Service;
    // Para desregistrar, llamamos exactamente al mismo _sendToTracker,
    // porque él detecta que filesShare[fileId] es true y hará action="unregister".
    await _sendToTracker(fileId, fileName, link, servicio);
    setState(() {
      filesInTracker[fileId] = 0;
      filesShare[fileId] = false;
    });
  }

  Future<void> _sendToTracker(String fileId, String fileName, String link, TrackerService tracker) async {
    final currentlyShared = filesShare[fileId] ?? false;
    final action = currentlyShared ? "unregister" : "register";

    try {
      /// Llamamos al método del servicio, pasándole:
      /// - user: username
      /// - action: "register" o "unregister"
      /// - fileId, fileName, link
      await tracker.registerUser(username, action, fileId, fileName, link);

      // Si no hubo excepción, consideramos que el tracker respondió OK (200) internamente
      setState(() {
        filesShare[fileId] = !currentlyShared;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyShared
                ? 'Se dejó de compartir "$fileName"'
                : 'Se compartió "$fileName"',
          ),
        ),
      );
    } catch (e) {
      // Si registerUser lanza excepción, lo capturamos aquí
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error conectando con ${tracker.trackerUrl}: $e'),
        ),
      );
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

      // Enviamos el audio al servidor para análisis
      final report = await trackers[0].sendToServerForAnalysis(filePath, /*fileId,*/ fileName);

      if (report == "Coincidencias encontradas"){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se han detectado derechos de autor.\nNo puede compartir el archivo en la red.')),);
      } else {
        String? fileId = await _driveService.uploadFile(widget.folderId, filePath, fileName);

        if (fileId != null) {
          debugPrint("Archivo subido con éxito: $fileId");
          _loadFiles(); // Refrescar la lista de archivos
        } else {
          debugPrint("Error al subir el archivo");
        }
      }

      //String? fileId = await _driveService.uploadFile(widget.folderId, filePath, fileName);

      /*if (fileId != null) {
        debugPrint("Archivo subido con éxito: $fileId");
        _loadFiles(); // Refrescar la lista de archivos
      } else {
        debugPrint("Error al subir el archivo");
      }*/

      // Enviamos el audio al servidor para análisis
      /*try {
        final uri = Uri.parse('http://34.175.220.81:8080/api/analyze');  // MODIFICAR
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Análisis completado:\n$report')),);
        } else {
          debugPrint('Error al iniciar análisis: ${resp.statusCode}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en análisis: ${resp.statusCode}')),);
        }
      } catch (e) {
        debugPrint('Excepción enviando audio al servidor: $e');
      }*/

    }

    // Refrescamos lista de audios cuando acabe el análisis
    await _loadFiles();

  }

  // DELETE AUDIO FROM APP
  Future<void> _deleteFile(String fileId, String fileName) async {
    try {
      await _driveService.deleteFile(fileId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo "$fileName" eliminado correctamente')),
      );
      _loadFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar "$fileName": $e')),
      );
    }
  }

  void _confirmSignOut() {
    showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: Text('Cerrar Sesión'),
              content: const Text('¿Está seguro? Se cerrará la sesión de su cuenta'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _authService.signOut();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: const Text(
                      'Aceptar', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
    );
  }

  void _confirmDelete(String fileId, String fileName) {
    if (filesShare[fileId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar un archivo que se está compartiendo')),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: Text('Eliminar "$fileName"'),
              content: const Text('¿Estás seguro de eliminar este audio?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteFile(fileId, fileName);
                  },
                  child: const Text(
                      'Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
      );
    }
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

    // Guardamos inmediatamente el nuevo estado
    await _saveAudioState(fileId, fileName, index);

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
          debugPrint("Reproducción finalizada. Revocando permiso...");
          await _driveService.revokePublicPermission(fileId);
        }
      });
    } catch (e) {
      debugPrint("Error en reproducción por streaming: $e");
    }
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
    twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _loadPrevState() async {
    await _loadFiles();
    await _restoreAudioState();
  }

  Future<void> _savePrevPosition(Duration pos) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setInt('savedPositionMs', pos.inMilliseconds);
  }

  Future<void> _saveAudioState(String fileId, String name, int idx) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString('savedFileId', fileId);
    await pref.setString('savedFileName', name);
    await pref.setInt('savedAudioIdx', idx);
  }

  Future<void> _restoreAudioState() async {
    final pref = await SharedPreferences.getInstance();
    final idx      = pref.getInt('savedAudioIdx');
    final fileId   = pref.getString('savedFileId');
    final fileName = pref.getString('savedFileName');
    final posMs    = pref.getInt('savedPositionMs') ?? 0;
    //final playFlag = pref.getBool('savedIsPlaying') ?? false;

    // Comprueba que los archivos ya estén cargados y el índice sea válido
    if (files != null && idx != null && idx >= 0 && idx < files!.length) {
      final f = files![idx];
      if (f['id'] == fileId) {
        setState(() {
          currentAudioIdx = idx;
          selectedAudio = fileName;
          //isPlaying = playFlag;
        });
        try {
          await _driveService.makeFilePublic(fileId!);
          final url = await _driveService.getFileUrl(fileId);
          await player.setUrl(url);
          await player.seek(Duration(milliseconds: posMs));
          //if (playFlag) await player.play();
        } catch (e) {
          debugPrint("Error restaurando audio: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // BARRA SUPERIOR
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("P2P-Audio-Share"),
        backgroundColor: Colors.orange[600],//Color(0xFF26A69A),
        leading: IconButton(
          icon: Icon(Icons.power_settings_new),
          onPressed: () => _confirmSignOut(), /*{
            _authService.signOut();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          },*/
        ),
        actions: [

          // ICONO DE SUBIDA
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _pickAndUploadFile,
            tooltip: "Subir archivo",
          ),

          // ICONO DE BÚSQUEDA
          IconButton(
            icon: const Icon(Icons.search),   // Icono de búsqueda
            onPressed: () /*async*/ {
              /*await*/ Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchPage(trackers: trackers, downloadedNotif: downloadedNotifier)),
              );
              // Esto se ejecuta al volver de SearchPage
              if (downloadedNotifier.value == true) {
                _loadFiles();
                downloadedNotifier.value = false;
              }
              // Volvemos a cargar los audios de Drive al volver
              //_loadFiles();
            }
          ),
        ],
      ),
      body: Stack(
          children: [
            // Añadimos círculo de carga
            isLoading ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: files == null || files!.isEmpty ? const Center(child: Text("Aún no tienes audios para compartir"))
                      : ListView.builder(
                    itemCount: files!.length,
                    itemBuilder: (context, index) {
                      final file = files![index];
                      final name = file['name'] ?? 'Archivo';
                      final fileId = file['id']!;
                      final isShared = filesShare[fileId] ?? false;

                      // LISTA DE AUDIOS DE DRIVE
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0,  // Reduce el padding horizontal por defecto
                        ),
                        title: Text(file['name'] ?? "Archivo"),
                        leading: const Icon(Icons.music_note),
                        onTap: () => _playAudio(index),
                        onLongPress: () => _confirmDelete(fileId, name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,  // Muy importante para no obligar al Row a ocupar todo el ancho
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20.0),  // Espacio extra al botón
                              child: SizedBox(
                                width: 36,
                                height: 36,

                                // BOTÓN DE COMPARTIR
                                child: ElevatedButton(
                                  onPressed: () => _toggleShare(fileId, name),
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

                            // BOTÓN DE LIKE
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
                  color: Colors.orange[600], //Color(0xFF26A69A),
                  //padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          // BOTÓN DE DESPLIEGUE/PLIEGUE
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

                          // BOTÓN DE PLAY/PAUSE
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),

                          // BOTÓN DE ANTERIOR
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white),
                            onPressed: _playPrevious,
                          ),

                          // BOTÓN DE SIGUIENTE
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
      /*floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120.0),
        child: FloatingActionButton(   // Botón para subir audio
          onPressed: _pickAndUploadFile,
          tooltip: "Subir archivo",
          child: const Icon(Icons.upload),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,*/
    );
  }

}