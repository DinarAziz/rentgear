import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  late LocalRentGearRepository repo;
  setUp(() => repo = LocalRentGearRepository.open(latency: Duration.zero));

  test('aksi admin tercatat dengan pelaku, sasaran, dan rincian', () async {
    final admin = await repo.login('admin@rentgear.id', 'password');
    await repo.setProviderStatus('p-puncak', ProviderStatus.verified, admin);
    await repo.setBlacklist('u-budi', admin, blocked: true, reason: 'Tidak mengembalikan alat');
    await repo.setBlacklist('u-budi', admin, blocked: false);

    // Terbaru lebih dulu.
    final log = await repo.auditLog(admin);
    expect(log.map((e) => e.action), [
      AuditAction.blacklistRemoved,
      AuditAction.blacklistAdded,
      AuditAction.providerStatus,
      AuditAction.login,
    ]);
    expect(log[1].target, 'Budi Santoso');
    expect(log[1].detail, 'Tidak mengembalikan alat');
    expect(log[2].target, 'Puncak Outdoor');
    expect(log[2].detail, 'Dari Menunggu verifikasi menjadi Terverifikasi.');
    expect(log[2].actorName, admin.name);
    expect(log[2].actorRole, 'admin');
  });

  test('gagal masuk tercatat tanpa password, dan hanya admin yang membaca jejak', () async {
    await expectLater(repo.login('budi@rentgear.id', 'rahasia-salah'), throwsCode('AUTH_FAILED'));
    final budi = await repo.login('budi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');
    expect(() => repo.auditLog(budi), throwsCode('FORBIDDEN'));
    expect(() => repo.auditLog(sari), throwsCode('FORBIDDEN'));

    final admin = await repo.login('admin@rentgear.id', 'password');
    final failed = (await repo.auditLog(admin)).last;
    expect(failed.action, AuditAction.loginFailed);
    expect(failed.target, 'budi@rentgear.id');
    expect(failed.actorName, 'Tidak dikenal');
    expect('${failed.detail}${failed.target}', isNot(contains('rahasia-salah')));
  });

  test('keputusan denda tercatat dengan nomor invoice', () async {
    final dewi = await repo.login('dewi@rentgear.id', 'password');
    final admin = await repo.login('admin@rentgear.id', 'password');
    // r-4: tenda ultralight Budi di Semeru Camp Rent, sedang disewa. Deposit 150.000.
    await repo.receiveReturn('r-4', dewi, condition: ReturnCondition.majorDamage, damageFee: 100000, damageNote: 'Robek');
    final r = await repo.decideDamageFee('r-4', admin, amount: 40000, note: ' Sebagian saja ');

    final entry = (await repo.auditLog(admin)).firstWhere((e) => e.action == AuditAction.damageFeeDecided);
    expect(entry.target, r.invoiceCode);
    expect(entry.detail, 'Denda akhir Rp40.000. Catatan: Sebagian saja');
  });

  test('jejak tersimpan setelah aplikasi ditutup, termasuk gagal masuk', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_audit');
    addTearDown(() => dir.delete(recursive: true));
    var local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    await expectLater(local.login('admin@rentgear.id', 'salah'), throwsCode('AUTH_FAILED'));
    var admin = await local.login('admin@rentgear.id', 'password');
    await local.setProviderStatus('p-puncak', ProviderStatus.rejected, admin);

    local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    admin = await local.login('admin@rentgear.id', 'password');
    expect((await local.auditLog(admin)).map((e) => e.action), [
      AuditAction.login,
      AuditAction.providerStatus,
      AuditAction.login,
      AuditAction.loginFailed,
    ]);
  });

  test('login Google dan saran AI ditolak tanpa server', () async {
    expect(() => repo.loginWithGoogle('token'), throwsCode('UNSUPPORTED'));
    final admin = await repo.login('admin@rentgear.id', 'password');
    expect(() => repo.aiRecommend(trip: 'Semeru', people: 2, days: 2), throwsCode('AI_UNAVAILABLE'));
    expect(() => repo.aiFineOpinion('r-4', admin), throwsCode('AI_UNAVAILABLE'));
    expect(() => repo.aiCustomerRisk('u-budi', admin), throwsCode('AI_UNAVAILABLE'));
  });
}
