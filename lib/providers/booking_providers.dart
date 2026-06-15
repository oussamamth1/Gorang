import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/booking.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

/// Earnings summary derived from the signed-in owner's completed bookings.
typedef OwnerEarnings = ({double totalEarned, int completedTrips});

/// Bookings where the signed-in user is the renter ("My trips").
final myRentalsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(bookingServiceProvider).watchAsRenter(user.uid);
});

/// Bookings on vehicles the signed-in user owns ("Requests").
final ownerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(bookingServiceProvider).watchAsOwner(user.uid);
});

final bookingByIdProvider = StreamProvider.family<Booking?, String>(
  (ref, id) => ref.watch(bookingServiceProvider).watchBooking(id),
);

/// Active bookings for a specific vehicle — used to block dates in the picker.
final vehicleBookedRangesProvider = StreamProvider.family<List<Booking>, String>(
  (ref, vehicleId) =>
      ref.watch(bookingServiceProvider).watchBookedRanges(vehicleId),
);

final ownerEarningsProvider = Provider<OwnerEarnings>((ref) {
  final bookings = ref.watch(ownerBookingsProvider).value ?? const [];
  final completed =
      bookings.where((b) => b.status == BookingStatus.completed).toList();
  return (
    totalEarned: completed.fold(0.0, (sum, b) => sum + b.totalPrice),
    completedTrips: completed.length,
  );
});
