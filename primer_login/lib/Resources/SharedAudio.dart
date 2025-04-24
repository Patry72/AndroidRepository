class SharedAudio {
  final String name;
  final String fileId;
  final String ip;
  final String owner;

  SharedAudio({
    required this.name,
    required this.fileId,
    required this.ip,
    required this.owner,
  });

  // Método para crear una instancia de Shared audio desde un JSON
  factory SharedAudio.fromJson(Map<String, dynamic> json) {
    return SharedAudio(
      name: json['name'],
      fileId: json['fileId'],
      ip: json['ip'],
      owner: json['owner'],
    );
  }
}