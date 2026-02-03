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
  final List<PrizeCountries> countries;
  final String specs;
  final bool customGrant;

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
    this.countries = const [PrizeCountries.all],
    this.specs = '',
    this.customGrant = true,
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
      countries: const [PrizeCountries.all],
      specs: '',
      customGrant: true,
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
      countries: json['countries'] != null
          ? (json['countries'] as List)
                .map(
                  (country) => PrizeCountries.values.firstWhere(
                    (e) => e.toString() == 'PrizeCountries.$country',
                    orElse: () => PrizeCountries.all,
                  ),
                )
                .toList()
          : [PrizeCountries.all],
      specs: json['specs'] ?? '',
      customGrant: json['custom_grant'] ?? true,
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
      'countries': countries
          .map((country) => country.toString().split('.').last)
          .toList(),
      'specs': specs,
      'custom_grant': customGrant,
    };
  }
}

enum PrizeType { normal, grant, reward, keyed }

enum PrizeCountries {
  all,
  // North America
  us,
  ca,
  mx,
  // South America
  ar,
  br,
  cl,
  co,
  pe,
  ve,
  ec,
  bo,
  py,
  uy,
  // Europe
  gb,
  de,
  fr,
  it,
  es,
  nl,
  be,
  ch,
  at,
  se,
  no,
  dk,
  fi,
  ie,
  pt,
  pl,
  cz,
  gr,
  ro,
  hu,
  // Asia
  cn,
  jp,
  kr,
  ind,
  sg,
  my,
  th,
  vn,
  ph,
  id,
  tw,
  hk,
  // Oceania
  au,
  nz,
  // Middle East
  ae,
  sa,
  il,
  tr,
  // Africa
  za,
  ng,
  eg,
  ke,
  ma,
}
