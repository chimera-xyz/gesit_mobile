import 'package:flutter/widgets.dart';

import '../data/app_session_controller.dart';

class AppSessionScope extends InheritedNotifier<AppSessionController> {
  const AppSessionScope({
    super.key,
    required AppSessionController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppSessionController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();
    assert(scope != null, 'AppSessionScope is missing in the widget tree.');
    return scope!.notifier!;
  }

  static AppSessionController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppSessionScope>();
    final scope = element?.widget as AppSessionScope?;
    assert(scope != null, 'AppSessionScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
