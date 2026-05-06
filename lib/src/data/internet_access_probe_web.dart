// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

const _internetProbeImages = <String>[
  'https://www.gstatic.com/images/branding/product/1x/googleg_standard_color_128dp.png',
  'https://www.cloudflare.com/favicon.ico',
];

Future<bool> hasInternetAccess({
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (html.window.navigator.onLine == false) {
    return false;
  }

  for (final rawUrl in _internetProbeImages) {
    if (await _canLoadImage(rawUrl, timeout: timeout)) {
      return true;
    }
  }

  return false;
}

Future<bool> _canLoadImage(String rawUrl, {required Duration timeout}) {
  final completer = Completer<bool>();
  final image = html.ImageElement();
  late final StreamSubscription<html.Event> loadSubscription;
  late final StreamSubscription<html.Event> errorSubscription;
  late final Timer timeoutTimer;

  void complete(bool value) {
    if (completer.isCompleted) {
      return;
    }

    timeoutTimer.cancel();
    unawaited(loadSubscription.cancel());
    unawaited(errorSubscription.cancel());
    completer.complete(value);
  }

  loadSubscription = image.onLoad.listen((_) => complete(true));
  errorSubscription = image.onError.listen((_) => complete(false));
  timeoutTimer = Timer(timeout, () => complete(false));
  image.src =
      '$rawUrl${rawUrl.contains('?') ? '&' : '?'}gesit_probe=${DateTime.now().millisecondsSinceEpoch}';

  return completer.future;
}
