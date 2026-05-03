import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../data/app_session_controller.dart';
import '../data/gesit_api_client.dart';
import '../models/session_models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key, required this.sessionController});

  final AppSessionController sessionController;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _selectedPhotoMimeType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioController.text = widget.sessionController.session?.user.bio ?? '';
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhotoSourceSheet(
        onSelect: (source) => Navigator.of(context).pop(source),
      ),
    );
    if (source == null) {
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 86,
    );
    if (pickedFile == null) {
      return;
    }

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) {
      return;
    }

    if (bytes.length > 4 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran foto maksimal 4 MB.')),
      );
      return;
    }

    setState(() {
      _selectedPhotoBytes = bytes;
      _selectedPhotoName = pickedFile.name;
      _selectedPhotoMimeType =
          pickedFile.mimeType ??
          lookupMimeType(pickedFile.name, headerBytes: bytes);
    });
  }

  Future<void> _saveProfile() async {
    final session = widget.sessionController.session;
    if (session == null || _saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.sessionController.updateCurrentUserProfile(
        bio: _bioController.text,
        profilePhoto: _selectedPhotoBytes == null
            ? null
            : ApiMultipartFilePayload(
                fileName: _selectedPhotoName ?? 'profile-photo.jpg',
                bytes: _selectedPhotoBytes,
                contentType: _selectedPhotoMimeType,
              ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedPhotoBytes = null;
        _selectedPhotoName = null;
        _selectedPhotoMimeType = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    } on GesitApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil belum bisa diperbarui.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionController,
      builder: (context, _) {
        final session = widget.sessionController.session;
        if (session == null) {
          return const SizedBox.shrink();
        }

        return _ProfileDetailView(
          session: session,
          bioController: _bioController,
          selectedPhotoBytes: _selectedPhotoBytes,
          saving: _saving,
          onPickPhoto: _pickProfilePhoto,
          onSave: _saveProfile,
        );
      },
    );
  }
}

class _ProfileDetailView extends StatelessWidget {
  const _ProfileDetailView({
    required this.session,
    required this.bioController,
    required this.selectedPhotoBytes,
    required this.saving,
    required this.onPickPhoto,
    required this.onSave,
  });

  final AppSession session;
  final TextEditingController bioController;
  final Uint8List? selectedPhotoBytes;
  final bool saving;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = session.user;
    final photoUrl = user.resolvedProfilePhotoUrl(session.apiBaseUrl);
    final division = _divisionFrom(user);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GesitBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealUp(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Detail Profil',
                          style: textTheme.headlineMedium,
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: FilledButton(
                          onPressed: saving ? null : onSave,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                RevealUp(
                  index: 1,
                  child: BrandSurface(
                    radius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProfilePhotoEditor(
                              initials: user.initials,
                              photoUrl: photoUrl,
                              selectedPhotoBytes: selectedPhotoBytes,
                              onTap: onPickPhoto,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontSize: 23,
                                      height: 1.12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    user.primaryRole,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    division,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            StatusChip(
                              label: '2FA Active',
                              color: AppColors.emerald,
                              icon: Icons.verified_user_rounded,
                            ),
                            StatusChip(
                              label: 'Managed Device',
                              color: AppColors.blue,
                              icon: Icons.devices_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const SectionHeader(eyebrow: 'Bio', title: 'Tentang Saya'),
                const SizedBox(height: 14),
                RevealUp(
                  index: 2,
                  child: TextField(
                    controller: bioController,
                    enabled: !saving,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 180,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Tulis bio singkat untuk profil internal.',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const SectionHeader(
                  eyebrow: 'Identitas',
                  title: 'Data Corporate',
                ),
                const SizedBox(height: 14),
                RevealUp(
                  index: 3,
                  child: BrandSurface(
                    radius: 22,
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Username S21Plus',
                          value: user.s21PlusUserId ?? '-',
                        ),
                        _ProfileInfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email GESIT',
                          value: user.email.isEmpty ? '-' : user.email,
                        ),
                        _ProfileInfoRow(
                          icon: Icons.apartment_rounded,
                          label: 'Divisi',
                          value: division,
                        ),
                        _ProfileInfoRow(
                          icon: Icons.account_tree_rounded,
                          label: 'Department',
                          value: user.department ?? '-',
                        ),
                        _ProfileInfoRow(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Employee ID',
                          value: user.employeeId ?? '-',
                        ),
                        _ProfileInfoRow(
                          icon: Icons.call_rounded,
                          label: 'Phone',
                          value: user.phoneNumber ?? '-',
                          showDivider: false,
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

  String _divisionFrom(AuthenticatedUser user) {
    final rawDepartment = user.department?.trim();
    if (rawDepartment == null || rawDepartment.isEmpty) {
      return user.divisionLabel;
    }

    final separatorMatch = RegExp(r'\s[-/]\s').firstMatch(rawDepartment);
    if (separatorMatch == null) {
      return rawDepartment;
    }

    return rawDepartment.substring(0, separatorMatch.start).trim();
  }
}

class _ProfilePhotoEditor extends StatelessWidget {
  const _ProfilePhotoEditor({
    required this.initials,
    required this.photoUrl,
    required this.selectedPhotoBytes,
    required this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final Uint8List? selectedPhotoBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = selectedPhotoBytes == null
        ? _NetworkProfilePhoto(url: photoUrl, initials: initials)
        : Image.memory(
            selectedPhotoBytes!,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          );

    return Semantics(
      button: true,
      label: 'Ganti foto profil',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Ink(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.goldDeep,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: image,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkProfilePhoto extends StatelessWidget {
  const _NetworkProfilePhoto({required this.url, required this.initials});

  final String? url;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _ProfileInitials(initials: initials);
    }

    return Image.network(
      url!,
      width: 88,
      height: 88,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _ProfileInitials(initials: initials);
      },
    );
  }
}

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.goldDeep, AppColors.gold]),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.goldDeep, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 62),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({required this.onSelect});

  final ValueChanged<ImageSource> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: BrandSurface(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PhotoSourceTile(
                icon: Icons.photo_library_rounded,
                title: 'Pilih dari Galeri',
                onTap: () => onSelect(ImageSource.gallery),
              ),
              const Divider(height: 1),
              _PhotoSourceTile(
                icon: Icons.photo_camera_rounded,
                title: 'Ambil Foto',
                onTap: () => onSelect(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.goldDeep),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}
