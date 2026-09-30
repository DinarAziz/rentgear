import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/payment.dart';
import '../../core/responsive.dart';
import '../../domain/guarantee.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/guarantee_widgets.dart';
import '../../widgets/motion.dart';
import '../../widgets/photo_widgets.dart';

/// Detail transaksi untuk semua role. Tombol aksi menyesuaikan role & status.
class RentalDetailScreen extends StatelessWidget {
  const RentalDetailScreen({super.key, required this.rentalId});

  final String rentalId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: AsyncView<Rental>(
        load: () => state.repo.rental(rentalId),
        builder: (context, rental) => Column(
          children: [
            Expanded(child: _Body(rental: rental)),
            _ActionBar(rental: rental),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.rental});
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final user = context.read<AppState>().currentUser;
    final canReview =
        user.role == UserRole.provider &&
        r.status == RentalStatus.pendingConfirmation;

    return ReadableListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.invoiceCode,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusPill(r.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ItemThumb(
                      photo: r.photo,
                      categoryId: r.categoryId,
                      size: 56,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.itemLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            r.providerName,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                InfoRow('Penyewa', r.customerName),
                InfoRow('Tanggal', rentangTanggal(r.startDate, r.endDate)),
                InfoRow('Durasi', '${r.durationDays} hari'),
                if (r.cancelReason != null) InfoRow('Alasan', r.cancelReason!),
              ],
            ),
          ),
        ),
        const SectionTitle('Biaya'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                InfoRow('Sewa', rupiah(r.subtotal)),
                InfoRow('Deposit', rupiah(r.depositTotal)),
                const Divider(),
                InfoRow('Total', rupiah(r.grandTotal), bold: true),
              ],
            ),
          ),
        ),
        if (r.status == RentalStatus.awaitingPayment &&
            user.role == UserRole.customer) ...[
          const SectionTitle('Cara bayar'),
          _LynkPaymentCard(rental: r),
        ],
        if (r.paymentProof != null) ...[
          const SectionTitle('Bukti bayar'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  r.paymentProof!,
                  fit: BoxFit.cover,
                  cacheWidth: 150,
                ),
              ),
              title: const Text('Lihat bukti bayar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => PhotoViewerScreen(
                    photos: [MemoryPhoto('${r.id}-payment', r.paymentProof!)],
                  ),
                ),
              ),
            ),
          ),
        ],
        SectionTitle('Jaminan (${r.guarantees.length})'),
        _GuaranteeHint(rental: r, role: user.role),
        for (final g in r.guarantees) ...[
          GuaranteeTile(
            guarantee: g,
            actions: canReview && g.status == GuaranteeStatus.submitted
                ? [
                    OutlinedButton(
                      onPressed: () => _reject(context, r, g),
                      child: const Text('Tolak'),
                    ),
                    FilledButton(
                      onPressed: () => _verify(context, r, g),
                      child: const Text('Valid'),
                    ),
                  ]
                : const [],
          ),
          const SizedBox(height: 8),
        ],
        const SectionTitle('Riwayat status'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final (i, log) in r.logs.reversed.indexed)
                  ListTile(
                    dense: true,
                    // The freshest entry is the one the user just caused; celebrate only
                    // the moment a transaction actually reaches "Selesai", not every visit.
                    leading: CompletionDot(
                      color: statusColor(log.to),
                      celebrate: i == 0 && log.to == RentalStatus.completed,
                    ),
                    title: Text(log.to.label),
                    subtitle: Text(
                      [
                        '${log.actorName} · ${tanggalJam(log.at)}',
                        ?log.note,
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _verify(BuildContext context, Rental r, Guarantee g) {
    final state = context.read<AppState>();
    return runAction(
      context,
      () => state.run(
        (repo) =>
            repo.reviewGuarantee(r.id, g.id, state.currentUser, accept: true),
      ),
    );
  }

  Future<void> _reject(BuildContext context, Rental r, Guarantee g) async {
    final state = context.read<AppState>();
    final reason = await askReason(
      context,
      title: 'Tolak ${g.type.label}',
      hint: 'Mis. foto buram, nama tidak cocok',
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => state.run(
        (repo) => repo.reviewGuarantee(
          r.id,
          g.id,
          state.currentUser,
          accept: false,
          note: reason,
        ),
      ),
    );
  }
}

class _GuaranteeHint extends StatelessWidget {
  const _GuaranteeHint({required this.rental, required this.role});
  final Rental rental;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final provider = role == UserRole.provider;
    final hasRejected = rental.guarantees.any(
      (g) => g.status == GuaranteeStatus.rejected,
    );
    if (rental.status == RentalStatus.pendingConfirmation && hasRejected) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          provider
              ? 'Ada jaminan yang ditolak. Tolak booking ini dengan alasan yang jelas agar penyewa bisa membuat booking baru.'
              : 'Jaminan Anda ditolak (lihat catatan di bawah). Batalkan booking ini, lalu buat booking baru dengan dokumen yang benar.',
          style: TextStyle(fontSize: 13, color: Colors.red.shade800),
        ),
      );
    }
    final text = switch (rental.status) {
      RentalStatus.pendingConfirmation =>
        provider
            ? 'Periksa foto & nomor setiap jaminan, lalu tandai Valid atau Tolak.'
            : 'Penyedia sedang memeriksa jaminan Anda.',
      RentalStatus.awaitingPayment || RentalStatus.paid =>
        provider
            ? 'Terima dokumen asli dan cocokkan dengan foto saat penyewa mengambil alat.'
            : 'Bawa dokumen asli saat mengambil alat.',
      RentalStatus.pickedUp || RentalStatus.overdue || RentalStatus.returned =>
        provider
            ? 'Dokumen asli sedang Anda pegang. Simpan dengan aman dan jangan difotokopi.'
            : 'Dokumen asli dipegang penyedia sampai alat dikembalikan.',
      RentalStatus.completed =>
        'Semua dokumen jaminan sudah dikembalikan ke penyewa.',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.rental});
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final user = state.currentUser;
    final r = rental;
    final actions = <Widget>[];

    Future<void> act(Future<Rental> Function() call, String success) =>
        runAction(context, () => state.run((_) => call()), success: success);

    if (user.role == UserRole.customer) {
      if (r.status == RentalStatus.awaitingPayment) {
        actions.add(
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload bukti bayar'),
            onPressed: () async {
              final bytes = await _pickPaymentProof(context, r.grandTotal);
              if (bytes == null || !context.mounted) return;
              await act(
                () => state.repo.submitPayment(r.id, user, bytes),
                'Bukti bayar terkirim.',
              );
            },
          ),
        );
      }
      if (r.status == RentalStatus.pendingConfirmation ||
          r.status == RentalStatus.awaitingPayment) {
        actions.add(
          OutlinedButton(
            onPressed: () async {
              final reason = await askReason(
                context,
                title: 'Batalkan booking',
              );
              if (reason == null || !context.mounted) return;
              await act(
                () => state.repo.cancelBooking(r.id, user, reason),
                'Booking dibatalkan.',
              );
            },
            child: const Text('Batalkan'),
          ),
        );
      }
    }

    if (user.role == UserRole.provider) {
      switch (r.status) {
        case RentalStatus.pendingConfirmation:
          final allVerified = r.guarantees.every(
            (g) => g.status == GuaranteeStatus.verified,
          );
          final anyRejected = r.guarantees.any(
            (g) => g.status == GuaranteeStatus.rejected,
          );
          actions
            ..add(
              FilledButton(
                onPressed: allVerified
                    ? () => act(
                        () => state.repo.confirmBooking(r.id, user),
                        'Booking dikonfirmasi.',
                      )
                    : null,
                child: Text(
                  allVerified
                      ? 'Konfirmasi booking'
                      : anyRejected
                      ? 'Jaminan ditolak — tidak bisa dikonfirmasi'
                      : 'Periksa semua jaminan dulu',
                ),
              ),
            )
            ..add(
              OutlinedButton(
                onPressed: () async {
                  final reason = await askReason(
                    context,
                    title: 'Tolak booking',
                  );
                  if (reason == null || !context.mounted) return;
                  await act(
                    () => state.repo.rejectBooking(r.id, user, reason),
                    'Booking ditolak.',
                  );
                },
                child: const Text('Tolak booking'),
              ),
            );
        case RentalStatus.paid:
          actions.add(
            FilledButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Terima jaminan & serahkan alat'),
              onPressed: () async {
                final docs = r.guarantees
                    .map((g) => '• ${g.type.label} ${g.maskedNumber}')
                    .join('\n');
                final ok = await confirmDialog(
                  context,
                  title: 'Serah terima',
                  message:
                      'Pastikan dokumen asli berikut sudah Anda terima dan cocok dengan foto:\n\n$docs',
                  confirmLabel: 'Sudah diterima',
                );
                if (!ok || !context.mounted) return;
                await act(
                  () => state.repo.handover(r.id, user),
                  'Alat diserahkan. Jaminan tercatat dipegang.',
                );
              },
            ),
          );
        case RentalStatus.pickedUp || RentalStatus.overdue:
          actions.add(
            FilledButton.icon(
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Terima pengembalian alat'),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Terima pengembalian',
                  message:
                      'Pastikan ${r.itemLabel} sudah kembali dan kondisinya sudah Anda periksa.',
                  confirmLabel: 'Sudah diterima',
                );
                if (!ok || !context.mounted) return;
                await act(
                  () => state.repo.receiveReturn(r.id, user),
                  'Alat diterima kembali.',
                );
              },
            ),
          );
        case RentalStatus.returned:
          actions.add(
            FilledButton.icon(
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Kembalikan jaminan & selesaikan'),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Kembalikan jaminan',
                  message:
                      'Serahkan semua dokumen asli jaminan ke ${r.customerName}. Transaksi akan ditutup.',
                  confirmLabel: 'Sudah dikembalikan',
                );
                if (!ok || !context.mounted) return;
                await act(
                  () => state.repo.returnGuaranteesAndComplete(r.id, user),
                  'Transaksi selesai.',
                );
              },
            ),
          );
        default:
          break;
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, a) in actions.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: a),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilih foto bukti bayar lalu tampilkan pratinjau. "Ganti" membuka
/// pemilih lagi; `null` bila dibatalkan.
Future<Uint8List?> _pickPaymentProof(BuildContext context, double total) async {
  final bytes = await pickPhoto(
    context,
    title: 'Screenshot bukti bayar Lynk.id',
  );
  if (bytes == null || !context.mounted) return null;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kirim bukti bayar?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 220,
              fit: BoxFit.contain,
              cacheWidth: 800,
            ),
          ),
          const SizedBox(height: 12),
          Text('Total yang harus dibayar: ${rupiah(total)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Ganti foto'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Kirim'),
        ),
      ],
    ),
  );
  if (ok == null) return null;
  if (ok) return bytes;
  if (!context.mounted) return null;
  return _pickPaymentProof(context, total);
}

