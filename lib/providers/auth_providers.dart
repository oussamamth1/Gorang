import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_user.dart';
import 'service_providers.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// The signed-in user's Firestore profile (null while signed out).
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchUser(user.uid);
});

/// Any user's Firestore profile by UID — used to display owner info on listings.
final userByIdProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(userServiceProvider).watchUser(uid),
);
