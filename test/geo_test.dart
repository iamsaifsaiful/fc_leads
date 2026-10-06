import 'package:fc_leads/data/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles every country with its calling code', () async {
    final geo = GeoRepository();
    final countries = await geo.countries();
    expect(countries.length, greaterThan(240));
    final bd = await geo.country('BD');
    expect(bd!.name, 'Bangladesh');
    expect(bd.dialCode, '880');
    expect(bd.flag, '🇧🇩');
  });

  test('lists cities largest first, capital included', () async {
    final geo = GeoRepository();
    final bd = await geo.cities('BD');
    expect(bd.first, 'Dhaka');
    expect(bd, contains('Chittagong'));
    final us = await geo.cities('US');
    expect(us.length, greaterThan(5000));
    expect(us.take(5), contains('New York City'));
  });

  test('unknown country gives no cities', () async {
    expect(await GeoRepository().cities('ZZ'), isEmpty);
  });
}
