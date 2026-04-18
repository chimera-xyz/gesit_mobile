import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _rememberSession = true;
  bool _loading = false;
  bool _biometricLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: 'raihan@yuliesekuritas.co.id',
    );
    _passwordController = TextEditingController(text: 'Internal@2026');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    widget.onContinue();
  }

  _BiometricPresentation get _biometricPresentation {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const _BiometricPresentation(
          label: 'Masuk dengan Face ID',
          title: 'Verifikasi Face ID',
          icon: Icons.face_rounded,
        );
      case TargetPlatform.android:
        return const _BiometricPresentation(
          label: 'Masuk dengan Fingerprint',
          title: 'Verifikasi Fingerprint',
          icon: Icons.fingerprint_rounded,
        );
      default:
        return const _BiometricPresentation(
          label: 'Masuk dengan Fingerprint',
          title: 'Verifikasi Fingerprint',
          icon: Icons.fingerprint_rounded,
        );
    }
  }

  Future<void> _handleBiometricSignIn() async {
    if (_loading || _biometricLoading) {
      return;
    }

    setState(() => _biometricLoading = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _BiometricPromptDialog(config: _biometricPresentation),
    );

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) {
      return;
    }

    setState(() => _biometricLoading = false);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Internal Access',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                RevealUp(
                  index: 1,
                  child: SvgPicture.asset(
                    'assets/branding/company-login-lockup.svg',
                    height: 46,
                  ),
                ),
                const SizedBox(height: 28),
                RevealUp(
                  index: 2,
                  child: Text(
                    'Masuk ke SiGESIT',
                    style: textTheme.displayMedium?.copyWith(fontSize: 34),
                  ),
                ),
                const SizedBox(height: 8),
                RevealUp(
                  index: 3,
                  child: Text(
                    'Internal workspace PT Yulie Sekuritas Indonesia Tbk.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                RevealUp(
                  index: 4,
                  child: BrandSurface(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: 'Email'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'nama@perusahaan.com',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _FieldLabel(label: 'Password'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Masukkan password',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberSession,
                              onChanged: (value) {
                                setState(
                                  () => _rememberSession = value ?? false,
                                );
                              },
                              activeColor: AppColors.goldDeep,
                              side: const BorderSide(
                                color: AppColors.borderStrong,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Ingat sesi login di perangkat ini',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _handleSignIn,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Masuk ke Workspace'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _InlineDivider(label: 'atau'),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _biometricLoading
                                ? null
                                : _handleBiometricSignIn,
                            icon: _biometricLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(_biometricPresentation.icon),
                            label: Text(_biometricPresentation.label),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Flow bantuan akses siap disambungkan ke backend perusahaan.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Butuh Bantuan Akses'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _InlineDivider extends StatelessWidget {
  const _InlineDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.border;

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor, height: 1)),
      ],
    );
  }
}

class _BiometricPromptDialog extends StatelessWidget {
  const _BiometricPromptDialog({required this.config});

  final _BiometricPresentation config;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(config.icon, color: AppColors.goldDeep, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifikasi untuk melanjutkan masuk ke workspace.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.goldDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricPresentation {
  const _BiometricPresentation({
    required this.label,
    required this.title,
    required this.icon,
  });

  final String label;
  final String title;
  final IconData icon;
}
