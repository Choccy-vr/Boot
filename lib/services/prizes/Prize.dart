class Prize {
  final String id;
  final DateTime createdAt;
  final String title;
  final String description;
  final String? picture;
  final int cost;
  final int stock;

  Prize({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.description,
    this.picture,
    required this.cost,
    required this.stock,
  });

  factory Prize.fromJson(Map<String, dynamic> json) {
    return Prize(
      id: json['id'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
      title: json['title'] ?? 'Untitled Prize',
      description: json['description'] ?? 'No description provided',
      picture: json['picture'],
      cost: json['cost'] ?? 0,
      stock: json['stock'] ?? 0,
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
    };
  }
}
