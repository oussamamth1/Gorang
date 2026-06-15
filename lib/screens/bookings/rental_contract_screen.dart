import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/booking.dart';
import '../../core/pricing.dart';
import '../../core/rental_contract.dart';
import '../../providers/booking_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state.dart';

/// Read-only view of the binding rental agreement for a booking.
/// Both the owner and the renter can open it at any time from the booking.
class RentalContractScreen extends ConsumerWidget {
  const RentalContractScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental contract'),
        actions: [
          bookingAsync.maybeWhen(
            data: (b) => b == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Copy contract',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: RentalContract(b).toPlainText()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Contract copied to clipboard')));
                      }
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Could not load the contract'),
        data: (booking) {
          if (booking == null) {
            return const EmptyState(
                icon: Icons.description_outlined, title: 'Contract not found');
          }
          return _ContractBody(booking: booking);
        },
      ),
    );
  }
}

class _ContractBody extends StatelessWidget {
  const _ContractBody({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contract = RentalContract(booking);
    final clauses = contract.clauses;
    final dates = DateFormat('EEE d MMM yyyy');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Heading
        Center(
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text('Vehicle Rental Agreement',
                  textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text('Binding agreement between owner and renter',
                  textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Parties
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _partyCard(theme,
                  role: 'Owner (lessor)',
                  name: booking.ownerName,
                  phone: booking.ownerPhone,
                  idCard: booking.ownerIdCard),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _partyCard(theme,
                  role: 'Renter (lessee)',
                  name: booking.renterName,
                  phone: booking.renterPhone,
                  idCard: booking.renterIdCard),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Vehicle & terms
        _card(theme, [
          _kv(theme, 'Vehicle', booking.vehicleTitle),
          _kv(theme, 'Period',
              '${dates.format(booking.startDate)}  →  ${dates.format(booking.endDate)}'),
          _kv(theme, 'Duration',
              '${booking.days} day${booking.days > 1 ? 's' : ''}'),
          _kv(theme, 'Included distance', '${booking.includedKmTotal} km'),
          _kv(theme, 'Extra km', '${formatTnd(booking.extraKmPrice)} / km'),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Base price', style: theme.textTheme.titleMedium),
              Text(formatTnd(booking.basePrice),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: AppColors.primary)),
            ],
          ),
        ]),
        const SizedBox(height: 22),

        Text('Terms & conditions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var i = 0; i < clauses.length; i++) ...[
          _clause(theme, i + 1, clauses[i].title, clauses[i].body),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        // Signature block
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: contract.isSigned
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (contract.isSigned ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                contract.isSigned
                    ? Icons.verified_rounded
                    : Icons.pending_rounded,
                color: contract.isSigned ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(contract.signatureLine,
                    style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RentGo is a marketplace that connects owners and renters. This '
          'agreement is concluded directly between the two parties; RentGo is '
          'not a party to it and is not liable for its execution.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _partyCard(ThemeData theme,
      {required String role,
      required String name,
      required String phone,
      required String idCard}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.primary, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(name.isNotEmpty ? name : '—', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(phone.isNotEmpty ? '+216 $phone' : 'Phone —',
              style: theme.textTheme.bodySmall),
          Text(idCard.isNotEmpty ? 'ID $idCard' : 'ID —',
              style: theme.textTheme.bodySmall),
        ],
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

  Widget _kv(ThemeData theme, String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child:
                    Text(key, style: theme.textTheme.bodyMedium)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right, style: theme.textTheme.titleSmall),
            ),
          ],
        ),
      );

  Widget _clause(ThemeData theme, int n, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$n',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
