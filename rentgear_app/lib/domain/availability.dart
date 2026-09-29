import 'dart:math';

/// ALG-2 Availability Sweep-Line.
///
/// Stok tersedia = stok total - okupansi PUNCAK pada rentang yang diminta,
/// bukan stok total - jumlah semua booking yang beririsan.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Nomor hari sejak epoch. Dipakai agar selisih hari tidak terganggu jam/DST.
int dayIndex(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Jumlah hari sewa, inklusif tanggal mulai dan selesai.
int inclusiveDays(DateTime start, DateTime end) =>
    dayIndex(end) - dayIndex(start) + 1;

class OccupancyRange {
  const OccupancyRange(this.start, this.end, this.qty);

  /// Tanggal mulai dan selesai, keduanya inklusif.
  final DateTime start;
  final DateTime end;
  final int qty;
}

int peakOccupancy(List<OccupancyRange> ranges, DateTime start, DateTime end) {
  final from = dayIndex(start);
  final to = dayIndex(end);
  final events = <int, int>{};

  for (final r in ranges) {
    final s = max(dayIndex(r.start), from);
    final e = min(dayIndex(r.end), to);
    if (s > e) continue; // tidak beririsan
    events[s] = (events[s] ?? 0) + r.qty;
    events[e + 1] = (events[e + 1] ?? 0) - r.qty;
  }

  var running = 0;
  var peak = 0;
  for (final day in events.keys.toList()..sort()) {
    running += events[day]!;
    peak = max(peak, running);
  }
  return peak;
}

int sweepAvailableQty({
  required int stockTotal,
  required List<OccupancyRange> ranges,
  required DateTime start,
  required DateTime end,
}) =>
    max(0, stockTotal - peakOccupancy(ranges, start, end));
