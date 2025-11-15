import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boot_app/services/misc/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class StorageService {
  static const _region = 'us-east-1';
  static const _bucket = 'boot';
  static const _serviceName = 's3';
  static const _signatureAlgorithm = 'AWS4-HMAC-SHA256';
  static const _requestType = 'aws4_request';
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

  static _R2Credentials? _credentials;

  static Future<void> initialize() async {
    if (_credentials != null) return;
    try {
      _credentials = const _R2Credentials(
        accountId: 'aa65a7097ad082df3dd34a27a0f5324c',
        accessKeyId: '9f9e0b8124183524d1619284853e365d',
        secretAccessKey:
            'dc9cdccc03e05ca076e6fb4bd96ade5385cc8c3e2ba5027f90e2f1893d27ce37',
      );
      AppLogger.info('StorageService initialized');
    } catch (e, stack) {
      AppLogger.error('Failed to initialize StorageService', e, stack);
      rethrow;
    }
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
    await _putObject(key: objectPath, bytes: bytes, contentType: mimeType);
  }

  static Future<void> _putObject({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final creds = _ensureCredentials();
    final sanitizedKey = _sanitizeKey(key);
    final uri = Uri.https(
      '${creds.accountId}.r2.cloudflarestorage.com',
      '/$_bucket/$sanitizedKey',
    );

    final timestamp = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(timestamp);
    final dateStamp = _formatDateStamp(timestamp);
    final payloadHash = _hashHex(bytes);

    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    final canonicalHeaders = StringBuffer()
      ..writeln('content-type:$contentType')
      ..writeln('host:${uri.host}')
      ..writeln('x-amz-content-sha256:$payloadHash')
      ..writeln('x-amz-date:$amzDate');

    final canonicalRequest = [
      'PUT',
      uri.path,
      '',
      canonicalHeaders.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/$_region/$_serviceName/$_requestType';
    final stringToSign = [
      _signatureAlgorithm,
      amzDate,
      credentialScope,
      _hashHex(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _deriveSigningKey(creds.secretAccessKey, dateStamp);
    final signature = _bytesToHex(
      Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).bytes,
    );

    final headers = {
      'Content-Type': contentType,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      'Authorization':
          '$_signatureAlgorithm Credential=${creds.accessKeyId}/$credentialScope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    };

    final response = await http.put(uri, headers: headers, body: bytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Upload failed (${response.statusCode}): ${response.body}',
      );
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

  static _R2Credentials _ensureCredentials() {
    final creds = _credentials;
    if (creds == null) {
      throw StateError('StorageService.initialize must be called first.');
    }
    return creds;
  }

  static String _sanitizeKey(String key) {
    return key.split('/').where((segment) => segment.isNotEmpty).join('/');
  }

  static String _formatAmzDate(DateTime timestamp) {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '$y$m${d}T$hh$mm${ss}Z';
  }

  static String _formatDateStamp(DateTime timestamp) {
    final y = timestamp.year.toString().padLeft(4, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _hashHex(List<int> data) => sha256.convert(data).toString();

  static List<int> _deriveSigningKey(String secretAccessKey, String dateStamp) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretAccessKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, _region);
    final kService = _hmacSha256(kRegion, _serviceName);
    return _hmacSha256(kService, _requestType);
  }

  static List<int> _hmacSha256(List<int> key, String message) {
    return Hmac(sha256, key).convert(utf8.encode(message)).bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final part in bytes) {
      buffer.write(part.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class _R2Credentials {
  const _R2Credentials({
    required this.accountId,
    required this.accessKeyId,
    required this.secretAccessKey,
  });

  final String accountId;
  final String accessKeyId;
  final String secretAccessKey;
}
