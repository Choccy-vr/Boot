class BootUser {
  //identifiers
  final String id;
  String username;
  //profile
  String bio;
  String profilePicture;
  //Projects
  int totalProjects;
  int devlogs;
  //Time
  final DateTime createdAt;
  DateTime updatedAt;
  //Votes
  int votes;
  //Currency
  int bootCoins;
  //Slack
  String slackUserId;
  //Hack Club
  String? hcUserId;
  bool? yswsEligible;
  bool? verificationStatus;
  //Role
  UserRole role;
  //shop
  List<String> cart;
  List<String> keys;

  //constructor
  BootUser({
    required this.id,
    required this.username,
    required this.bio,
    required this.profilePicture,
    this.totalProjects = 0,
    this.devlogs = 0,
    required this.createdAt,
    required this.updatedAt,
    this.votes = 0,
    required this.bootCoins,
    this.slackUserId = '',
    this.hcUserId,
    this.yswsEligible,
    this.verificationStatus,
    this.role = UserRole.normal,
    this.cart = const [],
    this.keys = const [],
  });

  factory BootUser.fromJson(Map<String, dynamic> json) {
    return BootUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      // Align with toJson key, but keep fallback for legacy key
      profilePicture:
          json['profile_picture_url'] ?? json['profile_pic_url'] ?? '',
      totalProjects: json['total_projects'] ?? 0,
      devlogs: json['total_devlogs'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      votes: json['total_votes'] ?? 0,
      bootCoins: json['boot_coins'] ?? 0,
      slackUserId: json['slack_user_id'] ?? '',
      hcUserId: json['hc_user_id'],
      yswsEligible: json['ysws_eligible'],
      verificationStatus: json['verification_status'],
      role: UserRole.values.firstWhere(
        (r) => r.name == (json['role'] ?? 'normal'),
        orElse: () => UserRole.normal,
      ),
      cart: List<String>.from(json['cart'] ?? []),
      keys: List<String>.from(json['keys'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'bio': bio,
      'profile_picture_url': profilePicture,
      'total_projects': totalProjects,
      'total_devlogs': devlogs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_votes': votes,
      'boot_coins': bootCoins,
      'slack_user_id': slackUserId,
      'hc_user_id': hcUserId,
      'ysws_eligible': yswsEligible,
      'verification_status': verificationStatus,
      'role': role.name,
      'cart': cart,
      'keys': keys,
    };
  }
}

enum UserRole { normal, reviewer, admin, owner }
