import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/booking_providers.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/skeleton_list.dart';

/// Bookings made by the signed-in user as a renter.
class MyRentalsScreen extends ConsumerWidget {
  const MyRentalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myRentalsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My trips', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text('Everything you have booked',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: bookings.when(
                loading: () => const SkeletonList(height: 90),
                error: (e, _) => const EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load your trips'),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.luggage_rounded,
                        title: 'No trips yet',
                        subtitle:
                            'Find a car or bike in Explore and book your first ride.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => BookingCard(booking: list[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
