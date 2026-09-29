import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/domain/availability.dart';
import 'package:rentgear/domain/guarantee.dart';

void main() {
  group('ALG-2 availability sweep-line', () {
    final d = DateTime(2026, 10, 1);
    DateTime day(int n) => d.add(Duration(days: n));

    test('peak, not sum, of overlapping bookings', () {
      // A: hari 0-1 (2 unit), B: hari 2-3 (2 unit). Tidak pernah bersamaan.
      final ranges = [
        OccupancyRange(day(0), day(1), 2),
        OccupancyRange(day(2), day(3), 2),
      ];
      expect(peakOccupancy(ranges, day(0), day(3)), 2);
      expect(sweepAvailableQty(stockTotal: 3, ranges: ranges, start: day(0), end: day(3)), 1);
    });

    test('overlapping bookings stack', () {
      final ranges = [
        OccupancyRange(day(0), day(2), 1),
        OccupancyRange(day(2), day(4), 2),
      ];
      expect(peakOccupancy(ranges, day(0), day(4)), 3);
      expect(sweepAvailableQty(stockTotal: 3, ranges: ranges, start: day(2), end: day(2)), 0);
      expect(sweepAvailableQty(stockTotal: 3, ranges: ranges, start: day(3), end: day(4)), 1);
    });

    test('bookings outside the window are ignored', () {
      final ranges = [OccupancyRange(day(10), day(12), 5)];
      expect(sweepAvailableQty(stockTotal: 2, ranges: ranges, start: day(0), end: day(5)), 2);
    });

    test('inclusiveDays counts both ends', () {
      expect(inclusiveDays(day(0), day(0)), 1);
      expect(inclusiveDays(day(0), day(2)), 3);
    });
  });

  group('GuaranteePolicy', () {
    const policy = GuaranteePolicy(
      acceptedTypes: {GuaranteeType.ktp, GuaranteeType.ktm, GuaranteeType.ijazah},
      highValueThreshold: 1000000,
      highValueRequired: 2,
    );
    final photo = Uint8List.fromList([1, 2, 3]);

    GuaranteeDraft draft(GuaranteeType type, String number, {String name = 'Budi Santoso'}) =>
        GuaranteeDraft(type: type, holderName: name, documentNumber: number)..photo = photo;

    test('required count rises for high-value rentals', () {
      expect(policy.requiredCount(500000), 1);
      expect(policy.requiredCount(1000000), 2);
    });

    test('valid single KTP passes', () {
      final errors = policy.validate(
        [draft(GuaranteeType.ktp, '3573011204020001')],
        rentalValue: 200000,
        renterName: 'budi  santoso',
      );
      expect(errors, isEmpty);
    });

    test('high-value rental needs two documents', () {
      final errors = policy.validate(
        [draft(GuaranteeType.ktp, '3573011204020001')],
        rentalValue: 1500000,
        renterName: 'Budi Santoso',
      );
      expect(errors, contains(contains('minimal 2')));
    });

    test('rejects unaccepted type, duplicate, bad NIK, other name, missing photo', () {
      final noPhoto = GuaranteeDraft(
          type: GuaranteeType.ijazah, holderName: 'Budi Santoso', documentNumber: 'DN-01');
      final errors = policy.validate(
        [
          draft(GuaranteeType.sim, '123'),
          draft(GuaranteeType.ktp, '12345'),
          draft(GuaranteeType.ktp, '3573011204020001', name: 'Orang Lain'),
          noPhoto,
        ],
        rentalValue: 100000,
        renterName: 'Budi Santoso',
      );
      expect(errors.join('\n'), allOf(
        contains('Maksimal 3'),
        contains('SIM tidak diterima'),
        contains('16 digit'),
        contains('sudah dipakai'),
        contains('atas nama penyewa'),
        contains('foto dokumen wajib'),
      ));
    });

    test('masks all but last 4 digits', () {
      expect(maskDocumentNumber('3573011204020001'), '••••••••••••0001');
    });
  });
}
