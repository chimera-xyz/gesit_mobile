import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

const _transactionLoadingAssetPath = 'assets/animations/yulie_loading.mp4';
const _transactionLoadingCanvas = Color(0xFFFFFFFF);

Future<T> runWithTransactionLoading<T>({
  required BuildContext context,
  required String message,
  required Future<T> Function() task,
  String delayedMessage = 'Mohon tunggu sebentar.',
  Duration minimumVisibleDuration = const Duration(milliseconds: 650),
  Duration delayedMessageAfter = const Duration(seconds: 6),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();

  final navigator = Navigator.of(context, rootNavigator: true);
  var routeOpen = true;
  final startedAt = DateTime.now();
  final loadingRoute = showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: _transactionLoadingCanvas,
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return TransactionLoadingScreen(
        message: message,
        delayedMessage: delayedMessage,
        delayedMessageAfter: delayedMessageAfter,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  ).whenComplete(() => routeOpen = false);

  Future<void> keepMinimumDuration() async {
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = minimumVisibleDuration - elapsed;
    if (!remaining.isNegative) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> dismissLoadingRoute() async {
    if (!routeOpen) {
      return;
    }

    if (!navigator.mounted) {
      unawaited(loadingRoute);
      return;
    }

    navigator.pop();
    await loadingRoute;
  }

  try {
    return await task();
  } finally {
    await keepMinimumDuration();
    await dismissLoadingRoute();
  }
}

class TransactionLoadingScreen extends StatefulWidget {
  const TransactionLoadingScreen({
    super.key,
    required this.message,
    this.delayedMessage = 'Mohon tunggu sebentar.',
    this.delayedMessageAfter = const Duration(seconds: 6),
  });

  final String message;
  final String delayedMessage;
  final Duration delayedMessageAfter;

  @override
  State<TransactionLoadingScreen> createState() =>
      _TransactionLoadingScreenState();
}

class _TransactionLoadingScreenState extends State<TransactionLoadingScreen>
    with WidgetsBindingObserver {
  late final VideoPlayerController _videoController;
  Timer? _delayedMessageTimer;
  bool _videoReady = false;
  bool _showDelayedMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _videoController = VideoPlayerController.asset(
      _transactionLoadingAssetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    unawaited(_prepareVideo());

    _delayedMessageTimer = Timer(widget.delayedMessageAfter, () {
      if (!mounted) {
        return;
      }
      setState(() => _showDelayedMessage = true);
    });
  }

  Future<void> _prepareVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0);
      await _videoController.play();

      if (!mounted) {
        return;
      }

      setState(() => _videoReady = true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _videoReady = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_videoReady) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_videoController.play());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_videoController.pause());
    }
  }

  @override
  void dispose() {
    _delayedMessageTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;
    final logoSize = shortestSide < 380 ? 224.0 : 254.0;
    final verticalPadding = size.height < 700 ? 28.0 : 40.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _transactionLoadingCanvas,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        child: Material(
          color: _transactionLoadingCanvas,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: verticalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _videoReady
                              ? _LoadingVideo(
                                  key: const ValueKey('loading-video'),
                                  controller: _videoController,
                                )
                              : const _LoadingFallback(
                                  key: ValueKey('loading-fallback'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _showDelayedMessage
                            ? Text(
                                widget.delayedMessage,
                                key: const ValueKey('delayed-message'),
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey('delayed-placeholder'),
                                height: 18,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingVideo extends StatelessWidget {
  const _LoadingVideo({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _LoadingFallback extends StatelessWidget {
  const _LoadingFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          strokeWidth: 2.8,
          color: AppColors.goldDeep.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
