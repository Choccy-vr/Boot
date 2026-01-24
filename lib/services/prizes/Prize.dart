class Prize {
  final String id;
  final DateTime createdAt;
  final String title;
  final String description;
  final String? picture;
  final int cost;
  final int stock;
  final double multiplier;
  final String key;
  final int coins;
  final PrizeType type;

  Prize({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.description,
    this.picture,
    required this.cost,
    required this.stock,
    this.multiplier = 0,
    this.key = '',
    this.coins = 0,
    this.type = PrizeType.normal,
  });

  /// Factory constructor for creating an empty/fallback Prize instance
  factory Prize.empty() {
    return Prize(
      id: '',
      createdAt: DateTime.now(),
      title: '',
      description: '',
      cost: 0,
      stock: 0,
    );
  }

  factory Prize.fromJson(Map<String, dynamic> json) {
    return Prize(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      title: json['title'] ?? 'Untitled Prize',
      description: json['description'] ?? 'No description provided',
      picture: json['picture'],
      cost: json['cost'] ?? 0,
      stock: json['stock'] ?? 0,
      multiplier: json['multiplier'] != null
          ? (json['multiplier'] as num).toDouble()
          : 0,
      key: json['key'] ?? '',
      coins: json['coins'] ?? 0,
      type: PrizeType.values.firstWhere(
        (e) => e.toString() == 'PrizeType.${json['type']}',
        orElse: () => PrizeType.normal,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'title': title,
      'description': description,
      'picture': picture,
      'cost': cost,
      'stock': stock,
      'multiplier': multiplier,
      'key': key,
      'coins': coins,
      'type': type.toString().split('.').last,
    };
  }
}

enum PrizeType { normal, reward, keyed }
