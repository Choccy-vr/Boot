class BootUser {
  //identifiers
  final String id;
  final String email;
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
  //Role
  UserRole role;
  //constructor
  BootUser({
    required this.id,
    required this.email,
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
    this.role = UserRole.normal,
  });

  factory BootUser.fromJson(Map<String, dynamic> json) {
    return BootUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
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
      role: UserRole.values.firstWhere(
        (r) => r.name == (json['role'] ?? 'normal'),
        orElse: () => UserRole.normal,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
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
    };
  }
}

enum UserRole { normal, reviewer, admin, owner }
