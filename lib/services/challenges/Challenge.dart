class Challenge {
  final int id;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final String title;
  final String description;
  final String requirements;
  final bool isActive;
  final int coins;
  final String key;

  Challenge({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.difficulty,
    required this.title,
    required this.description,
    required this.requirements,
    required this.isActive,
    this.coins = 0,
    this.key = '',
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
      difficulty: ChallengeDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == (json['difficulty'] ?? 'easy'),
        orElse: () => ChallengeDifficulty.easy,
      ),
      title: json['title'] ?? 'Untitled Challenge',
      description: json['description'] ?? 'No description provided',
      requirements: json['requirements'] ?? 'No requirements specified',
      isActive: json['active'] ?? false,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      key: json['key'] ?? '',
    );
  }
}

enum ChallengeType { special, weekly, monthly, scratch, base, normal }

enum ChallengeDifficulty { easy, medium, hard }
