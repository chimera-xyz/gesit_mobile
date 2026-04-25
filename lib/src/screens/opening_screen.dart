import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key, required this.onFinished, this.nextLabel});

  final VoidCallback onFinished;
  final String? nextLabel;

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _finishTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
    _finishTimer = Timer(const Duration(milliseconds: 2050), _finish);
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_completed) {
      return;
    }

    _completed = true;
    widget.onFinished();
  }

  double _phase(double start, double end, {Curve curve = Curves.linear}) {
    final value = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(value);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvasTop,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final size = MediaQuery.sizeOf(context);
            final fadeIn = _phase(0.0, 0.24, curve: Curves.easeOutCubic);
            final settle = _phase(0.16, 0.70, curve: Curves.easeInOutCubic);
            final fadeOut = _phase(0.82, 1.0, curve: Curves.easeInCubic);

            final logoScale =
                lerpDouble(0.82, 1.0, fadeIn)! *
                lerpDouble(1.0, 1.035, settle)!;
            final logoOpacity = (fadeIn * (1 - (fadeOut * 0.92))).clamp(
              0.0,
              1.0,
            );
            final logoTranslateY =
                lerpDouble(22, 0, fadeIn)! + lerpDouble(0, -8, fadeOut)!;

            return Opacity(
              opacity: (1 - fadeOut).clamp(0.0, 1.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.canvasTop, AppColors.canvasBottom],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -110,
                    left: -80,
                    child: IgnorePointer(
                      child: _GlowOrb(
                        size: 240,
                        colors: [
                          AppColors.goldSoft.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -140,
                    right: -100,
                    child: IgnorePointer(
                      child: _GlowOrb(
                        size: 300,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, logoTranslateY),
                      child: Opacity(
                        opacity: logoOpacity,
                        child: Transform.scale(
                          scale: logoScale,
                          child: SvgPicture.asset(
                            'assets/branding/company-login-lockup.svg',
                            key: const ValueKey('opening-logo'),
                            width: size.width.clamp(240.0, 340.0) * 0.78,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
