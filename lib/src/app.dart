import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_session_controller.dart';
import 'data/gesit_api_client.dart';
import 'navigation/gesit_shell.dart';
import 'screens/login_screen.dart';
import 'screens/opening_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_session_scope.dart';

class GesitApp extends StatefulWidget {
  const GesitApp({super.key});

  @override
  State<GesitApp> createState() => _GesitAppState();
}

class _GesitAppState extends State<GesitApp> {
  late final AppSessionController _sessionController;
  bool _openingComplete = false;

  @override
  void initState() {
    super.initState();
    _sessionController = AppSessionController(apiClient: GesitApiClient())
      ..bootstrap();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  void _handleOpeningComplete() {
    if (_openingComplete) {
      return;
    }

    setState(() => _openingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, _) {
        final Widget currentScreen;
        final nextLabel = switch (_sessionController.status) {
          AppSessionStatus.bootstrapping => 'Menyelaraskan sesi kerja',
          AppSessionStatus.authenticated => 'Membuka workspace',
          AppSessionStatus.unauthenticated => 'Membuka halaman login',
        };

        if (!_openingComplete || _sessionController.isBootstrapping) {
          currentScreen = OpeningScreen(
            key: const ValueKey('opening'),
            nextLabel: nextLabel,
            onFinished: _handleOpeningComplete,
          );
        } else if (_sessionController.isAuthenticated) {
          currentScreen = GesitShell(
            key: const ValueKey('shell'),
            sessionController: _sessionController,
          );
        } else {
          currentScreen = LoginScreen(
            key: const ValueKey('login'),
            sessionController: _sessionController,
          );
        }

        return AppSessionScope(
          notifier: _sessionController,
          child: MaterialApp(
            title: 'GESIT',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            scrollBehavior: const _GesitScrollBehavior(),
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final clampedScale = mediaQuery.textScaler.clamp(
                minScaleFactor: 0.95,
                maxScaleFactor: 1.05,
              );

              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: clampedScale),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.992, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: currentScreen,
            ),
          ),
        );
      },
    );
  }
}

class _GesitScrollBehavior extends MaterialScrollBehavior {
  const _GesitScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
