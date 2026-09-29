import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String rupiah(num value) => _rupiah.format(value);

final _ribuan = NumberFormat.decimalPattern('id_ID');

/// Angka dengan titik ribuan tanpa "Rp": 35000 → "35.000".
String ribuan(num value) => _ribuan.format(value.round());

/// Kebalikan [ribuan]: "35.000" → 35000. Null bila tidak ada angka.
double? parseRibuan(String text) => double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

/// Kolom nominal: hanya angka, tampil dengan titik ribuan saat diketik.
class RibuanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = ribuan(int.parse(digits));
    // Pertahankan posisi kursor relatif terhadap jumlah digit di kanannya.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsAfter = newValue.text.substring(cursor).replaceAll(RegExp(r'[^0-9]'), '').length;
    var offset = formatted.length;
    for (var seen = 0; offset > 0 && seen < digitsAfter; offset--) {
      if (formatted[offset - 1] != '.') seen++;
    }
    // Jangan berhenti tepat setelah titik: backspace di sana hanya akan
    // menghapus titik yang langsung muncul lagi, sehingga kursor terasa macet.
    while (offset > 0 && formatted[offset - 1] == '.') {
      offset--;
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: offset));
  }
}

String tanggal(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

String tanggalJam(DateTime d) => DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d);

/// Rentang ringkas: "27–28 Sep 2026", "30 Sep – 2 Okt 2026",
/// atau lengkap bila beda tahun.
String rentangTanggal(DateTime start, DateTime end) {
  if (start.year != end.year) return '${tanggal(start)} – ${tanggal(end)}';
  if (start.month != end.month) {
    return '${DateFormat('d MMM', 'id_ID').format(start)} – ${tanggal(end)}';
  }
  if (start.day == end.day) return tanggal(start);
  return '${start.day}–${tanggal(end)}';
}
