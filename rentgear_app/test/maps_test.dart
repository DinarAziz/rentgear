import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentgear/core/maps.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/domain/models.dart';
import 'package:rentgear/features/customer/store_map_screen.dart';

void main() {
  const malang = LatLng(-7.9396, 112.6289);
  const lumajang = LatLng(-8.1049, 113.1458);

  test('distanceKm follows the haversine formula', () {
    expect(distanceKm(malang, malang), 0);
    // Malang ke Lumajang sekitar 60 km garis lurus.
    expect(distanceKm(malang, lumajang), closeTo(59.8, 1));
    expect(distanceKm(malang, lumajang), closeTo(distanceKm(lumajang, malang), 1e-9));
    // Satu derajat lintang sekitar 111 km.
    expect(distanceKm(const LatLng(0, 0), const LatLng(1, 0)), closeTo(111.2, 0.2));
  });

  test('jarak formats metres and kilometres', () {
    expect(jarak(0.84), '850 m');
    expect(jarak(0.02), '0 m');
    expect(jarak(2.44), '2,4 km');
    expect(jarak(37.6), '38 km');
  });

  test('koordinat uses a decimal comma', () {
    expect(koordinat(malang), '-7,93960, 112,62890');
  });

  group('stores', () {
    late LocalRentGearRepository repo;
    setUp(() => repo = LocalRentGearRepository.open(latency: Duration.zero));

    test('sortStores puts the nearest store first when the location is known', () async {
      final stores = (await repo.providers()).where((p) => p.status == ProviderStatus.verified);
      expect(sortStores(stores, lumajang).first.id, 'p-semeru');
      expect(sortStores(stores, malang).first.id, 'p-arjuna');
      // Tanpa lokasi: urut rating, sama seperti sebelum ada peta.
      final byRating = sortStores(stores, null);
      expect(byRating.first.rating, greaterThanOrEqualTo(byRating.last.rating));
    });

    test('a provider moves its own store, and nobody else can', () async {
      final sari = await repo.login('sari@rentgear.id', 'password');
      final moved = await repo.updateProviderLocation('p-arjuna', sari, latitude: -7.95, longitude: 112.61);
      expect(moved.point, const LatLng(-7.95, 112.61));
      expect((await repo.provider('p-arjuna')).latitude, -7.95);

      final dewi = await repo.login('dewi@rentgear.id', 'password');
      expect(
        () => repo.updateProviderLocation('p-arjuna', dewi, latitude: 0, longitude: 0),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
      expect(
        () => repo.updateProviderLocation('p-arjuna', sari, latitude: 91, longitude: 0),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'VALIDATION')),
      );
    });
  });
}
