import 'package:flutter/material.dart';
import '../Resources/SharedAudio.dart';
import '../Services/tracker_service.dart';
import '../Services/drive_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TrackerService _trackerService = TrackerService();
  final DriveService _driveService = DriveService();
  List<SharedAudio> allAudios = [];
  List<SharedAudio> filteredAudios = [];

  @override
  void initState() {
    super.initState();
    _loadAudios();
  }

  // LOAD ALL SHARED AUDIOS IN NETWORK
  Future<void> _loadAudios() async {
    final audios = await _trackerService.getSharedAudios();
    print("Audios compartiendo: ${audios.length}");
    setState(() {
      allAudios = audios;
      //filteredAudios = audios;
    });
  }

  void _filterAudios(String query) {
    print("Filtrando audios: $query");
    filteredAudios.clear(); // Limpiar resultados anteriores
    setState(() {
      filteredAudios = allAudios
          .where((audio) => audio.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar audios")),
      body: Padding(
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
                              print('Seleccionado: ${audio.name} desde ${audio.ip}');
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Descargar'),
                              onPressed: () async {
                                // Asume 'root' o la carpeta destino conocida
                                final String? destinationFolderId = await _driveService.getFolderId("P2P-Audio-Share");
                                final newId = await _driveService.copyFile(
                                  audio.fileId,
                                  destinationFolderId,
                                  audio.name,
                                );
                                if (newId != null) {
                                  // Notificación en pantalla
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Archivo descargado con ID: $newId')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error al descargar el archivo')),
                                  );
                                }
                              },
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
    );
  }
}

