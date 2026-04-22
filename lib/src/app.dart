import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_session_controller.dart';
import 'data/app_update_controller.dart';
import 'data/gesit_api_client.dart';
import 'navigation/gesit_shell.dart';
import 'screens/login_screen.dart';
import 'screens/opening_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_session_scope.dart';
import 'widgets/app_update_prompt.dart';

class GesitApp extends StatefulWidget {
  const GesitApp({super.key});

  @override
  State<GesitApp> createState() => _GesitAppState();
}

class _GesitAppState extends State<GesitApp> with WidgetsBindingObserver {
  late final AppSessionController _sessionController;
  late final AppUpdateController _appUpdateController;
  bool _openingComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionController = AppSessionController(apiClient: GesitApiClient())
      ..bootstrap();
    _appUpdateController = AppUpdateController(
      sessionController: _sessionController,
    )..bootstrap();
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
    WidgetsBinding.instance.removeObserver(this);
    _appUpdateController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appUpdateController.refreshIfStale(
        force: _appUpdateController.shouldShowPrompt,
      );
    }
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
      animation: Listenable.merge([_sessionController, _appUpdateController]),
      builder: (context, _) {
        final Widget currentScreen;
        final nextLabel = _appUpdateController.isBootstrapping
            ? 'Memeriksa versi aplikasi'
            : switch (_sessionController.status) {
                AppSessionStatus.bootstrapping => 'Menyelaraskan sesi kerja',
                AppSessionStatus.authenticated => 'Membuka workspace',
                AppSessionStatus.unauthenticated =>
                  'Membuka halaman login',
              };

        if (!_openingComplete ||
            _sessionController.isBootstrapping ||
            _appUpdateController.isBootstrapping) {
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
            home: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.992,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: currentScreen,
                ),
                AppUpdatePrompt(controller: _appUpdateController),
              ],
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
