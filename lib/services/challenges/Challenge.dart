class Challenge {
  final int id;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final ChallengeType type;
  final String prize;
  final ChallengeDifficulty difficulty;
  final String title;
  final String description;
  final String requirements;
  final bool isActive;

  Challenge({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.prize,
    required this.difficulty,
    required this.title,
    required this.description,
    required this.requirements,
    required this.isActive,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
      startDate: DateTime.parse(
        json['start_date'] ?? DateTime.now().toString(),
      ),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toString()),
      type: ChallengeType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] ?? ''),
        orElse: () => ChallengeType.special,
      ),
      prize: json['prize'] ?? '',
      difficulty: ChallengeDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == (json['difficulty'] ?? 'easy'),
        orElse: () => ChallengeDifficulty.easy,
      ),
      title: json['title'] ?? 'Untitled Challenge',
      description: json['description'] ?? 'No description provided',
      requirements: json['requirements'] ?? 'No requirements specified',
      isActive: json['is_active'] ?? false,
    );
  }
}

enum ChallengeType { special, weekly, monthly, scratch, base, normal }

enum ChallengeDifficulty { easy, medium, hard }
