import '/services/supabase/DB/supabase_db.dart';
import '/services/Projects/Project.dart';

class ProjectService {
  static Future<List<Project>> getProjects(String userID) async {
    final response = await SupabaseDB.GetMultipleRowData(
      table: 'projects',
      column: 'owner',
      columnValue: [userID],
    );
    if (response.isEmpty) return [];
    return response.map<Project>((row) => Project.fromRow(row)).toList();
  }

  static Future<void> createProject({
    required String? title,
    required String? description,
    required String? imageURL,
    required String? githubRepo,
    required double? time,
    required int? likes,
    required DateTime? lastModified,
    required bool? awaitingReview,
    required String? level,
    required String? status,
    required bool? reviewed,
    required String? hackatimeProjects,
    required String? owner,
  }) async {
    await SupabaseDB.InsertData(
      table: 'projects',
      data: Project.toRow(
        title: title,
        description: description,
        imageURL: imageURL,
        githubRepo: githubRepo,
        time: time,
        likes: likes,
        lastModified: lastModified,
        awaitingReview: awaitingReview,
        level: level,
        status: status,
        reviewed: reviewed,
        hackatimeProjects: hackatimeProjects,
        owner: owner,
      ),
    );
  }
}
