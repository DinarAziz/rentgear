import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/availability.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';

void main() {
  late LocalRentGearRepository repo;
  late AppUser budi;
  late AppUser sari; // pemilik Arjuna Outdoor
  final today = dateOnly(DateTime.now());
  final photo = Uint8List.fromList([1]);

  setUp(() async {
    repo = LocalRentGearRepository.open(latency: Duration.zero);
    budi = await repo.login('budi@rentgear.id', 'password');
    sari = await repo.login('sari@rentgear.id', 'password');
  });

  BookingRequest request({
    String equipmentId = 'e-kompor',
    int qty = 1,
    int startOffset = 1,
    int endOffset = 2,
    List<GuaranteeDraft>? guarantees,
    String key = 'k1',
  }) =>
      BookingRequest(
        customerId: budi.id,
        equipmentId: equipmentId,
        qty: qty,
        startDate: today.add(Duration(days: startOffset)),
        endDate: today.add(Duration(days: endOffset)),
        idempotencyKey: key,
        guarantees: guarantees ??
            [
              GuaranteeDraft(
                type: GuaranteeType.ktp,
                holderName: budi.name,
                documentNumber: '3573011204020001',
              )..photo = photo,
            ],
      );

  test('full lifecycle: guarantee verified, held, then returned', () async {
    var r = await repo.createBooking(request());
    expect(r.status, RentalStatus.pendingConfirmation);
    expect(r.guarantees.single.status, GuaranteeStatus.submitted);

    // Konfirmasi ditolak selama jaminan belum diverifikasi.
    await expectLater(repo.confirmBooking(r.id, sari),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'INVALID_TRANSITION')));

    r = await repo.reviewGuarantee(r.id, r.guarantees.single.id, sari, accept: true);
    r = await repo.confirmBooking(r.id, sari);
    expect(r.status, RentalStatus.awaitingPayment);

    r = await repo.submitPayment(r.id, budi, photo);
    expect(r.status, RentalStatus.paymentReview);
    // Bukti belum diperiksa, jadi alat belum bisa diserahkan.
    await expectLater(repo.handover(r.id, sari),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'INVALID_STATE')));
    r = await repo.reviewPayment(r.id, sari, accept: true);
    expect(r.status, RentalStatus.paid);
    r = await repo.handover(r.id, sari);
    expect(r.status, RentalStatus.pickedUp);
    expect(r.guarantees.single.status, GuaranteeStatus.held);

    r = await repo.receiveReturn(r.id, sari);
    r = await repo.returnGuaranteesAndComplete(r.id, sari);
    expect(r.status, RentalStatus.completed);
    expect(r.guarantees.single.status, GuaranteeStatus.returned);
    expect(r.logs.map((l) => l.to), [
      RentalStatus.pendingConfirmation,
      RentalStatus.awaitingPayment,
      RentalStatus.paymentReview,
      RentalStatus.paid,
      RentalStatus.pickedUp,
      RentalStatus.returned,
      RentalStatus.completed,
    ]);
  });

  test('a rejected transfer proof goes back to the renter, who can upload again', () async {
    final rina = await repo.login('rina@rentgear.id', 'password');
    final dewi = await repo.login('dewi@rentgear.id', 'password'); // pemilik toko lain
    const id = 'r-2'; // seed: Tenda Dome milik Arjuna Outdoor, menunggu pembayaran

    var r = await repo.submitPayment(id, rina, photo);
    expect(r.status, RentalStatus.paymentReview);
    expect(r.paymentRejection, isNull);

    // Hanya toko pemilik pesanan yang memeriksa, dan penolakan wajib beralasan.
    await expectLater(repo.reviewPayment(id, dewi, accept: true),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'FORBIDDEN')));
    await expectLater(repo.reviewPayment(id, sari, accept: false, reason: '  '),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'VALIDATION')));

    r = await repo.reviewPayment(id, sari, accept: false, reason: 'Nominal kurang');
    expect(r.status, RentalStatus.awaitingPayment);
    expect(r.paymentRejection, 'Bukti transfer ditolak: Nominal kurang');
    // Tidak ada bukti yang menunggu, jadi tidak ada yang bisa diterima.
    await expectLater(repo.reviewPayment(id, sari, accept: true),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'INVALID_TRANSITION')));

    r = await repo.submitPayment(id, rina, photo);
    expect(r.paymentRejection, isNull);
    r = await repo.reviewPayment(id, sari, accept: true);
    expect(r.status, RentalStatus.paid);
  });

  test('booking without guarantee is refused', () async {
    await expectLater(repo.createBooking(request(guarantees: [])),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'GUARANTEE_INVALID')));
  });

  test('high-value booking needs two guarantees', () async {
    // 4 kompor × 10 hari × 20rb + deposit 4 × 50rb = 1.000.000 → wajib 2.
    await expectLater(
      repo.createBooking(request(qty: 4, startOffset: 20, endOffset: 29)),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('minimal 2'))),
    );
  });

  test('same idempotency key returns the same booking', () async {
    final a = await repo.createBooking(request());
    final b = await repo.createBooking(request());
    expect(b.id, a.id);
  });

  test('double booking is blocked by ALG-2', () async {
    // Tenda Dome stok 3; seed sudah memakai 1 (hari +3..+5) dan 2 (hari +4..+6).
    expect(await repo.availableQty('e-dome4', today.add(const Duration(days: 4)),
        today.add(const Duration(days: 4))), 0);
    await expectLater(
      repo.createBooking(request(equipmentId: 'e-dome4', startOffset: 4, endOffset: 4)),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'SLOT_UNAVAILABLE')),
    );
  });

  test('another provider cannot touch the order', () async {
    final dewi = await repo.login('dewi@rentgear.id', 'password');
    await expectLater(repo.confirmBooking('r-1', dewi),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'FORBIDDEN')));
  });

  test('data and session survive app restart', () async {
    final dir = Directory.systemTemp.createTempSync('rentgear');
    addTearDown(() => dir.deleteSync(recursive: true));

    var local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final user = await local.login('budi@rentgear.id', 'password');
    final created = await local.createBooking(BookingRequest(
      customerId: user.id,
      equipmentId: 'e-kompor',
      qty: 1,
      startDate: today.add(const Duration(days: 1)),
      endDate: today.add(const Duration(days: 1)),
      idempotencyKey: 'persist',
      guarantees: [
        GuaranteeDraft(type: GuaranteeType.ktp, holderName: user.name, documentNumber: '3573011204020001')
          ..photo = Uint8List.fromList([9, 8, 7]),
      ],
    ));

    // "Tutup" aplikasi lalu buka lagi dari file yang sama.
    local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    expect((await local.restoreSession())?.id, user.id);
    final reloaded = await local.rental(created.id);
    expect(reloaded.invoiceCode, created.invoiceCode);
    expect(reloaded.guarantees.single.photo, [9, 8, 7]);

    await local.logout();
    local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    expect(await local.restoreSession(), isNull);
  });

  test('scheduled jobs expire, cancel, no-show and flag overdue', () async {
    // Data demo dibuat 2 hari lalu, lalu aplikasi baru dibuka hari ini.
    final old = LocalRentGearRepository.open(
        now: DateTime.now().subtract(const Duration(days: 2)), latency: Duration.zero);
    expect(await old.runScheduledJobs(), 5);
    Future<RentalStatus> status(String id) async => (await old.rental(id)).status;
    expect(await status('r-1'), RentalStatus.expired);
    expect(await status('r-2'), RentalStatus.cancelled);
    expect(await status('r-3'), RentalStatus.noShow);
    expect(await status('r-4'), RentalStatus.overdue);
    expect(await status('r-6'), RentalStatus.overdue);
    expect((await old.rental('r-4')).logs.last.actorName, 'Sistem');
    expect(await old.runScheduledJobs(), 0);
  });

  group('shoe sizes', () {
    BookingRequest shoe({String? size, int qty = 1, String key = 's1'}) => BookingRequest(
          customerId: budi.id,
          equipmentId: 'e-sepatu',
          qty: qty,
          size: size,
          startDate: today.add(const Duration(days: 2)),
          endDate: today.add(const Duration(days: 3)),
          idempotencyKey: key,
          guarantees: [
            GuaranteeDraft(type: GuaranteeType.ktp, holderName: budi.name, documentNumber: '3573011204020001')
              ..photo = photo,
          ],
        );

    test('size is required and must exist', () async {
      await expectLater(repo.createBooking(shoe()),
          throwsA(isA<AppException>().having((e) => e.code, 'code', 'SIZE_REQUIRED')));
      await expectLater(repo.createBooking(shoe(size: '50')),
          throwsA(isA<AppException>().having((e) => e.code, 'code', 'SIZE_REQUIRED')));
    });

    test('stock is tracked per size', () async {
      final start = today.add(const Duration(days: 2));
      final end = today.add(const Duration(days: 3));
      expect(await repo.sizeAvailability('e-sepatu', start, end),
          {'39': 1, '40': 2, '41': 2, '42': 2, '43': 1, '44': 1});

      final r = await repo.createBooking(shoe(size: '43'));
      expect(r.size, '43');
      expect(r.itemLabel, contains('ukuran 43'));

      final after = await repo.sizeAvailability('e-sepatu', start, end);
      expect(after['43'], 0); // ukuran 43 habis
      expect(after['42'], 2); // ukuran lain tidak terpengaruh
      expect(await repo.availableQty('e-sepatu', start, end), 8);
      await expectLater(repo.createBooking(shoe(size: '43', key: 's2')),
          throwsA(isA<AppException>().having((e) => e.code, 'code', 'SLOT_UNAVAILABLE')));
    });
  });

  group('provider equipment management', () {
    Equipment draft({List<ItemPhoto> photos = const [], List<SizeStock> sizes = const [], String category = 'tenda'}) =>
        Equipment(
          id: '',
          providerId: '',
          categoryId: category,
          name: 'Tenda Baru',
          brand: 'Consina',
          description: 'Tes',
          pricePerDay: 30000,
          depositAmount: 50000,
          weightGram: 2000,
          stock: 2,
          sizes: sizes,
          photos: photos,
        );

    test('new equipment needs a photo and appears in catalog', () async {
      await expectLater(repo.saveEquipment(draft(), sari),
          throwsA(isA<AppException>().having((e) => e.message, 'message', contains('foto'))));

      final saved = await repo.saveEquipment(draft(photos: [MemoryPhoto('p1', photo)]), sari);
      expect(saved.id, isNotEmpty);
      expect(saved.providerId, 'p-arjuna');
      final found = await repo.searchEquipment(query: 'Tenda Baru');
      expect(found.single.id, saved.id);
    });

    test('shoes must have sizes; hidden items leave the catalog', () async {
      await expectLater(
        repo.saveEquipment(draft(category: 'sepatu', photos: [MemoryPhoto('p', photo)]), sari),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('ukuran'))),
      );
      final e = await repo.equipment('e-kompor');
      await repo.saveEquipment(e.copyWith(isActive: false), sari);
      expect((await repo.searchEquipment()).any((x) => x.id == 'e-kompor'), isFalse);
      expect((await repo.providerEquipment('p-arjuna')).any((x) => x.id == 'e-kompor'), isTrue);
    });

    test('provider cannot edit another store equipment', () async {
      final other = await repo.equipment('e-sepatu'); // milik Semeru
      await expectLater(repo.saveEquipment(other.copyWith(name: 'Hack'), sari),
          throwsA(isA<AppException>().having((e) => e.code, 'code', 'FORBIDDEN')));
    });

    test('uploaded photos and sizes survive restart', () async {
      final dir = Directory.systemTemp.createTempSync('rentgear');
      addTearDown(() => dir.deleteSync(recursive: true));
      var local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
      final owner = await local.login('dewi@rentgear.id', 'password');
      final saved = await local.saveEquipment(
        draft(
          category: 'sepatu',
          photos: [const AssetPhoto('assets/equipment/sepatu_1.jpg'), MemoryPhoto('up', Uint8List.fromList([4, 5]))],
          sizes: const [SizeStock('40', 1), SizeStock('41', 3)],
        ),
        owner,
      );
      local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
      final back = await local.equipment(saved.id);
      expect(back.sizes.map((s) => '${s.label}:${s.stock}'), ['40:1', '41:3']);
      expect(back.photos.first, isA<AssetPhoto>());
      expect((back.photos.last as MemoryPhoto).bytes, [4, 5]);
    });
  });
}
