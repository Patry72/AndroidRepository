import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Resources/SharedAudio.dart';
import '../Services/tracker_service.dart';
import '../Services/drive_service.dart';
import '../Services/notification_service.dart';
import '../Services/download_service.dart';


class SearchPage extends StatefulWidget {
  final List<TrackerService> trackers;
  final ValueNotifier<bool> downloadedNotif;

  const SearchPage({super.key, required this.trackers, required this.downloadedNotif});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  //final TrackerService _trackerService = TrackerService("http://34.175.220.81:8080"); // De momento sólo busca en tracker-1
  bool isDownloading = false;
  Set<String> downloadingFiles = {};
  final DriveService _driveService = DriveService();
  final DownloadService _downloadService = DownloadService();
  //List<SharedAudio> allAudios = [];
  List<SharedAudio> filteredAudios = [];

  @override
  void initState() {
    super.initState();
    //_loadAudios();
  }



  // LOAD ALL SHARED AUDIOS IN NETWORK
  /*Future<void> _loadAudios() async {
    // Obtenemos todos los audios que se están compartiendo
    final audios = await _trackerService.getSharedAudios();

    debugPrint("Audios compartiendo: ${audios.length}");

    setState(() {
      // Inicializamos los audios compartiendo
      allAudios = audios;
      //filteredAudios = audios;
    });
  }*/

  void _filterAudios(String query) async {
    debugPrint("Filtrando audios: $query");
    debugPrint("query empty?: ${query.isEmpty}");

    // Limpiamos resulatdos anteriores
    filteredAudios.clear();

    // Obtenemos tracker más cercano
    final int bestTracker = await _findTracker();

    debugPrint('Conectando al tracker ${bestTracker+1}');

    try {
      final results = await widget.trackers[bestTracker].searchAudios(query);
      setState(() {
        filteredAudios = results;
        debugPrint("tamaño de filteredAudios: ${filteredAudios.length}");
      });
    } catch (e) {
      debugPrint("Error al buscar audios: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al buscar audios")),
      );
    }

    /*setState(() {
      // Filtramos por las palabras de búsqueda
      filteredAudios = allAudios
          .where((audio) => audio.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });*/

  }

  Future<int> _findTracker() async {
    List<int> latencies = [];

    // Medimos la latencia a cada tracker
    //final ping1 = widget.trackers[0].findTracker();
    //final ping2 = widget.trackers[1].findTracker();

    // Esperamos ambos resultados
    //latencies.add(await ping1);
    //latencies.add(await ping2);
    //latencies[0] = await widget.trackers[0].findTracker();
    //latencies[1] = await widget.trackers[1].findTracker();

    final results = await Future.wait([
      widget.trackers[0].findTracker(),
      widget.trackers[1].findTracker(),
    ]);
    latencies = results;

    debugPrint('lat del tracker-1: ${latencies[0]}');
    debugPrint('lat del tracker-2: ${latencies[1]}');

    // Determinamos el orden de referencia
    if (latencies[0] <= latencies[1]) {
      debugPrint('mejor tracker-1');
      // Si el tracker-1 es más cercano devolvemos su índice
      return 0;
    }
    debugPrint('mejor tracker-2');

    // Si no devolvemos el índice del tracker-2
    return 1;
  }

  Future<void> showDownloadNotification(String fileName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'download_channel',
      'Descargas',
      channelDescription: 'Notificaciones de descarga de audio',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await NotificationService.plugin.show(
      0,
      'Descarga completada',
      'El archivo $fileName se ha descargado correctamente.',
      platformChannelSpecifics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar audios")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Buscar...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onSubmitted: _filterAudios,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: filteredAudios.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.headphones, size: 64, color: Colors.grey),
                        const SizedBox(height: 20),
                        const Text("No se encontraron audios", style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredAudios.length,
                    itemBuilder: (context, index) {
                      final audio = filteredAudios[index];
                      /*return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(audio.name),
                        subtitle: Text("Compartido por: ${audio.owner}"),
                        onTap: () {
                          // Aquí podrías abrir un reproductor o iniciar descarga
                          print("Seleccionado: ${audio.name} desde ${audio.ip}");
                        },
                      );*/
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(audio.name),
                            subtitle: Text('Compartido por: ${audio.owner}'),
                            onTap: () {
                              debugPrint('Seleccionado: ${audio.name}');
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ElevatedButton.icon(
                              icon: downloadingFiles.contains(audio.fileId)
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.download_rounded),//const Icon(Icons.download_rounded),
                              label: Text(downloadingFiles.contains(audio.fileId) ? 'Descargando...' : 'Descargar'),//const Text('Descargar'),
                              onPressed: downloadingFiles.contains(audio.fileId)
                                  ? null
                                  : () {
                                setState(() {
                                  downloadingFiles.add(audio.fileId);
                                });

                                _downloadService.downloadAndNotify(
                                  fileId: audio.fileId,
                                  link: audio.link,
                                  name: audio.name,
                                  onStart: (_) {}, // Opcional, ya se agregó en el setState
                                  onComplete: (id) {
                                    if (mounted) {
                                      setState(() {
                                        downloadingFiles.remove(id);
                                      });
                                      widget.downloadedNotif.value = true;
                                    }
                                  },
                                  onError: (id) {
                                    if (mounted) {
                                      setState(() {
                                        downloadingFiles.remove(id);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Error al descargar el archivo')),
                                      );
                                    }
                                  },
                                );
                              },

                              /*onPressed: downloadingFiles.contains(audio.fileId)//isDownloading
                                ? null
                                : () async {
                                  if (!mounted) return; // Extra seguro

                                  setState(() {
                                    downloadingFiles.add(audio.fileId);//isDownloading = true;
                                  });
                                // Asume 'root' o la carpeta destino conocida
                                final String? destinationFolderId = await _driveService.getFolderId("P2P-Audio-Share");
                                /*final newId = await _driveService.copyFile(
                                  audio.fileId,
                                  destinationFolderId,
                                  audio.name,
                                );*/
                                final String? downloaded = await _driveService.uploadFileFromLink(
                                    audio.link, audio.name, destinationFolderId!
                                );

                                if (!mounted) return; // Revisa si la pantalla sigue activa

                                setState(() {
                                  downloadingFiles.remove(audio.fileId);//isDownloading = false;
                                });

                                if (downloaded != null) {
                                  widget.downloadedNotif.value = true;
                                  debugPrint('Enviando Notfier true...');

                                  // Notificación en pantalla
                                  /*ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Archivo descargado!')),
                                  );*/
                                  showDownloadNotification(audio.name);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error al descargar el archivo')),
                                  );
                                }
                              },*/
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          /*if (isDownloading)
            Container(
              color: const Color.fromARGB(77, 0, 0, 0), // 0.3 * 255 = 76.5 ≈ 77
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),*/
        ],
      )
    );
  }
}

