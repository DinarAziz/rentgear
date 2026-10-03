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
    required this.policy,
    required this.latitude,
    required this.longitude,
    this.bankAccount,
  });

  final String id;
  final String ownerId;
  final String businessName;
  final String city;
  final String address;
  ProviderStatus status;
  GuaranteePolicy policy;

  /// Aturan denda toko. Berlaku untuk booking berikutnya.
  FinePolicy finePolicy = const FinePolicy();

  /// Lokasi toko di peta. Penyedia bisa memindahkannya.
  double latitude;
  double longitude;

  /// Rata-rata bintang, jumlah ulasan, dan jumlah pengikut. Dihitung ulang
  /// oleh repository setiap kali ulasan atau pengikut berubah.
  double rating = 0;
  int reviewCount = 0;
  int followerCount = 0;

  /// Rekening tujuan transfer, mis. "BCA 1234567890 a.n. Arjuna Outdoor".
  final String? bankAccount;
}

class Category {
  const Category(this.id, this.name);
  final String id;
  final String name;
}

/// Foto alat: bawaan aplikasi (asset), diunggah penyedia (bytes), atau dari
/// server (URL).
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

/// Foto yang disimpan di server. [id] dipakai saat penyedia mengubah alat,
/// untuk memberi tahu server foto mana yang dipertahankan.
class NetworkPhoto extends ItemPhoto {
  const NetworkPhoto(this.id, this.url);
  final String id;
  final String url;
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

  /// Ulasan penyewa untuk toko, diisi setelah transaksi selesai.
  Review? review;

  /// Aturan denda toko saat booking dibuat, dikunci seperti harga dan deposit.
  FinePolicy finePolicy = const FinePolicy();

  /// Foto kondisi alat saat diserahkan dan saat kembali, urut waktu.
  /// Hanya ditambah, tidak pernah dihapus.
  final List<ConditionPhoto> conditionPhotos = [];

  List<ConditionPhoto> conditionPhotosOf(ConditionPhase phase) =>
      [for (final p in conditionPhotos) if (p.phase == phase) p];

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
  int lateDaysAt(DateTime at) => finePolicy.lateDays(endDate, returnedAt ?? at);

  /// Denda terlambat untuk [lateDaysAt]; perkiraan selama alat belum kembali.
  double lateFeeAt(DateTime at) =>
      finePolicy.lateFee(pricePerDay: pricePerDaySnapshot, qty: qty, days: lateDaysAt(at));

  /// Keberatan hanya untuk denda kerusakan yang belum pernah ditinjau admin.
  bool get canObjectToDamageFee =>
      status == RentalStatus.returned && damageFee > 0 && damageReview == DamageReview.none;
}

/// Ulasan penyewa untuk sebuah toko.
class Review {
  Review({
    required this.id,
    required this.providerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.at,
    this.rentalId,
    this.equipmentName,
    this.reply,
    this.repliedAt,
  });

  final String id;
  final String providerId;
  final String customerName;

  /// 1 sampai 5 bintang.
  final int rating;
  final String comment;
  final DateTime at;

  /// Kosong untuk ulasan bawaan data demo.
  final String? rentalId;
  final String? equipmentName;

  /// Balasan pemilik toko, kosong bila belum dibalas.
  String? reply;
  DateTime? repliedAt;
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

/// Satu baris jejak audit: siapa melakukan apa, kapan, pada apa.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actorName,
    required this.actorRole,
    required this.action,
    this.target,
    this.detail,
  });

  final String id;
  final DateTime at;

  /// Nama pelaku, "Sistem" untuk aksi otomatis, atau "Tidak dikenal" untuk
  /// percobaan masuk yang gagal.
  final String actorName;

  /// `customer`, `provider`, `admin`, atau `system`.
  final String actorRole;

  /// Salah satu kode di [AuditAction].
  final String action;
  final String? target;
  final String? detail;
}

/// Kode aksi yang dicatat. Sama dengan konstanta `Audit` di server.
abstract final class AuditAction {
  static const login = 'login';
  static const loginGoogle = 'login_google';
  static const registerGoogle = 'register_google';
  static const loginFailed = 'login_failed';
  static const providerStatus = 'provider_status';
  static const damageFeeDecided = 'damage_fee_decided';
  static const blacklistAdded = 'blacklist_added';
  static const blacklistRemoved = 'blacklist_removed';
  static const aiFineOpinion = 'ai_fine_opinion';
  static const aiCustomerRisk = 'ai_customer_risk';

