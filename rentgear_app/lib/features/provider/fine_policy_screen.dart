import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/fines.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../rental/fine_widgets.dart';

/// Penyedia mengatur aturan denda tokonya dalam batas platform.
class FinePolicyScreen extends StatefulWidget {
  const FinePolicyScreen({super.key, required this.provider});

  final ProviderProfile provider;

  @override
  State<FinePolicyScreen> createState() => _FinePolicyScreenState();
}

class _FinePolicyScreenState extends State<FinePolicyScreen> {
  late FinePolicy _policy = widget.provider.finePolicy;

  /// Contoh hitungan memakai angka yang mudah dibayangkan.
  static const double _examplePrice = 50000;
  static const double _exampleDeposit = 100000;

  Future<void> _save() async {
    final state = context.read<AppState>();
    final ok = await runAction(
      context,
      () => state.run(
        (repo) => repo.updateFinePolicy(
          widget.provider.id,
          _policy,
          state.currentUser,
        ),
      ),
      success: 'Aturan denda disimpan.',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _policy;
    final error = p.error;
    final changed = p != widget.provider.finePolicy;
    return Scaffold(
      appBar: AppBar(title: const Text('Aturan Denda')),
      body: ReadableListView(
        children: [
          const Text(
            'Aturan ini tampil ke penyewa sebelum memesan dan berlaku untuk '
            'booking berikutnya. Sewa yang sudah dipesan tetap memakai aturan '
            'saat dipesan.',
            style: TextStyle(color: Colors.black54),
          ),
          const SectionTitle('Terlambat mengembalikan'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slider(
                    label: 'Denda per hari terlambat',
                    value: '${kali(p.lateMultiplier)} tarif harian',
                    min: FinePolicy.minLateMultiplier,
                    max: FinePolicy.maxLateMultiplier,
                    divisions: 10,
                    current: p.lateMultiplier,
                    onChanged: (v) => _policy = p.copyWith(
                      lateMultiplier: (v * 10).round() / 10,
                    ),
                  ),
                  _slider(
                    label: 'Masa tenggang',
                    value: p.graceHours == 0
                        ? 'Tidak ada'
                        : '${p.graceHours} jam setelah hari terakhir',
                    min: 0,
                    max: FinePolicy.maxGraceHours.toDouble(),
                    divisions: FinePolicy.maxGraceHours,
                    current: p.graceHours.toDouble(),
                    onChanged: (v) =>
                        _policy = p.copyWith(graceHours: v.round()),
                  ),
                  Text(
                    'Contoh: alat ${rupiah(_examplePrice)} per hari, telat 2 hari, '
                    'dendanya ${rupiah(p.lateFee(pricePerDay: _examplePrice, qty: 1, days: 2))}.',
                    style: _hint,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SectionTitle('Pedoman denda kerusakan'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _percent(
                    'Rusak ringan',
                    p.minorDamagePercent,
                    (v) => p.copyWith(minorDamagePercent: v),
                  ),
                  _percent(
                    'Rusak berat',
                    p.majorDamagePercent,
                    (v) => p.copyWith(majorDamagePercent: v),
                  ),
                  _percent(
                    'Hilang',
                    p.lostPercent,
                    (v) => p.copyWith(lostPercent: v),
                  ),
                  const Text(
                    'Pedoman menjadi isian awal saat Anda menerima alat kembali. '
                    'Anda tetap bisa mengubah nominalnya sesuai kerusakan, paling '
                    'tinggi sebesar deposit. Denda di atas separuh deposit '
                    'ditinjau admin.',
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
                  child: const Text('Simpan aturan denda'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _hint = TextStyle(fontSize: 13, color: Colors.black54);

  Widget _percent(String label, int value, FinePolicy Function(int) apply) =>
      _slider(
        label: label,
        value:
            '$value% deposit (${rupiah(_exampleDeposit * value / 100)} dari '
            'deposit ${rupiah(_exampleDeposit)})',
        min: 0,
        max: 100,
        divisions: 20,
        current: value.toDouble(),
        onChanged: (v) => _policy = apply(v.round()),
      );

  Widget _slider({
    required String label,
    required String value,
    required double min,
    required double max,
    required int divisions,
    required double current,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(value, style: _hint),
      Slider(
        value: current,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    ],
  );
}
