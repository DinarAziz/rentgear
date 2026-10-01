import 'dart:math';
import 'dart:typed_data';

import 'availability.dart';
import 'fines.dart';
import 'guarantee.dart';

enum UserRole {
  customer('Penyewa'),
  provider('Penyedia'),
  admin('Admin');

  const UserRole(this.label);
  final String label;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.city,
    this.providerId,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String city;

  /// Terisi hanya untuk role provider.
  final String? providerId;
}

enum ProviderStatus {
  pending('Menunggu verifikasi'),
  verified('Terverifikasi'),
  rejected('Ditolak');

  const ProviderStatus(this.label);
  final String label;
}

class ProviderProfile {
  ProviderProfile({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.city,
    required this.address,
    required this.status,
    required this.rating,
    required this.policy,
    this.bankAccount,
  });

  final String id;
  final String ownerId;
  final String businessName;
  final String city;
  final String address;
  ProviderStatus status;
  final double rating;
  GuaranteePolicy policy;

  /// Rekening tujuan transfer, mis. "BCA 1234567890 a.n. Arjuna Outdoor".
  final String? bankAccount;
}

class Category {
  const Category(this.id, this.name);
  final String id;
  final String name;
}

/// Foto alat: bawaan aplikasi (asset) atau diunggah penyedia (bytes).
sealed class ItemPhoto {
  const ItemPhoto();
}

class AssetPhoto extends ItemPhoto {
  const AssetPhoto(this.path);
  final String path;
}

class MemoryPhoto extends ItemPhoto {
  const MemoryPhoto(this.id, this.bytes);
  final String id;
  final Uint8List bytes;
}

/// Stok per ukuran, dipakai alat berukuran seperti sepatu.
class SizeStock {
  const SizeStock(this.label, this.stock);
  final String label;
  final int stock;
}

class Equipment {
  const Equipment({
    required this.id,
    required this.providerId,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.description,
    required this.pricePerDay,
    required this.depositAmount,
    required this.weightGram,
    this.stock = 0,
    this.sizes = const [],
    this.photos = const [],
    this.rating = 0,
    this.conditionScore = 100,
    this.capacityPerson,
    this.isActive = true,
  });

  final String id;
  final String providerId;
  final String categoryId;
  final String name;
  final String brand;
  final String description;
  final double pricePerDay;
  final double depositAmount;
  final int weightGram;

  /// Stok untuk alat tanpa ukuran. Diabaikan bila [sizes] terisi.
  final int stock;

  /// Kosong = alat tidak punya ukuran.
  final List<SizeStock> sizes;
  final List<ItemPhoto> photos;
  final double rating;

  /// 0-100, rata-rata kondisi unit fisik.
  final int conditionScore;
  final int? capacityPerson;

  /// `false` = disembunyikan dari katalog oleh penyedia.
  final bool isActive;

  bool get hasSizes => sizes.isNotEmpty;

  int get stockTotal => hasSizes ? sizes.fold(0, (sum, s) => sum + s.stock) : stock;

  /// Stok untuk satu ukuran, atau stok total bila alat tanpa ukuran.
  int stockFor(String? size) => size == null
      ? stockTotal
      : sizes.where((s) => s.label == size).fold(0, (sum, s) => sum + s.stock);

  /// Mis. "39–44" untuk ditampilkan di katalog.
  String? get sizeRange =>
      hasSizes ? (sizes.length == 1 ? sizes.first.label : '${sizes.first.label}–${sizes.last.label}') : null;

  Equipment copyWith({
    String? categoryId,
    String? name,
    String? brand,
    String? description,
    double? pricePerDay,
    double? depositAmount,
    int? weightGram,
    int? stock,
    List<SizeStock>? sizes,
    List<ItemPhoto>? photos,
    int? Function()? capacityPerson,
    bool? isActive,
  }) =>
      Equipment(
        id: id,
        providerId: providerId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        description: description ?? this.description,
        pricePerDay: pricePerDay ?? this.pricePerDay,
        depositAmount: depositAmount ?? this.depositAmount,
        weightGram: weightGram ?? this.weightGram,
        stock: stock ?? this.stock,
        sizes: sizes ?? this.sizes,
        photos: photos ?? this.photos,
        rating: rating,
        conditionScore: conditionScore,
        capacityPerson: capacityPerson == null ? this.capacityPerson : capacityPerson(),
        isActive: isActive ?? this.isActive,
      );
}

enum RentalStatus {
  pendingConfirmation('Menunggu konfirmasi'),
  awaitingPayment('Menunggu pembayaran'),
  paid('Siap diambil'),
  pickedUp('Sedang disewa'),
  overdue('Terlambat'),
  returned('Sudah dikembalikan'),
  completed('Selesai'),
  rejected('Ditolak'),
  cancelled('Dibatalkan'),
  expired('Kedaluwarsa'),
  noShow('Tidak diambil'),
  disputed('Sengketa');

  const RentalStatus(this.label);
  final String label;
}

class StatusLog {
  const StatusLog({
    required this.from,
    required this.to,
    required this.actorName,
    required this.at,
    this.note,
  });

