import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common/press_scale.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final (kycLabel, kycHint, kycColor, kycIcon) = switch (user.kycStatus) {
              KycStatus.none => (
                  'Not verified',
                  'Add your documents to start renting',
                  AppColors.warning,
                  Icons.gpp_maybe_rounded
                ),
              KycStatus.pending => (
                  'Verification pending',
                  'We are reviewing your documents',
                  AppColors.info,
                  Icons.hourglass_top_rounded
                ),
              KycStatus.verified => (
                  'Verified',
                  'You can rent any vehicle',
                  AppColors.success,
                  Icons.verified_rounded
                ),
              KycStatus.rejected => (
                  'Verification rejected',
                  'Tap to resubmit your documents',
                  AppColors.danger,
                  Icons.gpp_bad_rounded
                ),
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.surface,
                          child: ClipOval(
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: user.photoUrl != null
                                  ? AppImage(user.photoUrl!)
                                  : Center(
                                      child: Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName[0].toUpperCase()
                                            : '?',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(color: AppColors.primary),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: PressScale(
                          onTap: () => context.push(Routes.editProfile),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.surface, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(user.fullName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(user.email,
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 28),
                PressScale(
                  onTap: user.kycStatus == KycStatus.verified
                      ? null
                      : () => context.push(Routes.kyc),
                  child: _tile(
                    theme,
                    icon: kycIcon,
                    iconColor: kycColor,
                    title: kycLabel,
                    subtitle: kycHint,
                    trailing: user.kycStatus == KycStatus.verified
                        ? null
                        : const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                _tile(
                  theme,
                  icon: Icons.phone_rounded,
                  iconColor: AppColors.primary,
                  title: 'Phone',
                  subtitle: '+216 ${user.phone}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.showPhone ? 'Visible' : 'Hidden',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: user.showPhone
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch.adaptive(
                        value: user.showPhone,
                        onChanged: (v) => ref
                            .read(userServiceProvider)
                            .setShowPhone(user.uid, show: v),
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.4),
                        width: 1.4),
                  ),
                  label: const Text('Sign out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
