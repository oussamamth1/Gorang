import 'package:intl/intl.dart';

import 'models/booking.dart';
import 'pricing.dart';

/// Builds the legal rental-agreement content for a booking.
///
/// The contract is a binding agreement between the **owner** (the party who
/// hands over the vehicle) and the **renter** (the party who takes it for the
/// agreed period). Identity details are snapshotted onto the [Booking] at
/// request time, so the contract always reflects who actually signed — even if
/// either party later edits their profile.
class RentalContract {
  RentalContract(this.booking);

  final Booking booking;

  static final _dateLong = DateFormat('EEEE d MMMM yyyy');
  static final _dateShort = DateFormat('d MMM yyyy');
  static final _stamp = DateFormat('d MMM yyyy · HH:mm');

  String get _renterName =>
      booking.renterName.isNotEmpty ? booking.renterName : 'The renter';
  String get _ownerName =>
      booking.ownerName.isNotEmpty ? booking.ownerName : 'The owner';

  /// One numbered clause: a short heading and the binding text.
  List<({String title, String body})> get clauses => [
        (
          title: 'Object of the contract',
          body:
              'The owner agrees to rent out the vehicle "${booking.vehicleTitle}" '
                  'to the renter for the period and price set out below. The renter '
                  'takes the vehicle in good working condition and undertakes to '
                  'return it in the same condition.',
        ),
        (
          title: 'Rental period',
          body:
              'The rental runs from ${_dateLong.format(booking.startDate)} to '
                  '${_dateLong.format(booking.endDate)} '
                  '(${booking.days} day${booking.days > 1 ? 's' : ''}). The vehicle '
                  'must be returned no later than the end date. Each started day of '
                  'delay is billed at the daily rate of '
                  '${formatTnd(booking.pricePerDay)} and may incur additional damages.',
        ),
        (
          title: 'Price & distance',
          body:
              'The base price is ${formatTnd(booking.basePrice)} for the period, '
                  'including ${booking.includedKmTotal} km '
                  '(${booking.includedKmPerDay} km/day). Distance driven beyond the '
                  'allowance is billed at ${formatTnd(booking.extraKmPrice)} per km, '
                  'measured by the odometer recorded at pickup and at return, and is '
                  'payable before the vehicle is considered returned.',
        ),
        (
          title: 'Use of the vehicle',
          body:
              'The renter confirms they hold a valid driving licence and will drive '
                  'the vehicle personally. The vehicle may not be sub-let, used for '
                  'paid transport of people or goods, used in races or competitions, '
                  'driven outside Tunisia without the owner\'s written consent, or '
                  'driven under the influence of alcohol or drugs.',
        ),
        (
          title: 'Condition, fuel & cleanliness',
          body:
              'The vehicle is handed over with a given fuel level and in a clean '
                  'condition; it must be returned the same way. The owner may charge '
                  'the renter for refuelling and cleaning if it is not.',
        ),
        (
          title: 'Liability for damage, fines & theft',
          body:
              'From pickup until return the renter is fully responsible for the '
                  'vehicle. The renter bears the cost of any damage, mechanical abuse, '
                  'loss or theft occurring during the rental, as well as every traffic '
                  'fine, toll or penalty incurred during the period, even if received '
                  'by the owner afterwards.',
        ),
        (
          title: 'Accidents',
          body:
              'In case of accident the renter must immediately inform the owner, '
                  'notify the police where required, and never abandon the vehicle. '
                  'The renter remains liable for damage caused by their fault or '
                  'negligence.',
        ),
        (
          title: 'Owner\'s rights',
          body:
              'The vehicle remains the exclusive property of the owner. The owner may '
                  'refuse the hand-over or recover the vehicle if the renter provides '
                  'false information, fails to pay, or breaches this contract. RentGo '
                  'acts only as an intermediary platform and is not a party to this '
                  'agreement.',
        ),
      ];

  /// Whether the renter has signed (accepted) this contract.
  bool get isSigned => booking.termsAcceptedAt != null;

  String get signatureLine => isSigned
      ? 'Signed electronically by $_renterName on '
          '${_stamp.format(booking.termsAcceptedAt!)}.'
      : 'Not yet signed.';

  /// Plain-text rendering for copy-to-clipboard / external sharing.
  String toPlainText() {
    final b = StringBuffer()
      ..writeln('VEHICLE RENTAL AGREEMENT')
      ..writeln('RentGo — ${_dateShort.format(booking.startDate)}')
      ..writeln('')
      ..writeln('OWNER (lessor)')
      ..writeln('  Name:  $_ownerName')
      ..writeln('  Phone: ${booking.ownerPhone.isNotEmpty ? '+216 ${booking.ownerPhone}' : '—'}')
      ..writeln('  ID:    ${booking.ownerIdCard.isNotEmpty ? booking.ownerIdCard : '—'}')
      ..writeln('')
      ..writeln('RENTER (lessee)')
      ..writeln('  Name:  $_renterName')
      ..writeln('  Phone: ${booking.renterPhone.isNotEmpty ? '+216 ${booking.renterPhone}' : '—'}')
      ..writeln('  ID:    ${booking.renterIdCard.isNotEmpty ? booking.renterIdCard : '—'}')
      ..writeln('')
      ..writeln('VEHICLE: ${booking.vehicleTitle}')
      ..writeln('PERIOD:  ${_dateShort.format(booking.startDate)} → '
          '${_dateShort.format(booking.endDate)} (${booking.days} day'
          '${booking.days > 1 ? 's' : ''})')
      ..writeln('PRICE:   ${formatTnd(booking.basePrice)} '
          '(${booking.includedKmTotal} km included)')
      ..writeln('');
    for (var i = 0; i < clauses.length; i++) {
      b
        ..writeln('${i + 1}. ${clauses[i].title}')
        ..writeln('   ${clauses[i].body}')
        ..writeln('');
    }
    b.writeln(signatureLine);
    return b.toString();
  }
}
