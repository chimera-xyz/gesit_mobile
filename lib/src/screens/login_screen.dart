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
