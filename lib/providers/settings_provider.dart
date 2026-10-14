import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/cloudinary_service.dart';
import '../services/settings_service.dart';

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService(
    cloudName: AppConfig.cloudinaryCloudName,
    uploadPreset: AppConfig.cloudinaryUploadPreset,
  );
});

final companySettingsProvider = StreamProvider<CompanySettings>((ref) {
  return ref.watch(settingsServiceProvider).watch();
});