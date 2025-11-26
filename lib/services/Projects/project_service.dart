import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/supabase/DB/functions/supabase_db_functions.dart';

import '/services/supabase/DB/supabase_db.dart';
import '/services/Projects/Project.dart';

class ProjectService {
  static Future<List<Project>> getProjects(String userID) async {
    final response = await SupabaseDB.getMultipleRowData(
      table: 'projects',
      column: 'owner',
      columnValue: [userID],
    );
    if (response.isEmpty) return [];
    return response.map<Project>((row) => Project.fromRow(row)).toList();
  }

  static Future<List<Project>> getAllProjects({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Use selectData to get all projects and sort manually
      final response = await SupabaseDB.selectData(table: 'projects');

      if (response.isEmpty) return [];

      final projects = response
          .map<Project>((row) => Project.fromRow(row))
          .toList();

      // Sort by time (if available) or created_at as fallback
      projects.sort((a, b) {
        if (a.time > 0 && b.time > 0) {
          return b.time.compareTo(a.time); // Sort by time descending
        }
        return b.createdAt.compareTo(a.createdAt); // Fallback to created_at
      });

      // Apply pagination
      final startIndex = offset;
      final endIndex = (startIndex + limit).clamp(0, projects.length);

      if (startIndex >= projects.length) return [];

      return projects.sublist(startIndex, endIndex);
    } catch (e, stack) {
      AppLogger.error('Error fetching all projects', e, stack);
      return [];
    }
  }

  static Future<List<Project>> getLikedProjects(
    List<int> likedProjectIds,
  ) async {
    if (likedProjectIds.isEmpty) return [];

    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'projects',
        column: 'id',
        columnValue: likedProjectIds.map((id) => id.toString()).toList(),
      );

      if (response.isEmpty) return [];
      return response.map<Project>((row) => Project.fromRow(row)).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching liked projects', e, stack);
      return [];
    }
  }

  static Future<Project?> getProjectById(int projectId) async {
    try {
      final response = await SupabaseDB.getRowData(
        table: 'projects',
        rowID: projectId,
      );
      return Project.fromRow(response);
    } catch (e, stack) {
      AppLogger.error('Error fetching project by ID $projectId', e, stack);
      return null;
    }
  }

  static Future<void> createProject({
    required String? title,
    required String? description,
    required String? imageURL,
    required String? githubRepo,
    required int? likes,
    required DateTime? lastModified,
    required bool? awaitingReview,
    required String? level,
    required String? status,
    required bool? reviewed,
    required List<String>? hackatimeProjects,
    required String owner,
  }) async {
    await SupabaseDB.insertData(
      table: 'projects',
      data: Project.toRow(
        title: title,
        description: description,
        imageURL: imageURL,
        githubRepo: githubRepo,
        likes: likes,
        lastModified: lastModified,
        awaitingReview: awaitingReview,
        level: level,
        reviewed: reviewed,
        hackatimeProjects: hackatimeProjects,
        owner: owner,
      ),
    );
    await SupabaseDBFunctions.callIncrementFunction(
      table: 'users',
      column: 'total_projects',
      rowID: owner,
      incrementBy: 1,
    );
  }

  static Future<void> deleteProject({
    required int projectId,
    required String ownerId,
  }) async {
    await SupabaseDB.deleteData(
      table: 'projects',
      column: 'id',
      value: projectId,
    );
    await SupabaseDBFunctions.callIncrementFunction(
      table: 'users',
      column: 'total_projects',
      rowID: ownerId,
      incrementBy: -1,
    );
  }

  static Future<void> updateProject(Project project) async {
    await SupabaseDB.updateData(
      table: 'projects',
      column: 'id',
      value: project.id,
      data: Project.toRow(
        title: project.title,
        description: project.description,
        imageURL: project.imageURL,
        githubRepo: project.githubRepo,
        likes: project.likes,
        lastModified: project.lastModified,
        awaitingReview: project.awaitingReview,
        level: project.level,
        reviewed: project.reviewed,
        hackatimeProjects: project.hackatimeProjects,
        isoUrl: project.isoUrl,
        qemuCMD: project.qemuCMD,
        challenges: project.challenges,
        challengeIds: project.challengeIds,
        coinsEarned: project.coinsEarned,
        readableTime: project.readableTime,
        time: project.time,
      ),
    );
  }

  static Future<List<Project>> getTopProjectsByLikes({int limit = 50}) async {
    try {
      final response = await SupabaseDB.selectData(table: 'projects');

      if (response.isEmpty) return [];

      final projects = response
          .map<Project>((row) => Project.fromRow(row))
          .toList();

      // Sort by likes descending
      projects.sort((a, b) => b.likes.compareTo(a.likes));

      // Return top projects
      return projects.take(limit).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching top projects by likes', e, stack);
      return [];
    }
  }

  static Future<List<Project>> getTopProjectsByTime({int limit = 50}) async {
    try {
      final response = await SupabaseDB.selectData(table: 'projects');

      if (response.isEmpty) return [];

      final projects = response
          .map<Project>((row) => Project.fromRow(row))
          .toList();

      // Sort by time descending
      projects.sort((a, b) => b.time.compareTo(a.time));

      // Return top projects
      return projects.take(limit).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching top projects by time', e, stack);
      return [];
    }
  }

  static Future<List<Project>> getTopProjectsByChallenges({
    int limit = 50,
  }) async {
    try {
      final response = await SupabaseDB.selectData(table: 'projects');

      if (response.isEmpty) return [];

      final projects = response
          .map<Project>((row) => Project.fromRow(row))
          .toList();

      // Sort by number of challenges completed descending
      projects.sort(
        (a, b) => b.challengeIds.length.compareTo(a.challengeIds.length),
      );

      // Return top projects
      return projects.take(limit).toList();
    } catch (e, stack) {
      AppLogger.error('Error fetching top projects by challenges', e, stack);
      return [];
    }
  }
}
