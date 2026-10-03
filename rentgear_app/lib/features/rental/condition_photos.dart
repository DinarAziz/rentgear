import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';

/// Foto kondisi alat saat diserahkan dan saat kembali. Semua pihak dalam
/// transaksi bisa melihatnya; hanya toko pemilik yang bisa menambah, dan
/// foto yang sudah masuk tidak bisa dihapus.
class ConditionPhotosSection extends StatelessWidget {
  const ConditionPhotosSection({super.key, required this.rental});

  final Rental rental;

  static const double _thumb = 76;

  /// Bagian ini tampil bila sudah ada foto, atau bila [user] bisa menambah.
  static bool visibleFor(Rental r, AppUser user) =>
      r.conditionPhotos.isNotEmpty ||
      ConditionPhase.values.any((phase) => _canAdd(r, user, phase));

  static bool _canAdd(Rental r, AppUser user, ConditionPhase phase) =>
      user.role == UserRole.provider &&
      user.providerId == r.providerId &&
      conditionPhotoError(phase, r.status) == null &&
      r.conditionPhotosOf(phase).length < maxConditionPhotos;

  Future<void> _add(BuildContext context, ConditionPhase phase) async {
    final state = context.read<AppState>();
    final photo = await pickPhoto(
      context,
      title: 'Foto kondisi ${phase.label.toLowerCase()}',
    );
    if (photo == null || !context.mounted) return;
    await runAction(
      context,
      () => state.run(
        (repo) =>
            repo.addConditionPhoto(rental.id, state.currentUser, phase, photo),
      ),
      success: 'Foto kondisi tersimpan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, phase) in ConditionPhase.values.indexed) ...[
              if (i > 0) const Divider(height: 24),
              _phase(context, phase, _canAdd(rental, user, phase)),
            ],
            const SizedBox(height: 10),
            const Text(
              'Foto ini menjadi bukti kondisi alat bila ada keberatan atas '
              'denda. Foto yang sudah tersimpan tidak bisa dihapus.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phase(BuildContext context, ConditionPhase phase, bool canAdd) {
    final photos = rental.conditionPhotosOf(phase);
    final viewer = [
      for (final (i, p) in photos.indexed)
        MemoryPhoto('${rental.id}-${phase.name}-$i', p.bytes),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(phase.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          photos.isEmpty
              ? 'Belum ada foto.'
              : '${photos.length} foto, ${tanggalJam(photos.last.at)}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        if (photos.isNotEmpty || canAdd) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, p) in photos.indexed)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) =>
                          PhotoViewerScreen(photos: viewer, initialIndex: i),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      p.bytes,
                      width: _thumb,
                      height: _thumb,
                      fit: BoxFit.cover,
                      cacheWidth: 240,
                    ),
                  ),
                ),
              if (canAdd)
                AddPhotoTile(size: _thumb, onTap: () => _add(context, phase)),
            ],
          ),
        ],
      ],
    );
  }
}
