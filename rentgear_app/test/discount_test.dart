import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/discount.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

const diskon = DiscountPolicy(shortPercent: 10, longPercent: 20);

/// Kompor Rp15.000 per hari, deposit Rp30.000, di Arjuna Outdoor.
BookingRequest kompor(AppUser budi, String key, int startOffset, int days) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day + startOffset);
  return BookingRequest(
    customerId: budi.id,
    equipmentId: 'e-kompor',
    qty: 1,
    startDate: start,
    endDate: start.add(Duration(days: days - 1)),
    idempotencyKey: key,
    guarantees: [
      GuaranteeDraft(type: GuaranteeType.ktp, holderName: 'Budi Santoso', documentNumber: '3573011204020001')
        ..photo = Uint8List.fromList([1, 2, 3]),
    ],
  );
}

void main() {
  // Kasus yang sama dengan tests/Unit/Domain/DiscountPolicyTest.php di server.
  group('DiscountPolicy', () {
    test('tanpa diskon bila toko belum mengatur', () {
      const policy = DiscountPolicy();
      expect(policy.error, isNull);
      expect(policy.percentFor(10), 0);
      expect(DiscountPolicy.fromJson(null), policy);
    });

    test('persen diskon mengikuti lama sewa', () {
      expect(diskon.percentFor(2), 0);
      expect(diskon.percentFor(3), 10);
      expect(diskon.percentFor(6), 10);
      expect(diskon.percentFor(7), 20);
    });

    test('di luar batas platform ditolak', () {
      expect(const DiscountPolicy(shortPercent: 10, longPercent: 55).error, isNotNull);
      expect(const DiscountPolicy(shortPercent: -5, longPercent: 10).error, isNotNull);
      expect(const DiscountPolicy(shortPercent: 20, longPercent: 10).error, isNotNull);
      expect(const DiscountPolicy(shortPercent: 50, longPercent: 50).error, isNull);
    });
  });

  test('toko mengatur diskonnya sendiri', () async {
    final repo = LocalRentGearRepository.open(latency: Duration.zero);
    final budi = await repo.login('budi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');

    expect(() => repo.updateDiscountPolicy('p-arjuna', diskon, budi), throwsCode('FORBIDDEN'));
    expect(() => repo.updateDiscountPolicy('p-arjuna', diskon.copyWith(longPercent: 60), sari),
        throwsCode('VALIDATION'));

    await repo.updateDiscountPolicy('p-arjuna', diskon, sari);
    expect((await repo.provider('p-arjuna')).discountPolicy, diskon);
    expect((await repo.provider('p-semeru')).discountPolicy, const DiscountPolicy());
  });

  test('diskon memotong sewa, bukan deposit, dan dikunci saat dipesan', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_discount');
    addTearDown(() => dir.delete(recursive: true));
    var repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final budi = await repo.login('budi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');
    await repo.updateDiscountPolicy('p-arjuna', diskon, sari);

    final dua = await repo.createBooking(kompor(budi, 'k1', 1, 2));
    final tiga = await repo.createBooking(kompor(budi, 'k2', 5, 3));
    expect(dua.discountPercent, 0);
    expect(tiga.discountPercent, 10);
    expect(tiga.rentGross, tiga.pricePerDaySnapshot * 3);
    expect(tiga.discount, (tiga.rentGross * 0.1).roundToDouble());
    expect(tiga.grandTotal, tiga.rentGross - tiga.discount + tiga.depositTotal);

    // Toko menghapus diskonnya; sewa yang sudah dipesan tetap, juga setelah dibuka ulang.
    await repo.updateDiscountPolicy('p-arjuna', const DiscountPolicy(), sari);
    repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    expect((await repo.rental(tiga.id)).discountPercent, 10);
    expect((await repo.provider('p-arjuna')).discountPolicy, const DiscountPolicy());
  });
}
