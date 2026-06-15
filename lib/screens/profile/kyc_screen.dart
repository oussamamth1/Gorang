import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/press_scale.dart';

/// Identity verification: ID card number + photos of the ID card and
/// driving licence. Required before a user can rent a vehicle.
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumber = TextEditingController();
  XFile? _idCardImage;
  XFile? _licenseImage;
  bool _saving = false;

  @override
  void dispose() {
    _idNumber.dispose();
    super.dispose();
  }

  // Small + compressed: photos are stored as base64 inside the Firestore
  // user document, which is capped at 1 MiB.
  Future<XFile?> _pick() => ImagePicker()
      .pickImage(source: ImageSource.camera, maxWidth: 900, imageQuality: 50);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCardImage == null || _licenseImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Both photos are required')));
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final cin = _idNumber.text.trim();

      // Free on-device AI check: does the typed CIN appear on the ID photo?
      final aiVerified = await ref
          .read(idVerificationServiceProvider)
          .idCardMatchesCin(_idCardImage!, cin);

      if (!aiVerified) {
        if (!mounted) return;
        final submitAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Could not verify automatically'),
            content: const Text(
                'We could not read your CIN number on the ID card photo. '
                'Retake a sharper, well-lit photo for instant verification, '
                'or submit for manual review.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Retake photo')),
              FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit anyway')),
            ],
          ),
        );
        if (submitAnyway != true) {
          if (mounted) setState(() => _idCardImage = null);
          return;
        }
      }

      await ref.read(userServiceProvider).submitKyc(
            uid: user.uid,
            idCardNumber: cin,
            idCardImage: _idCardImage!,
            licenseImage: _licenseImage!,
            autoVerified: aiVerified,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(aiVerified
                ? 'Identity verified automatically — you can rent now!'
                : 'Documents submitted for manual review')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoTile(String title, XFile? file, ValueChanged<XFile> onPicked) {
    final added = file != null;
    final color = added ? AppColors.success : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressScale(
        onTap: () async {
          final picked = await _pick();
          if (picked != null) onPicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: added ? AppColors.success : AppColors.border, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                    added ? Icons.check_rounded : Icons.photo_camera_rounded,
                    color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      added ? 'Photo added — tap to retake' : 'Tap to take a photo',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: added ? AppColors.success : null),
                    ),
                  ],
                ),
              ),
              Icon(
                added ? Icons.refresh_rounded : Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your identity')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To keep the community safe, we verify every renter. '
                          'Verification is instant: our AI reads your CIN '
                          'directly from the photo, on your device.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _idNumber,
                  decoration: const InputDecoration(
                    labelText: 'ID card number (CIN)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().length != 8) ? 'CIN must be 8 digits' : null,
                ),
                const SizedBox(height: 16),
                _photoTile('ID card photo', _idCardImage,
                    (f) => setState(() => _idCardImage = f)),
                _photoTile('Driving licence photo', _licenseImage,
                    (f) => setState(() => _licenseImage = f)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit for review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
