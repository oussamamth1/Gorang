import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/vehicle.dart';
import '../../providers/notification_providers.dart';
import '../../providers/vehicle_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../widgets/vehicle_card.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(exploreTypeFilterProvider);
    final selectedCity = ref.watch(exploreZoneFilterProvider);
    final vehicles = ref.watch(exploreVehiclesProvider);
    final cities = ref.watch(availableCitiesProvider).value ?? const <TunisiaCity>[];
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find your ride',
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text('Cars & bikes from owners near you',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  _HeaderIcon(
                    icon: Icons.favorite_border_rounded,
                    onTap: () => context.push(Routes.favorites),
                  ),
                  const SizedBox(width: 10),
                  _HeaderIcon(
                    icon: Icons.notifications_none_rounded,
                    badge: ref.watch(unreadNotificationsProvider),
                    onTap: () => context.push(Routes.notifications),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  const Expanded(child: _SearchBar()),
                  const SizedBox(width: 8),
                  const _FilterButton(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _TypeChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    selected: selectedType == null,
                    onTap: () =>
                        ref.read(exploreTypeFilterProvider.notifier).set(null),
                  ),
                  for (final type in VehicleType.values)
                    _TypeChip(
                      label: type.label,
                      icon: vehicleTypeIcon(type),
                      selected: selectedType == type,
                      onTap: () =>
                          ref.read(exploreTypeFilterProvider.notifier).set(type),
                    ),
                ],
              ),
            ),
            if (cities.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _ZoneChip(
                      label: 'All zones',
                      selected: selectedCity == null,
                      onTap: () =>
                          ref.read(exploreZoneFilterProvider.notifier).set(null),
                    ),
                    for (final city in cities)
                      _ZoneChip(
                        label: city.label,
                        selected: selectedCity == city,
                        onTap: () =>
                            ref.read(exploreZoneFilterProvider.notifier).set(city),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: vehicles.when(
                loading: () => const SkeletonList(height: 240),
                error: (e, _) => EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load vehicles',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(exploreVehiclesProvider),
                ),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.directions_car_rounded,
                        title: 'No vehicles yet',
                        subtitle:
                            'Be the first to put your car or bike to work.',
                        actionLabel: 'List a vehicle',
                        onAction: () => context.push(Routes.addVehicle),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => VehicleCard(vehicle: list[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = ref.watch(exploreSearchFilterProvider).isNotEmpty;
    return TextField(
      controller: _controller,
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          ref.read(exploreSearchFilterProvider.notifier).set(v.trim());
        });
      },
      decoration: InputDecoration(
        hintText: 'Search brand or model…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: hasQuery
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  ref.read(exploreSearchFilterProvider.notifier).set('');
                },
              )
            : null,
      ),
    );
  }
}

class _FilterButton extends ConsumerWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(explorePriceFilterProvider) != null ||
        ref.watch(exploreSortProvider) != ExploreSortOrder.newest;
    return PressScale(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _PriceFilterSheet(),
      ),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1.4,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: isActive ? Colors.white : AppColors.text,
          size: 22,
        ),
      ),
    );
  }
}

class _PriceFilterSheet extends ConsumerStatefulWidget {
  const _PriceFilterSheet();

  @override
  ConsumerState<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends ConsumerState<_PriceFilterSheet> {
  late double _max;
  late ExploreSortOrder _sort;

  @override
  void initState() {
    super.initState();
    _max = ref.read(explorePriceFilterProvider) ?? 1000;
    _sort = ref.read(exploreSortProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Filter & Sort', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text('Sort by', style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SegmentedButton<ExploreSortOrder>(
              segments: const [
                ButtonSegment(
                  value: ExploreSortOrder.newest,
                  label: Text('Newest'),
                  icon: Icon(Icons.schedule_rounded, size: 16),
                ),
                ButtonSegment(
                  value: ExploreSortOrder.priceAsc,
                  label: Text('Price ↑'),
                  icon: Icon(Icons.trending_up_rounded, size: 16),
                ),
                ButtonSegment(
                  value: ExploreSortOrder.priceDesc,
                  label: Text('Price ↓'),
                  icon: Icon(Icons.trending_down_rounded, size: 16),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (s) => setState(() => _sort = s.first),
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            const SizedBox(height: 20),
            Text('Max price / day',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('20', style: theme.textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: _max,
                    min: 20,
                    max: 1000,
                    divisions: 98,
                    label: '${_max.round()} TND',
                    onChanged: (v) => setState(() => _max = v),
                  ),
                ),
                Text('1000', style: theme.textTheme.bodySmall),
              ],
            ),
            Center(
              child: Text(
                _max >= 1000 ? 'No limit' : 'Up to ${_max.round()} TND/day',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(explorePriceFilterProvider.notifier).set(null);
                      ref
                          .read(exploreSortProvider.notifier)
                          .set(ExploreSortOrder.newest);
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(explorePriceFilterProvider.notifier)
                          .set(_max >= 1000 ? null : _max);
                      ref.read(exploreSortProvider.notifier).set(_sort);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.4),
            ),
            child: Icon(icon, size: 22, color: AppColors.text),
          ),
          if (badge > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(100),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 14,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.text,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: selected ? null : Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.text,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
