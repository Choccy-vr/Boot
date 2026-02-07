import 'package:boot_app/services/Projects/Project.dart';
import 'package:boot_app/services/Projects/project_service.dart';
import 'package:boot_app/services/misc/logger.dart';
import 'package:boot_app/services/supabase/DB/functions/supabase_db_functions.dart';
import 'package:boot_app/services/Storage/storage.dart';
import 'package:boot_app/services/users/User.dart';
import 'Devlog.dart';
import '/services/supabase/DB/supabase_db.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    required String readableTime,
    required double time,
    required double? totalProjectTime,
    required String author,
    List<PlatformFile> cachedMediaFiles = const [],
    List<int> challengeIds = const [],
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    if (trimmedTitle.length <= 2) {
      throw ArgumentError('Devlog title must be at least 3 characters long');
    }
    if (trimmedDescription.length <= 150) {
      throw ArgumentError(
        'Devlog description must be more than 150 characters',
      );
    }
    if (cachedMediaFiles.isEmpty) {
      throw ArgumentError('Attach at least one media file to the devlog');
    }
    if (time <= 0) {
      throw ArgumentError(
        'Cannot create devlog with zero or negative time tracked',
      );
    }
    final timeInMinutes = (time * 60).round();
    if (timeInMinutes < 5) {
      throw ArgumentError(
        'Devlog must have at least 5 minutes of tracked time. Current: ${timeInMinutes}m',
      );
    }

    try {
      final project = await ProjectService.getProjectById(projectID);
      if (project == null) {
        throw Exception('Project with ID $projectID not found');
      }
      final response = await SupabaseDB.insertAndReturnData(
        table: 'devlogs',
        data: {
          'project': projectID,
          'title': trimmedTitle,
          'description': trimmedDescription,
          'time_tracked': time,
          'time_tracked_readable': readableTime,
          'challenges': challengeIds,
          'author': author,
        },
      );
      final tempDevlog = Devlog.fromJson(response.first);
      final objectPaths = await StorageService.uploadMultipleFiles(
        files: cachedMediaFiles,
        dirPath: 'project/$projectID/devlog_${tempDevlog.id}',
      );

      // Convert object paths to public URLs before saving
      final mediaUrls = <String>[];
      for (final path in objectPaths) {
        final publicUrl = await StorageService.getPublicUrl(path: path);
        if (publicUrl != null) {
          mediaUrls.add(publicUrl);
        }
      }

      final updatedDevlog = await SupabaseDB.updateAndReturnData(
        table: 'devlogs',
        data: {'media_urls': mediaUrls},
        column: 'id',
        value: tempDevlog.id.toString(),
      );

      final updatedTimeTracked = project.timeTrackedShip + time;

      await SupabaseDBFunctions.callIncrementFunction(
        table: 'users',
        column: 'total_devlogs',
        rowID: author,
        incrementBy: 1,
      );

      await SupabaseDB.updateAndReturnData(
        table: 'projects',
        data: {
          'time': totalProjectTime ?? (project.time + time),
          'time_readable': readableTime,
          'time_tracked_ship': updatedTimeTracked,
        },
        column: 'id',
        value: projectID,
      );
      return Devlog.fromJson(updatedDevlog.first);
    } catch (e, stack) {
      AppLogger.error('Error adding devlog for project $projectID', e, stack);
      throw Exception('Error adding devlog: $e');
    }
  }

  static Future<Devlog> updateDevlog({
    required Devlog devlog,
    required String title,
    required String description,
    List<PlatformFile> newMediaFiles = const [],
    List<String> existingMediaUrls = const [],
    List<int> challengeIds = const [],
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

    if (trimmedTitle.length <= 2) {
      throw ArgumentError('Devlog title must be at least 3 characters long');
    }
    if (trimmedDescription.length <= 150) {
      throw ArgumentError(
        'Devlog description must be more than 150 characters',
      );
    }

    // Must have at least one media (existing or new)
    if (existingMediaUrls.isEmpty && newMediaFiles.isEmpty) {
      throw ArgumentError('Devlog must have at least one media file');
    }

    try {
      final projectID = int.parse(devlog.projectId);

      // Upload new media files if any
      List<String> allMediaUrls = List.from(existingMediaUrls);
      if (newMediaFiles.isNotEmpty) {
        final objectPaths = await StorageService.uploadMultipleFiles(
          files: newMediaFiles,
          dirPath: 'project/$projectID/devlog_${devlog.id}',
        );

        // Convert object paths to public URLs
        for (final path in objectPaths) {
          final publicUrl = await StorageService.getPublicUrl(path: path);
          if (publicUrl != null) {
            allMediaUrls.add(publicUrl);
          }
        }
      }

      final updatedDevlog = await SupabaseDB.updateAndReturnData(
        table: 'devlogs',
        data: {
          'title': trimmedTitle,
          'description': trimmedDescription,
          'media_urls': allMediaUrls,
          'challenges': challengeIds,
        },
        column: 'id',
        value: devlog.id.toString(),
      );

      return Devlog.fromJson(updatedDevlog.first);
    } catch (e, stack) {
      AppLogger.error('Error updating devlog ${devlog.id}', e, stack);
      throw Exception('Error updating devlog: $e');
    }
  }

  static Future<PlatformFile?> cacheMediaFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      allowMultiple: false,
      withData: kIsWeb, // Fetch bytes on web
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();
    const allowed = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
    if (!allowed.contains(ext)) {
      throw Exception('Unsupported file type: .$ext');
    }
    return file;
  }
}
