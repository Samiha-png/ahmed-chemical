import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName;
  final String uploadPreset;

  CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
  });

  Future<String> uploadBytes(
    Uint8List bytes,
    String filename, {
    String? folder,
  }) async {
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary is not configured. '
        'Set cloudinaryCloudName and cloudinaryUploadPreset in AppConfig.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset;

    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed (${response.statusCode}): $body',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null) {
      throw Exception('Cloudinary response missing secure_url: $body');
    }
    return url;
  }

  /// Pick a single image and upload.
  Future<String?> pickAndUploadImage({String? folder}) async {
    final picked = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return uploadBytes(bytes, picked.name, folder: folder);
  }

  /// Pick any single file (PDF, etc.) and upload.
  Future<String?> pickAndUploadFile({
    String? folder,
    List<String>? allowedExtensions,
  }) async {
    final picked = await FilePicker.pickFile(
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return uploadBytes(bytes, picked.name, folder: folder);
  }
}