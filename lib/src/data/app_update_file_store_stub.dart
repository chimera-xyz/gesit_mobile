import 'app_update_file_store_types.dart';

AppUpdateFileStore createAppUpdateFileStore() => _UnsupportedAppUpdateFileStore();

class _UnsupportedAppUpdateFileStore implements AppUpdateFileStore {
  @override
  Future<AppUpdateDownloadArtifact> saveReleaseArchive({
    required Stream<List<int>> stream,
    required String fileName,
    required void Function(int writtenBytes) onBytesWritten,
  }) {
    throw UnsupportedError('App update archive storage is unsupported here.');
  }
}
