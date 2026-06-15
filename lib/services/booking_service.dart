import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/app_user.dart';
import '../core/models/booking.dart';
import '../core/models/vehicle.dart';
import '../core/pricing.dart';
import 'notification_service.dart';

class BookingService {
  BookingService(this._notifications);

  final NotificationService _notifications;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');

  Future<void> _notify(String userId, String title, String body, String bookingId) =>
      _notifications.send(userId: userId, title: title, body: body, refId: bookingId);

  /// Creates a pending booking request with a snapshot of the vehicle pricing
  /// and notifies the owner.
  Future<String> requestBooking({
    required Vehicle vehicle,
    required AppUser renter,
    AppUser? owner,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime termsAcceptedAt,
  }) async {
    // Soft overlap check: fetch all bookings for this vehicle and reject if
    // the requested dates conflict with any active one. A small race window
    // exists for simultaneous requests; owners can still reject duplicates.
    final activeStatuses = {
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.paid,
      BookingStatus.ongoing,
    };
    final existing =
        await _bookings.where('vehicleId', isEqualTo: vehicle.id).get();
    for (final doc in existing.docs) {
      final b = Booking.fromDoc(doc);
      if (!activeStatuses.contains(b.status)) continue;
      if (startDate.isBefore(b.endDate) && endDate.isAfter(b.startDate)) {
        throw 'These dates overlap with an existing booking. Please choose different dates.';
      }
    }

    final days = Pricing.rentalDays(startDate, endDate);
    final booking = Booking(
      id: '',
      vehicleId: vehicle.id,
      vehicleTitle: vehicle.title,
      ownerId: vehicle.ownerId,
      renterId: renter.uid,
      ownerName: owner?.fullName ?? '',
      ownerPhone: owner?.phone ?? '',
      ownerIdCard: owner?.idCardNumber ?? '',
      renterName: renter.fullName,
      renterPhone: renter.phone,
      renterIdCard: renter.idCardNumber,
      startDate: startDate,
      endDate: endDate,
      days: days,
      pricePerDay: vehicle.pricePerDay,
      includedKmPerDay: vehicle.includedKmPerDay,
      extraKmPrice: vehicle.extraKmPrice,
      basePrice: Pricing.basePrice(days: days, pricePerDay: vehicle.pricePerDay),
      termsAcceptedAt: termsAcceptedAt,
    );
    final doc = await _bookings.add(booking.toMap());
    await _notify(vehicle.ownerId, 'New booking request',
        '${vehicle.title} · $days day${days > 1 ? 's' : ''}. Open to accept or reject.', doc.id);
    return doc.id;
  }

  /// Active (non-terminal) bookings for a vehicle — used to block unavailable
  /// dates in the date picker.
  Stream<List<Booking>> watchBookedRanges(String vehicleId) => _bookings
      .where('vehicleId', isEqualTo: vehicleId)
      .where('status', whereIn: [
        BookingStatus.pending.name,
        BookingStatus.accepted.name,
        BookingStatus.paid.name,
        BookingStatus.ongoing.name,
      ])
      .snapshots()
      .map((snap) => snap.docs.map(Booking.fromDoc).toList());

  Stream<List<Booking>> watchAsRenter(String renterId) => _bookings
      .where('renterId', isEqualTo: renterId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Booking.fromDoc).toList());

  Stream<List<Booking>> watchAsOwner(String ownerId) => _bookings
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Booking.fromDoc).toList());

  Stream<Booking?> watchBooking(String id) =>
      _bookings.doc(id).snapshots().map((doc) => doc.exists ? Booking.fromDoc(doc) : null);

  Future<void> updateStatus(Booking booking, BookingStatus status) async {
    await _bookings.doc(booking.id).update({'status': status.name});
    switch (status) {
      case BookingStatus.accepted:
        await _notify(booking.renterId, 'Booking accepted',
            'Pay now to confirm ${booking.vehicleTitle}.', booking.id);
      case BookingStatus.rejected:
        await _notify(booking.renterId, 'Booking rejected',
            'The owner declined your request for ${booking.vehicleTitle}.', booking.id);
      case BookingStatus.cancelled:
        await _notify(booking.ownerId, 'Booking cancelled',
            'The request for ${booking.vehicleTitle} was cancelled.', booking.id);
      default:
        break;
    }
  }

  /// Owner hands the keys over and records the starting odometer.
  Future<void> checkIn(Booking booking, int startOdometer) async {
    await _bookings.doc(booking.id).update({
      'startOdometer': startOdometer,
      'status': BookingStatus.ongoing.name,
    });
    await _notify(booking.renterId, 'Trip started',
        '${booking.vehicleTitle} is yours — enjoy the ride!', booking.id);
  }

  /// Vehicle returned: record the end odometer and compute the extra-km
  /// charge. If nothing extra is due the booking completes immediately,
  /// otherwise it waits in `returned` until the renter pays the difference.
  Future<void> checkOut(Booking booking, int endOdometer) async {
    final extra = Pricing.extraKmCharge(
      kmDriven: endOdometer - (booking.startOdometer ?? endOdometer),
      days: booking.days,
      includedKmPerDay: booking.includedKmPerDay,
      extraKmPrice: booking.extraKmPrice,
    );
    await _bookings.doc(booking.id).update({
      'endOdometer': endOdometer,
      'extraKmCharge': extra,
      'status': (extra > 0 ? BookingStatus.returned : BookingStatus.completed).name,
    });
    await _notify(
        booking.renterId,
        extra > 0 ? 'Extra kilometres to pay' : 'Trip completed',
        extra > 0
            ? '${booking.vehicleTitle}: ${formatTnd(extra)} due for extra kilometres.'
            : '${booking.vehicleTitle} returned within the allowance. Thanks!',
        booking.id);
  }

  Future<void> markPaid(Booking booking, String paymentRef) async {
    await _bookings.doc(booking.id).update({
      'paymentRef': paymentRef,
      'status': BookingStatus.paid.name,
    });
    await _notify(booking.ownerId, 'Payment received',
        '${booking.vehicleTitle}: ${formatTnd(booking.basePrice)} paid by the renter.',
        booking.id);
  }

  Future<void> markExtraPaid(Booking booking, String paymentRef) async {
    await _bookings.doc(booking.id).update({
      'extraPaymentRef': paymentRef,
      'status': BookingStatus.completed.name,
    });
    await _notify(booking.ownerId, 'Extra payment received',
        '${booking.vehicleTitle}: ${formatTnd(booking.extraKmCharge)} paid. Booking completed.',
        booking.id);
  }
}