/// Langkah bayar lewat Lynk.id: salin nominal & kode invoice, buka halaman
/// Lynk.id, lalu unggah screenshot struknya lewat tombol di bawah.
class _LynkPaymentCard extends StatelessWidget {
  const _LynkPaymentCard({required this.rental});

  final Rental rental;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label disalin.')));
  }

  Future<void> _open(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(lynkPaymentUrl),
      mode: LaunchMode.inAppBrowserView,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak bisa membuka Lynk.id. Coba lagi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = rental;
    const hint = TextStyle(fontSize: 13, color: Colors.black54);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bayar lewat Lynk.id (QRIS, e-wallet, VA bank).'),
            const SizedBox(height: 8),
            _CopyRow(
              label: 'Nominal',
              value: rupiah(r.grandTotal),
              onCopy: () =>
                  _copy(context, 'Nominal', r.grandTotal.round().toString()),
            ),
            _CopyRow(
              label: 'Kode invoice',
              value: r.invoiceCode,
              onCopy: () => _copy(context, 'Kode invoice', r.invoiceCode),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Buka Lynk.id, isi nominal persis sama.\n'
              '2. Tulis kode invoice di catatan pembayaran.\n'
              '3. Setelah lunas, unggah screenshot struknya lewat tombol di bawah.',
              style: hint,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka Lynk.id'),
              onPressed: () => _open(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          tooltip: 'Salin $label',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: onCopy,
        ),
      ],
    );
  }
}
