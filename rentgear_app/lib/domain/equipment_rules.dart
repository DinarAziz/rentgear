import 'availability.dart';
import 'models.dart';
import 'rental_state_machine.dart';

const maxEquipmentPhotos = 8;

/// Kategori yang wajib memakai pilihan ukuran.
const sizedCategories = {'sepatu'};

/// Validasi data alat sebelum disimpan. Daftar kosong berarti valid.
/// Dipakai form penyedia dan dicek ulang di repository.
List<String> validateEquipment(Equipment e) {
  final errors = <String>[];
  if (e.name.trim().length < 3) errors.add('Nama alat minimal 3 huruf.');
  if (e.pricePerDay <= 0) errors.add('Harga sewa per hari harus lebih dari 0.');
  if (e.depositAmount < 0) errors.add('Deposit tidak boleh negatif.');
  if (e.weightGram < 0) errors.add('Berat tidak boleh negatif.');
  if (e.photos.isEmpty) errors.add('Tambahkan minimal 1 foto alat.');
  if (e.photos.length > maxEquipmentPhotos) {
    errors.add('Maksimal $maxEquipmentPhotos foto per alat.');
  }

  if (sizedCategories.contains(e.categoryId) && !e.hasSizes) {
    errors.add('Tambahkan minimal satu ukuran beserta stoknya.');
  }
  if (e.hasSizes) {
    final labels = <String>{};
    for (final s in e.sizes) {
      if (s.label.trim().isEmpty) {
        errors.add('Label ukuran tidak boleh kosong.');
      } else if (!labels.add(s.label.trim())) {
        errors.add('Ukuran ${s.label} tercantum dua kali.');
      }
      if (s.stock < 0) errors.add('Stok ukuran ${s.label} tidak boleh negatif.');
    }
  }
  if (e.stockTotal < 1) errors.add('Stok total minimal 1 unit.');
  return errors;
}

/// Urutkan ukuran: angka dari kecil ke besar, lalu teks (S, M, L) sesuai input.
List<SizeStock> sortSizes(List<SizeStock> sizes) {
  final list = [...sizes];
  list.sort((a, b) {
    final x = num.tryParse(a.label);
    final y = num.tryParse(b.label);
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1;
    if (y != null) return 1;
    return 0;
  });
  return list;
}

/// Stok baru tidak boleh lebih kecil dari unit yang sudah dipesan atau sedang
/// disewa mulai [today]. Tanpa aturan ini, toko bisa menurunkan stok sampai
/// booking yang sudah dibayar kehilangan unitnya. Pesannya sama dengan server.
String? stockReductionError(Equipment draft, Iterable<Rental> rentals, DateTime today) {
  final from = dateOnly(today);
  final bySize = <String?, List<OccupancyRange>>{};
  for (final r in rentals) {
    if (r.equipmentId != draft.id || !RentalStateMachine.lockingStatuses.contains(r.status)) continue;
    // Alat yang terlambat kembali masih dipakai sampai hari ini.
    final end = r.endDate.isBefore(from) ? from : r.endDate;
    bySize.putIfAbsent(r.size, () => []).add(OccupancyRange(r.startDate, end, r.qty));
  }
  for (final MapEntry(key: size, value: ranges) in bySize.entries) {
    final last = ranges.map((r) => r.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final booked = peakOccupancy(ranges, from, last);
    if (draft.stockFor(size) < booked) {
      final which = size == null ? 'Stok' : 'Stok ukuran $size';
      return '$which tidak bisa kurang dari $booked unit karena sudah dipesan sampai ${_day(last)}. '
          'Kurangi stok setelah sewa itu selesai.';
    }
  }
  return null;
}

/// Sama dengan format `d/m/Y` di server.
String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
