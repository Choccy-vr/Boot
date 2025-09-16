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

  static Future<List<Project>> getAllProjects({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Use SelectData to get all projects and sort manually
      final response = await SupabaseDB.SelectData(table: 'projects');
      
      if (response.isEmpty) return [];
      
      final projects = response.map<Project>((row) => Project.fromRow(row)).toList();
      
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
    } catch (e) {
      print('Error fetching all projects: $e');
      return [];
    }
  }

  static Future<List<Project>> getLikedProjects(List<int> likedProjectIds) async {
    if (likedProjectIds.isEmpty) return [];
    
    try {
      final response = await SupabaseDB.GetMultipleRowData(
        table: 'projects',
        column: 'id',
        columnValue: likedProjectIds.map((id) => id.toString()).toList(),
      );
      
      if (response.isEmpty) return [];
      return response.map<Project>((row) => Project.fromRow(row)).toList();
    } catch (e) {
      print('Error fetching liked projects: $e');
      return [];
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

  static Future<void> updateProject(Project project) async {
    await SupabaseDB.UpdateData(
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
        status: project.status,
        reviewed: project.reviewed,
        hackatimeProjects: project.hackatimeProjects,
      ),
    );
  }
}
