class Devlog {
  final String id;
  final DateTime createdAt;
  final String projectId;
  String title;
  String description;
  List<String> mediaUrls;

  Devlog({
    required this.id,
    required this.createdAt,
    required this.projectId,
    required this.title,
    required this.description,
    this.mediaUrls = const [],
  });

  factory Devlog.fromJson(Map<String, dynamic> json) {
    return Devlog(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      projectId: json['project']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      mediaUrls:
          (json['media_urls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList() ??
          [],
    );
  }
}
