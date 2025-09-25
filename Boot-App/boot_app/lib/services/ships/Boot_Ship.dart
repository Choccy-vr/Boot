class Ship {
  final String id;
  final DateTime createdAt;
  final int project;
  final double time;
  final bool approved;
  final String reviewer;
  final String comment;
  final int earned;

  Ship({
    required this.id,
    required this.createdAt,
    required this.project,
    required this.time,
    this.approved = false,
    this.reviewer = '',
    this.comment = '',
    this.earned = 0,
  });

  factory Ship.fromJson(Map<String, dynamic> json) {
    return Ship(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      project: json['project'] ?? 0,
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      approved: json['approved'] ?? false,
      reviewer: json['reviewer'] ?? '',
      comment: json['comment'] ?? '',
      earned: json['earned'] ?? 0,
    );
  }
}



