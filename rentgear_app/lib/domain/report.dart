import 'models.dart';

/// Status setelah pembayaran diterima toko. Sewa yang dananya dikembalikan tidak dihitung.
const paidStatuses = {
  RentalStatus.paid,
  RentalStatus.pickedUp,
  RentalStatus.overdue,
  RentalStatus.returned,
  RentalStatus.completed,
  RentalStatus.disputed,
};

const failedStatuses = {
  RentalStatus.rejected,
  RentalStatus.cancelled,
  RentalStatus.expired,
  RentalStatus.noShow,
};

class ReportRow {
  ReportRow(this.name);
  final String name;
  int count = 0;
  double revenue = 0;
}

/// Rekap transaksi untuk admin. Pendapatan = biaya sewa setelah diskon ditambah denda;
/// deposit tidak dihitung karena dikembalikan ke penyewa.
class RentalReport {
  RentalReport(List<Rental> all, {this.month}) {
    final rentals = [
      for (final r in all)
        if (month == null || (r.startDate.year == month!.year && r.startDate.month == month!.month)) r,
    ];
    final gear = <String, ReportRow>{};
    final stores = <String, ReportRow>{};
    for (final r in rentals) {
      total++;
      if (r.status == RentalStatus.completed) completed++;
      if (failedStatuses.contains(r.status)) failed++;
      if (!paidStatuses.contains(r.status)) continue;
      paid++;
      final income = r.subtotal + r.fineTotal;
      rentRevenue += r.subtotal;
      fineRevenue += r.fineTotal;
      if (r.lateFee > 0) late++;
      for (final row in [
        gear.putIfAbsent(r.equipmentId, () => ReportRow(r.equipmentName)),
        stores.putIfAbsent(r.providerId, () => ReportRow(r.providerName)),
      ]) {
        row
          ..count += r.qty
          ..revenue += income;
      }
    }
    int byCount(ReportRow a, ReportRow b) => b.count != a.count ? b.count - a.count : b.revenue.compareTo(a.revenue);
    topGear = gear.values.toList()..sort(byCount);
    byStore = stores.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
  }

  /// Bulan yang direkap (hari diabaikan); `null` berarti semua waktu.
  final DateTime? month;
  int total = 0;
  int paid = 0;
  int completed = 0;
  int failed = 0;
  int late = 0;
  double rentRevenue = 0;
  double fineRevenue = 0;
  double get revenue => rentRevenue + fineRevenue;
  late final List<ReportRow> topGear;
  late final List<ReportRow> byStore;

  /// Bulan yang punya transaksi, terbaru lebih dulu, untuk pilihan periode.
  static List<DateTime> months(List<Rental> rentals) =>
      {for (final r in rentals) DateTime(r.startDate.year, r.startDate.month)}.toList()
        ..sort((a, b) => b.compareTo(a));
}
