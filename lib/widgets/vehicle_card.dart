import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/vehicle.dart';
import '../core/pricing.dart';
import '../providers/auth_providers.dart';
import '../providers/favorite_providers.dart';
import '../providers/service_providers.dart';
import '../router/routes.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';
import 'common/press_scale.dart';

IconData vehicleTypeIcon(VehicleType type) => switch (type) {
      VehicleType.car => Icons.directions_car_rounded,
      VehicleType.motorcycle => Icons.two_wheeler_rounded,
      VehicleType.scooter => Icons.moped_rounded,
      VehicleType.van => Icons.airport_shuttle_rounded,
    };

class VehicleCard extends ConsumerWidget {
  const VehicleCard({super.key, required this.vehicle, this.onTap});

  final Vehicle vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).value?.uid;
    final isOwn = uid == vehicle.ownerId;
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(vehicle.id) ?? false;
    return PressScale(
      onTap: onTap ?? () => context.push(Routes.vehicleDetailPath(vehicle.id)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: vehicle.photoUrls.isNotEmpty
                        ? AppImage(vehicle.photoUrls.first)
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF1EBFD), Color(0xFFE2D8F8)],
                              ),
                            ),
                            child: Icon(vehicleTypeIcon(vehicle.type),
                                size: 56,
                                color: AppColors.primary.withValues(alpha: 0.45)),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Pill(
                      background: Colors.white.withValues(alpha: 0.92),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(vehicleTypeIcon(vehicle.type),
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(vehicle.type.label,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _Pill(
                      gradient: AppColors.primaryGradient,
                      child: Text(
                        '${formatTnd(vehicle.pricePerDay)}/day',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (uid != null && !isOwn)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: PressScale(
                        onTap: () => ref
                            .read(favoriteServiceProvider)
                            .setFavorite(uid, vehicle.id, !isFavorite),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isFavorite
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${vehicle.brand} ${vehicle.model}',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${vehicle.city.label} · ${vehicle.year}',
                          style: theme.textTheme.bodySmall),
                      const Spacer(),
                      const Icon(Icons.route_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${vehicle.includedKmPerDay} km/day',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.background, this.gradient});

  final Widget child;
  final Color? background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        gradient: gradient,
        borderRadius: BorderRadius.circular(100),
      ),
      child: child,
    );
  }
}
