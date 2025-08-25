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
