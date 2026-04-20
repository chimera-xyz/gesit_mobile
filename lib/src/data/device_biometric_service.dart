import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class DeviceBiometricService {
  DeviceBiometricService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  bool get supportsBiometricLoginUi {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get platformValue {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unsupported';
    }
  }

  String get defaultDeviceName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'GESIT Android';
      case TargetPlatform.iOS:
        return 'GESIT iPhone';
      default:
        return 'GESIT Device';
    }
  }

  Future<bool> isSupported() async {
    if (!supportsBiometricLoginUi) {
      return false;
    }

    try {
      return await _localAuthentication.canCheckBiometrics;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String localizedReason}) async {
    if (!supportsBiometricLoginUi) {
      return false;
    }

    try {
      return await _localAuthentication.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
