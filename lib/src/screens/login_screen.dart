import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_runtime_config.dart';
import '../data/app_session_controller.dart';
import '../data/biometric_token_store.dart';
import '../data/device_biometric_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.sessionController,
    this.biometricTokenStore,
    this.deviceBiometricService,
  });

  final AppSessionController sessionController;
  final BiometricTokenStore? biometricTokenStore;
  final DeviceBiometricService? deviceBiometricService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final BiometricTokenStore _biometricTokenStore;
  late final DeviceBiometricService _deviceBiometricService;
  bool _rememberSession = true;
  bool _biometricLoading = false;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(
      text: widget.sessionController.apiBaseUrlDraft,
    );
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _biometricTokenStore = widget.biometricTokenStore ?? BiometricTokenStore();
    _deviceBiometricService =
        widget.deviceBiometricService ?? DeviceBiometricService();
    _rememberSession = widget.sessionController.rememberSession;
    unawaited(_loadBiometricSupport());
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSupport() async {
    final supported = await _deviceBiometricService.isSupported();
    if (!mounted) {
      return;
    }
    setState(() => _biometricSupported = supported);
  }

  Future<bool> _refreshBiometricSupport() async {
    final supported = await _deviceBiometricService.isSupported();
    if (mounted && supported != _biometricSupported) {
      setState(() => _biometricSupported = supported);
    } else {
      _biometricSupported = supported;
    }
    return supported;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleApiBaseUrlChanged(String value) async {
    await widget.sessionController.updateApiBaseUrl(value);
    widget.sessionController.clearError();
  }

  Future<void> _resetApiBaseUrl() async {
    final fallback = AppRuntimeConfig.defaultApiBaseUrl;
    _apiBaseUrlController.value = TextEditingValue(
      text: fallback,
      selection: TextSelection.collapsed(offset: fallback.length),
    );
    await _handleApiBaseUrlChanged(fallback);
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    await widget.sessionController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
      rememberSession: _rememberSession,
    );
    if (!mounted || !widget.sessionController.isAuthenticated) {
      return;
    }

    if (!_rememberSession) {
      await _biometricTokenStore.clearToken();
      return;
    }

    final biometricSupported = await _refreshBiometricSupport();
    if (!biometricSupported) {
      return;
    }

    try {
      final deviceId = await _biometricTokenStore.readOrCreateDeviceId();
      final enrollment = await widget.sessionController.enrollMobileBiometric(
        deviceId: deviceId,
        deviceName: _deviceBiometricService.defaultDeviceName,
        platform: _deviceBiometricService.platformValue,
      );
      final session = widget.sessionController.session;
      if (session == null) {
        return;
      }
      await _biometricTokenStore.writeToken(
        token: enrollment.token,
        baseUrl: session.apiBaseUrl,
        deviceId: deviceId,
        deviceName: _deviceBiometricService.defaultDeviceName,
        platform: _deviceBiometricService.platformValue,
      );
    } catch (_) {
      _showSnackBar(
        'Login berhasil, tetapi aktivasi fingerprint di perangkat ini belum selesai.',
      );
    }
  }

  Future<StoredBiometricToken?> _readStoredBiometricToken() async {
    final storedToken = await _biometricTokenStore.readToken();
    if (storedToken != null) {
      return storedToken;
    }

    _showSnackBar(
      'Login fingerprint akan aktif setelah Anda login manual sekali di perangkat ini.',
    );
    return null;
  }

  Future<void> _completeBiometricSignIn(
    StoredBiometricToken storedToken,
  ) async {
    setState(() => _biometricLoading = true);

    try {
      final authenticated = await _deviceBiometricService.authenticate(
        localizedReason:
            '${_biometricPresentation.title} untuk masuk ke workspace GESIT.',
      );

      if (!authenticated) {
        return;
      }

      final response = await widget.sessionController.signInWithBiometricToken(
        biometricToken: storedToken.token,
        baseUrl: storedToken.baseUrl,
      );

      if (response?.biometricToken != null) {
        await _biometricTokenStore.writeToken(
          token: response!.biometricToken!,
          baseUrl: storedToken.baseUrl,
          deviceId: storedToken.deviceId,
          deviceName: storedToken.deviceName,
          platform: storedToken.platform,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _biometricLoading = false);
      }
    }
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
    if (widget.sessionController.isBusy || _biometricLoading) {
      return;
    }

    final biometricSupported = await _refreshBiometricSupport();
    if (!biometricSupported) {
      _showSnackBar(
        'Fingerprint belum tersedia di perangkat ini. Gunakan login email dan password terlebih dahulu.',
      );
      return;
    }

    final storedToken = await _readStoredBiometricToken();
    if (storedToken == null) {
      return;
    }

    await _completeBiometricSignIn(storedToken);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionController,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final isLoading = widget.sessionController.isBusy;
        final errorMessage = widget.sessionController.errorMessage;
        final defaultApiBaseUrl = AppRuntimeConfig.defaultApiBaseUrl;

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
                            if (kIsWeb) ...[
                              _FieldLabel(label: 'Alamat API'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _apiBaseUrlController,
                                keyboardType: TextInputType.url,
                                onChanged: (value) {
                                  unawaited(_handleApiBaseUrlChanged(value));
                                },
                                decoration: InputDecoration(
                                  hintText: defaultApiBaseUrl,
                                  helperText:
                                      'Alamat default saat ini: $defaultApiBaseUrl',
                                  suffixIcon: IconButton(
                                    tooltip: 'Reset alamat API',
                                    onPressed: _resetApiBaseUrl,
                                    icon: const Icon(Icons.refresh_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            _FieldLabel(label: 'Email'),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) =>
                                  widget.sessionController.clearError(),
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
                              onChanged: (_) =>
                                  widget.sessionController.clearError(),
                              decoration: const InputDecoration(
                                hintText: 'Masukkan password',
                              ),
                            ),
                            if (errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _LoginErrorBanner(message: errorMessage),
                            ],
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
                                onPressed: isLoading ? null : _handleSignIn,
                                child: isLoading
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
                            if (_biometricSupported) ...[
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
                            ],
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
      },
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0C6BC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.red,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
