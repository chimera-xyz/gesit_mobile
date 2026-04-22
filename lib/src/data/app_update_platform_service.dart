import 'package:flutter/services.dart';

abstract class AppUpdatePlatformService {
  Future<bool> canRequestPackageInstalls();

  Future<void> openUnknownAppSourcesSettings();

  Future<void> installApk(String filePath);
}

class MethodChannelAppUpdatePlatformService
    implements AppUpdatePlatformService {
  MethodChannelAppUpdatePlatformService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'gesit/app_update';

  final MethodChannel _channel;

  @override
  Future<bool> canRequestPackageInstalls() async {
    final result = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );

    return result ?? false;
  }

  @override
  Future<void> openUnknownAppSourcesSettings() {
    return _channel.invokeMethod<void>('openUnknownAppSourcesSettings');
  }

  @override
  Future<void> installApk(String filePath) {
    return _channel.invokeMethod<void>('installApk', {
      'filePath': filePath,
    });
  }
}
