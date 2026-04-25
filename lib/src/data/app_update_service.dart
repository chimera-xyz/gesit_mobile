import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_runtime_config.dart';
import 'app_update_file_store.dart';
import 'app_update_file_store_types.dart';
import 'app_update_models.dart';

abstract class AppBuildInfoProvider {
  Future<InstalledAppBuild> loadBuild();
}

class PackageInfoAppBuildInfoProvider implements AppBuildInfoProvider {
  @override
  Future<InstalledAppBuild> loadBuild() async {
    final packageInfo = await PackageInfo.fromPlatform();

    return InstalledAppBuild(
      versionName: packageInfo.version,
      versionCode: int.tryParse(packageInfo.buildNumber) ?? 0,
      packageName: packageInfo.packageName,
    );
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateService {
  AppUpdateService({
    http.Client? httpClient,
    AppBuildInfoProvider? buildInfoProvider,
    AppUpdateFileStore? fileStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _buildInfoProvider =
           buildInfoProvider ?? PackageInfoAppBuildInfoProvider(),
       _fileStore = fileStore ?? createAppUpdateFileStore();

  final http.Client _httpClient;
  final AppBuildInfoProvider _buildInfoProvider;
  final AppUpdateFileStore _fileStore;

  Future<AppUpdateCheckResult> checkForUpdate({required String baseUrl}) async {
    final currentBuild = await _buildInfoProvider.loadBuild();
    final normalizedBaseUrl = AppRuntimeConfig.normalizeBaseUrl(baseUrl);

    final uri = Uri.parse(normalizedBaseUrl).resolve(
      '/api/mobile-app/releases/latest?platform=android&channel=production&current_version_code=${currentBuild.versionCode}',
    );

    late final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const AppUpdateException(
        'Server pembaruan terlalu lama merespons. Coba lagi sebentar.',
      );
    } catch (_) {
      throw const AppUpdateException(
        'Gagal menghubungi server pembaruan aplikasi.',
      );
    }

    if (response.statusCode == 404 || response.statusCode == 501) {
      return AppUpdateCheckResult(
        availability: AppUpdateAvailability.unavailable,
        currentBuild: currentBuild,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException(
        _errorMessageFromBody(response.body) ??
            'Server pembaruan mengembalikan status ${response.statusCode}.',
      );
    }

    final payload = _jsonMap(response.body);
    final releasePayload = payload['release'];
    final release = releasePayload is Map<String, dynamic>
        ? AppUpdateRelease.fromJson(releasePayload)
        : releasePayload is Map
        ? AppUpdateRelease.fromJson(releasePayload.cast<String, dynamic>())
        : null;

    return AppUpdateCheckResult(
      availability: _availabilityFromStatus('${payload['status'] ?? ''}'),
      currentBuild: currentBuild,
      release: release,
    );
  }

  Future<AppUpdateDownloadArtifact> downloadRelease(
    AppUpdateRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    final downloadUrl = release.downloadUrl.trim();
    if (downloadUrl.isEmpty) {
      throw const AppUpdateException(
        'Link unduhan APK tidak tersedia untuk release ini.',
      );
    }

    final request = http.Request('GET', Uri.parse(downloadUrl));

    late final http.StreamedResponse response;
    try {
      response = await _httpClient
          .send(request)
          .timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const AppUpdateException('Unduhan APK terlalu lama. Coba lagi.');
    } catch (_) {
      throw const AppUpdateException('Unduhan APK gagal dimulai.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw AppUpdateException(
        _errorMessageFromBody(body) ??
            'Unduhan APK gagal dengan status ${response.statusCode}.',
      );
    }

    final expectedSize = release.fileSize > 0
        ? release.fileSize
        : (response.contentLength ?? 0);

    onProgress(0);
    late final AppUpdateDownloadArtifact artifact;
    try {
      artifact = await _fileStore.saveReleaseArchive(
        stream: response.stream,
        fileName: release.apkFileName,
        onBytesWritten: (writtenBytes) {
          if (expectedSize <= 0) {
            return;
          }

          final progress = writtenBytes / expectedSize;
          onProgress(progress.clamp(0, 1).toDouble());
        },
      );
    } catch (error) {
      debugPrint('App update download stream failed: $error');
      throw const AppUpdateException(
        'Unduhan APK terputus sebelum selesai. Cek koneksi ke server pembaruan lalu coba lagi.',
      );
    }

    if (release.fileSize > 0 && artifact.fileSize != release.fileSize) {
      throw const AppUpdateException(
        'Ukuran file APK tidak sesuai dengan metadata release.',
      );
    }

    if (release.sha256.isNotEmpty &&
        artifact.sha256.toLowerCase() != release.sha256.toLowerCase()) {
      throw const AppUpdateException(
        'Checksum APK tidak cocok. Unduhan dibatalkan untuk keamanan.',
      );
    }

    onProgress(1);
    return artifact;
  }

  void dispose() {
    _httpClient.close();
  }

  AppUpdateAvailability _availabilityFromStatus(String status) {
    switch (status.trim()) {
      case 'force_update':
        return AppUpdateAvailability.requiredUpdate;
      case 'optional_update':
        return AppUpdateAvailability.optionalUpdate;
      case 'up_to_date':
        return AppUpdateAvailability.upToDate;
      case 'unsupported_platform':
        return AppUpdateAvailability.unsupported;
      default:
        return AppUpdateAvailability.unavailable;
    }
  }

  Map<String, dynamic> _jsonMap(String body) {
    if (body.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }

    return const <String, dynamic>{};
  }

  String? _errorMessageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = '${decoded['error'] ?? decoded['message'] ?? ''}'.trim();
        return error.isEmpty ? null : error;
      }
      if (decoded is Map) {
        final error = '${decoded['error'] ?? decoded['message'] ?? ''}'.trim();
        return error.isEmpty ? null : error;
      }
    } catch (_) {
      // Ignore malformed JSON and use the fallback error.
    }

    final normalized = body.trim();
    if (normalized.startsWith('<!DOCTYPE html') ||
        normalized.startsWith('<html')) {
      return 'Server pembaruan menolak request unduhan APK.';
    }

    return normalized.isEmpty ? null : normalized;
  }
}
