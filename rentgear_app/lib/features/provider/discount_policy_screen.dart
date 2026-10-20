import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/discount.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Penyedia mengatur diskon durasi tokonya dalam batas platform.
class DiscountPolicyScreen extends StatefulWidget {
  const DiscountPolicyScreen({super.key, required this.provider});

  final ProviderProfile provider;

  @override
  State<DiscountPolicyScreen> createState() => _DiscountPolicyScreenState();
}

class _DiscountPolicyScreenState extends State<DiscountPolicyScreen> {
  late DiscountPolicy _policy = widget.provider.discountPolicy;

  /// Contoh hitungan memakai angka yang mudah dibayangkan.
  static const double _examplePrice = 50000;

  Future<void> _save() async {
    final state = context.read<AppState>();
    final ok = await runAction(
      context,
      () => state.run(
        (repo) => repo.updateDiscountPolicy(
          widget.provider.id,
          _policy,
          state.currentUser,
        ),
      ),
      success: 'Diskon disimpan.',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _policy;
    final error = p.error;
    final changed = p != widget.provider.discountPolicy;
    return Scaffold(
      appBar: AppBar(title: const Text('Diskon Sewa')),
      body: ReadableListView(
        children: [
          const Text(
            'Diskon memotong biaya sewa, bukan deposit, dan ditanggung toko. '
            'Penyewa melihatnya sebelum memesan. Sewa yang sudah dipesan tetap '
            'memakai diskon saat dipesan.',
            style: TextStyle(color: Colors.black54),
          ),
          const SectionTitle('Diskon menurut lama sewa'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slider(
                    'Sewa ${DiscountPolicy.shortDays} hari atau lebih',
                    p.shortPercent,
                    (v) => _policy = p.copyWith(shortPercent: v),
                  ),
                  _slider(
                    'Sewa ${DiscountPolicy.longDays} hari atau lebih',
                    p.longPercent,
                    (v) => _policy = p.copyWith(longPercent: v),
                  ),
                  Text(
                    'Contoh: alat ${rupiah(_examplePrice)} per hari selama '
                    '${DiscountPolicy.longDays} hari, sewanya '
                    '${rupiah(_example(DiscountPolicy.longDays))} setelah diskon. '
                    'Batas platform ${DiscountPolicy.maxPercent}%.',
                    style: _hint,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: TextStyle(color: Colors.red.shade700)),
            ),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: changed && error == null ? _save : null,
                  child: const Text('Simpan diskon'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _example(int days) {
    final rent = _examplePrice * days;
    return rent - discountAmount(rent, _policy.percentFor(days));
  }

  static const _hint = TextStyle(fontSize: 13, color: Colors.black54);

  Widget _slider(String label, int value, ValueChanged<int> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            value == 0 ? 'Tanpa diskon' : 'Diskon $value% biaya sewa',
            style: _hint,
          ),
          Slider(
            value: value.toDouble(),
            max: DiscountPolicy.maxPercent.toDouble(),
            divisions: DiscountPolicy.maxPercent ~/ 5,
            onChanged: (v) => setState(() => onChanged(v.round())),
          ),
        ],
      );
}

/// Diskon toko pada halaman alat, untuk penyewa.
class DiscountPolicyInfo extends StatelessWidget {
  const DiscountPolicyInfo({super.key, required this.policy});

  final DiscountPolicy policy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (policy.shortPercent > 0)
            InfoRow(
              'Sewa ${DiscountPolicy.shortDays} hari atau lebih',
              'hemat ${policy.shortPercent}%',
            ),
          if (policy.longPercent > 0)
            InfoRow(
              'Sewa ${DiscountPolicy.longDays} hari atau lebih',
              'hemat ${policy.longPercent}%',
            ),
          const SizedBox(height: 6),
          const Text(
            'Diskon memotong biaya sewa, bukan deposit, dan terhitung otomatis '
            'saat Anda memilih tanggal.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
