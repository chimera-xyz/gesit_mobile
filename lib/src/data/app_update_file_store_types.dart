abstract class AppUpdateFileStore {
  Future<AppUpdateDownloadArtifact> saveReleaseArchive({
    required Stream<List<int>> stream,
    required String fileName,
    required void Function(int writtenBytes) onBytesWritten,
  });
}

class AppUpdateDownloadArtifact {
  const AppUpdateDownloadArtifact({
    required this.filePath,
    required this.fileSize,
    required this.sha256,
  });

  final String filePath;
  final int fileSize;
  final String sha256;
}
