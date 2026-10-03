import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

/// r-3: carrier Rina di Arjuna Outdoor (Sari), sudah dibayar.
void main() {
  final foto = Uint8List.fromList([1, 2, 3]);

  test('hanya toko pemilik yang menambah foto, pada tahap yang tepat', () async {
    final repo = LocalRentGearRepository.open(latency: Duration.zero);
    final rina = await repo.login('rina@rentgear.id', 'password');
    final dewi = await repo.login('dewi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');

    expect(() => repo.addConditionPhoto('r-3', rina, ConditionPhase.handover, foto), throwsCode('FORBIDDEN'));
    expect(() => repo.addConditionPhoto('r-3', dewi, ConditionPhase.handover, foto), throwsCode('FORBIDDEN'));
    // Alat belum kembali, jadi belum ada foto pengembalian.
    expect(() => repo.addConditionPhoto('r-3', sari, ConditionPhase.returned, foto), throwsCode('INVALID_STATE'));

    await repo.addConditionPhoto('r-3', sari, ConditionPhase.handover, foto);
    await repo.handover('r-3', sari);
    await repo.receiveReturn('r-3', sari, condition: ReturnCondition.good);
    expect(() => repo.addConditionPhoto('r-3', sari, ConditionPhase.handover, foto), throwsCode('INVALID_STATE'));
    final r = await repo.addConditionPhoto('r-3', sari, ConditionPhase.returned, foto);

    expect(r.conditionPhotosOf(ConditionPhase.handover), hasLength(1));
    expect(r.conditionPhotosOf(ConditionPhase.returned), hasLength(1));
  });

  test('paling banyak empat foto per tahap, dan foto tersimpan setelah aplikasi ditutup', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_condition');
    addTearDown(() => dir.delete(recursive: true));
    var repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final sari = await repo.login('sari@rentgear.id', 'password');
    for (var i = 0; i < maxConditionPhotos; i++) {
      await repo.addConditionPhoto('r-3', sari, ConditionPhase.handover, Uint8List.fromList([i, 9]));
    }
    expect(() => repo.addConditionPhoto('r-3', sari, ConditionPhase.handover, foto), throwsCode('VALIDATION'));

    repo = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final photos = (await repo.rental('r-3')).conditionPhotos;
    expect(photos, hasLength(maxConditionPhotos));
    expect(photos.first.phase, ConditionPhase.handover);
    expect(photos.last.bytes, [maxConditionPhotos - 1, 9]);
  });

  test('aturan waktu foto sama untuk semua status', () {
    expect(conditionPhotoError(ConditionPhase.handover, RentalStatus.paid), isNull);
    expect(conditionPhotoError(ConditionPhase.handover, RentalStatus.pickedUp), isNull);
    expect(conditionPhotoError(ConditionPhase.handover, RentalStatus.awaitingPayment), isNotNull);
    expect(conditionPhotoError(ConditionPhase.returned, RentalStatus.returned), isNull);
    expect(conditionPhotoError(ConditionPhase.returned, RentalStatus.pickedUp), isNotNull);
    expect(conditionPhotoError(ConditionPhase.returned, RentalStatus.completed), isNotNull);
  });
}
