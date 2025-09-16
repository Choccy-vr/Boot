import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static final supabase = Supabase.instance.client;

  static Future<String> uploadFileWithPicker({
    required String bucket,
    required String supabasePath,
  }) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) {
      return 'User cancelled';
    }
    final file = File(result.files.single.path!);
    final response = await supabase.storage
        .from(bucket)
        .upload(
          supabasePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    if (response == '') {
      return 'Upload failed';
    }

    return supabasePath;
  }

  static Future<List<String>> uploadMultipleFilesWithURL({
    required List<String> filePaths,
    required String bucket,
    required String supabaseDirPath,
  }) async {
    List<String> uploadedPaths = [];
    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      final file = File(filePath);
      final fileName = file.uri.pathSegments.last;
      final fileExtension = fileName.split('.').last;
      final supabasePath = '$supabaseDirPath/media_${i + 1}.$fileExtension';

      final response = await supabase.storage
          .from(bucket)
          .upload(
            supabasePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      if (response != '') {
        final publicUrl = await getPublicUrl(
          bucket: bucket,
          supabasePath: supabasePath,
        );
        uploadedPaths.add(publicUrl ?? supabasePath);
      }
    }

    return uploadedPaths;
  }

  static Future<String?> getPublicUrl({
    required String bucket,
    required String supabasePath,
  }) async {
    try {
      final response = supabase.storage.from(bucket).getPublicUrl(supabasePath);
      return response;
    } catch (e) {
      throw Exception('Failed to get public URL: ${e.toString()}');
    }
  }
}
