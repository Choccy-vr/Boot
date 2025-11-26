import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/challenges/Challenge.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/supabase/DB/supabase_db.dart';

class ChallengeService {
  static List<Challenge> challenges = [];

  static Future<List<Challenge>> fetchChallenges() async {
    try {
      final response = await SupabaseDB.getAllRowData(table: 'challenges');
      challenges = (response as List)
          .map((json) => Challenge.fromJson(json))
          .toList();
      return challenges;
    } catch (e, stack) {
      AppLogger.error('Error getting challenges', e, stack);
      return [];
    }
  }

  static Future<Challenge?> getChallengeById(int id) async {
    try {
      final response = await SupabaseDB.getRowData(
        table: 'challenges',
        rowID: id,
      );
      return Challenge.fromJson(response);
    } catch (e, stack) {
      AppLogger.error('Error getting challenge with id $id', e, stack);
      return null;
    }
  }

  static Future<List<Challenge>> getChallengesByIdsAsync(List<int> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await SupabaseDB.getMultipleRowData(
        table: 'challenges',
        column: 'id',
        columnValue: ids,
      );
      return (response as List)
          .map((json) => Challenge.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting challenges by ids', e, stack);
      return [];
    }
  }

  static List<Challenge> getChallengesByIds(List<int> ids) {
    try {
      if (ids.isEmpty) return [];
      final response = SupabaseDB.getMultipleRowData(
        table: 'challenges',
        column: 'id',
        columnValue: ids,
      );
      return (response as List)
          .map((json) => Challenge.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting challenges by ids', e, stack);
      return [];
    }
  }

  static Future<List<Challenge>> getActiveChallenges() async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'challenges',
        column: 'is_active',
        columnValue: [true],
      );
      return (response as List)
          .map((json) => Challenge.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting active challenges', e, stack);
      return [];
    }
  }

  static Future<List<Challenge>> getChallengesByType(ChallengeType type) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'challenges',
        column: 'type',
        columnValue: [type.toString().split('.').last],
      );
      return (response as List)
          .map((json) => Challenge.fromJson(json))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Error getting challenges by type', e, stack);
      return [];
    }
  }

  static Future<void> markChallengeAsCompleted({
    required Project project,
    required Challenge challenge,
  }) async {
    try {
      if (!project.challenges.any((c) => c.id == challenge.id)) {
        project.challenges = List<Challenge>.from(project.challenges)
          ..add(challenge);
      }
      if (!project.challengeIds.contains(challenge.id)) {
        project.challengeIds = List<int>.from(project.challengeIds)
          ..add(challenge.id);
      }

      await ProjectService.updateProject(project);
    } catch (e, stack) {
      AppLogger.error(
        'Error marking challenge ${challenge.id} as completed for project ${project.title}',
        e,
        stack,
      );
    }
  }
}