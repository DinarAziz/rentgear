import 'dart:math';

import 'availability.dart';

/// Denda keterlambatan = hari terlambat × tarif harian × jumlah unit × pengali ini
/// (docs/03 bagian 2).
const lateFeeMultiplier = 1.5;

/// Denda kerusakan di atas porsi deposit ini ditinjau admin sebelum transaksi ditutup.
const damageReviewShare = 0.5;

/// Jumlah pelanggaran baru yang membuat penyewa masuk blacklist otomatis.
const autoBlacklistAfter = 3;

/// Kondisi alat saat diterima kembali oleh penyedia.
enum ReturnCondition {
  good('Baik'),
  minorDamage('Rusak ringan'),
  majorDamage('Rusak berat'),
  lost('Hilang');

  const ReturnCondition(this.label);
  final String label;
}

/// Status tinjauan admin atas denda kerusakan.
enum DamageReview {
  none('Berlaku'),
  pending('Ditinjau admin'),
  decided('Diputuskan admin');

  const DamageReview(this.label);
  final String label;
}

/// Hari terlambat dihitung per tanggal kalender, bukan per 24 jam.
int lateDays(DateTime endDate, DateTime returnedAt) =>
    max(0, dayIndex(returnedAt) - dayIndex(endDate));

double lateFeeFor({
  required double pricePerDay,
  required int qty,
  required int days,
}) => days * pricePerDay * qty * lateFeeMultiplier;

/// Pesan kesalahan, atau `null` bila denda kerusakan sah untuk kondisi tersebut.
String? damageFeeError(ReturnCondition condition, double fee, double deposit) {
  if (fee < 0) return 'Denda kerusakan tidak boleh negatif.';
  if (condition == ReturnCondition.good) {
    return fee > 0
        ? 'Alat berkondisi baik tidak dikenai denda kerusakan.'
        : null;
  }
  if (fee <= 0) return 'Isi nominal denda kerusakan.';
  if (fee > deposit) return 'Denda kerusakan tidak boleh melebihi deposit.';
  return null;
}

bool needsAdminReview(double fee, double deposit) =>
    fee > deposit * damageReviewShare;

/// [baseline] = jumlah pelanggaran saat admin terakhir mencabut blacklist, supaya
/// penyewa tidak langsung masuk blacklist lagi karena pelanggaran lama.
bool shouldAutoBlacklist({required int violations, required int baseline}) =>
    violations - baseline >= autoBlacklistAfter;
