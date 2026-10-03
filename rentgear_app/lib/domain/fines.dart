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

/// Aturan denda sebuah toko. Penyedia mengaturnya dalam batas platform. Tiap
/// sewa menyimpan salinannya saat booking dibuat, jadi perubahan aturan tidak
/// mengenai sewa yang sudah dipesan.
class FinePolicy {
  const FinePolicy({
    this.lateMultiplier = lateFeeMultiplier,
    this.graceHours = 0,
    this.minorDamagePercent = 25,
    this.majorDamagePercent = 60,
    this.lostPercent = 100,
  });

  static const minLateMultiplier = 1.0;
  static const maxLateMultiplier = 2.0;
  static const maxGraceHours = 12;

  /// Denda terlambat = hari terlambat × tarif harian × jumlah unit × pengali ini.
  final double lateMultiplier;

  /// Terlambat sampai sekian jam setelah hari terakhir sewa belum dikenai denda.
  final int graceHours;

  /// Pedoman denda kerusakan, dalam persen dari deposit. Bukan batas: penyedia
  /// tetap mengisi nominalnya saat menerima alat.
  final int minorDamagePercent;
  final int majorDamagePercent;
  final int lostPercent;

  FinePolicy copyWith({
    double? lateMultiplier,
    int? graceHours,
    int? minorDamagePercent,
    int? majorDamagePercent,
    int? lostPercent,
  }) => FinePolicy(
    lateMultiplier: lateMultiplier ?? this.lateMultiplier,
    graceHours: graceHours ?? this.graceHours,
    minorDamagePercent: minorDamagePercent ?? this.minorDamagePercent,
    majorDamagePercent: majorDamagePercent ?? this.majorDamagePercent,
    lostPercent: lostPercent ?? this.lostPercent,
  );

  /// Pesan kesalahan, atau `null` bila aturan ini ada dalam batas platform.
  String? get error {
    if (lateMultiplier < minLateMultiplier ||
        lateMultiplier > maxLateMultiplier) {
      return 'Pengali denda terlambat harus antara 1 dan 2 kali tarif harian.';
    }
    if (graceHours < 0 || graceHours > maxGraceHours) {
      return 'Masa tenggang paling lama $maxGraceHours jam.';
    }
    final percents = [minorDamagePercent, majorDamagePercent, lostPercent];
    if (percents.any((p) => p < 0 || p > 100)) {
      return 'Pedoman denda kerusakan harus antara 0 dan 100 persen deposit.';
    }
    if (minorDamagePercent > majorDamagePercent ||
        majorDamagePercent > lostPercent) {
      return 'Pedoman denda harus naik: rusak ringan, rusak berat, lalu hilang.';
    }
    return null;
  }

  /// Hari terlambat per tanggal kalender, setelah dikurangi masa tenggang.
  int lateDays(DateTime endDate, DateTime returnedAt) => max(
    0,
    dayIndex(returnedAt.subtract(Duration(hours: graceHours))) -
        dayIndex(endDate),
  );

  double lateFee({
    required double pricePerDay,
    required int qty,
    required int days,
  }) => days * pricePerDay * qty * lateMultiplier;

  /// Nominal pedoman untuk sebuah kondisi. Alat berkondisi baik tidak dikenai denda.
  double guidelineFee(ReturnCondition condition, double deposit) {
    final percent = switch (condition) {
      ReturnCondition.good => 0,
      ReturnCondition.minorDamage => minorDamagePercent,
      ReturnCondition.majorDamage => majorDamagePercent,
      ReturnCondition.lost => lostPercent,
    };
    return (deposit * percent / 100).roundToDouble();
  }

  Map<String, dynamic> toJson() => {
    'lateMultiplier': lateMultiplier,
    'graceHours': graceHours,
    'minorDamagePercent': minorDamagePercent,
    'majorDamagePercent': majorDamagePercent,
    'lostPercent': lostPercent,
  };

  /// Data lama dan toko yang belum mengatur apa pun memakai nilai bawaan.
  factory FinePolicy.fromJson(Map<String, dynamic>? j) {
    const d = FinePolicy();
    return FinePolicy(
      lateMultiplier:
          (j?['lateMultiplier'] as num?)?.toDouble() ?? d.lateMultiplier,
      graceHours: (j?['graceHours'] as num?)?.toInt() ?? d.graceHours,
      minorDamagePercent:
          (j?['minorDamagePercent'] as num?)?.toInt() ?? d.minorDamagePercent,
      majorDamagePercent:
          (j?['majorDamagePercent'] as num?)?.toInt() ?? d.majorDamagePercent,
      lostPercent: (j?['lostPercent'] as num?)?.toInt() ?? d.lostPercent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FinePolicy &&
      other.lateMultiplier == lateMultiplier &&
      other.graceHours == graceHours &&
      other.minorDamagePercent == minorDamagePercent &&
      other.majorDamagePercent == majorDamagePercent &&
      other.lostPercent == lostPercent;

  @override
  int get hashCode => Object.hash(
    lateMultiplier,
    graceHours,
    minorDamagePercent,
    majorDamagePercent,
    lostPercent,
  );
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
