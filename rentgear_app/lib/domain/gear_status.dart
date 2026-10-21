import 'dart:math';

import 'availability.dart';
import 'fines.dart';
import 'models.dart';

/// Status satu alat pada satu hari, dihitung dari transaksinya:
/// - disewa: unit yang sedang di tangan penyewa (sudah diambil, termasuk yang terlambat kembali);
/// - dipesan: unit dari booking yang mencakup hari itu tetapi belum diambil;
/// - tersedia: sisanya.
class GearStatus {
  const GearStatus({required this.equipment, required this.rented, required this.booked, this.lastDamage});

  /// Hitung status [equipment] pada [day] dari semua [rentals] (boleh berisi alat lain).
  factory GearStatus.of(Equipment equipment, Iterable<Rental> rentals, DateTime day) {
    final own = rentals.where((r) => r.equipmentId == equipment.id).toList();
    final today = dayIndex(day);
    var rented = 0;
    var booked = 0;
    for (final r in own) {
      if (r.status == RentalStatus.pickedUp || r.status == RentalStatus.overdue) {
        rented += r.qty;
      } else if (beforePickupStatuses.contains(r.status) &&
          dayIndex(r.startDate) <= today &&
          today <= dayIndex(r.endDate)) {
        booked += r.qty;
      }
    }
    final damaged = damageHistory(equipment, own);
    return GearStatus(equipment: equipment, rented: rented, booked: booked, lastDamage: damaged.firstOrNull);
  }

  final Equipment equipment;
  final int rented;
  final int booked;

  /// Pengembalian terakhir yang tidak dalam kondisi baik, untuk diperiksa toko.
  final Rental? lastDamage;

  int get total => equipment.stockTotal;
  int get available => max(0, total - rented - booked);

  /// Pengembalian alat ini yang rusak atau hilang, terbaru lebih dulu.
  /// Dipakai sebagai catatan kerusakan per alat.
  static List<Rental> damageHistory(Equipment equipment, Iterable<Rental> rentals) => [
        for (final r in rentals)
          if (r.equipmentId == equipment.id &&
              r.returnCondition != null &&
              r.returnCondition != ReturnCondition.good)
            r,
      ]..sort((a, b) => b.returnedAt!.compareTo(a.returnedAt!));
}
