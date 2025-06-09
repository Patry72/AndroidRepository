class SharedAudio {
  final String name;
  final String fileId;
  final String owner;
  //final String ip;
  final String link;

  SharedAudio({
    required this.name,
    required this.fileId,
    required this.owner,
    //required this.ip,
    required this.link,
  });

  // Método para crear una instancia de Shared audio desde un JSON
  factory SharedAudio.fromJson(Map<String, dynamic> json) {
    return SharedAudio(
      name: json['fileName'],
      fileId: json['fileId'],
      owner: json['user'],
      //ip: json['ip'],
      link: json['link'],
    );
  }
}