class Project {
  String title;
  String description;
  String imageURL;
  String githubRepo;
  double time;
  int likes;
  final String owner;
  final DateTime createdAt;
  DateTime lastModified;
  bool awaitingReview;
  bool reviewed;
  String level;
  final int id;
  String status;
  String hackatimeProjects;

  Project({
    required this.title,
    required this.description,
    required this.reviewed,
    required this.lastModified,
    required this.imageURL,
    required this.githubRepo,
    required this.time,
    required this.likes,
    required this.owner,
    required this.createdAt,
    required this.awaitingReview,
    required this.level,
    required this.id,
    required this.status,
    required this.hackatimeProjects,
  });

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] ?? 0,
      title: row['name'] ?? 'Untitled Project',
      description: row['description'] ?? 'No description provided',
      imageURL: row['image_url'] ?? '',
      githubRepo: row['github_repo'] ?? '',
      time: (row['total_time'] ?? 0.0).toDouble(),
      likes: row['total_likes'] ?? 0,
      owner: row['owner'] ?? 'unknown',
      createdAt: DateTime.parse(row['created_at'] ?? DateTime.now().toString()),
      lastModified: DateTime.parse(
        row['updated_at'] ?? DateTime.now().toString(),
      ),
      awaitingReview: row['awaiting_review'] ?? false,
      level: row['level'] ?? 'unknown',
      status: row['status'] ?? 'unknown',
      reviewed: row['reviewed'] ?? false,
      hackatimeProjects: row['hackatime_projects'] ?? '',
    );
  }
  static Map<String, dynamic> toRow({
    String? title,
    String? description,
    String? imageURL,
    String? githubRepo,
    double? time,
    int? likes,
    DateTime? lastModified,
    bool? awaitingReview,
    String? level,
    String? status,
    bool? reviewed,
    String? hackatimeProjects,
    String? owner,
  }) {
    final map = <String, dynamic>{};
    if (title != null) map['name'] = title;
    if (description != null) map['description'] = description;
    if (imageURL != null) map['image_url'] = imageURL;
    if (githubRepo != null) map['github_repo'] = githubRepo;
    if (time != null) map['total_time'] = time;
    if (likes != null) map['total_likes'] = likes;
    if (lastModified != null) {
      map['updated_at'] = lastModified.toIso8601String();
    }
    if (awaitingReview != null) map['awaiting_review'] = awaitingReview;
    if (level != null) map['level'] = level;
    if (status != null) map['status'] = status;
    if (reviewed != null) map['reviewed'] = reviewed;
    if (hackatimeProjects != null) {
      map['hackatime_projects'] = hackatimeProjects;
    }
    if (owner != null) map['owner'] = owner;
    return map;
  }
}
