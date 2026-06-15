import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/vehicle.dart';
import '../providers/service_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/bookings/booking_detail_screen.dart';
import '../screens/bookings/rental_contract_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/kyc_screen.dart';
import '../screens/vehicles/add_vehicle_screen.dart';
import '../screens/vehicles/vehicle_detail_screen.dart';
import 'routes.dart';

/// Re-runs the router redirect whenever the Firebase auth state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final refresh = _RouterRefresh(authService.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = authService.currentUser != null;
      final onAuthPage =
          state.matchedLocation == Routes.login || state.matchedLocation == Routes.register;
      if (!loggedIn && !onAuthPage) return Routes.login;
      if (loggedIn && onAuthPage) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeShell()),
      GoRoute(path: Routes.kyc, builder: (_, _) => const KycScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: Routes.addVehicle, builder: (_, _) => const AddVehicleScreen()),
      GoRoute(
        path: Routes.editVehicle,
        builder: (_, state) => AddVehicleScreen(vehicle: state.extra as Vehicle?),
      ),
      GoRoute(path: Routes.favorites, builder: (_, _) => const FavoritesScreen()),
      GoRoute(
          path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: Routes.vehicleDetail,
        builder: (_, state) => VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.bookingDetail,
        builder: (_, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.rentalContract,
        builder: (_, state) =>
            RentalContractScreen(bookingId: state.pathParameters['id']!),
      ),
    ],
  );
});
