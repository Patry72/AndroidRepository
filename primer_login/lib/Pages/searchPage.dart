import 'package:flutter/material.dart';

import '../Resources/SharedAudio.dart';
import '../Services/tracker_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();

  //@override
  /*Widget build(BuildContext context) {
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
              onChanged: (value) {
                print("Buscando: $value"); // Aquí irá la lógica de búsqueda
              },
            ),
          ],
        ),
      ),
    );
  }*/
}

class _SearchPageState extends State<SearchPage> {
  final TrackerService _trackerService = TrackerService();
  List<SharedAudio> allAudios = [];
  List<SharedAudio> filteredAudios = [];

  @override
  void initState() {
    super.initState();
    _loadAudios();
  }

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
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(audio.name),
                        subtitle: Text("Compartido por: ${audio.owner}"),
                        onTap: () {
                          // Aquí podrías abrir un reproductor o iniciar descarga
                          print("Seleccionado: ${audio.name} desde ${audio.ip}");
                        },
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

