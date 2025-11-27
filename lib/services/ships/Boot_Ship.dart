import 'package:boot_app/services/challenges/Challenge.dart';
import 'package:boot_app/services/challenges/Challenge_Service.dart';

class Ship {
  final String id;
  final DateTime createdAt;
  final int project;
  final double time;
  final bool approved;
  final String reviewer;
  final String comment;
  final List<Challenge> challengesRequested;
  final List<Challenge> challengesCompleted;
  final bool reviewed;

  Ship({
    required this.id,
    required this.createdAt,
    required this.project,
    required this.time,
    this.approved = false,
    this.reviewer = '',
    this.comment = '',
    this.challengesRequested = const [],
    this.challengesCompleted = const [],
    this.reviewed = false,
  });

  static Future<Ship> fromJson(Map<String, dynamic> json) async {
    return Ship(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      project: json['project'] ?? 0,
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      approved: json['approved'] ?? false,
      reviewer: json['reviewer'] ?? '',
      comment: json['comment'] ?? '',
      challengesRequested:
          await _resolveChallenges(json['challenges_requested']),
      challengesCompleted:
          await _resolveChallenges(json['challenges_completed']),
      reviewed: json['reviewed'] ?? false,
    );
  }

  static Future<List<Challenge>> _resolveChallenges(dynamic raw) async {
    if (raw is! List) return [];

    final futures = raw.map<Future<Challenge?>>((entry) {
      if (entry is Map<String, dynamic>) {
        return Future.value(Challenge.fromJson(entry));
      }

      final challengeId = _extractChallengeId(entry);
      if (challengeId == null) return Future.value(null);
      return ChallengeService.getChallengeById(challengeId);
    }).toList();

    if (futures.isEmpty) return [];

    final resolved = await Future.wait(futures);
    return resolved.whereType<Challenge>().toList();
  }

  static int? _extractChallengeId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Map<String, dynamic> && value['id'] != null) {
      final nestedId = value['id'];
      if (nestedId is int) return nestedId;
      if (nestedId is num) return nestedId.toInt();
      if (nestedId is String) return int.tryParse(nestedId);
    }
    return null;
  }
}
