import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/guarantee.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Provider mengatur jenis dan jumlah jaminan yang diminta dari penyewa.
class ProviderPolicyScreen extends StatelessWidget {
  const ProviderPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Aturan Jaminan')),
      body: AsyncView<ProviderProfile>(
        load: () => state.repo.provider(state.currentUser.providerId!),
        builder: (context, p) => _PolicyForm(key: ValueKey(p.policy), profile: p),
      ),
    );
  }
}

class _PolicyForm extends StatefulWidget {
  const _PolicyForm({super.key, required this.profile});
  final ProviderProfile profile;

  @override
  State<_PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends State<_PolicyForm> {
  late GuaranteePolicy _policy = widget.profile.policy;
  late final _threshold = TextEditingController(
      text: ribuan(_policy.highValueThreshold));

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  /// "Ijazah dan Paspor" — hanya dokumen sulit diganti yang dipilih.
  String _hardToReplaceLabels() {
    final labels = [
      for (final t in GuaranteeType.values)
        if (t.isHardToReplace && _policy.acceptedTypes.contains(t)) t.label,
    ];
    if (labels.length == 1) return labels.first;
    return '${labels.sublist(0, labels.length - 1).join(', ')} dan ${labels.last}';
  }

  Widget _count(String label, int value, ValueChanged<int> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            SegmentedButton<int>(
              segments: [
                for (var i = 1; i <= GuaranteePolicy.maxPerBooking; i++)
                  ButtonSegment(value: i, label: Text('$i')),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        ),
      );

  Future<void> _save() async {
    final threshold = parseRibuan(_threshold.text);
    if (threshold == null || threshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batas nilai sewa harus angka positif.')));
      return;
    }
    final state = context.read<AppState>();
    await runAction(
      context,
      () => state.run((repo) => repo.updateGuaranteePolicy(
          widget.profile.id, _policy.copyWith(highValueThreshold: threshold), state.currentUser)),
      success: 'Aturan jaminan disimpan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReadableListView(
      children: [
        const Text(
          'Penyewa wajib menyerahkan dokumen asli sebagai jaminan saat mengambil alat. '
          'Pilih dokumen yang Anda terima.',
          style: TextStyle(color: Colors.black54),
        ),
        const SectionTitle('Jenis dokumen yang diterima'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in GuaranteeType.values)
              FilterChip(
                label: Text(t.label),
                tooltip: t.fullName,
                selected: _policy.acceptedTypes.contains(t),
                onSelected: (on) => setState(() {
                  final types = {..._policy.acceptedTypes};
                  on ? types.add(t) : types.remove(t);
                  _policy = _policy.copyWith(acceptedTypes: types);
                }),
              ),
          ],
        ),
        if (_policy.acceptedTypes.any((t) => t.isHardToReplace))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_hardToReplaceLabels()} sulit diurus ulang. Bila hilang saat Anda pegang, '
              'Anda bertanggung jawab. Simpan di tempat terkunci.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        const SectionTitle('Jumlah jaminan'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _count('Sewa biasa', _policy.baseRequired,
                    (v) => setState(() => _policy = _policy.copyWith(baseRequired: v))),
                _count('Sewa bernilai tinggi', _policy.highValueRequired,
                    (v) => setState(() => _policy = _policy.copyWith(highValueRequired: v))),
                const SizedBox(height: 8),
                TextField(
                  controller: _threshold,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Batas sewa bernilai tinggi',
                    prefixText: 'Rp ',
                    helperText: 'Total sewa + deposit di atas nilai ini memakai jumlah "bernilai tinggi"',
                    helperMaxLines: 2,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contoh: sewa ${rupiah(parseRibuan(_threshold.text) ?? 0)} ke atas wajib '
                    '${_policy.requiredCount(double.infinity)} jaminan.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
