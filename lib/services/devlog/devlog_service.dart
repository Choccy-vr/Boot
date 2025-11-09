import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/supabase/DB/functions/supabase_db_functions.dart';
import 'package:boot_app/services/supabase/Storage/supabase_storage.dart';
import 'package:boot_app/services/users/User.dart';
import 'Devlog.dart';
import '/services/supabase/DB/supabase_db.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class DevlogService {
  static Future<List<Devlog>> getDevlogsByProjectId(String projectId) async {
    try {
      final response = await SupabaseDB.getMultipleRowData(
        table: 'devlogs',
        column: 'project',
        columnValue: [projectId],
      );
      return (response as List).map((json) => Devlog.fromJson(json)).toList();
    } catch (e, stack) {
      AppLogger.error('Error getting devlogs for project $projectId', e, stack);
      return [];
    }
  }

  static Future<Devlog> addDevlog({
    required int projectID,
    required String title,
    required String description,
    List<String> cachedMediaUrls = const [],
  }) async {
    try {
      final response = await SupabaseDB.insertAndReturnData(
        table: 'devlogs',
        data: {
          'project': projectID,
          'title': title,
          'description': description,
        },
      );
      final tempDevlog = Devlog.fromJson(response.first);
      final mediaUrls = await SupabaseStorageService.uploadMultipleFilesWithURL(
        filePaths: cachedMediaUrls,
        bucket: 'Devlogs',
        supabaseDirPath: '$projectID/devlog_${tempDevlog.id}',
      );
      final updatedDevlog = await SupabaseDB.updateAndReturnData(
        table: 'devlogs',
        data: {'media_urls': mediaUrls},
        column: 'id',
        value: tempDevlog.id.toString(),
      );
      await SupabaseDBFunctions.callIncrementFunction(
        table: 'users',
        column: 'total_devlogs',
        rowID: UserService.currentUser?.id ?? '',
        incrementBy: 1,
      );
      return Devlog.fromJson(updatedDevlog.first);
    } catch (e, stack) {
      AppLogger.error('Error adding devlog for project $projectID', e, stack);
      throw Exception('Error adding devlog: $e');
    }
  }

  static Future<String> cacheMediaFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return 'User cancelled';
    }
    final ext = (result.files.single.extension ?? '').toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'webp'];
    if (!allowed.contains(ext)) {
      throw Exception('Unsupported file type: .$ext');
    }
    final file = File(result.files.single.path!);
    return file.path;
  }
}
