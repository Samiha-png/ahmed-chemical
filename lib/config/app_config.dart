class AppConfig {
  AppConfig._();

  static const String companyName = 'Ahmed Chemical Co.';
  static const String companyShortName = 'ACC';
  static const String appVersion = '1.0.0';
  static const String baseCurrency = 'PKR';
  static const String timeZone = 'Asia/Karachi';

  // ─── Cloudinary ───
  // Cloud name: from Cloudinary dashboard (top-left)
  // Upload preset: must be UNSIGNED (Settings → Upload → Upload presets)
  static const String cloudinaryCloudName = 'zj88b2fd';
  static const String cloudinaryUploadPreset = 'ahmed_erp_unsigned';
}