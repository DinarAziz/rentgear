import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/guarantee.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/blacklist_notice.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';
import '../rental/fine_widgets.dart';
import 'booking_screen.dart';
import 'provider_store_screen.dart';

class EquipmentDetailScreen extends StatelessWidget {
  const EquipmentDetailScreen({super.key, required this.equipmentId});

  final String equipmentId;

  Future<(Equipment, ProviderProfile, BlacklistEntry?)> _load(
    AppState state,
  ) async {
    final e = await state.repo.equipment(equipmentId);
    final p = await state.repo.provider(e.providerId);
    final blocked = await state.repo.blacklistOf(state.currentUser.id);
    return (e, p, blocked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Alat')),
      body: AsyncView<(Equipment, ProviderProfile, BlacklistEntry?)>(
        load: () => _load(state),
        builder: (context, data) {
          final (e, p, blocked) = data;
          // Penyewa blacklist dihentikan di sini, sebelum mengisi form booking.
          final rentButton = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocked != null) ...[
                Text(
                  blacklistMessage(blocked),
                  style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: blocked != null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BookingScreen(equipment: e, provider: p),
                        ),
                      ),
                child: const Text('Sewa Sekarang'),
              ),
            ],
          );
          final info = [
            Text(
              e.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(e.brand, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (e.rating > 0)
                  Pill('★ ${bintang(e.rating)}', color: Colors.amber.shade800),
                Pill(
                  'Kondisi ${e.conditionScore}/100',
                  color: AppColors.forest,
                ),
                Pill(
                  '${(e.weightGram / 1000).toStringAsFixed(1).replaceAll('.', ',')} kg',
                  color: Colors.blueGrey,
                ),
                if (e.capacityPerson != null)
                  Pill('${e.capacityPerson} orang', color: Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 16),
            Text(e.description),
            const SectionTitle('Harga'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    InfoRow('Sewa per hari', rupiah(e.pricePerDay), bold: true),
                    InfoRow(
                      'Deposit per unit (uang jaminan)',
                      rupiah(e.depositAmount),
                    ),
                    InfoRow('Stok total', '${e.stockTotal} unit'),
                    const DepositNote(),
                  ],
                ),
              ),
            ),
            if (e.hasSizes) ...[
              const SectionTitle('Ukuran'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final size in e.sizes)
                    Chip(
                      label: Text(size.label),
                      avatar: size.stock == 0
                          ? const Icon(Icons.block, size: 16)
                          : null,
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Ketersediaan tiap ukuran dicek saat Anda memilih tanggal.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ],
            const SectionTitle('Penyedia'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(p.businessName),
                subtitle: Text(p.address),
                trailing: Text(
                  p.reviewCount == 0
                      ? 'Lihat toko'
                      : '★ ${bintang(p.rating)} (${p.reviewCount})',
                ),
                onTap: () => openProviderStore(context, p.id),
              ),
            ),
            const SectionTitle('Jaminan yang diterima'),
            _GuaranteeInfo(policy: p.policy),
            const SectionTitle('Aturan denda toko'),
            FinePolicyInfo(policy: p.finePolicy),
          ];
          return LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 900
                ? _WideLayout(
                    gallery: PhotoGallery(
                      photos: e.photos,
                      categoryId: e.categoryId,
                      height: 420,
                    ),
                    info: info,
                    action: rentButton,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ReadableListView(
                          children: [
                            PhotoGallery(
                              photos: e.photos,
                              categoryId: e.categoryId,
                              height: c.maxWidth >= 600 ? 380 : 280,
                            ),
                            const SizedBox(height: 16),
                            ...info,
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: ReadableWidth(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: rentButton,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// Desktop: galeri tetap di kiri, info dan tombol sewa di kanan
/// (tombol ikut di akhir info, bukan menempel di bawah layar).
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.gallery,
    required this.info,
    required this.action,
  });

  final Widget gallery;
  final List<Widget> info;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Padding(padding: const EdgeInsets.all(24), child: gallery),
          ),
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
              children: [...info, const SizedBox(height: 24), action],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuaranteeInfo extends StatelessWidget {
  const _GuaranteeInfo({required this.policy});
  final GuaranteePolicy policy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GuaranteeType.values)
                if (policy.acceptedTypes.contains(t))
                  Pill(
                    t.label,
                    color: AppColors.forest,
                    icon: Icons.badge_outlined,
                  ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Minimal ${policy.baseRequired} dokumen. Untuk total sewa ≥ ${rupiah(policy.highValueThreshold)}, '
            'minimal ${policy.requiredCount(policy.highValueThreshold)} dokumen.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dokumen asli diserahkan saat mengambil alat dan dikembalikan saat alat dikembalikan.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