  static String label(String action) => switch (action) {
    login => 'Masuk',
    loginGoogle => 'Masuk dengan Google',
    registerGoogle => 'Daftar dengan Google',
    loginFailed => 'Gagal masuk',
    providerStatus => 'Status penyedia diubah',
    damageFeeDecided => 'Denda kerusakan diputuskan',
    blacklistAdded => 'Masuk blacklist',
    blacklistRemoved => 'Blacklist dicabut',
    aiFineOpinion => 'Pendapat AI atas denda diminta',
    aiCustomerRisk => 'Analisis risiko AI diminta',
    _ => action,
  };
}

/// Satu alat dalam paket yang disarankan AI. Harga dihitung server.
class AiPick {
  const AiPick({
    required this.equipmentId,
    required this.name,
    required this.providerName,
    required this.city,
    required this.qty,
    required this.reason,
    required this.rentCost,
    required this.deposit,
  });

  final String equipmentId;
  final String name;
  final String providerName;
  final String city;
  final int qty;
  final String reason;
  final double rentCost;
  final double deposit;
}

/// Paket alat yang disarankan AI untuk satu rencana perjalanan.
class AiRecommendation {
  const AiRecommendation({
    required this.summary,
    required this.items,
    required this.tips,
    required this.days,
    required this.people,
    required this.rentTotal,
    required this.depositTotal,
  });

  final String summary;
  final List<AiPick> items;
  final List<String> tips;
  final int days;
  final int people;
  final double rentTotal;
  final double depositTotal;
}

/// Pendapat AI atas denda kerusakan. Hanya saran; admin yang memutuskan.
class AiFineOpinion {
  const AiFineOpinion({
    required this.verdict,
    required this.suggestedFee,
    required this.explanation,
    required this.proposedFee,
    this.photoFinding = '',
    this.photosBefore = 0,
    this.photosAfter = 0,
  });

  /// Apa yang terlihat dari perbandingan foto kondisi. Kosong bila tidak
  /// ada foto.
  final String photoFinding;
  final int photosBefore;
  final int photosAfter;

  /// `wajar`, `terlalu_tinggi`, `terlalu_rendah`, atau `perlu_bukti`.
  final String verdict;
  final double suggestedFee;
  final String explanation;
  final double proposedFee;

  String get verdictLabel => switch (verdict) {
    'wajar' => 'Denda wajar',
    'terlalu_tinggi' => 'Denda terlalu tinggi',
    'terlalu_rendah' => 'Denda terlalu rendah',
    _ => 'Perlu bukti tambahan',
  };
}

/// Tingkat risiko seorang penyewa menurut AI. Hanya saran untuk admin.
class AiRisk {
  const AiRisk({
    required this.level,
    required this.summary,
    required this.factors,
  });

  /// `rendah`, `sedang`, atau `tinggi`.
  final String level;
  final String summary;
  final List<String> factors;
}

/// Kapan foto kondisi alat diambil.
enum ConditionPhase {
  handover('Saat diserahkan'),
  returned('Saat kembali');

  const ConditionPhase(this.label);
  final String label;
}

/// Satu foto kondisi alat pada sebuah transaksi.
class ConditionPhoto {
  const ConditionPhoto({required this.phase, required this.bytes, required this.at});

  final ConditionPhase phase;
  final Uint8List bytes;
  final DateTime at;
}

/// Paling banyak foto kondisi per tahap.
const maxConditionPhotos = 4;

/// Kenapa foto kondisi tidak bisa ditambah pada [status], atau `null` bila
/// boleh. Foto serah terima: selama alat belum kembali. Foto pengembalian:
/// setelah alat diterima dan sebelum transaksi ditutup.
String? conditionPhotoError(ConditionPhase phase, RentalStatus status) => switch (phase) {
  ConditionPhase.handover =>
    status == RentalStatus.paid || status == RentalStatus.pickedUp
        ? null
        : 'Foto serah terima hanya bisa ditambah sebelum alat kembali.',
  ConditionPhase.returned =>
    status == RentalStatus.returned
        ? null
        : 'Foto pengembalian hanya bisa ditambah setelah alat diterima dan sebelum transaksi ditutup.',
};
