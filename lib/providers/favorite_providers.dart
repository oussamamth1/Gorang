import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'service_providers.dart';

/// Ids of the vehicles the signed-in user has favorited, live.
final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const {});
  return ref.watch(favoriteServiceProvider).watchIds(user.uid);
});
