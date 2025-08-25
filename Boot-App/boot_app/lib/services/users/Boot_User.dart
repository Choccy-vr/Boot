class Boot_User {
  //identifiers
  final String id;
  final String email;
  final String username;
  //profile
  final String bio;
  final String profilePicture;
  //Projects
  final List<String> projects;
  final int devlogs;
  //Time
  final DateTime createdAt;
  final DateTime updatedAt;
  //Votes
  final int votes;
  //Currency
  final String bootCoins;

  //constructor
  Boot_User({
    required this.id,
    required this.email,
    required this.username,
    required this.bio,
    required this.profilePicture,
    this.projects = const [],
    this.devlogs = 0,
    required this.createdAt,
    required this.updatedAt,
    this.votes = 0,
    required this.bootCoins,
  });

  factory Boot_User.fromJson(Map<String, dynamic> json) {
    return Boot_User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      profilePicture: json['profile_pic_url'] ?? '',
      projects: List<String>.from(json['projects'] ?? []),
      devlogs: json['total_devlogs'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      votes: json['total_votes'] ?? 0,
      bootCoins: (json['boot_coins'] ?? 0).toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'bio': bio,
      'profilePicture': profilePicture,
      'projects': projects,
      'devlogs': devlogs,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'votes': votes,
      'bootCoins': bootCoins,
    };
  }
}
