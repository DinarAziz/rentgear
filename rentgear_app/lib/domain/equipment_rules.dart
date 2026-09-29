import 'models.dart';

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
