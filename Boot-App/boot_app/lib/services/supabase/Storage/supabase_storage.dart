import 'dart:io';
import 'package:boot_app/services/misc/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static final supabase = Supabase.instance.client;

  static Future<String> uploadFileWithPicker({
    required String bucket,
    required String supabasePath,
  }) async {
    // Restrict to common image types by default and handle cancel gracefully
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
    final response = await supabase.storage
        .from(bucket)
        .upload(
          supabasePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    if (response == '') {
      AppLogger.error(
        'Upload failed for $supabasePath in bucket $bucket (single pick)',
      );
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
      } else {
        AppLogger.error(
          'Upload failed for $supabasePath in bucket $bucket (multi-upload)',
        );
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
    } catch (e, stack) {
      AppLogger.error(
        'Failed to get public URL for $supabasePath in bucket $bucket',
        e,
        stack,
      );
      throw Exception('Failed to get public URL: ${e.toString()}');
    }
  }
}
