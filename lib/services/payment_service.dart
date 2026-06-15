import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// While true, payments are simulated locally so the whole flow can be tested
/// before the Konnect Cloud Functions are deployed.
/// Run with `--dart-define=MOCK_PAYMENTS=false` to use real payments.
const bool kUseMockPayments = bool.fromEnvironment('MOCK_PAYMENTS', defaultValue: true);

class PaymentResult {
  final String paymentRef;
  final bool completedImmediately;
  const PaymentResult({required this.paymentRef, required this.completedImmediately});
}

/// Talks to the `initKonnectPayment` Cloud Function (see functions/index.js),
/// which holds the Konnect API key server-side. The function returns a payUrl
/// that we open in the browser; the Konnect webhook then updates the booking.
class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Starts a payment for [amountTnd] linked to [bookingId].
  ///
  /// In mock mode this returns immediately with a fake reference. In real
  /// mode it opens the Konnect payment page and the booking is updated by
  /// the webhook once the payment succeeds.
  Future<PaymentResult> pay({
    required String bookingId,
    required double amountTnd,
    required bool isExtraCharge,
  }) async {
    if (kUseMockPayments) {
      return PaymentResult(
        paymentRef: 'MOCK-${DateTime.now().millisecondsSinceEpoch}',
        completedImmediately: true,
      );
    }

    final result = await _functions.httpsCallable('initKonnectPayment').call({
      'bookingId': bookingId,
      'amountMillimes': (amountTnd * 1000).round(),
      'isExtraCharge': isExtraCharge,
    });
    final data = Map<String, dynamic>.from(result.data);
    final payUrl = Uri.parse(data['payUrl'] as String);
    await launchUrl(payUrl, mode: LaunchMode.externalApplication);
    return PaymentResult(
      paymentRef: data['paymentRef'] as String,
      completedImmediately: false,
    );
  }
}
