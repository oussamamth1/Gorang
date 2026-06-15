import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/booking.dart';
import '../../core/pricing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/booking_providers.dart';
import '../../providers/service_providers.dart';
import '../../router/routes.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks for an odometer reading (used at pickup and at return).
  Future<int?> _askOdometer(String title, {int? minValue}) async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Odometer', suffixText: 'km'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v == null || (minValue != null && v < minValue)) return;
              Navigator.pop(context, v);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _pay(Booking booking, {required bool isExtra}) => _run(() async {
        final payments = ref.read(paymentServiceProvider);
        final bookingsService = ref.read(bookingServiceProvider);
        final result = await payments.pay(
          bookingId: booking.id,
          amountTnd: isExtra ? booking.extraKmCharge : booking.basePrice,
          isExtraCharge: isExtra,
        );
        if (result.completedImmediately) {
          // Mock mode: update the booking directly. With real Konnect
          // payments the webhook in functions/index.js does this instead.
          if (isExtra) {
            await bookingsService.markExtraPaid(booking, result.paymentRef);
          } else {
            await bookingsService.markPaid(booking, result.paymentRef);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Complete the payment in your browser — the booking '
                  'updates automatically once it succeeds.')));
        }
      });

  /// One-line guidance shown in the status banner, per role and status.
  String _statusHint(Booking booking, {required bool isOwner}) {
    return switch (booking.status) {
      BookingStatus.pending => isOwner
          ? 'Review the request and accept or reject it.'
          : 'Waiting for the owner to approve your request.',
      BookingStatus.accepted => isOwner
          ? 'Waiting for the renter to pay the base price.'
          : 'Approved! Pay now to confirm your trip.',
      BookingStatus.paid => isOwner
          ? 'Record the odometer when you hand over the keys.'
          : 'Paid. Pick up the vehicle on the start date.',
      BookingStatus.ongoing => isOwner
          ? 'Record the odometer when the vehicle comes back.'
          : 'Enjoy the ride! Return by the agreed date.',
      BookingStatus.returned => isOwner
          ? 'Waiting for the renter to pay the extra-km charge.'
          : 'Pay the extra-km charge to close this booking.',
      BookingStatus.completed => 'All done. Thanks for using RentGo!',
      BookingStatus.rejected => 'The owner declined this request.',
      BookingStatus.cancelled => 'This booking was cancelled.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingByIdProvider(widget.bookingId));
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Could not load this booking'),
        data: (booking) {
          if (booking == null || user == null) {
            return const EmptyState(
                icon: Icons.search_off_rounded, title: 'Booking not found');
          }
          final theme = Theme.of(context);
          final isOwner = user.uid == booking.ownerId;
          final color = bookingStatusColor(booking.status);
          final dates = DateFormat('EEE d MMM yyyy');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Status banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(bookingStatusIcon(booking.status), color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.status.label,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: color)),
                          const SizedBox(height: 2),
                          Text(_statusHint(booking, isOwner: isOwner),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(booking.vehicleTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(isOwner ? 'You are the owner' : 'You are the renter',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              _card(theme, [
                _row(theme, Icons.flight_takeoff_rounded, 'Pickup',
                    dates.format(booking.startDate)),
                _row(theme, Icons.flight_land_rounded, 'Return',
                    dates.format(booking.endDate)),
                _row(theme, Icons.schedule_rounded, 'Duration',
                    '${booking.days} day${booking.days > 1 ? 's' : ''}'),
                _row(theme, Icons.route_rounded, 'Included distance',
                    '${booking.includedKmTotal} km'),
              ]),
              const SizedBox(height: 14),
              _card(theme, [
                _row(theme, Icons.receipt_long_rounded, 'Base price',
                    formatTnd(booking.basePrice)),
                if (booking.startOdometer != null)
                  _row(theme, Icons.speed_rounded, 'Odometer at pickup',
                      '${booking.startOdometer} km'),
                if (booking.endOdometer != null) ...[
                  _row(theme, Icons.speed_rounded, 'Odometer at return',
                      '${booking.endOdometer} km'),
                  _row(theme, Icons.straighten_rounded, 'Distance driven',
                      '${booking.kmDriven} km'),
                  _row(
                      theme,
                      Icons.add_road_rounded,
                      'Extra km charge',
                      booking.extraKmCharge > 0
                          ? formatTnd(booking.extraKmCharge)
                          : 'None',
                      valueColor: booking.extraKmCharge > 0
                          ? AppColors.warning
                          : AppColors.success),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: theme.textTheme.titleMedium),
                    Text(formatTnd(booking.totalPrice),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: AppColors.primary)),
                  ],
                ),
              ]),
              const SizedBox(height: 14),
              // Rental contract — the binding agreement between owner and renter.
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(Routes.rentalContractPath(booking.id)),
                icon: const Icon(Icons.description_rounded, size: 20),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.4),
                  minimumSize: const Size.fromHeight(48),
                ),
                label: const Text('View rental contract'),
              ),
              const SizedBox(height: 24),
              ..._actionsFor(booking, isOwner: isOwner),
            ],
          );
        },
      ),
    );
  }

  Widget _card(ThemeData theme, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(children: children),
      );

  Widget _row(ThemeData theme, IconData icon, String label, String value,
          {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(value,
                style: theme.textTheme.titleSmall?.copyWith(color: valueColor)),
          ],
        ),
      );

  List<Widget> _actionsFor(Booking booking, {required bool isOwner}) {
    final service = ref.read(bookingServiceProvider);

    Widget primary(String label, VoidCallback onPressed) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton(
              onPressed: _busy ? null : onPressed, child: Text(label)),
        );

    Widget destructive(String label, VoidCallback onPressed) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton(
            onPressed: _busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.4), width: 1.4),
            ),
            child: Text(label),
          ),
        );

    if (isOwner) {
      return switch (booking.status) {
        BookingStatus.pending => [
            primary('Accept request',
                () => _run(() => service.updateStatus(booking, BookingStatus.accepted))),
            destructive('Reject',
                () => _run(() => service.updateStatus(booking, BookingStatus.rejected))),
          ],
        BookingStatus.paid => [
            primary('Hand over keys — record odometer', () async {
              final odo = await _askOdometer('Odometer at pickup');
              if (odo != null) await _run(() => service.checkIn(booking, odo));
            }),
          ],
        BookingStatus.ongoing => [
            primary('Vehicle returned — record odometer', () async {
              final odo = await _askOdometer('Odometer at return',
                  minValue: booking.startOdometer);
              if (odo != null) await _run(() => service.checkOut(booking, odo));
            }),
          ],
        _ => const [],
      };
    }

    // Renter actions.
    return switch (booking.status) {
      BookingStatus.pending => [
          destructive('Cancel request',
              () => _run(() => service.updateStatus(booking, BookingStatus.cancelled))),
        ],
      BookingStatus.accepted => [
          primary(
              'Pay ${formatTnd(booking.basePrice)}${kUseMockPayments ? ' (mock)' : ' with Konnect'}',
              () => _pay(booking, isExtra: false)),
          destructive('Cancel',
              () => _run(() => service.updateStatus(booking, BookingStatus.cancelled))),
        ],
      BookingStatus.returned => [
          primary(
              'Pay extra ${formatTnd(booking.extraKmCharge)}${kUseMockPayments ? ' (mock)' : ' with Konnect'}',
              () => _pay(booking, isExtra: true)),
        ],
      _ => const [],
    };
  }
}
