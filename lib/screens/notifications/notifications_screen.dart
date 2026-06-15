import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_notification.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/service_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/press_scale.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen clears the unread badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        ref.read(notificationServiceProvider).markAllRead(user.uid);
      }
    });
  }

  void _open(AppNotification n) {
    if (n.refId == null) return;
    switch (n.type) {
      case NotificationType.booking:
        context.push(Routes.bookingDetailPath(n.refId!));
      case NotificationType.vehicle:
        context.push(Routes.vehicleDetailPath(n.refId!));
      case NotificationType.system:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Could not load notifications'),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_rounded,
                title: 'No notifications yet',
                subtitle:
                    'Booking updates and news about your saved vehicles will appear here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final n = list[i];
                  final icon = switch (n.type) {
                    NotificationType.booking => Icons.event_note_rounded,
                    NotificationType.vehicle => Icons.directions_car_rounded,
                    NotificationType.system => Icons.info_rounded,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PressScale(
                      onTap: () => _open(n),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.read ? AppColors.surface : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: n.read
                                  ? AppColors.border
                                  : AppColors.primary.withValues(alpha: 0.25),
                              width: 1.4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon,
                                  size: 20, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(n.title,
                                            style: theme.textTheme.titleSmall),
                                      ),
                                      if (n.createdAt != null)
                                        Text(
                                          DateFormat('d MMM, HH:mm')
                                              .format(n.createdAt!),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(n.body, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
