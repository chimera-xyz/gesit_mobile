import 'package:flutter/material.dart';

import '../data/app_update_controller.dart';
import '../theme/app_theme.dart';
import 'brand_widgets.dart';

class AppUpdatePrompt extends StatelessWidget {
  const AppUpdatePrompt({
    super.key,
    required this.controller,
  });

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.shouldShowPrompt) {
          return const SizedBox.shrink();
        }

        final release = controller.release;
        final currentBuild = controller.currentBuild;
        if (release == null || currentBuild == null) {
          return const SizedBox.shrink();
        }

        final isRequired = controller.isRequired;
        final textTheme = Theme.of(context).textTheme;

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.48),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: BrandSurface(
                        padding: const EdgeInsets.all(24),
                        backgroundColor: AppColors.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isRequired
                                    ? const Color(0xFFFFF1F2)
                                    : AppColors.goldSoft.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                isRequired
                                    ? Icons.system_update_alt_rounded
                                    : Icons.download_rounded,
                                color: isRequired
                                    ? const Color(0xFFBE123C)
                                    : AppColors.goldDeep,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              isRequired
                                  ? 'Versi baru tersedia dan wajib dipasang'
                                  : 'Versi baru GESIT tersedia',
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isRequired
                                  ? 'Untuk melanjutkan memakai aplikasi, Anda perlu memasang APK terbaru yang sudah dipublikasikan oleh sistem internal.'
                                  : 'Anda bisa memasang APK terbaru sekarang untuk mendapatkan fitur dan perbaikan terbaru.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _VersionSummary(
                              currentVersion: currentBuild.displayLabel,
                              latestVersion: release.displayLabel,
                              minimumSupportedVersionCode:
                                  release.minimumSupportedVersionCode,
                            ),
                            if (release.releaseNotes != null &&
                                release.releaseNotes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Release Notes',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.goldDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      release.releaseNotes!,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AppColors.ink,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (controller.isDownloading) ...[
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: controller.downloadProgress.clamp(
                                    0,
                                    1,
                                  ),
                                  minHeight: 10,
                                  backgroundColor: AppColors.goldSoft,
                                  color: AppColors.goldDeep,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Mengunduh APK ${(controller.downloadProgress * 100).toStringAsFixed(0)}%',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (controller.statusMessage != null) ...[
                              const SizedBox(height: 18),
                              _InfoBanner(message: controller.statusMessage!),
                            ],
                            if (controller.errorMessage != null) ...[
                              const SizedBox(height: 18),
                              _ErrorBanner(message: controller.errorMessage!),
                            ],
                            const SizedBox(height: 22),
                            if (controller.needsInstallPermission) ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: controller.openUnknownAppSourcesSettings,
                                  child: const Text('Buka Pengaturan Instalasi'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: controller.beginUpdate,
                                  child: const Text('Saya Sudah Mengizinkan'),
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: controller.isBusy
                                      ? null
                                      : controller.beginUpdate,
                                  child: Text(
                                    controller.isDownloading
                                        ? 'Mengunduh...'
                                        : 'Update Sekarang',
                                  ),
                                ),
                              ),
                              if (!isRequired) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: controller.dismissOptionalUpdate,
                                    child: const Text('Nanti Saja'),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Catatan: installer Android akan muncul setelah unduhan selesai. Pastikan izin instalasi dari sumber internal GESIT sudah diaktifkan.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                                height: 1.5,
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
          ],
        );
      },
    );
  }
}

class _VersionSummary extends StatelessWidget {
  const _VersionSummary({
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumSupportedVersionCode,
  });

  final String currentVersion;
  final String latestVersion;
  final int minimumSupportedVersionCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _VersionRow(label: 'Versi saat ini', value: currentVersion),
          const SizedBox(height: 12),
          _VersionRow(label: 'Versi terbaru', value: latestVersion),
          const SizedBox(height: 12),
          _VersionRow(
            label: 'Minimum supported',
            value: '$minimumSupportedVersionCode',
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: emphasized ? AppColors.red : AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.goldDeep,
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
