import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/core/maps.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  late LocalRentGearRepository repo;
  late AppUser budi;
  late AppUser rina;
  late AppUser sari; // pemilik Arjuna Outdoor

  setUp(() async {
    repo = LocalRentGearRepository.open(latency: Duration.zero);
    budi = await repo.login('budi@rentgear.id', 'password');
    rina = await repo.login('rina@rentgear.id', 'password');
    sari = await repo.login('sari@rentgear.id', 'password');
  });

  test('rating toko adalah rata-rata ulasannya', () async {
    final reviews = await repo.providerReviews('p-arjuna');
    final arjuna = await repo.provider('p-arjuna');
    expect(reviews, isNotEmpty);
    expect(arjuna.reviewCount, reviews.length);
    final average =
        reviews.fold(0, (sum, r) => sum + r.rating) / reviews.length;
    expect(arjuna.rating, closeTo(average, 0.001));
    // Ulasan terbaru tampil lebih dulu.
    expect(reviews.first.at.isBefore(reviews.last.at), isFalse);

    final puncak = await repo.provider('p-puncak');
    expect(puncak.reviewCount, 0);
    expect(puncak.rating, 0);
  });

  test(
    'ulasan hanya dari penyewa transaksi yang sudah selesai, satu kali',
    () async {
      final before = await repo.provider('p-arjuna');
      final count = before.reviewCount;
      final total = before.rating * count;

      // r-1 belum selesai, r-5 (Budi, Arjuna) sudah selesai.
      await expectLater(
        repo.submitReview('r-1', budi, rating: 5),
        throwsCode('INVALID_STATE'),
      );
      await expectLater(
        repo.submitReview('r-5', rina, rating: 5),
        throwsCode('FORBIDDEN'),
      );
      await expectLater(
        repo.submitReview('r-5', sari, rating: 5),
        throwsCode('FORBIDDEN'),
      );
      await expectLater(
        repo.submitReview('r-5', budi, rating: 0),
        throwsCode('VALIDATION'),
      );
      await expectLater(
        repo.submitReview('r-5', budi, rating: 6),
        throwsCode('VALIDATION'),
      );

      final r = await repo.submitReview(
        'r-5',
        budi,
        rating: 2,
        comment: '  Sleeping bag lembap  ',
      );
      expect(r.review?.rating, 2);
      expect(r.review?.comment, 'Sleeping bag lembap');
      expect(r.review?.customerName, budi.name);

      final after = await repo.provider('p-arjuna');
      expect(after.reviewCount, count + 1);
      expect(after.rating, closeTo((total + 2) / (count + 1), 0.001));
      expect(
        (await repo.providerReviews('p-arjuna')).first.comment,
        'Sleeping bag lembap',
      );

      await expectLater(
        repo.submitReview('r-5', budi, rating: 5),
        throwsCode('ALREADY_REVIEWED'),
      );
    },
  );

  test('follow dan unfollow mengubah jumlah pengikut', () async {
    final before = (await repo.provider('p-semeru')).followerCount;
    expect(await repo.followedProviders(budi.id), isNot(contains('p-semeru')));

    var p = await repo.setFollow('p-semeru', budi, follow: true);
    expect(p.followerCount, before + 1);
    expect(await repo.followedProviders(budi.id), contains('p-semeru'));

    // Mengikuti dua kali tidak menambah hitungan.
    p = await repo.setFollow('p-semeru', budi, follow: true);
    expect(p.followerCount, before + 1);

    p = await repo.setFollow('p-semeru', budi, follow: false);
    expect(p.followerCount, before);

    await expectLater(
      repo.setFollow('p-semeru', sari, follow: true),
      throwsCode('FORBIDDEN'),
    );
    await expectLater(
      repo.setFollow('p-tidak-ada', budi, follow: true),
      throwsCode('NOT_FOUND'),
    );
  });

  test('ulasan dan follow tersimpan setelah aplikasi ditutup', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_store');
    addTearDown(() => dir.delete(recursive: true));
    var local = LocalRentGearRepository.open(
      store: LocalStore(dir),
      latency: Duration.zero,
    );
    await local.submitReview('r-5', budi, rating: 4, comment: 'Mantap');
    await local.setFollow('p-semeru', budi, follow: true);
    final saved = await local.provider('p-arjuna');

    local = LocalRentGearRepository.open(
      store: LocalStore(dir),
      latency: Duration.zero,
    );
    expect((await local.rental('r-5')).review?.comment, 'Mantap');
    expect(await local.followedProviders(budi.id), contains('p-semeru'));
    final loaded = await local.provider('p-arjuna');
    expect(loaded.reviewCount, saved.reviewCount);
    expect(loaded.rating, closeTo(saved.rating, 0.001));
  });

  test('hanya pemilik toko yang bisa membalas ulasan, dan balasan tersimpan', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_reply');
    addTearDown(() => dir.delete(recursive: true));
    var local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final dewi = await local.login('dewi@rentgear.id', 'password'); // pemilik Semeru Camp Rent

    // rv-1 adalah ulasan bawaan untuk Arjuna Outdoor (toko Sari).
    expect(() => local.replyToReview('rv-1', budi, 'Halo'), throwsCode('FORBIDDEN'));
    expect(() => local.replyToReview('rv-1', dewi, 'Halo'), throwsCode('FORBIDDEN'));
    expect(() => local.replyToReview('rv-1', sari, '   '), throwsCode('VALIDATION'));
    expect(() => local.replyToReview('rv-x', sari, 'Halo'), throwsCode('NOT_FOUND'));

    await local.replyToReview('rv-1', sari, '  Terima kasih, Kak.  ');
    final replied = await local.replyToReview('rv-1', sari, 'Terima kasih sudah menyewa.');
    expect(replied.reply, 'Terima kasih sudah menyewa.');
    expect(replied.repliedAt, isNotNull);

    // Ulasan penyewa juga bisa dibalas, dan balasannya ikut ke detail transaksi.
    await local.submitReview('r-5', budi, rating: 4, comment: 'Mantap');
    await local.replyToReview('rv-r-5', sari, 'Sampai jumpa lagi.');

    local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    final reviews = await local.providerReviews('p-arjuna');
    expect(reviews.firstWhere((r) => r.id == 'rv-1').reply, 'Terima kasih sudah menyewa.');
    expect((await local.rental('r-5')).review?.reply, 'Sampai jumpa lagi.');
    expect(reviews.where((r) => r.reply != null), hasLength(2));
  });

  test('tiap toko punya koordinat untuk dibuka di Google Maps', () async {
    for (final p in await repo.providers()) {
      expect(p.latitude, inInclusiveRange(-11, 6), reason: p.businessName);
      expect(p.longitude, inInclusiveRange(95, 141), reason: p.businessName);
    }
    expect(
      googleMapsUri(-7.9396, 112.6289).toString(),
      'https://www.google.com/maps/search/?api=1&query=-7.9396%2C112.6289',
    );
  });
}
