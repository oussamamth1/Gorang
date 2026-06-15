import 'package:cloud_firestore/cloud_firestore.dart';

enum VehicleType { car, motorcycle, scooter, van }

extension VehicleTypeX on VehicleType {
  String get label => switch (this) {
        VehicleType.car => 'Car',
        VehicleType.motorcycle => 'Motorcycle',
        VehicleType.scooter => 'Scooter',
        VehicleType.van => 'Van',
      };
}

enum TunisiaCity {
  tunis,
  ariana,
  benArous,
  manouba,
  nabeul,
  zaghouan,
  bizerte,
  beja,
  jendouba,
  kef,
  siliana,
  sousse,
  monastir,
  mahdia,
  sfax,
  kairouan,
  kasserine,
  sidiBouzid,
  gabes,
  medenine,
  tataouine,
  gafsa,
  tozeur,
  kebili,
}

extension TunisiaCityX on TunisiaCity {
  String get label => switch (this) {
        TunisiaCity.tunis => 'Tunis',
        TunisiaCity.ariana => 'Ariana',
        TunisiaCity.benArous => 'Ben Arous',
        TunisiaCity.manouba => 'Manouba',
        TunisiaCity.nabeul => 'Nabeul',
        TunisiaCity.zaghouan => 'Zaghouan',
        TunisiaCity.bizerte => 'Bizerte',
        TunisiaCity.beja => 'Béja',
        TunisiaCity.jendouba => 'Jendouba',
        TunisiaCity.kef => 'Le Kef',
        TunisiaCity.siliana => 'Siliana',
        TunisiaCity.sousse => 'Sousse',
        TunisiaCity.monastir => 'Monastir',
        TunisiaCity.mahdia => 'Mahdia',
        TunisiaCity.sfax => 'Sfax',
        TunisiaCity.kairouan => 'Kairouan',
        TunisiaCity.kasserine => 'Kasserine',
        TunisiaCity.sidiBouzid => 'Sidi Bouzid',
        TunisiaCity.gabes => 'Gabès',
        TunisiaCity.medenine => 'Médenine',
        TunisiaCity.tataouine => 'Tataouine',
        TunisiaCity.gafsa => 'Gafsa',
        TunisiaCity.tozeur => 'Tozeur',
        TunisiaCity.kebili => 'Kébili',
      };
}

/// A vehicle listed by an owner on the marketplace.
///
/// Pricing model: flat daily price that includes [includedKmPerDay] km per
/// rental day. Kilometers beyond the included allowance are billed at
/// [extraKmPrice] when the vehicle is returned.
class Vehicle {
  final String id;
  final String ownerId;
  final VehicleType type;
  final String brand;
  final String model;
  final int year;
  final TunisiaCity city;
  final String street;
  final String? description;
  final List<String> photoUrls;
  final double pricePerDay; // TND
  final int includedKmPerDay; // km included in the daily price
  final double extraKmPrice; // TND per km over the allowance
  final bool isActive;
  final DateTime? createdAt;

  const Vehicle({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.city,
    required this.street,
    this.description,
    required this.photoUrls,
    required this.pricePerDay,
    required this.includedKmPerDay,
    required this.extraKmPrice,
    this.isActive = true,
    this.createdAt,
  });

  String get title => '$brand $model ($year)';

  factory Vehicle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Vehicle(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      type: VehicleType.values.asNameMap()[data['type']] ?? VehicleType.car,
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      city: TunisiaCity.values.asNameMap()[data['city']] ?? TunisiaCity.tunis,
      street: data['street'] ?? '',
      description: data['description'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      includedKmPerDay: data['includedKmPerDay'] ?? 0,
      extraKmPrice: (data['extraKmPrice'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'description': description,
        'type': type.name,
        'brand': brand,
        'model': model,
        'year': year,
        'city': city.name,
        'street': street,
        'photoUrls': photoUrls,
        'pricePerDay': pricePerDay,
        'includedKmPerDay': includedKmPerDay,
        'extraKmPrice': extraKmPrice,
        'isActive': isActive,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };
}
