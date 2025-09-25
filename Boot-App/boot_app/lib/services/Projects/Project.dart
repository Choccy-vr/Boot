class Project {
  String title;
  String description;
  String imageURL;
  String githubRepo;
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
  double timeDevlogs;
  //not in db
  String readableTime;
  double time;

  Project({
    required this.title,
    required this.description,
    required this.reviewed,
    required this.lastModified,
    required this.imageURL,
    required this.githubRepo,
    required this.likes,
    required this.owner,
    required this.createdAt,
    required this.awaitingReview,
    required this.level,
    required this.id,
    required this.status,
    required this.hackatimeProjects,
    required this.timeDevlogs,
    this.readableTime = '0s',
    required this.time,
  });

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] ?? 0,
      title: row['name'] ?? 'Untitled Project',
      description: row['description'] ?? 'No description provided',
      imageURL: row['image_url'] ?? '',
      githubRepo: row['github_repo'] ?? '',
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
      timeDevlogs: row['total_time_devlogs'] ?? 0.0,
      readableTime: '0s',
      time: 0.0,
    );
  }
  static Map<String, dynamic> toRow({
    String? title,
    String? description,
    String? imageURL,
    String? githubRepo,
    int? likes,
    DateTime? lastModified,
    bool? awaitingReview,
    String? level,
    String? status,
    bool? reviewed,
    String? hackatimeProjects,
    String? owner,
    double? timeDevlogs,
  }) {
    final map = <String, dynamic>{};
    if (title != null) map['name'] = title;
    if (description != null) map['description'] = description;
    if (imageURL != null) map['image_url'] = imageURL;
    if (githubRepo != null) map['github_repo'] = githubRepo;
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
    if (timeDevlogs != null) map['total_time_devlogs'] = timeDevlogs;
    return map;
  }
}



