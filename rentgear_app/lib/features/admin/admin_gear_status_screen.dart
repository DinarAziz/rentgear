import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/availability.dart';
import '../../domain/gear_status.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';

/// Status semua alat hari ini, per toko: berapa unit sedang disewa, dipesan,
/// dan tersedia. Admin memakai ini untuk memantau stok di seluruh platform.
class AdminGearStatusScreen extends StatefulWidget {
  const AdminGearStatusScreen({super.key});

  @override
  State<AdminGearStatusScreen> createState() => _AdminGearStatusScreenState();
}

class _AdminGearStatusScreenState extends State<AdminGearStatusScreen> {
  bool _onlyInUse = false;

  Future<List<(ProviderProfile, List<GearStatus>)>> _load(AppState state) async {
    final providers = await state.repo.providers();
    final rentals = await state.repo.allRentals();
    final equipment = await Future.wait([for (final p in providers) state.repo.providerEquipment(p.id)]);
    final today = dateOnly(DateTime.now());
    return [
      for (final (i, p) in providers.indexed)
        (p, [for (final e in equipment[i]) GearStatus.of(e, rentals, today)]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Status Alat Hari Ini')),
      body: AsyncView<List<(ProviderProfile, List<GearStatus>)>>(
        load: () => _load(state),
        builder: (context, stores) {
          final all = [for (final (_, items) in stores) ...items];
          int sum(int Function(GearStatus s) pick) => all.fold(0, (total, s) => total + pick(s));
          return ReadableListView(
            maxWidth: 720,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Count('Sedang disewa', sum((s) => s.rented), Colors.blue.shade800),
                      _Count('Dipesan hari ini', sum((s) => s.booked), Colors.orange.shade800),
                      _Count('Tersedia', sum((s) => s.available), Colors.green.shade800),
                      _Count('Total unit', sum((s) => s.total), Colors.black87),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hanya alat yang sedang dipakai'),
                value: _onlyInUse,
                onChanged: (v) => setState(() => _onlyInUse = v),
              ),
              for (final (p, items) in stores) ...[
                if (items.where((s) => !_onlyInUse || s.rented + s.booked > 0) case final shown when shown.isNotEmpty) ...[
                  SectionTitle('${p.businessName} · ${p.status.label}'),
                  for (final s in shown) _GearTile(status: s),
                ],
              ],
              if (_onlyInUse && all.every((s) => s.rented + s.booked == 0))
                const Text('Tidak ada alat yang sedang disewa atau dipesan hari ini.',
                    style: TextStyle(color: Colors.black54)),
            ],
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );
}

class _GearTile extends StatelessWidget {
  const _GearTile({required this.status});

  final GearStatus status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final e = s.equipment;
    return Card(
      child: ListTile(
        leading: ItemThumb(photo: e.photos.firstOrNull, categoryId: e.categoryId, size: 44),
        title: Text(e.name),
        subtitle: Text([
          '${s.available}/${s.total} tersedia',
          if (s.rented > 0) '${s.rented} disewa',
          if (s.booked > 0) '${s.booked} dipesan',
          if (!e.isActive) 'disembunyikan',
          if (s.lastDamage case final d?) 'rusak terakhir ${tanggal(d.returnedAt!)}',
        ].join(' · ')),
        trailing: Pill(
          s.available == 0 ? 'Habis' : (s.rented > 0 ? 'Sebagian disewa' : 'Tersedia'),
          color: s.available == 0
              ? Colors.red.shade700
              : (s.rented > 0 ? Colors.blue.shade800 : Colors.green.shade800),
        ),
      ),
    );
  }
}
