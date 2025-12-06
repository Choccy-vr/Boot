import 'dart:convert';

import 'package:boot_app/services/challenges/Challenge.dart';

class Project {
  String title;
  String description;
  String imageURL;
  String githubRepo;
  int likes;
  final String owner;
  final DateTime createdAt;
  DateTime lastModified;
  bool awaitingReview;
  bool reviewed;
  String level;
  final int id;
  String status;
  List<String> hackatimeProjects;
  String isoUrl;
  String qemuCMD;
  List<Challenge> challenges;
  List<int> challengeIds;
  int coinsEarned;
  String readableTime;
  double time;
  List<String> tags;

  Project({
    required this.title,
    required this.description,
    required this.reviewed,
    required this.lastModified,
    required this.imageURL,
    required this.githubRepo,
    required this.likes,
    required this.owner,
    required this.createdAt,
    required this.awaitingReview,
    required this.level,
    required this.id,
    required this.status,
    required this.hackatimeProjects,
    required this.readableTime,
    required this.time,
    this.isoUrl = '',
    this.qemuCMD = '',
    this.challenges = const [],
    this.challengeIds = const [],
    this.coinsEarned = 0,
    this.tags = const [],
  });

  factory Project.fromRow(Map<String, dynamic> row) {
    final challengeIds = _parseChallengeIds(row['challenges']);
    return Project(
      id: row['id'] ?? 0,
      title: row['name'] ?? 'Untitled Project',
      description: row['description'] ?? 'No description provided',
      imageURL: row['image_url'] ?? '',
      githubRepo: row['github_repo'] ?? '',
      likes: row['total_likes'] ?? 0,
      owner: row['owner'] ?? 'unknown',
      createdAt: DateTime.parse(row['created_at'] ?? DateTime.now().toString()),
      lastModified: DateTime.parse(
        row['updated_at'] ?? DateTime.now().toString(),
      ),
      awaitingReview: row['awaiting_review'] ?? false,
      level: row['level'] ?? 'unknown',
      status: row['status'] ?? 'unknown',
      reviewed: row['reviewed'] ?? false,
      hackatimeProjects: _parseHackatimeProjects(row['hackatime_projects']),
      readableTime: row['time_readable'] ?? '',
      time: (row['time'] as num?)?.toDouble() ?? 0.0,
      isoUrl: row['ISO_url'] ?? '',
      qemuCMD: row['qemu_cmd'] ?? '',
      challenges: const [],
      challengeIds: List<int>.from(challengeIds),
      coinsEarned: row['coins_earned'] ?? 0,
      tags: row['tags'] != null
          ? List<String>.from(row['tags'])
          : [],
    );
  }

  static Map<String, dynamic> toRow({
    String? title,
    String? description,
    String? imageURL,
    String? githubRepo,
    int? likes,
    DateTime? lastModified,
    bool? awaitingReview,
    String? level,
    bool? reviewed,
    List<String>? hackatimeProjects,
    String? owner,
    String? isoUrl,
    String? qemuCMD,
    List<Challenge>? challenges,
    List<int>? challengeIds,
    int? coinsEarned,
    String? readableTime,
    double? time,
    List<String>? tags,
  }) {
    final map = <String, dynamic>{};
    if (title != null) map['name'] = title;
    if (description != null) map['description'] = description;
    if (imageURL != null) map['image_url'] = imageURL;
    if (githubRepo != null) map['github_repo'] = githubRepo;
    if (likes != null) map['total_likes'] = likes;
    if (lastModified != null) {
      map['updated_at'] = lastModified.toIso8601String();
    }
    if (awaitingReview != null) map['awaiting_review'] = awaitingReview;
    if (level != null) map['level'] = level;
    if (reviewed != null) map['reviewed'] = reviewed;
    if (hackatimeProjects != null) {
      map['hackatime_projects'] = hackatimeProjects;
    }
    if (owner != null) map['owner'] = owner;
    if (isoUrl != null) map['ISO_url'] = isoUrl;
    if (qemuCMD != null) map['qemu_cmd'] = qemuCMD;
    final serializedChallengeIds = (challenges != null && challenges.isNotEmpty)
        ? challenges.map((c) => c.id).toList()
        : (challengeIds ?? []);
    if (serializedChallengeIds.isNotEmpty) {
      map['challenges'] = serializedChallengeIds;
    }
    if (coinsEarned != null) map['coins_earned'] = coinsEarned;
    if (readableTime != null) map['time_readable'] = readableTime;
    if (time != null) map['time'] = time;
    if (tags != null) map['tags'] = tags;
    return map;
  }

  static List<String> _parseHackatimeProjects(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((value) => value == null ? '' : value.toString())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((value) => value == null ? '' : value.toString())
                .where((value) => value.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      return [trimmed];
    }
    return [];
  }

  static List<int> _parseChallengeIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map(_coerceInt)
          .where((value) => value != null)
          .cast<int>()
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map(_coerceInt)
                .where((value) => value != null)
                .cast<int>()
                .toList();
          }
        } catch (_) {}
      }
      final singleId = int.tryParse(trimmed);
      return singleId == null ? [] : [singleId];
    }
    if (raw is num) {
      return [raw.toInt()];
    }
    return [];
  }

  static int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