  final RentalStatus? from;
  final RentalStatus to;
  final String actorName;
  final DateTime at;
  final String? note;
}

class Rental {
  Rental({
    required this.id,
    required this.invoiceCode,
    required this.customerId,
    required this.customerName,
    required this.providerId,
    required this.providerName,
    required this.equipmentId,
    required this.equipmentName,
    required this.categoryId,
    required this.qty,
    required this.startDate,
    required this.endDate,
    required this.pricePerDaySnapshot,
    required this.depositSnapshot,
    required this.status,
    required this.guarantees,
    required this.createdAt,
    this.size,
    this.photo,
    List<StatusLog>? logs,
  }) : logs = logs ?? [];

  final String id;
  final String invoiceCode;
  final String customerId;
  final String customerName;
  final String providerId;
  final String providerName;
  final String equipmentId;
  final String equipmentName;
  final String categoryId;
  final int qty;

  /// Ukuran yang disewa (mis. sepatu "42"), `null` untuk alat tanpa ukuran.
  final String? size;

  /// Foto utama alat saat booking dibuat, untuk kartu transaksi.
  final ItemPhoto? photo;
  final DateTime startDate;
  final DateTime endDate;

  /// Harga dikunci saat booking dibuat, tidak ikut perubahan harga provider.
  final double pricePerDaySnapshot;
  final double depositSnapshot;
  RentalStatus status;
  final List<Guarantee> guarantees;
  final DateTime createdAt;
  final List<StatusLog> logs;
  Uint8List? paymentProof;
  String? cancelReason;

  /// Terisi saat penyedia menerima alat kembali, bersama kondisi dan dendanya.
  DateTime? returnedAt;
  ReturnCondition? returnCondition;
  double lateFee = 0;
  double damageFee = 0;
  String? damageNote;
  DamageReview damageReview = DamageReview.none;

  /// Kenapa denda kerusakan ditinjau admin (nominal besar atau keberatan penyewa).
  String? reviewReason;

  /// Catatan keputusan admin.
  String? reviewNote;

  int get durationDays => inclusiveDays(startDate, endDate);

  /// Mis. "Sepatu Hiking × 1 (ukuran 42)".
  String get itemLabel => '$equipmentName × $qty${size == null ? '' : ' (ukuran $size)'}';
  double get subtotal => pricePerDaySnapshot * qty * durationDays;
  double get depositTotal => depositSnapshot * qty;
  double get grandTotal => subtotal + depositTotal;

  double get fineTotal => lateFee + damageFee;

  /// Deposit yang kembali ke penyewa setelah dipotong denda.
  double get depositRefund => max(0, depositTotal - fineTotal);

  /// Denda yang tidak tertutup deposit dan harus dibayar penyewa.
  double get fineShortfall => max(0, fineTotal - depositTotal);

  /// Hari terlambat sampai [at]; setelah alat kembali, sampai tanggal kembalinya.
  int lateDaysAt(DateTime at) => lateDays(endDate, returnedAt ?? at);

  /// Denda terlambat untuk [lateDaysAt]; perkiraan selama alat belum kembali.
  double lateFeeAt(DateTime at) =>
      lateFeeFor(pricePerDay: pricePerDaySnapshot, qty: qty, days: lateDaysAt(at));

  /// Keberatan hanya untuk denda kerusakan yang belum pernah ditinjau admin.
  bool get canObjectToDamageFee =>
      status == RentalStatus.returned && damageFee > 0 && damageReview == DamageReview.none;
}

/// Penyewa yang tidak boleh membuat booking baru.
class BlacklistEntry {
  const BlacklistEntry({required this.reason, required this.by, required this.at});

  final String reason;

  /// Nama admin, atau "Sistem" untuk blacklist otomatis.
  final String by;
  final DateTime at;
}

/// Ringkasan riwayat satu penyewa untuk admin.
class CustomerRecord {
  const CustomerRecord({
    required this.user,
    required this.rentalCount,
    required this.lateCount,
    required this.noShowCount,
    required this.damageCount,
    required this.fineTotal,
    this.blacklist,
  });

  final AppUser user;
  final int rentalCount;
  final int lateCount;
  final int noShowCount;
  final int damageCount;
  final double fineTotal;
  final BlacklistEntry? blacklist;

  int get violations => lateCount + noShowCount + damageCount;
}

class BookingRequest {
  const BookingRequest({
    required this.customerId,
    required this.equipmentId,
    required this.qty,
    required this.startDate,
    required this.endDate,
    required this.guarantees,
    required this.idempotencyKey,
    this.size,
  });

  final String customerId;
  final String equipmentId;
  final int qty;
  final String? size;
  final DateTime startDate;
  final DateTime endDate;
  final List<GuaranteeDraft> guarantees;
  final String idempotencyKey;
}

/// Kesalahan bisnis dengan kode yang sama seperti kontrak API
/// (`{ "success": false, "error": { "code": ..., "message": ... } }`).
class AppException implements Exception {
  const AppException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}
