import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/domain/models.dart';
import 'package:rentgear/domain/report.dart';
import 'package:rentgear/features/admin/admin_report_screen.dart';
import 'package:pdf/pdf.dart';

Matcher throwsCode(String code) => throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  group('kode serah terima', () {
    test('kode salah ditolak, dan kode berganti setelah alat diambil', () async {
      final repo = LocalRentGearRepository.open(latency: Duration.zero);
      final sari = await repo.login('sari@rentgear.id', 'password');
      final old = (await repo.rental('r-3')).handoverCode!;
      expect(old, matches(RegExp(r'^\d{6}$')));

      await expectLater(repo.handover('r-3', sari, code: '000000x'), throwsCode('HANDOVER_CODE_INVALID'));
      final r = await repo.handover('r-3', sari, code: old);
      expect(r.status, RentalStatus.pickedUp);
      expect(r.handoverCode, isNot(old));
      await expectLater(repo.receiveReturn('r-3', sari, code: old), throwsCode('HANDOVER_CODE_INVALID'));
      expect((await repo.receiveReturn('r-3', sari, code: r.handoverCode!)).status, RentalStatus.returned);
    });

    test('isi QR hanya berlaku untuk sewanya sendiri', () async {
      final repo = LocalRentGearRepository.open(latency: Duration.zero);
      final r = await repo.rental('r-3');
      final payload = handoverQrPayload(r);
      expect(codeFromHandoverQr(payload, 'r-3'), r.handoverCode);
      expect(codeFromHandoverQr(payload, 'r-4'), isNull);
      expect(codeFromHandoverQr('https://contoh.id', 'r-3'), isNull);
    });
  });

  test('favorit: penyewa menyimpan dan menghapus, toko ditolak', () async {
    final repo = LocalRentGearRepository.open(latency: Duration.zero);
    final budi = await repo.login('budi@rentgear.id', 'password');
    final sari = await repo.login('sari@rentgear.id', 'password');

    expect(await repo.setWishlist('e-kompor', budi, saved: true), ['e-kompor']);
    expect(await repo.setWishlist('e-kompor', budi, saved: true), ['e-kompor']);
    expect(await repo.wishlist(budi.id), ['e-kompor']);
    expect(await repo.setWishlist('e-kompor', budi, saved: false), isEmpty);
    await expectLater(repo.setWishlist('e-kompor', sari, saved: true), throwsCode('FORBIDDEN'));
  });

  test('laporan menghitung sewa yang dibayar saja dan tidak memasukkan deposit', () async {
    final repo = LocalRentGearRepository.open(latency: Duration.zero);
    final rentals = await repo.allRentals();
    final report = RentalReport(rentals);

    final paid = rentals.where((r) => paidStatuses.contains(r.status));
    expect(report.total, rentals.length);
    expect(report.paid, paid.length);
    expect(report.rentRevenue, paid.fold<double>(0, (sum, r) => sum + r.subtotal));
    expect(report.topGear.map((g) => g.count).fold<int>(0, (a, b) => a + b), paid.fold<int>(0, (a, r) => a + r.qty));
    expect(RentalReport(rentals, month: DateTime(1999)).total, 0);

    final pdf = await reportPdf(report, PdfPageFormat.a4);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });
}
