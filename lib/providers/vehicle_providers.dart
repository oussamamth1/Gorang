import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/vehicle.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

/// Selected vehicle type filter on the explore screen (null = all).
class ExploreTypeFilter extends Notifier<VehicleType?> {
  @override
  VehicleType? build() => null;

  void set(VehicleType? type) => state = type;
}

final exploreTypeFilterProvider =
    NotifierProvider<ExploreTypeFilter, VehicleType?>(ExploreTypeFilter.new);

/// Selected city/zone filter on the explore screen (null = all zones).
class ExploreZoneFilter extends Notifier<TunisiaCity?> {
  @override
  TunisiaCity? build() => null;

  void set(TunisiaCity? city) => state = city;
}

final exploreZoneFilterProvider =
    NotifierProvider<ExploreZoneFilter, TunisiaCity?>(ExploreZoneFilter.new);

/// Free-text search filter (empty string = no filter).
class ExploreSearchFilter extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final exploreSearchFilterProvider =
    NotifierProvider<ExploreSearchFilter, String>(ExploreSearchFilter.new);

/// Max price per day filter in TND (null = no limit).
class ExplorePriceFilter extends Notifier<double?> {
  @override
  double? build() => null;

  void set(double? max) => state = max;
}

final explorePriceFilterProvider =
    NotifierProvider<ExplorePriceFilter, double?>(ExplorePriceFilter.new);

enum ExploreSortOrder { newest, priceAsc, priceDesc }

class ExploreSortNotifier extends Notifier<ExploreSortOrder> {
  @override
  ExploreSortOrder build() => ExploreSortOrder.newest;

  void set(ExploreSortOrder order) => state = order;
}

final exploreSortProvider =
    NotifierProvider<ExploreSortNotifier, ExploreSortOrder>(
        ExploreSortNotifier.new);

final exploreVehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final type = ref.watch(exploreTypeFilterProvider);
  final city = ref.watch(exploreZoneFilterProvider);
  final search = ref.watch(exploreSearchFilterProvider);
  final maxPrice = ref.watch(explorePriceFilterProvider);
  final sort = ref.watch(exploreSortProvider);
  return ref
      .watch(vehicleServiceProvider)
      .watchActiveVehicles(type: type)
      .map((list) {
    var result = city == null ? list : list.where((v) => v.city == city).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((v) =>
              v.brand.toLowerCase().contains(q) ||
              v.model.toLowerCase().contains(q))
          .toList();
    }
    if (maxPrice != null) {
      result = result.where((v) => v.pricePerDay <= maxPrice).toList();
    }
    result = List<Vehicle>.from(result);
    switch (sort) {
      case ExploreSortOrder.priceAsc:
        result.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case ExploreSortOrder.priceDesc:
        result.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      case ExploreSortOrder.newest:
        result.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
    return result;
  });
});

/// Cities that currently have active listings, in enum declaration order.
final availableCitiesProvider = StreamProvider<List<TunisiaCity>>((ref) {
  return ref.watch(vehicleServiceProvider).watchActiveVehicles().map((list) {
    final seen = <TunisiaCity>{};
    for (final v in list) {
      seen.add(v.city);
    }
    return TunisiaCity.values.where(seen.contains).toList();
  });
});

final myVehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(vehicleServiceProvider).watchMyVehicles(user.uid);
});

final vehicleByIdProvider = StreamProvider.family<Vehicle?, String>(
  (ref, id) => ref.watch(vehicleServiceProvider).watchVehicle(id),
);
