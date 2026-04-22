class InstalledAppBuild {
  const InstalledAppBuild({
    required this.versionName,
    required this.versionCode,
    required this.packageName,
  });

  final String versionName;
  final int versionCode;
  final String packageName;

  String get displayLabel => '$versionName ($versionCode)';
}

enum AppUpdateAvailability {
  unsupported,
  unavailable,
  upToDate,
  optionalUpdate,
  requiredUpdate,
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.id,
    required this.platform,
    required this.channel,
    required this.versionName,
    required this.versionCode,
    required this.minimumSupportedVersionCode,
    required this.apkFileName,
    required this.fileSize,
    required this.sha256,
    required this.downloadUrl,
    this.releaseNotes,
    this.publishedAt,
  });

  final int id;
  final String platform;
  final String channel;
  final String versionName;
  final int versionCode;
  final int minimumSupportedVersionCode;
  final String apkFileName;
  final int fileSize;
  final String sha256;
  final String downloadUrl;
  final String? releaseNotes;
  final DateTime? publishedAt;

  String get displayLabel => '$versionName ($versionCode)';

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) {
    return AppUpdateRelease(
      id: _intValue(json['id']),
      platform: '${json['platform'] ?? 'android'}'.trim(),
      channel: '${json['channel'] ?? 'production'}'.trim(),
      versionName: '${json['version_name'] ?? '0.0.0'}'.trim(),
      versionCode: _intValue(json['version_code']),
      minimumSupportedVersionCode: _intValue(
        json['minimum_supported_version_code'],
      ),
      apkFileName: '${json['apk_file_name'] ?? 'gesit-release.apk'}'.trim(),
      fileSize: _intValue(json['file_size']),
      sha256: '${json['sha256'] ?? ''}'.trim().toLowerCase(),
      downloadUrl: '${json['download_url'] ?? ''}'.trim(),
      releaseNotes: _nullableString(json['release_notes']),
      publishedAt: _dateTimeValue(json['published_at']),
    );
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.availability,
    required this.currentBuild,
    this.release,
  });

  final AppUpdateAvailability availability;
  final InstalledAppBuild currentBuild;
  final AppUpdateRelease? release;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse('${value ?? ''}') ?? 0;
}

String? _nullableString(Object? value) {
  final normalized = '${value ?? ''}'.trim();

  return normalized.isEmpty ? null : normalized;
}

DateTime? _dateTimeValue(Object? value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return DateTime.tryParse(normalized);
}
