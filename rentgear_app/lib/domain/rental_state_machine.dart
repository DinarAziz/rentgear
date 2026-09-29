import 'guarantee.dart';
import 'models.dart';

/// Satu-satunya pintu perubahan status transaksi (lihat docs/03 bagian 1).
class RentalStateMachine {
  static const _allowed = <RentalStatus, Set<RentalStatus>>{
    RentalStatus.pendingConfirmation: {
      RentalStatus.awaitingPayment,
      RentalStatus.rejected,
      RentalStatus.expired,
      RentalStatus.cancelled,
    },
    RentalStatus.awaitingPayment: {RentalStatus.paid, RentalStatus.cancelled},
    RentalStatus.paid: {RentalStatus.pickedUp, RentalStatus.noShow},
    RentalStatus.pickedUp: {RentalStatus.returned, RentalStatus.overdue},
    RentalStatus.overdue: {RentalStatus.returned},
    RentalStatus.returned: {RentalStatus.completed, RentalStatus.disputed},
    RentalStatus.disputed: {RentalStatus.completed},
  };

  /// Role yang boleh memicu status tujuan. `null` = job sistem.
  static const _actors = <RentalStatus, Set<UserRole?>>{
    RentalStatus.awaitingPayment: {UserRole.provider},
    RentalStatus.rejected: {UserRole.provider},
    RentalStatus.cancelled: {UserRole.customer, null}, // null: tidak dibayar 24 jam
    RentalStatus.paid: {UserRole.customer},
    RentalStatus.pickedUp: {UserRole.provider},
    RentalStatus.returned: {UserRole.provider},
    RentalStatus.completed: {UserRole.provider, UserRole.admin},
    RentalStatus.disputed: {UserRole.customer, UserRole.provider},
    RentalStatus.expired: {null},
    RentalStatus.noShow: {null},
    RentalStatus.overdue: {null},
  };

  /// Status yang ikut mengunci stok pada perhitungan ALG-2.
  static const lockingStatuses = {
    RentalStatus.pendingConfirmation,
    RentalStatus.awaitingPayment,
    RentalStatus.paid,
    RentalStatus.pickedUp,
    RentalStatus.overdue,
    RentalStatus.returned,
  };

  static bool canTransition(RentalStatus from, RentalStatus to) =>
      _allowed[from]?.contains(to) ?? false;

  /// Mengembalikan pesan kesalahan, atau `null` bila transisi sah.
  static String? guardError(Rental rental, RentalStatus to, UserRole? actor) {
    if (!canTransition(rental.status, to)) {
      return 'Status "${rental.status.label}" tidak bisa diubah menjadi "${to.label}".';
    }
    if (!(_actors[to]?.contains(actor) ?? false)) {
      return 'Anda tidak berwenang melakukan aksi ini.';
    }
    final g = rental.guarantees;
    switch (to) {
      case RentalStatus.awaitingPayment:
        if (g.isEmpty || g.any((x) => x.status != GuaranteeStatus.verified)) {
          return 'Semua jaminan harus diverifikasi sebelum konfirmasi.';
        }
      case RentalStatus.pickedUp:
        if (g.any((x) => x.status != GuaranteeStatus.held)) {
          return 'Dokumen asli jaminan harus diterima sebelum alat diserahkan.';
        }
      case RentalStatus.completed:
        if (g.any((x) => x.status != GuaranteeStatus.returned)) {
          return 'Semua jaminan harus dikembalikan sebelum transaksi selesai.';
        }
      default:
        break;
    }
    return null;
  }
}
