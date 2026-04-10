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
                .map((country) => prizeCountryFromJsonValue(country))
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
      'countries': countries.map(prizeCountryToJsonValue).toList(),
      'specs': specs,
      'custom_grant': customGrant,
    };
  }
}

class PrizeOption {
  final String id;
  final DateTime createdAt;
  final String prizeId;
  final String name;

  PrizeOption({
    required this.id,
    required this.createdAt,
    required this.prizeId,
    required this.name,
  });

  factory PrizeOption.fromJson(Map<String, dynamic> json) {
    return PrizeOption(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      prizeId: json['prize_id'] ?? '',
      name: json['name'] ?? 'Untitled Option',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'prize_id': prizeId,
      'name': name,
    };
  }
}

class PrizeOptionValues {
  final String id;
  final DateTime createdAt;
  final String optionId;
  final String label;
  final int priceModifier;
  final int stock;

  PrizeOptionValues({
    required this.id,
    required this.createdAt,
    required this.optionId,
    required this.label,
    required this.priceModifier,
    required this.stock,
  });

  factory PrizeOptionValues.fromJson(Map<String, dynamic> json) {
    return PrizeOptionValues(
      id: json['id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      optionId: json['option_id'] ?? '',
      label: json['label'] ?? 'No Label',
      priceModifier: json['price_modifier'] ?? 0,
      stock: json['stock'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'option_id': optionId,
      'label': label,
      'price_modifier': priceModifier,
      'stock': stock,
    };
  }
}

enum PrizeType { normal, reward, keyed }

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

const Map<PrizeCountries, String> _prizeCountryToCode = {
  PrizeCountries.all: 'all',
  PrizeCountries.us: 'us',
  PrizeCountries.ca: 'ca',
  PrizeCountries.mx: 'mx',
  PrizeCountries.ar: 'ar',
  PrizeCountries.br: 'br',
  PrizeCountries.cl: 'cl',
  PrizeCountries.co: 'co',
  PrizeCountries.pe: 'pe',
  PrizeCountries.ve: 've',
  PrizeCountries.ec: 'ec',
  PrizeCountries.bo: 'bo',
  PrizeCountries.py: 'py',
  PrizeCountries.uy: 'uy',
  PrizeCountries.gb: 'gb',
  PrizeCountries.de: 'de',
  PrizeCountries.fr: 'fr',
  PrizeCountries.it: 'it',
  PrizeCountries.es: 'es',
  PrizeCountries.nl: 'nl',
  PrizeCountries.be: 'be',
  PrizeCountries.ch: 'ch',
  PrizeCountries.at: 'at',
  PrizeCountries.se: 'se',
  PrizeCountries.no: 'no',
  PrizeCountries.dk: 'dk',
  PrizeCountries.fi: 'fi',
  PrizeCountries.ie: 'ie',
  PrizeCountries.pt: 'pt',
  PrizeCountries.pl: 'pl',
  PrizeCountries.cz: 'cz',
  PrizeCountries.gr: 'gr',
  PrizeCountries.ro: 'ro',
  PrizeCountries.hu: 'hu',
  PrizeCountries.cn: 'cn',
  PrizeCountries.jp: 'jp',
  PrizeCountries.kr: 'kr',
  PrizeCountries.ind: 'ind',
  PrizeCountries.sg: 'sg',
  PrizeCountries.my: 'my',
  PrizeCountries.th: 'th',
  PrizeCountries.vn: 'vn',
  PrizeCountries.ph: 'ph',
  PrizeCountries.id: 'id',
  PrizeCountries.tw: 'tw',
  PrizeCountries.hk: 'hk',
  PrizeCountries.au: 'au',
  PrizeCountries.nz: 'nz',
  PrizeCountries.ae: 'ae',
  PrizeCountries.sa: 'sa',
  PrizeCountries.il: 'il',
  PrizeCountries.tr: 'tr',
  PrizeCountries.za: 'za',
  PrizeCountries.ng: 'ng',
  PrizeCountries.eg: 'eg',
  PrizeCountries.ke: 'ke',
  PrizeCountries.ma: 'ma',
};

const Map<String, PrizeCountries> _prizeCountryCodeToEnum = {
  'all': PrizeCountries.all,
  'us': PrizeCountries.us,
  'ca': PrizeCountries.ca,
  'mx': PrizeCountries.mx,
  'ar': PrizeCountries.ar,
  'br': PrizeCountries.br,
  'cl': PrizeCountries.cl,
  'co': PrizeCountries.co,
  'pe': PrizeCountries.pe,
  've': PrizeCountries.ve,
  'ec': PrizeCountries.ec,
  'bo': PrizeCountries.bo,
  'py': PrizeCountries.py,
  'uy': PrizeCountries.uy,
  'gb': PrizeCountries.gb,
  'de': PrizeCountries.de,
  'fr': PrizeCountries.fr,
  'it': PrizeCountries.it,
  'es': PrizeCountries.es,
  'nl': PrizeCountries.nl,
  'be': PrizeCountries.be,
  'ch': PrizeCountries.ch,
  'at': PrizeCountries.at,
  'se': PrizeCountries.se,
  'no': PrizeCountries.no,
  'dk': PrizeCountries.dk,
  'fi': PrizeCountries.fi,
  'ie': PrizeCountries.ie,
  'pt': PrizeCountries.pt,
  'pl': PrizeCountries.pl,
  'cz': PrizeCountries.cz,
  'gr': PrizeCountries.gr,
  'ro': PrizeCountries.ro,
  'hu': PrizeCountries.hu,
  'cn': PrizeCountries.cn,
  'jp': PrizeCountries.jp,
  'kr': PrizeCountries.kr,
  'ind': PrizeCountries.ind,
  'sg': PrizeCountries.sg,
  'my': PrizeCountries.my,
  'th': PrizeCountries.th,
  'vn': PrizeCountries.vn,
  'ph': PrizeCountries.ph,
  'id': PrizeCountries.id,
  'tw': PrizeCountries.tw,
  'hk': PrizeCountries.hk,
  'au': PrizeCountries.au,
  'nz': PrizeCountries.nz,
  'ae': PrizeCountries.ae,
  'sa': PrizeCountries.sa,
  'il': PrizeCountries.il,
  'tr': PrizeCountries.tr,
  'za': PrizeCountries.za,
  'ng': PrizeCountries.ng,
  'eg': PrizeCountries.eg,
  'ke': PrizeCountries.ke,
  'ma': PrizeCountries.ma,
  // Backward-compatible support for previous full names.
  'unitedstates': PrizeCountries.us,
  'canada': PrizeCountries.ca,
  'mexico': PrizeCountries.mx,
  'argentina': PrizeCountries.ar,
  'brazil': PrizeCountries.br,
  'chile': PrizeCountries.cl,
  'colombia': PrizeCountries.co,
  'peru': PrizeCountries.pe,
  'venezuela': PrizeCountries.ve,
  'ecuador': PrizeCountries.ec,
  'bolivia': PrizeCountries.bo,
  'paraguay': PrizeCountries.py,
  'uruguay': PrizeCountries.uy,
  'unitedkingdom': PrizeCountries.gb,
  'germany': PrizeCountries.de,
  'france': PrizeCountries.fr,
  'italy': PrizeCountries.it,
  'spain': PrizeCountries.es,
  'netherlands': PrizeCountries.nl,
  'belgium': PrizeCountries.be,
  'switzerland': PrizeCountries.ch,
  'austria': PrizeCountries.at,
  'sweden': PrizeCountries.se,
  'norway': PrizeCountries.no,
  'denmark': PrizeCountries.dk,
  'finland': PrizeCountries.fi,
  'ireland': PrizeCountries.ie,
  'portugal': PrizeCountries.pt,
  'poland': PrizeCountries.pl,
  'czechrepublic': PrizeCountries.cz,
  'greece': PrizeCountries.gr,
  'romania': PrizeCountries.ro,
  'hungary': PrizeCountries.hu,
  'china': PrizeCountries.cn,
  'japan': PrizeCountries.jp,
  'southkorea': PrizeCountries.kr,
  'india': PrizeCountries.ind,
  'singapore': PrizeCountries.sg,
  'malaysia': PrizeCountries.my,
  'thailand': PrizeCountries.th,
  'vietnam': PrizeCountries.vn,
  'philippines': PrizeCountries.ph,
  'indonesia': PrizeCountries.id,
  'taiwan': PrizeCountries.tw,
  'hongkong': PrizeCountries.hk,
  'australia': PrizeCountries.au,
  'newzealand': PrizeCountries.nz,
  'unitedarabemirates': PrizeCountries.ae,
  'saudiarabia': PrizeCountries.sa,
  'israel': PrizeCountries.il,
  'turkey': PrizeCountries.tr,
  'southafrica': PrizeCountries.za,
  'nigeria': PrizeCountries.ng,
  'egypt': PrizeCountries.eg,
  'kenya': PrizeCountries.ke,
  'morocco': PrizeCountries.ma,
};

const Map<PrizeCountries, String> _prizeCountryDisplayNames = {
  PrizeCountries.all: 'All Countries',
  PrizeCountries.us: 'United States',
  PrizeCountries.ca: 'Canada',
  PrizeCountries.mx: 'Mexico',
  PrizeCountries.ar: 'Argentina',
  PrizeCountries.br: 'Brazil',
  PrizeCountries.cl: 'Chile',
  PrizeCountries.co: 'Colombia',
  PrizeCountries.pe: 'Peru',
  PrizeCountries.ve: 'Venezuela',
  PrizeCountries.ec: 'Ecuador',
  PrizeCountries.bo: 'Bolivia',
  PrizeCountries.py: 'Paraguay',
  PrizeCountries.uy: 'Uruguay',
  PrizeCountries.gb: 'United Kingdom',
  PrizeCountries.de: 'Germany',
  PrizeCountries.fr: 'France',
  PrizeCountries.it: 'Italy',
  PrizeCountries.es: 'Spain',
  PrizeCountries.nl: 'Netherlands',
  PrizeCountries.be: 'Belgium',
  PrizeCountries.ch: 'Switzerland',
  PrizeCountries.at: 'Austria',
  PrizeCountries.se: 'Sweden',
  PrizeCountries.no: 'Norway',
  PrizeCountries.dk: 'Denmark',
  PrizeCountries.fi: 'Finland',
  PrizeCountries.ie: 'Ireland',
  PrizeCountries.pt: 'Portugal',
  PrizeCountries.pl: 'Poland',
  PrizeCountries.cz: 'Czech Republic',
  PrizeCountries.gr: 'Greece',
  PrizeCountries.ro: 'Romania',
  PrizeCountries.hu: 'Hungary',
  PrizeCountries.cn: 'China',
  PrizeCountries.jp: 'Japan',
  PrizeCountries.kr: 'South Korea',
  PrizeCountries.ind: 'India',
  PrizeCountries.sg: 'Singapore',
  PrizeCountries.my: 'Malaysia',
  PrizeCountries.th: 'Thailand',
  PrizeCountries.vn: 'Vietnam',
  PrizeCountries.ph: 'Philippines',
  PrizeCountries.id: 'Indonesia',
  PrizeCountries.tw: 'Taiwan',
  PrizeCountries.hk: 'Hong Kong',
  PrizeCountries.au: 'Australia',
  PrizeCountries.nz: 'New Zealand',
  PrizeCountries.ae: 'United Arab Emirates',
  PrizeCountries.sa: 'Saudi Arabia',
  PrizeCountries.il: 'Israel',
  PrizeCountries.tr: 'Turkey',
  PrizeCountries.za: 'South Africa',
  PrizeCountries.ng: 'Nigeria',
  PrizeCountries.eg: 'Egypt',
  PrizeCountries.ke: 'Kenya',
  PrizeCountries.ma: 'Morocco',
};

String prizeCountryToJsonValue(PrizeCountries country) {
  return _prizeCountryToCode[country] ?? 'all';
}

PrizeCountries prizeCountryFromJsonValue(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.isEmpty) return PrizeCountries.all;

  final normalized = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return _prizeCountryCodeToEnum[normalized] ?? PrizeCountries.all;
}

String prizeCountryDisplayName(PrizeCountries country) {
  return _prizeCountryDisplayNames[country] ?? 'Unknown';
}
