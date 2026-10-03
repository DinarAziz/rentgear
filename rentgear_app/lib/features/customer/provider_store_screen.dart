import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/maps.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import 'equipment_cards.dart';

typedef _Store = (ProviderProfile, List<Equipment>, List<Review>, bool);

/// Isi dialog ulasan: jumlah bintang dan komentar.
typedef ReviewDraft = ({int rating, String comment});

const _muted = TextStyle(color: Colors.black54);
const _mutedSmall = TextStyle(fontSize: 13, color: Colors.black54);

void openProviderStore(BuildContext context, String providerId) {
  dismissKeyboard();
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProviderStoreScreen(providerId: providerId),
    ),
  );
}

/// Halaman satu toko: profil, lokasi, tombol ikuti, daftar alat, dan ulasan.
class ProviderStoreScreen extends StatelessWidget {
  const ProviderStoreScreen({super.key, required this.providerId});

  final String providerId;

  static const double _maxWidth = 1100;

  Future<_Store> _load(AppState state) async {
    final repo = state.repo;
    final equipment = await repo.providerEquipment(providerId);
    final followed = await repo.followedProviders(state.currentUser.id);
    return (
      await repo.provider(providerId),
      equipment.where((e) => e.isActive).toList(),
      await repo.providerReviews(providerId),
      followed.contains(providerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Toko')),
      body: AsyncView<_Store>(
        load: () => _load(state),
        builder: (context, data) {
          final (p, equipment, reviews, followed) = data;
          return LayoutBuilder(
            builder: (context, c) {
              final gutter = centeredPadding(c.maxWidth, maxWidth: _maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(gutter.left, 8, gutter.right, 24),
                children: [
                  _Header(store: p, followed: followed),
                  SectionTitle('Alat (${equipment.length})'),
                  if (equipment.isEmpty)
                    const Text('Toko ini belum memasang alat.', style: _muted)
                  else
                    EquipmentCollection(
                      items: equipment,
                      width: c.maxWidth - gutter.horizontal,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                    ),
                  SectionTitle('Ulasan (${reviews.length})'),
                  if (reviews.isEmpty)
                    const Text(
                      'Belum ada ulasan. Ulasan bisa diisi penyewa setelah transaksi selesai.',
                      style: _muted,
                    )
                  else
                    for (final r in reviews) ReviewTile(r),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store, required this.followed});

  final ProviderProfile store;
  final bool followed;

  Future<void> _openMap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      googleMapsUri(store.latitude, store.longitude),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final user = context.select<AppState, LatLng?>((s) => s.location);
    final p = store;
    final isCustomer = state.currentUser.role == UserRole.customer;

    Future<void> toggleFollow() => runAction(
      context,
      () => state.run(
        (repo) => repo.setFollow(p.id, state.currentUser, follow: !followed),
      ),
      success: followed
          ? 'Berhenti mengikuti ${p.businessName}.'
          : 'Mengikuti ${p.businessName}.',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.businessName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(p.address, style: _muted)),
              ],
            ),
            const SizedBox(height: 12),
            MiniMap(point: p.point, user: user, onTap: () => _openMap(context)),
            if (user != null) ...[
              const SizedBox(height: 6),
              Text(
                '${jarak(distanceKm(user, p.point))} dari lokasi Anda',
                style: _mutedSmall,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  p.reviewCount == 0 ? '-' : '★ ${bintang(p.rating)}',
                  '${p.reviewCount} ulasan',
                ),
                _Stat('${p.followerCount}', 'pengikut'),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isCustomer)
                  followed
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Mengikuti'),
                          onPressed: toggleFollow,
                        )
                      : FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Ikuti'),
                          onPressed: toggleFollow,
                        ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Buka di Google Maps'),
                  onPressed: () => _openMap(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(label, style: _mutedSmall),
      ],
    ),
  );
}

/// Lima bintang, terisi sebanyak [rating].
class StarRow extends StatelessWidget {
  const StarRow(this.rating, {super.key, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= rating ? Icons.star : Icons.star_border,
          size: size,
          color: Colors.amber.shade800,
        ),
    ],
  );
}

class ReviewTile extends StatelessWidget {
  const ReviewTile(this.review, {super.key});

  final Review review;

  Future<void> _reply(BuildContext context) async {
    final state = context.read<AppState>();
    final text = await askReason(
      context,
      title: 'Balas ulasan ${review.customerName}',
      hint: 'Balasan toko',
      initial: review.reply ?? '',
    );
    if (text == null || !context.mounted) return;
    await runAction(
      context,
      () => state.run(
        (repo) => repo.replyToReview(review.id, state.currentUser, text),
      ),
      success: 'Balasan tersimpan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = review;
    final isOwner =
        context.read<AppState>().currentUser.providerId == r.providerId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                StarRow(r.rating),
              ],
            ),
            Text(
              [?r.equipmentName, tanggal(r.at)].join(', '),
              style: _mutedSmall,
            ),
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.comment),
            ],
            if (r.reply case final reply?) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balasan toko, ${tanggal(r.repliedAt!)}',
                      style: _mutedSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(reply),
                  ],
                ),
              ),
            ],
            if (isOwner)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.reply, size: 18),
                  label: Text(r.reply == null ? 'Balas' : 'Ubah balasan'),
                  onPressed: () => _reply(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog ulasan: bintang wajib, komentar boleh kosong. `null` bila dibatalkan.
Future<ReviewDraft?> askReview(BuildContext context, String storeName) {
  dismissKeyboard();
  return showDialog<ReviewDraft>(
    context: context,
    builder: (_) => _ReviewDialog(storeName: storeName),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.storeName});

  final String storeName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  var _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Ulasan untuk ${widget.storeName}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i bintang',
                  iconSize: 34,
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade800,
                  ),
                  onPressed: () => setState(() => _rating = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Komentar',
              hintText: 'Kondisi alat, pelayanan, serah terima',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: _rating == 0
            ? null
            : () => Navigator.pop(context, (
                rating: _rating,
                comment: _comment.text.trim(),
              )),
        child: const Text('Kirim ulasan'),
      ),
    ],
  );
}
