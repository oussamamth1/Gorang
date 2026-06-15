import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/vehicle.dart';
import '../../core/pricing.dart';
import '../../providers/booking_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/vehicle_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../widgets/vehicle_card.dart';

/// Owner side: my listed vehicles + incoming booking requests.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final earnings = ref.watch(ownerEarningsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.addVehicle),
          icon: const Icon(Icons.add_rounded),
          label: const Text('List a vehicle'),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My garage', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('Manage your listings and booking requests',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (earnings.completedTrips > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total earned',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70)),
                              Text(formatTnd(earnings.totalEarned),
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Completed',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70)),
                            Text(
                              '${earnings.completedTrips} trip${earnings.completedTrips == 1 ? '' : 's'}',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.4),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: theme.textTheme.labelLarge,
                  tabs: const [
                    Tab(height: 40, text: 'Vehicles'),
                    Tab(height: 40, text: 'Requests'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: TabBarView(children: [_MyVehiclesTab(), _OwnerBookingsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyVehiclesTab extends ConsumerWidget {
  const _MyVehiclesTab();

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text(
            '${vehicle.title} will be removed from RentGo. Existing bookings '
            'are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(vehicleServiceProvider).deleteVehicle(vehicle);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(myVehiclesProvider);
    return vehicles.when(
      loading: () => const SkeletonList(height: 240),
      error: (e, _) => const EmptyState(
          icon: Icons.cloud_off_rounded, title: 'Could not load your vehicles'),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.garage_rounded,
              title: 'Your garage is empty',
              subtitle:
                  'List your car or bike and earn money when you are not using it.',
              actionLabel: 'List a vehicle',
              onAction: () => context.push(Routes.addVehicle),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final v = list[i];
                return Column(
                  children: [
                    VehicleCard(vehicle: v),
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            v.isActive
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: v.isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v.isActive ? 'Visible' : 'Hidden',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Switch(
                            value: v.isActive,
                            onChanged: (val) =>
                                ref.read(vehicleServiceProvider).setActive(v.id, val),
                          ),
                          IconButton(
                            tooltip: 'Edit listing',
                            icon: const Icon(Icons.edit_rounded,
                                size: 20, color: AppColors.primary),
                            onPressed: () =>
                                context.push(Routes.editVehicle, extra: v),
                          ),
                          IconButton(
                            tooltip: 'Delete listing',
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20, color: AppColors.danger),
                            onPressed: () => _confirmDelete(context, ref, v),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _OwnerBookingsTab extends ConsumerWidget {
  const _OwnerBookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(ownerBookingsProvider);
    return bookings.when(
      loading: () => const SkeletonList(height: 90),
      error: (e, _) => const EmptyState(
          icon: Icons.cloud_off_rounded, title: 'Could not load requests'),
      data: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No requests yet',
              subtitle:
                  'Booking requests for your vehicles will show up here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: list.length,
              itemBuilder: (_, i) => BookingCard(booking: list[i]),
            ),
    );
  }
}
