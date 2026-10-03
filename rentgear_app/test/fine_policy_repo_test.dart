import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

const aturan = FinePolicy(lateMultiplier: 2, graceHours: 3, minorDamagePercent: 20, majorDamagePercent: 50, lostPercent: 90);

BookingRequest kompor(AppUser budi, String key, int startOffset) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day + startOffset);
  return BookingRequest(
    customerId: budi.id,
    equipmentId: 'e-kompor',
    qty: 1,
    startDate: start,
    endDate: start.add(const Duration(days: 1)),
    idempotencyKey: key,
    guarantees: [
      GuaranteeDraft(type: GuaranteeType.ktp, holderName: 'Budi Santoso', documentNumber: '3573011204020001')
        ..photo = Uint8List.fromList([1, 2, 3]),
    ],
  );
}

void main() {
  test('toko mengatur aturan dendanya sendiri, dalam batas platform', () async {
    final repo = LocalRentGearRepository.open(latency: Duration.zero);
    final budi = await repo.login('budi@rentgear.id', 'password');
    final dewi = await repo.login('dewi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');

    expect(() => repo.updateFinePolicy('p-arjuna', aturan, budi), throwsCode('FORBIDDEN'));
    expect(() => repo.updateFinePolicy('p-arjuna', aturan, dewi), throwsCode('FORBIDDEN'));
    expect(() => repo.updateFinePolicy('p-arjuna', aturan.copyWith(lateMultiplier: 2.5), sari), throwsCode('VALIDATION'));

    await repo.updateFinePolicy('p-arjuna', aturan, sari);
    expect((await repo.provider('p-arjuna')).finePolicy, aturan);
    // Toko lain tidak ikut berubah.
    expect((await repo.provider('p-semeru')).finePolicy, const FinePolicy());
  });

  test('sewa memakai aturan saat dipesan, dan aturannya tersimpan', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_fine_policy');
    addTearDown(() => dir.delete(recursive: true));
    var repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final budi = await repo.login('budi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');

    final lama = await repo.createBooking(kompor(budi, 'k1', 1));
    await repo.updateFinePolicy('p-arjuna', aturan, sari);
    final baru = await repo.createBooking(kompor(budi, 'k2', 5));
    expect(lama.finePolicy, const FinePolicy());
    expect(baru.finePolicy, aturan);

    repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    expect((await repo.provider('p-arjuna')).finePolicy, aturan);
    expect((await repo.rental(lama.id)).finePolicy, const FinePolicy());
    expect((await repo.rental(baru.id)).finePolicy, aturan);
  });
}
