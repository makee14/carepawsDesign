import 'package:carepaws/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('promo grooming price matches Full Grooming service price', () {
    final promo = Seed.promos.firstWhere((p) => p.id == 'promo-groom');
    final fullGroom = Seed.services.firstWhere((s) => s.id == 'sv4');
    expect(promo.subtitle, contains('₱${fullGroom.price.toInt()}'));
  });
}
