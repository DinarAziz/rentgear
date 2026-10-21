import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/gear_status.dart';
import 'package:rentgear/domain/models.dart';

final today = DateTime(2026, 10, 21);

const tent = Equipment(
  id: 'e-tenda',
  providerId: 'p-1',
  categoryId: 'tenda',
  name: 'Tenda',
  brand: 'Eiger',
  description: '-',
  pricePerDay: 45000,
  depositAmount: 100000,
  weightGram: 3200,
  stock: 5,
);

Rental rental(String id, RentalStatus status, {int qty = 1, int start = 0, int end = 1, String equipmentId = 'e-tenda'}) =>
    Rental(
      id: id,
      invoiceCode: 'INV-$id',
      customerId: 'u-1',
      customerName: 'Budi',
      providerId: 'p-1',
      providerName: 'Toko',
      equipmentId: equipmentId,
      equipmentName: 'Tenda',
      categoryId: 'tenda',
      qty: qty,
      startDate: today.add(Duration(days: start)),
      endDate: today.add(Duration(days: end)),
      pricePerDaySnapshot: 45000,
      depositSnapshot: 100000,
      status: status,
      guarantees: const [],
      createdAt: today,
    );

void main() {
  test('unit yang sudah diambil dihitung disewa, booking hari ini dihitung dipesan', () {
    final s = GearStatus.of(tent, [
      rental('a', RentalStatus.pickedUp, qty: 2, start: -2, end: 0),
      // Terlambat kembali: alat masih di tangan penyewa walau tanggalnya lewat.
      rental('b', RentalStatus.overdue, start: -5, end: -1),
      rental('c', RentalStatus.paid, start: 0, end: 2),
      // Booking minggu depan belum memakai stok hari ini.
      rental('d', RentalStatus.paid, qty: 3, start: 7, end: 8),
      rental('e', RentalStatus.completed, start: -10, end: -9),
      rental('f', RentalStatus.pickedUp, equipmentId: 'e-lain'),
    ], today);

    expect(s.rented, 3);
    expect(s.booked, 1);
    expect(s.available, 1);
    expect(s.total, 5);
  });

  test('tersedia tidak pernah negatif', () {
    final s = GearStatus.of(tent, [rental('a', RentalStatus.pickedUp, qty: 6)], today);
    expect(s.available, 0);
  });

  test('riwayat kerusakan berisi pengembalian rusak atau hilang, terbaru lebih dulu', () {
    final older = rental('a', RentalStatus.completed, start: -20, end: -19)
      ..returnedAt = today.subtract(const Duration(days: 19))
      ..returnCondition = ReturnCondition.minorDamage
      ..damageNote = 'Pasak bengkok';
    final good = rental('b', RentalStatus.completed, start: -10, end: -9)
      ..returnedAt = today.subtract(const Duration(days: 9))
      ..returnCondition = ReturnCondition.good;
    final newer = rental('c', RentalStatus.returned, start: -3, end: -2)
      ..returnedAt = today.subtract(const Duration(days: 2))
      ..returnCondition = ReturnCondition.majorDamage;

    expect(GearStatus.damageHistory(tent, [older, good, newer]).map((r) => r.id), ['c', 'a']);
    expect(GearStatus.of(tent, [older, good, newer], today).lastDamage?.id, 'c');
  });
}
