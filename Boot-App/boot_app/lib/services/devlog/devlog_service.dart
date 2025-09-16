import 'package:boot_app/services/supabase/Storage/supabase_storage.dart';
import 'package:flutter/material.dart';
import 'Devlog.dart';
import '/services/supabase/DB/supabase_db.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class DevlogService {
  static Future<List<Devlog>> getDevlogsByProjectId(String projectId) async {
    try {
      final response = await SupabaseDB.GetMultipleRowData(
        table: 'devlogs',
        column: 'project',
        columnValue: [projectId],
      );
      return (response as List).map((json) => Devlog.fromJson(json)).toList();
    } catch (e) {
      print('Error getting devlogs for project $projectId: $e');
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
      final response = await SupabaseDB.InsertAndReturnData(
        table: 'devlogs',
        data: {
          'project': projectID,
          'title': title,
          'description': description,
        },
      );
      final _tempDevlog = Devlog.fromJson(response.first);
      final mediaUrls = await SupabaseStorageService.uploadMultipleFilesWithURL(
        filePaths: cachedMediaUrls,
        bucket: 'Devlogs',
        supabaseDirPath: '$projectID/devlog_${_tempDevlog.id}',
      );
      final updatedDevlog = await SupabaseDB.UpdateAndReturnData(
        table: 'devlogs',
        data: {'media_urls': mediaUrls},
        column: 'id',
        value: _tempDevlog.id.toString(),
      );
      return Devlog.fromJson(updatedDevlog.first);
    } catch (e) {
      print('Error adding devlog: $e');
      throw Exception('Error adding devlog: $e');
    }
  }

  static Future<String> cacheMediaFilePicker() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) {
      return 'User cancelled';
    }
    final file = File(result.files.single.path!);
    return file.path;
  }
}
