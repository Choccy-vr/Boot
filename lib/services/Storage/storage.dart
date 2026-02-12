import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boot_app/services/misc/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static const _publicBaseUrl =
      'https://pub-cf54be118c1744359d9745f16deaa5fb.r2.dev';

  static const List<String> _allowedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
  ];

  static const Map<String, String> _mimeByExtension = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  static Future<void> initialize() async {
    AppLogger.info('StorageService initialized');
  }

  static Future<String> uploadFileWithPicker({required String path}) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (selection == null || selection.files.isEmpty) {
      return 'User cancelled';
    }

    final file = selection.files.single;
    _validateExtension(file);

    try {
      await _uploadPlatformFile(file, path);
      return path;
    } catch (e, stack) {
      AppLogger.error('Failed to upload $path', e, stack);
      rethrow;
    }
  }

  static Future<List<String>> uploadMultipleFiles({
    required List<PlatformFile> files,
    required String dirPath,
  }) async {
    final uploadedPaths = <String>[];

    for (final file in files) {
      _validateExtension(file);
      final objectPath = '$dirPath/${file.name}';

      try {
        await _uploadPlatformFile(file, objectPath);
        uploadedPaths.add(objectPath);
      } catch (e, stack) {
        AppLogger.error('Failed to upload ${file.name}', e, stack);
      }
    }

    return uploadedPaths;
  }

  static Future<String?> getPublicUrl({required String path}) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.isEmpty) return null;
    return '$_publicBaseUrl/$cleanPath';
  }

  static Future<void> _uploadPlatformFile(
    PlatformFile file,
    String objectPath,
  ) async {
    final bytes = await _loadFileBytes(file);
    final mimeType = _detectMimeType(file.name);
    await _uploadViaPresignedUrl(
      key: objectPath,
      bytes: bytes,
      contentType: mimeType,
    );
  }

  static Future<void> _uploadViaPresignedUrl({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception('User must be authenticated to upload files');
      }

      final response = await supabase.functions.invoke(
        'generate-upload-url',
        body: {'path': key, 'contentType': contentType},
      );

      if (response.data == null) {
        throw Exception('Failed to get upload URL: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      final uploadUrl = data['uploadUrl'] as String;

      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );

      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw Exception(
          'Upload failed (${uploadResponse.statusCode}): ${uploadResponse.body}',
        );
      }

      AppLogger.info('Successfully uploaded $key');
    } catch (e, stack) {
      AppLogger.error('Failed to upload via presigned URL', e, stack);
      rethrow;
    }
  }

  static void _validateExtension(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      throw Exception('Unsupported file type: .$ext');
    }
  }

  static String _detectMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _mimeByExtension[ext] ?? 'application/octet-stream';
  }

  static Future<Uint8List> _loadFileBytes(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('File bytes missing for ${file.name}');
      }
      return Uint8List.fromList(bytes);
    }

    final path = file.path;
    if (path == null) {
      throw Exception('File path missing for ${file.name}');
    }
    return File(path).readAsBytes();
  }
}
