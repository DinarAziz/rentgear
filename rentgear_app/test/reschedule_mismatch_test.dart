import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/domain/availability.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';

void main() {
  late LocalRentGearRepository repo;
  late AppUser budi;
  late AppUser sari; // pemilik Arjuna Outdoor
  late AppUser admin;
  final today = dateOnly(DateTime.now());
  final photo = Uint8List.fromList([1]);
  DateTime day(int offset) => today.add(Duration(days: offset));

  Matcher fails(String code) => throwsA(isA<AppException>().having((e) => e.code, 'code', code));

  setUp(() async {
    repo = LocalRentGearRepository.open(latency: Duration.zero);
    budi = await repo.login('budi@rentgear.id', 'password');
    sari = await repo.login('sari@rentgear.id', 'password');
    admin = await repo.login('admin@rentgear.id', 'password');
  });

  /// Booking kompor (stok 4) oleh Budi.
  Future<Rental> book({int qty = 1, int start = 1, int end = 2, String key = 'k1'}) =>
      repo.createBooking(BookingRequest(
        customerId: budi.id,
        equipmentId: 'e-kompor',
        qty: qty,
        startDate: day(start),
        endDate: day(end),
        idempotencyKey: key,
        guarantees: [
          GuaranteeDraft(type: GuaranteeType.ktp, holderName: 'Teman Budi', documentNumber: '3573011204020001')
            ..photo = photo,
        ],
      ));

  /// Booking yang dibawa sampai alat diserahkan hari ini.
  Future<Rental> pickedUp({String key = 'k1'}) async {
    final r = await book(start: 0, end: 1, key: key);
    await repo.reviewGuarantee(r.id, r.guarantees.single.id, sari, accept: true);
    await repo.confirmBooking(r.id, sari);
    await repo.submitPayment(r.id, budi, photo);
    await repo.reviewPayment(r.id, sari, accept: true);
    return repo.handover(r.id, sari);
  }

  group('ganti tanggal', () {
    test('new dates apply only after the store agrees', () async {
      var r = await book();
      r = await repo.requestReschedule(r.id, budi, day(5), day(6));
      expect([r.startDate, r.rescheduleStart, r.canRequestReschedule], [day(1), day(5), false]);
      await expectLater(repo.requestReschedule(r.id, budi, day(7), day(8)), fails('INVALID_STATE'));
      await expectLater(repo.reviewReschedule(r.id, budi, accept: true), fails('FORBIDDEN'));

      r = await repo.reviewReschedule(r.id, sari, accept: true);
      expect([r.startDate, r.endDate, r.rescheduleStart], [day(5), day(6), null]);
      expect(r.status, RentalStatus.pendingConfirmation);
      expect(r.logs.last.isNote, isTrue);
      expect(r.logs.last.note, startsWith('Tanggal sewa diganti menjadi'));
    });

    test('a refused request keeps the old dates', () async {
      var r = await book();
      await repo.requestReschedule(r.id, budi, day(5), day(6));
      await expectLater(repo.reviewReschedule(r.id, sari, accept: false), fails('VALIDATION'));
      r = await repo.reviewReschedule(r.id, sari, accept: false, reason: 'Toko tutup');
      expect([r.startDate, r.rescheduleStart], [day(1), null]);
      expect(r.logs.last.note, 'Ganti tanggal ditolak: Toko tutup');
    });

    test('the rental cannot get longer, move to the past, or stay the same', () async {
      final r = await book();
      await expectLater(repo.requestReschedule(r.id, budi, day(5), day(7)), fails('INVALID_DATE'));
      await expectLater(repo.requestReschedule(r.id, budi, day(1), day(2)), fails('INVALID_DATE'));
      await expectLater(repo.requestReschedule(r.id, budi, day(-3), day(-2)), fails('INVALID_DATE'));
    });

    test('dates taken by another rental are refused at request and at approval', () async {
      final r = await book();
      await book(qty: 4, start: 5, end: 6, key: 'k2');
      await expectLater(repo.requestReschedule(r.id, budi, day(5), day(6)), fails('SLOT_UNAVAILABLE'));

      // Bergeser satu hari di atas tanggalnya sendiri boleh.
      await repo.requestReschedule(r.id, budi, day(2), day(3));
      // Stok habis setelah permintaan dibuat, sebelum toko menjawab.
      await book(qty: 4, start: 3, end: 3, key: 'k3');
      await expectLater(repo.reviewReschedule(r.id, sari, accept: true), fails('SLOT_UNAVAILABLE'));
      expect((await repo.rental(r.id)).startDate, day(1));
    });

    test('dates are locked once the gear is picked up', () async {
      final r = await pickedUp();
      expect(r.canRequestReschedule, isFalse);
      await expectLater(repo.requestReschedule(r.id, budi, day(5), day(6)), fails('INVALID_STATE'));
    });
  });

  group('barang tidak sesuai', () {
    test('a refund closes the rental, returns the documents and frees the stock', () async {
      var r = await pickedUp();
      final before = await repo.availableQty('e-kompor', day(0), day(1));
      expect(r.canReportMismatchAt(DateTime.now()), isTrue);

      r = await repo.reportMismatch(r.id, budi, 'Kompor tidak menyala');
      expect(r.mismatch, MismatchStatus.pending);
      await expectLater(repo.reportMismatch(r.id, budi, 'Lagi'), fails('INVALID_STATE'));
      await expectLater(repo.receiveReturn(r.id, sari), fails('MISMATCH_PENDING'));
      await expectLater(repo.decideMismatch(r.id, sari, MismatchStatus.refund), fails('FORBIDDEN'));

      r = await repo.decideMismatch(r.id, admin, MismatchStatus.refund, note: 'Terlihat di foto');
      expect([r.status, r.mismatch, r.guarantees.single.status],
          [RentalStatus.refunded, MismatchStatus.refund, GuaranteeStatus.returned]);
      expect(await repo.availableQty('e-kompor', day(0), day(1)), before + 1);
      expect((await repo.auditLog(admin)).first.action, AuditAction.mismatchDecided);
    });

    test('an exchange or a refusal lets the rental go on', () async {
      for (final decision in [MismatchStatus.exchange, MismatchStatus.rejected]) {
        var r = await pickedUp(key: decision.name);
        await repo.reportMismatch(r.id, budi, 'Tenda sobek');
        r = await repo.decideMismatch(r.id, admin, decision);
        expect([r.status, r.mismatch], [RentalStatus.pickedUp, decision]);
        expect((await repo.receiveReturn(r.id, sari)).status, RentalStatus.returned);
      }
    });

    test('reports are refused before pickup and for gear picked up on an earlier day', () async {
      final waiting = await book(key: 'belum');
      await expectLater(repo.reportMismatch(waiting.id, budi, 'x'), fails('INVALID_STATE'));
      // r-4: diambil Budi dua hari yang lalu.
      expect((await repo.rental('r-4')).canReportMismatchAt(DateTime.now()), isFalse);
      await expectLater(repo.reportMismatch('r-4', budi, 'x'), fails('INVALID_STATE'));
    });
  });
}
