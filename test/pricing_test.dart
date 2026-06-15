import 'package:flutter_test/flutter_test.dart';
import 'package:rentgo/core/pricing.dart';

void main() {
  group('Pricing.rentalDays', () {
    test('same day counts as one day', () {
      final d = DateTime(2026, 6, 13);
      expect(Pricing.rentalDays(d, d), 1);
    });

    test('counts whole days between pickup and return', () {
      expect(Pricing.rentalDays(DateTime(2026, 6, 13), DateTime(2026, 6, 16)), 3);
    });

    test('ignores time of day', () {
      expect(
        Pricing.rentalDays(DateTime(2026, 6, 13, 23), DateTime(2026, 6, 14, 1)),
        1,
      );
    });
  });

  group('Pricing.basePrice', () {
    test('days times daily price', () {
      expect(Pricing.basePrice(days: 3, pricePerDay: 90), 270);
    });
  });

  group('Pricing.extraKmCharge', () {
    test('no charge when within the allowance', () {
      expect(
        Pricing.extraKmCharge(
            kmDriven: 250, days: 3, includedKmPerDay: 100, extraKmPrice: 0.5),
        0,
      );
    });

    test('charges only the kilometres above the allowance', () {
      // 3 days * 100 km = 300 km included; 380 driven -> 80 extra * 0.5 TND.
      expect(
        Pricing.extraKmCharge(
            kmDriven: 380, days: 3, includedKmPerDay: 100, extraKmPrice: 0.5),
        40,
      );
    });

    test('exactly at the allowance is free', () {
      expect(
        Pricing.extraKmCharge(
            kmDriven: 300, days: 3, includedKmPerDay: 100, extraKmPrice: 0.5),
        0,
      );
    });
  });
}
