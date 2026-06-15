import 'package:intl/intl.dart';

/// Pure pricing rules for the "flat daily price + km cap" model.
///
/// total = days * pricePerDay + max(0, kmDriven - days * includedKmPerDay) * extraKmPrice
class Pricing {
  Pricing._();

  /// Number of billable days for a rental period. A same-day rental counts
  /// as one day.
  static int rentalDays(DateTime start, DateTime end) {
    final days = DateTime(end.year, end.month, end.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
    return days <= 0 ? 1 : days;
  }

  static double basePrice({required int days, required double pricePerDay}) =>
      days * pricePerDay;

  static double extraKmCharge({
    required int kmDriven,
    required int days,
    required int includedKmPerDay,
    required double extraKmPrice,
  }) {
    final extraKm = kmDriven - days * includedKmPerDay;
    return extraKm > 0 ? extraKm * extraKmPrice : 0;
  }
}

final NumberFormat _tnd = NumberFormat('#,##0.###');

String formatTnd(double amount) => '${_tnd.format(amount)} TND';
