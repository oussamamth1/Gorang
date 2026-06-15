import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a booking:
///
/// pending -> accepted -> paid -> ongoing -> returned -> completed
///    \-> rejected / cancelled
///
/// - `accepted`: owner approved, waiting for the renter to pay the base price.
/// - `ongoing`: owner checked the vehicle out (start odometer recorded).
/// - `returned`: end odometer recorded; if there is an extra-km charge the
///   renter pays it before the booking becomes `completed`.
enum BookingStatus { pending, accepted, paid, ongoing, returned, completed, rejected, cancelled }

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
        BookingStatus.pending => 'Pending approval',
        BookingStatus.accepted => 'Awaiting payment',
        BookingStatus.paid => 'Paid — awaiting pickup',
        BookingStatus.ongoing => 'Ongoing',
        BookingStatus.returned => 'Returned',
        BookingStatus.completed => 'Completed',
        BookingStatus.rejected => 'Rejected',
        BookingStatus.cancelled => 'Cancelled',
      };

  bool get isFinal =>
      this == BookingStatus.completed ||
      this == BookingStatus.rejected ||
      this == BookingStatus.cancelled;
}

class Booking {
  final String id;
  final String vehicleId;
  final String vehicleTitle;
  final String ownerId;
  final String renterId;
  // Identity snapshot taken when the booking is created, so the rental contract
  // is immutable proof of who agreed — even if either party later edits their
  // profile. Empty strings when the data was not available at request time.
  final String ownerName;
  final String ownerPhone;
  final String ownerIdCard;
  final String renterName;
  final String renterPhone;
  final String renterIdCard;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  // Pricing snapshot taken when the booking is created, so later changes to
  // the vehicle listing never affect an existing booking.
  final double pricePerDay;
  final int includedKmPerDay;
  final double extraKmPrice;
  final double basePrice;
  // Odometer readings recorded at pickup / return.
  final int? startOdometer;
  final int? endOdometer;
  final double extraKmCharge;
  final BookingStatus status;
  final String? paymentRef;
  final String? extraPaymentRef;
  final DateTime? createdAt;
  final DateTime? termsAcceptedAt;

  const Booking({
    required this.id,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.ownerId,
    required this.renterId,
    this.ownerName = '',
    this.ownerPhone = '',
    this.ownerIdCard = '',
    this.renterName = '',
    this.renterPhone = '',
    this.renterIdCard = '',
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.pricePerDay,
    required this.includedKmPerDay,
    required this.extraKmPrice,
    required this.basePrice,
    this.startOdometer,
    this.endOdometer,
    this.extraKmCharge = 0,
    this.status = BookingStatus.pending,
    this.paymentRef,
    this.extraPaymentRef,
    this.createdAt,
    this.termsAcceptedAt,
  });

  int get includedKmTotal => days * includedKmPerDay;

  int? get kmDriven => (startOdometer != null && endOdometer != null)
      ? (endOdometer! - startOdometer!)
      : null;

  double get totalPrice => basePrice + extraKmCharge;

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Booking(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      vehicleTitle: data['vehicleTitle'] ?? '',
      ownerId: data['ownerId'] ?? '',
      renterId: data['renterId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      ownerPhone: data['ownerPhone'] ?? '',
      ownerIdCard: data['ownerIdCard'] ?? '',
      renterName: data['renterName'] ?? '',
      renterPhone: data['renterPhone'] ?? '',
      renterIdCard: data['renterIdCard'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      days: data['days'] ?? 1,
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      includedKmPerDay: data['includedKmPerDay'] ?? 0,
      extraKmPrice: (data['extraKmPrice'] ?? 0).toDouble(),
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      startOdometer: data['startOdometer'],
      endOdometer: data['endOdometer'],
      extraKmCharge: (data['extraKmCharge'] ?? 0).toDouble(),
      status: BookingStatus.values.asNameMap()[data['status']] ?? BookingStatus.pending,
      paymentRef: data['paymentRef'],
      extraPaymentRef: data['extraPaymentRef'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      termsAcceptedAt: (data['termsAcceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'vehicleTitle': vehicleTitle,
        'ownerId': ownerId,
        'renterId': renterId,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'ownerIdCard': ownerIdCard,
        'renterName': renterName,
        'renterPhone': renterPhone,
        'renterIdCard': renterIdCard,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'days': days,
        'pricePerDay': pricePerDay,
        'includedKmPerDay': includedKmPerDay,
        'extraKmPrice': extraKmPrice,
        'basePrice': basePrice,
        'startOdometer': startOdometer,
        'endOdometer': endOdometer,
        'extraKmCharge': extraKmCharge,
        'status': status.name,
        'paymentRef': paymentRef,
        'extraPaymentRef': extraPaymentRef,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        if (termsAcceptedAt != null) 'termsAcceptedAt': Timestamp.fromDate(termsAcceptedAt!),
      };
}
