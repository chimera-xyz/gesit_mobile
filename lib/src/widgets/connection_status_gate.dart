import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/connection_status_controller.dart';
import '../theme/app_theme.dart';
import 'connection_mascot_fallback_images.dart';

const _connectionMascotAssetPaths = [
  'assets/illustrations/mascot-offline-sad.png',
  'assets/illustrations/mascot-server-confused.png',
];
const _offlineCanvasColor = Color(0xFFF8F6F7);
const _serverUnavailableCanvasColor = Color(0xFFFFFEFE);

class ConnectionStatusGate extends StatefulWidget {
  const ConnectionStatusGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final ConnectionStatusController controller;
  final Widget child;

  @override
  State<ConnectionStatusGate> createState() => _ConnectionStatusGateState();
}

class _ConnectionStatusGateState extends State<ConnectionStatusGate> {
  bool _didPrecacheConnectionAssets = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didPrecacheConnectionAssets) {
      return;
    }

    _didPrecacheConnectionAssets = true;
    for (final assetPath in _connectionMascotAssetPaths) {
      precacheImage(AssetImage(assetPath), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;

              return IgnorePointer(
                ignoring: !controller.hasIssue,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: controller.hasIssue
                      ? ConnectionLostScreen(
                          key: ValueKey(controller.issue),
                          issue: controller.issue,
                          checking: controller.isChecking,
                          lastCheckedAt: controller.lastCheckedAt,
                          onRetry: () => unawaited(controller.checkNow()),
                        )
                      : const SizedBox.shrink(key: ValueKey('online')),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ConnectionLostScreen extends StatelessWidget {
  const ConnectionLostScreen({
    super.key,
    required this.issue,
    required this.checking,
    required this.onRetry,
    this.lastCheckedAt,
  });

  final ConnectionIssue issue;
  final bool checking;
  final DateTime? lastCheckedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _ConnectionCopy.forIssue(issue);
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width < 420 ? 24.0 : 36.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: copy.canvasColor,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        color: copy.canvasColor,
        child: DecoratedBox(
          decoration: BoxDecoration(color: copy.canvasColor),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableContentWidth =
                    (constraints.maxWidth - (horizontalPadding * 2)).clamp(
                      0.0,
                      430.0,
                    );
                final maxIllustrationWidth = size.height < 700 ? 292.0 : 356.0;
                final illustrationWidth =
                    availableContentWidth < maxIllustrationWidth
                    ? availableContentWidth
                    : maxIllustrationWidth;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _StatusPill(copy: copy),
                              SizedBox(height: size.height < 700 ? 14 : 18),
                              Image.asset(
                                copy.assetPath,
                                width: illustrationWidth,
                                height: illustrationWidth,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                semanticLabel: copy.assetSemanticLabel,
                                errorBuilder: (context, error, stackTrace) {
                                  return _ConnectionMascotFallbackImage(
                                    copy: copy,
                                    size: illustrationWidth,
                                  );
                                },
                              ),
                              SizedBox(height: size.height < 700 ? 16 : 20),
                              Text(
                                copy.title,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                copy.message,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkSoft,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: checking ? null : onRetry,
                                  icon: checking
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    checking ? 'Mengecek...' : 'Coba Lagi',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: copy.actionColor,
                                    disabledBackgroundColor: copy.actionColor
                                        .withValues(alpha: 0.58),
                                    disabledForegroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (lastCheckedAt != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Terakhir dicek ${_formatTime(lastCheckedAt!)}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.copy});

  final _ConnectionCopy copy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: copy.tintColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: copy.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(copy.icon, size: 17, color: copy.actionColor),
            const SizedBox(width: 8),
            Text(
              copy.badge,
              style: textTheme.labelSmall?.copyWith(
                color: copy.actionColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionMascotFallbackImage extends StatelessWidget {
  const _ConnectionMascotFallbackImage({
    required this.copy,
    required this.size,
  });

  final _ConnectionCopy copy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallbackBytes = connectionMascotFallbackBytes(copy.assetPath);

    if (fallbackBytes.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    return Image.memory(
      fallbackBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      semanticLabel: copy.assetSemanticLabel,
    );
  }
}

class _ConnectionCopy {
  const _ConnectionCopy({
    required this.assetPath,
    required this.assetSemanticLabel,
    required this.badge,
    required this.title,
    required this.message,
    required this.icon,
    required this.actionColor,
    required this.tintColor,
    required this.borderColor,
    required this.canvasColor,
  });

  final String assetPath;
  final String assetSemanticLabel;
  final String badge;
  final String title;
  final String message;
  final IconData icon;
  final Color actionColor;
  final Color tintColor;
  final Color borderColor;
  final Color canvasColor;

  static _ConnectionCopy forIssue(ConnectionIssue issue) {
    return switch (issue) {
      ConnectionIssue.offline => _offline,
      ConnectionIssue.serverUnavailable => _serverUnavailable,
      ConnectionIssue.none => _serverUnavailable,
    };
  }

  static const _offline = _ConnectionCopy(
    assetPath: 'assets/illustrations/mascot-offline-sad.png',
    assetSemanticLabel: 'Maskot GESIT sedih karena koneksi offline',
    badge: 'OFFLINE',
    title: 'Kamu sedang offline',
    message: 'Periksa WiFi, kuota, atau mode pesawat, lalu coba lagi.',
    icon: Icons.wifi_off_rounded,
    actionColor: AppColors.goldDeep,
    tintColor: AppColors.goldSoft,
    borderColor: AppColors.borderStrong,
    canvasColor: _offlineCanvasColor,
  );

  static const _serverUnavailable = _ConnectionCopy(
    assetPath: 'assets/illustrations/mascot-server-confused.png',
    assetSemanticLabel: 'Maskot GESIT bingung karena server tidak tersambung',
    badge: 'SERVER',
    title: 'Koneksi ke server terputus',
    message:
        'Internet kamu aktif, tapi GESIT belum bisa tersambung ke server. Coba lagi sebentar.',
    icon: Icons.dns_rounded,
    actionColor: AppColors.blue,
    tintColor: Color(0xFFEAF1FF),
    borderColor: Color(0xFFD9E3F4),
    canvasColor: _serverUnavailableCanvasColor,
  );
}
