import 'app_update_file_store_types.dart';
import 'app_update_file_store_stub.dart'
    if (dart.library.io) 'app_update_file_store_io.dart' as delegate;

AppUpdateFileStore createAppUpdateFileStore() =>
    delegate.createAppUpdateFileStore();
