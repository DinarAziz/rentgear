import 'dart:math';
import 'dart:typed_data';

/// Jenis dokumen yang boleh dijadikan jaminan sewa.
/// Dokumen asli diserahkan ke provider saat pengambilan alat
/// dan dikembalikan saat alat dikembalikan.
enum GuaranteeType {
  ktp('KTP', 'Kartu Tanda Penduduk', 16),
  sim('SIM', 'Surat Izin Mengemudi', null),
  ktm('KTM', 'Kartu Tanda Mahasiswa', null),
  kartuKeluarga('KK', 'Kartu Keluarga', 16),
  ijazah('Ijazah', 'Ijazah asli (SMA/D3/S1)', null),
  paspor('Paspor', 'Paspor', null),
  npwp('NPWP', 'Kartu NPWP', null),
  bpkb('BPKB', 'BPKB kendaraan', null);

  const GuaranteeType(this.label, this.fullName, this.exactDigits);

  final String label;
  final String fullName;

  /// Jumlah digit wajib bila nomornya berformat tetap (NIK/No. KK = 16 digit).
  final int? exactDigits;

  /// Dokumen yang sulit dan lama diurus ulang bila hilang.
  /// UI menampilkan peringatan untuk jenis ini.
  bool get isHardToReplace =>
      this == ijazah || this == paspor || this == kartuKeluarga || this == bpkb;
}

enum GuaranteeStatus {
  submitted('Diajukan'),
  verified('Terverifikasi'),
  rejected('Ditolak'),
  held('Dipegang provider'),
  returned('Sudah dikembalikan');

  const GuaranteeStatus(this.label);
  final String label;
}

class Guarantee {
  Guarantee({
    required this.id,
    required this.type,
    required this.holderName,
    required this.documentNumber,
    this.photo,
    this.status = GuaranteeStatus.submitted,
    this.note,
  });

  final String id;
  final GuaranteeType type;
  final String holderName;

  /// Pada backend nyata nomor disimpan terenkripsi dan API hanya
  /// mengembalikan versi tersamar ([maskedNumber]).
  final String documentNumber;
  final Uint8List? photo;
  GuaranteeStatus status;
  String? note;
  DateTime? heldAt;
  DateTime? returnedAt;

  String get maskedNumber => maskDocumentNumber(documentNumber);
}

String maskDocumentNumber(String number) {
  final clean = number.replaceAll(RegExp(r'\s'), '');
  if (clean.length <= 4) return '••••';
  return '${'•' * (clean.length - 4)}${clean.substring(clean.length - 4)}';
}

/// Isian form jaminan di layar booking, sebelum dikirim.
class GuaranteeDraft {
  GuaranteeDraft({this.type, this.holderName = '', this.documentNumber = ''});

  GuaranteeType? type;
  String holderName;
  String documentNumber;
  Uint8List? photo;
}

/// Aturan jaminan milik satu provider.
class GuaranteePolicy {
  const GuaranteePolicy({
    required this.acceptedTypes,
    this.baseRequired = 1,
    this.highValueThreshold = 1000000,
    this.highValueRequired = 2,
  });

  static const maxPerBooking = 3;

  final Set<GuaranteeType> acceptedTypes;

  /// Jumlah jaminan minimum untuk sewa biasa.
  final int baseRequired;

  /// Bila total sewa + deposit >= nilai ini, jaminan yang diminta naik.
  final double highValueThreshold;
  final int highValueRequired;

  int requiredCount(double rentalValue) => rentalValue >= highValueThreshold
      ? max(baseRequired, highValueRequired)
      : baseRequired;

  /// Mengembalikan daftar pesan kesalahan. Daftar kosong berarti valid.
  /// Aturan yang sama wajib dicek ulang di server.
  List<String> validate(
    List<GuaranteeDraft> drafts, {
    required double rentalValue,
    required String renterName,
  }) {
    final errors = <String>[];
    final required = requiredCount(rentalValue);
    if (drafts.length < required) {
      errors.add('Sewa ini membutuhkan minimal $required jaminan.');
    }
    if (drafts.length > maxPerBooking) {
      errors.add('Maksimal $maxPerBooking jaminan per sewa.');
    }

    final seen = <GuaranteeType>{};
    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      final n = 'Jaminan ${i + 1}';
      final type = d.type;
      if (type == null) {
        errors.add('$n: pilih jenis dokumen.');
        continue;
      }
      if (!acceptedTypes.contains(type)) {
        errors.add('$n: ${type.label} tidak diterima provider ini.');
      }
      if (!seen.add(type)) {
        errors.add('$n: ${type.label} sudah dipakai. Gunakan jenis lain.');
      }
      final number = d.documentNumber.replaceAll(RegExp(r'\s'), '');
      if (number.isEmpty) {
        errors.add('$n: nomor dokumen wajib diisi.');
      } else if (type.exactDigits != null &&
          !RegExp('^\\d{${type.exactDigits}}\$').hasMatch(number)) {
        errors.add('$n: nomor ${type.label} harus ${type.exactDigits} digit angka.');
      }
      if (_normalize(d.holderName) != _normalize(renterName)) {
        errors.add('$n: dokumen harus atas nama penyewa ($renterName).');
      }
      if (d.photo == null) {
        errors.add('$n: foto dokumen wajib diunggah.');
      }
    }
    return errors;
  }

  GuaranteePolicy copyWith({
    Set<GuaranteeType>? acceptedTypes,
    int? baseRequired,
    double? highValueThreshold,
    int? highValueRequired,
  }) =>
      GuaranteePolicy(
        acceptedTypes: acceptedTypes ?? this.acceptedTypes,
        baseRequired: baseRequired ?? this.baseRequired,
        highValueThreshold: highValueThreshold ?? this.highValueThreshold,
        highValueRequired: highValueRequired ?? this.highValueRequired,
      );

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
