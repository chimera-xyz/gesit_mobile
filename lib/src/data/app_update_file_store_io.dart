import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_file_store_types.dart';

AppUpdateFileStore createAppUpdateFileStore() => _IoAppUpdateFileStore();

class _IoAppUpdateFileStore implements AppUpdateFileStore {
  @override
  Future<AppUpdateDownloadArtifact> saveReleaseArchive({
    required Stream<List<int>> stream,
    required String fileName,
    required void Function(int writtenBytes) onBytesWritten,
  }) async {
    final directory = await getTemporaryDirectory();
    final sanitizedFileName = _sanitizeFileName(fileName);
    final file = File('${directory.path}/$sanitizedFileName');

    if (await file.exists()) {
      await file.delete();
    }

    final output = file.openWrite();

    var writtenBytes = 0;

    try {
      await for (final chunk in stream) {
        output.add(chunk);
        writtenBytes += chunk.length;
        onBytesWritten(writtenBytes);
      }
    } catch (_) {
      await output.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }

    await output.close();
    final digest = sha256
        .convert(await file.readAsBytes())
        .toString()
        .toLowerCase();

    return AppUpdateDownloadArtifact(
      filePath: file.path,
      fileSize: writtenBytes,
      sha256: digest,
    );
  }

  String _sanitizeFileName(String rawFileName) {
    final trimmed = rawFileName.trim();
    if (trimmed.isEmpty) {
      return 'gesit-release.apk';
    }

    final sanitized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    return sanitized.toLowerCase().endsWith('.apk')
        ? sanitized
        : '$sanitized.apk';
  }
}
