import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/favorite_providers.dart';
import '../../providers/vehicle_providers.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../widgets/vehicle_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved vehicles')),
      body: favoritesAsync.when(
        loading: () => const SkeletonList(height: 240),
        error: (e, _) => const EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Could not load favorites'),
        data: (ids) {
          if (ids.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_rounded,
              title: 'Nothing saved yet',
              subtitle:
                  'Tap the heart on any vehicle to keep it here and get notified when it changes.',
            );
          }
          final list = ids.toList();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _FavoriteItem(vehicleId: list[i]),
          );
        },
      ),
    );
  }
}

class _FavoriteItem extends ConsumerWidget {
  const _FavoriteItem({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId)).value;
    if (vehicle == null) return const SizedBox.shrink();
    return VehicleCard(vehicle: vehicle);
  }
}
