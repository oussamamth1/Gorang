import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'service_providers.dart';

/// Watching this provider activates FCM for the signed-in user.
/// Watch it once in the root widget so it stays alive for the session.
final fcmInitProvider = Provider<void>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid != null) ref.read(fcmServiceProvider).init(uid);
});
