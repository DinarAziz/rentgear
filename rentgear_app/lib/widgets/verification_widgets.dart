import 'package:flutter/material.dart';

import '../core/format.dart';
import '../domain/models.dart';
import 'photo_widgets.dart';

Color providerStatusColor(ProviderStatus status) => switch (status) {
  ProviderStatus.verified => Colors.green.shade800,
  ProviderStatus.pending => Colors.orange.shade800,
  ProviderStatus.rejected => Colors.red.shade700,
};

/// Ringkasan status verifikasi toko, untuk pemilik toko dan admin.
class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard(
    this.verification, {
    super.key,
    required this.forAdmin,
  });

  final StoreVerification verification;
  final bool forAdmin;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final (icon, title, body) = switch (v.status) {
      ProviderStatus.verified => (
        Icons.verified_outlined,
        'Toko terverifikasi',
        v.reviewedAt == null
            ? 'Alat yang aktif tampil di katalog.'
            : 'Diverifikasi ${tanggal(v.reviewedAt!)}.',
      ),
      ProviderStatus.rejected => (
        Icons.report_outlined,
        'Verifikasi ditolak',
        'Alasan admin: ${v.rejectionReason ?? '-'}',
      ),
      ProviderStatus.pending when v.submitted => (
        Icons.hourglass_top,
        'Menunggu pemeriksaan admin',
        'Dokumen dikirim ${tanggalJam(v.submittedAt!)}.',
      ),
      ProviderStatus.pending => (
        Icons.upload_file_outlined,
        'Dokumen belum dikirim',
        forAdmin
            ? 'Toko ini belum bisa diverifikasi sampai pemiliknya mengirim dokumen.'
            : 'Kirim data toko dan dokumen di bawah. Admin memeriksanya sebelum alat Anda tampil di katalog.',
      ),
    };
    final color = providerStatusColor(v.status);
    return Card(
      color: color.withValues(alpha: 0.06),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
        subtitle: Text(body),
      ),
    );
  }
}

/// Foto KTP, swafoto dengan KTP, dan foto toko. Ketuk untuk layar penuh.
class DocumentPhotos extends StatelessWidget {
  const DocumentPhotos(this.verification, {super.key});

  final StoreVerification verification;

  @override
  Widget build(BuildContext context) {
    final v = verification;
    final entries = [
      if (v.ktpPhoto case final p?) ('KTP', p),
      if (v.selfiePhoto case final p?) ('Swafoto dengan KTP', p),
      for (final (i, p) in v.storePhotos.indexed) ('Foto toko ${i + 1}', p),
    ];
    if (entries.isEmpty) {
      return const Text(
        'Foto dokumen tidak tersedia.',
        style: TextStyle(color: Colors.black54),
      );
    }
    final photos = [for (final e in entries) e.$2];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (i, (label, photo)) in entries.indexed)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) =>
                          PhotoViewerScreen(photos: photos, initialIndex: i),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 104,
                      child: ItemPhotoView(photo, decodeWidth: 320),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
