import 'dart:typed_data';

import '../domain/fines.dart';
import '../domain/guarantee.dart';
import '../domain/models.dart';

/// Kontrak data aplikasi. Implementasi saat ini: [LocalRentGearRepository]
/// (data tersimpan di HP). Nanti bisa diganti implementasi HTTP ke Laravel
/// `/api/v1` tanpa mengubah layar.
abstract class RentGearRepository {
  Future<AppUser> login(String email, String password);

  /// Pengguna yang masih login dari sesi sebelumnya, atau `null`.
  Future<AppUser?> restoreSession();
  Future<void> logout();

  /// Menjalankan perubahan status otomatis (kedaluwarsa, terlambat, dll.).
  /// Mengembalikan jumlah transaksi yang berubah. Versi server: no-op.
  Future<int> runScheduledJobs();

  Future<List<Category>> categories();
  Future<List<Equipment>> searchEquipment({String query = '', String? categoryId});
  Future<List<Equipment>> providerEquipment(String providerId);
  Future<Equipment> equipment(String id);
  Future<ProviderProfile> provider(String id);
  Future<List<ProviderProfile>> providers();
  /// Jumlah unit yang masih bisa disewa pada rentang tanggal (ALG-2).
  /// Untuk alat berukuran, isi [size]; tanpa [size] = total semua ukuran.
  Future<int> availableQty(String equipmentId, DateTime start, DateTime end, {String? size});

  /// Ketersediaan tiap ukuran, mis. `{'41': 2, '42': 0}`.
  Future<Map<String, int>> sizeAvailability(String equipmentId, DateTime start, DateTime end);

  /// Tambah alat baru (`id` kosong) atau simpan perubahan alat milik penyedia.
  Future<Equipment> saveEquipment(Equipment draft, AppUser actor);

  Future<Rental> createBooking(BookingRequest request);
  Future<Rental> rental(String id);
  Future<List<Rental>> customerRentals(String customerId);
  Future<List<Rental>> providerRentals(String providerId);
  Future<List<Rental>> allRentals();

  Future<Rental> reviewGuarantee(
    String rentalId,
    String guaranteeId,
    AppUser actor, {
    required bool accept,
    String? note,
  });
  Future<Rental> confirmBooking(String rentalId, AppUser actor);
  Future<Rental> rejectBooking(String rentalId, AppUser actor, String reason);
  Future<Rental> cancelBooking(String rentalId, AppUser actor, String reason);
  Future<Rental> submitPayment(String rentalId, AppUser actor, Uint8List proof);

  /// Provider menerima dokumen asli jaminan lalu menyerahkan alat.
  Future<Rental> handover(String rentalId, AppUser actor);

  /// Penyedia menerima alat kembali. Denda keterlambatan dihitung otomatis;
  /// denda kerusakan diisi penyedia dan ditinjau admin bila nominalnya besar.
  Future<Rental> receiveReturn(
    String rentalId,
    AppUser actor, {
    ReturnCondition condition = ReturnCondition.good,
    double damageFee = 0,
    String? damageNote,
  });

  /// Penyewa meminta admin meninjau denda kerusakan.
  Future<Rental> objectToDamageFee(String rentalId, AppUser actor, String reason);

  /// Admin menetapkan nominal akhir denda kerusakan (0 = denda dibatalkan).
  Future<Rental> decideDamageFee(String rentalId, AppUser actor,
      {required double amount, String? note});

  /// Provider mengembalikan dokumen asli jaminan dan menutup transaksi.
  Future<Rental> returnGuaranteesAndComplete(String rentalId, AppUser actor);

  Future<ProviderProfile> updateGuaranteePolicy(
      String providerId, GuaranteePolicy policy, AppUser actor);
  Future<ProviderProfile> setProviderStatus(
      String providerId, ProviderStatus status, AppUser actor);

  /// Riwayat semua penyewa, untuk admin.
  Future<List<CustomerRecord>> customers(AppUser actor);

  /// Data blacklist seorang penyewa, atau `null` bila tidak di-blacklist.
  Future<BlacklistEntry?> blacklistOf(String userId);

  /// Admin memasukkan penyewa ke blacklist ([reason] wajib) atau mencabutnya.
  Future<void> setBlacklist(String customerId, AppUser actor,
      {required bool blocked, String? reason});
}
