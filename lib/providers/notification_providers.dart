import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_notification.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(notificationServiceProvider).watch(user.uid);
});

/// Number of unread notifications — drives the bell badge.
final unreadNotificationsProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? const [];
  return notifications.where((n) => !n.read).length;
});
