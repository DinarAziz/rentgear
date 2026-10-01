import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/availability.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  group('rumus denda', () {
    final end = DateTime(2026, 10, 5);

    test(
      'hari terlambat dihitung dari tanggal selesai, tidak pernah negatif',
      () {
        expect(lateDays(end, DateTime(2026, 10, 5, 23, 59)), 0);
        expect(lateDays(end, DateTime(2026, 10, 6, 0, 1)), 1);
        expect(lateDays(end, DateTime(2026, 10, 8)), 3);
        expect(lateDays(end, DateTime(2026, 10, 3)), 0);
      },
    );

    test('denda terlambat = hari x tarif x unit x 1,5', () {
      expect(lateFeeFor(pricePerDay: 45000, qty: 1, days: 2), 135000);
      expect(lateFeeFor(pricePerDay: 15000, qty: 2, days: 3), 135000);
      expect(lateFeeFor(pricePerDay: 45000, qty: 1, days: 0), 0);
    });

    test(
      'denda kerusakan harus cocok dengan kondisi dan tidak melebihi deposit',
      () {
        expect(damageFeeError(ReturnCondition.good, 0, 100000), isNull);
        expect(damageFeeError(ReturnCondition.good, 10000, 100000), isNotNull);
        expect(
          damageFeeError(ReturnCondition.minorDamage, 0, 100000),
          isNotNull,
        );
        expect(
          damageFeeError(ReturnCondition.minorDamage, 30000, 100000),
          isNull,
        );
        expect(damageFeeError(ReturnCondition.lost, 100000, 100000), isNull);
        expect(damageFeeError(ReturnCondition.lost, 100001, 100000), isNotNull);
      },
    );

    test('denda di atas separuh deposit ditinjau admin', () {
      expect(needsAdminReview(50000, 100000), isFalse);
      expect(needsAdminReview(50001, 100000), isTrue);
    });
  });

  group('denda pada transaksi', () {
    late LocalRentGearRepository repo;
    late AppUser budi;
    late AppUser dewi; // pemilik Semeru Camp Rent
    late AppUser admin;

    // Data demo dibuat 4 hari lalu, jadi r-4 (Budi, tenda ultralight) sudah lewat 3 hari.
    setUp(() async {
      repo = LocalRentGearRepository.open(
        now: DateTime.now().subtract(const Duration(days: 4)),
        latency: Duration.zero,
      );
      await repo.runScheduledJobs();
      budi = await repo.login('budi@rentgear.id', 'password');
      dewi = await repo.login('dewi@rentgear.id', 'password');
      admin = await repo.login('admin@rentgear.id', 'password');
    });

    test(
      'terlambat 3 hari: denda dihitung saat alat diterima dan dipotong dari deposit',
      () async {
        expect((await repo.rental('r-4')).status, RentalStatus.overdue);

        final r = await repo.receiveReturn('r-4', dewi);
        expect(r.status, RentalStatus.returned);
        expect(r.returnCondition, ReturnCondition.good);
        expect(r.lateFee, 3 * r.pricePerDaySnapshot * r.qty * 1.5);
        expect(r.damageFee, 0);
        expect(r.fineTotal, r.lateFee);
        expect(
          r.depositRefund + r.fineShortfall,
          (r.depositTotal - r.fineTotal).abs(),
        );
        expect(r.depositRefund == 0 || r.fineShortfall == 0, isTrue);
      },
    );

    test(
      'denda kerusakan kecil langsung berlaku dan transaksi bisa ditutup',
      () async {
        final deposit = (await repo.rental('r-4')).depositTotal;
        var r = await repo.receiveReturn(
          'r-4',
          dewi,
          condition: ReturnCondition.minorDamage,
          damageFee: deposit * 0.2,
          damageNote: 'Pasak bengkok',
        );
        expect(r.damageFee, deposit * 0.2);
        expect(r.damageReview, DamageReview.none);

        r = await repo.returnGuaranteesAndComplete('r-4', dewi);
        expect(r.status, RentalStatus.completed);
      },
    );

    test('denda kerusakan tidak sah ditolak', () async {
      final deposit = (await repo.rental('r-4')).depositTotal;
      await expectLater(
        repo.receiveReturn(
          'r-4',
          dewi,
          condition: ReturnCondition.good,
          damageFee: 10000,
        ),
        throwsCode('VALIDATION'),
      );
      await expectLater(
        repo.receiveReturn(
          'r-4',
          dewi,
          condition: ReturnCondition.lost,
          damageFee: deposit + 1,
        ),
        throwsCode('VALIDATION'),
      );
      expect((await repo.rental('r-4')).status, RentalStatus.overdue);
    });

    test(
      'denda besar menunggu keputusan admin sebelum transaksi ditutup',
      () async {
        final deposit = (await repo.rental('r-4')).depositTotal;
        var r = await repo.receiveReturn(
          'r-4',
          dewi,
          condition: ReturnCondition.majorDamage,
          damageFee: deposit * 0.8,
          damageNote: 'Flysheet sobek',
        );
        expect(r.damageReview, DamageReview.pending);
        await expectLater(
          repo.returnGuaranteesAndComplete('r-4', dewi),
          throwsCode('DAMAGE_REVIEW_PENDING'),
        );

        // Hanya admin yang memutuskan, dan nominalnya tetap dibatasi deposit.
        await expectLater(
          repo.decideDamageFee('r-4', dewi, amount: 0),
          throwsCode('FORBIDDEN'),
        );
        await expectLater(
          repo.decideDamageFee('r-4', admin, amount: deposit + 1),
          throwsCode('VALIDATION'),
        );

        r = await repo.decideDamageFee(
          'r-4',
          admin,
          amount: deposit * 0.4,
          note: 'Sobekan kecil',
        );
        expect(r.damageFee, deposit * 0.4);
        expect(r.damageReview, DamageReview.decided);
        expect(
          (await repo.returnGuaranteesAndComplete('r-4', dewi)).status,
          RentalStatus.completed,
        );
      },
    );

    test('penyewa bisa mengajukan keberatan atas denda kerusakan', () async {
      final deposit = (await repo.rental('r-4')).depositTotal;
      await repo.receiveReturn(
        'r-4',
        dewi,
        condition: ReturnCondition.minorDamage,
        damageFee: deposit * 0.3,
        damageNote: 'Resleting macet',
      );

      await expectLater(
        repo.objectToDamageFee('r-4', dewi, 'bukan saya'),
        throwsCode('FORBIDDEN'),
      );
      final r = await repo.objectToDamageFee(
        'r-4',
        budi,
        'Resleting sudah macet sejak awal',
      );
      expect(r.damageReview, DamageReview.pending);
      expect(r.reviewReason, contains('Resleting sudah macet'));
      await expectLater(
        repo.objectToDamageFee('r-4', budi, 'lagi'),
        throwsCode('INVALID_STATE'),
      );
    });

    test('denda dan catatannya tersimpan setelah aplikasi ditutup', () async {
      final dir = await Directory.systemTemp.createTemp('rentgear_fines');
      addTearDown(() => dir.delete(recursive: true));
      var local = LocalRentGearRepository.open(
        store: LocalStore(dir),
        now: DateTime.now().subtract(const Duration(days: 4)),
        latency: Duration.zero,
      );
      await local.runScheduledJobs();
      final saved = await local.receiveReturn(
        'r-4',
        dewi,
        condition: ReturnCondition.majorDamage,
        damageFee: (await local.rental('r-4')).depositTotal * 0.8,
        damageNote: 'Frame patah',
      );
      await local.setBlacklist(
        budi.id,
        admin,
        blocked: true,
        reason: 'Merusak alat',
      );

      local = LocalRentGearRepository.open(
        store: LocalStore(dir),
        latency: Duration.zero,
      );
      final r = await local.rental('r-4');
      expect(r.lateFee, saved.lateFee);
      expect(r.damageFee, saved.damageFee);
      expect(r.returnCondition, ReturnCondition.majorDamage);
      expect(r.damageNote, 'Frame patah');
      expect(r.damageReview, DamageReview.pending);
      expect(r.returnedAt, isNotNull);
      expect((await local.blacklistOf(budi.id))?.reason, 'Merusak alat');
    });
  });

  group('blacklist', () {
    late LocalRentGearRepository repo;
    late AppUser budi;
    late AppUser admin;
    final today = dateOnly(DateTime.now());

    setUp(() async {
      repo = LocalRentGearRepository.open(latency: Duration.zero);
      budi = await repo.login('budi@rentgear.id', 'password');
      admin = await repo.login('admin@rentgear.id', 'password');
    });

    BookingRequest request(String key) => BookingRequest(
      customerId: budi.id,
      equipmentId: 'e-kompor',
      qty: 1,
      startDate: today.add(const Duration(days: 1)),
      endDate: today.add(const Duration(days: 2)),
      idempotencyKey: key,
      guarantees: [
        GuaranteeDraft(
          type: GuaranteeType.ktp,
          holderName: budi.name,
          documentNumber: '3573011204020001',
        )..photo = Uint8List.fromList([1]),
      ],
    );

    test('penyewa blacklist tidak bisa booking sampai dicabut admin', () async {
      await expectLater(
        repo.setBlacklist(budi.id, budi, blocked: true, reason: 'x'),
        throwsCode('FORBIDDEN'),
      );
      await expectLater(
        repo.setBlacklist(budi.id, admin, blocked: true, reason: '  '),
        throwsCode('VALIDATION'),
      );

      await repo.setBlacklist(
        budi.id,
        admin,
        blocked: true,
        reason: 'Tidak mengembalikan alat',
      );
      expect(
        (await repo.blacklistOf(budi.id))?.reason,
        'Tidak mengembalikan alat',
      );
      await expectLater(
        repo.createBooking(request('a')),
        throwsCode('BLACKLISTED'),
      );

      await repo.setBlacklist(budi.id, admin, blocked: false);
      expect(await repo.blacklistOf(budi.id), isNull);
      expect(
        (await repo.createBooking(request('b'))).status,
        RentalStatus.pendingConfirmation,
      );
    });

    test('admin melihat riwayat pelanggaran tiap penyewa', () async {
      await expectLater(repo.customers(budi), throwsCode('FORBIDDEN'));
      final records = await repo.customers(admin);
      expect(
        records.map((c) => c.user.email),
        containsAll(['budi@rentgear.id', 'rina@rentgear.id']),
      );
      final record = records.firstWhere((c) => c.user.id == budi.id);
      expect(record.rentalCount, 3);
      expect(record.violations, 0);
      expect(record.blacklist, isNull);
    });

    test('tiga pelanggaran membuat penyewa masuk blacklist otomatis', () async {
      // Data demo dibuat 4 hari lalu, jadi sewa Budi (r-4) sudah terlambat.
      final old = LocalRentGearRepository.open(
        now: DateTime.now().subtract(const Duration(days: 4)),
        latency: Duration.zero,
      );
      await old.runScheduledJobs();
      final adminOld = await old.login('admin@rentgear.id', 'password');
      final dewi = await old.login('dewi@rentgear.id', 'password');

      Future<CustomerRecord> recordOfBudi() async {
        final records = await old.customers(adminOld);
        return records.firstWhere((c) => c.user.id == 'u-budi');
      }

      expect((await recordOfBudi()).violations, 0);

      // Budi terlambat: pelanggaran pertama.
      await old.receiveReturn('r-4', dewi);
      final budiRecord = await recordOfBudi();
      expect(budiRecord.lateCount, 1);
      expect(budiRecord.violations, 1);
      expect(budiRecord.blacklist, isNull);

      expect(shouldAutoBlacklist(violations: 2, baseline: 0), isFalse);
      expect(shouldAutoBlacklist(violations: 3, baseline: 0), isTrue);
      // Setelah admin mencabut blacklist pada 3 pelanggaran, hitungan mulai lagi dari sana.
      expect(shouldAutoBlacklist(violations: 4, baseline: 3), isFalse);
      expect(shouldAutoBlacklist(violations: 6, baseline: 3), isTrue);
    });
  });
}
