import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/session_store.dart';
import 'navigation/gesit_shell.dart';
import 'screens/login_screen.dart';
import 'screens/opening_screen.dart';
import 'theme/app_theme.dart';

class GesitApp extends StatefulWidget {
  const GesitApp({super.key});

  @override
  State<GesitApp> createState() => _GesitAppState();
}

class _GesitAppState extends State<GesitApp> {
  bool? _authenticated;
  bool _openingComplete = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
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

  Future<void> _restoreSession() async {
    final authenticated = await SessionStore.readAuthenticated();
    if (!mounted) {
      return;
    }
    setState(() => _authenticated = authenticated);
  }

  Future<void> _setAuthenticated(bool value) async {
    if (mounted) {
      setState(() => _authenticated = value);
    }
    await SessionStore.writeAuthenticated(value);
  }

  void _handleOpeningComplete() {
    if (_openingComplete) {
      return;
    }

    setState(() => _openingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget currentScreen;

    if (!_openingComplete || _authenticated == null) {
      currentScreen = OpeningScreen(
        key: const ValueKey('opening'),
        nextLabel: _authenticated == null
            ? null
            : _authenticated!
            ? 'Membuka dashboard'
            : 'Membuka halaman login',
        onFinished: _handleOpeningComplete,
      );
    } else if (_authenticated!) {
      currentScreen = GesitShell(
        key: const ValueKey('shell'),
        onLogout: () {
          _setAuthenticated(false);
        },
      );
    } else {
      currentScreen = LoginScreen(
        key: const ValueKey('login'),
        onContinue: () {
          _setAuthenticated(true);
        },
      );
    }

    return MaterialApp(
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
