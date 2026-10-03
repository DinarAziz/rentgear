import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'equipment_detail_screen.dart';

/// Penyewa menulis rencana perjalanan, AI menyarankan paket alat dari
/// katalog. Hanya saran: penyewa tetap memilih dan memesan sendiri.
class AiRecommendScreen extends StatefulWidget {
  const AiRecommendScreen({super.key});

  @override
  State<AiRecommendScreen> createState() => _AiRecommendScreenState();
}

class _AiRecommendScreenState extends State<AiRecommendScreen> {
  final _trip = TextEditingController();
  int _people = 2;
  int _days = 2;
  bool _loading = false;
  String? _error;
  AiRecommendation? _result;

  static const _examples = [
    'Semeru lewat Ranu Pane, musim hujan',
    'Camping keluarga di Ranu Kumbolo',
    'Tektok Gunung Arjuno, tidak menginap',
  ];

  @override
  void dispose() {
    _trip.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    dismissKeyboard();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AppState>().repo.aiRecommend(
        trip: _trip.text.trim(),
        people: _people,
        days: _days,
      );
      if (mounted) setState(() => _result = result);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Saran Paket Alat')),
      body: ReadableListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Ceritakan rencana perjalanan Anda. AI akan memilihkan alat dari '
            'katalog RentGear.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _trip,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _trip,
                  maxLines: 2,
                  maxLength: 300,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Rencana perjalanan',
                    hintText: 'Mis. Semeru 3 hari, musim hujan, masak sendiri',
                  ),
                ),
                if (_trip.text.isEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final example in _examples)
                        ActionChip(
                          label: Text(example),
                          onPressed: () => _trip.text = example,
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _Stepper(
                          label: 'Jumlah orang',
                          value: _people,
                          max: 20,
                          onChanged: (v) => setState(() => _people = v),
                        ),
                        _Stepper(
                          label: 'Lama sewa (hari)',
                          value: _days,
                          max: 14,
                          onChanged: (v) => setState(() => _days = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _loading ? 'AI sedang memilih…' : 'Minta saran AI',
                  ),
                  onPressed: _loading || _trip.text.trim().length < 3
                      ? null
                      : _ask,
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '$_error Anda tetap bisa memilih alat sendiri dari katalog.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          if (result != null) ..._resultWidgets(context, result),
        ],
      ),
    );
  }

  List<Widget> _resultWidgets(BuildContext context, AiRecommendation r) => [
    SectionTitle('Saran untuk ${r.people} orang, ${r.days} hari'),
    Text(r.summary),
    const SizedBox(height: 12),
    if (r.items.isEmpty)
      const Text(
        'AI tidak menemukan alat yang cocok di katalog.',
        style: TextStyle(color: Colors.black54),
      ),
    for (final pick in r.items)
      Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(
            '${pick.name} × ${pick.qty}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${pick.reason}\n${pick.providerName}, ${pick.city}'),
          isThreeLine: true,
          trailing: Text(
            rupiah(pick.rentCost),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  EquipmentDetailScreen(equipmentId: pick.equipmentId),
            ),
          ),
        ),
      ),
    if (r.items.isNotEmpty) ...[
      const SizedBox(height: 4),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              InfoRow('Perkiraan sewa ${r.days} hari', rupiah(r.rentTotal)),
              InfoRow('Deposit (dikembalikan)', rupiah(r.depositTotal)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Ketuk alat untuk melihat detail dan memesan. Tiap alat dipesan '
        'terpisah, dan stok dicek lagi pada tanggal yang Anda pilih.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
    ],
    if (r.tips.isNotEmpty) ...[
      const SectionTitle('Yang perlu disiapkan sendiri'),
      for (final tip in r.tips)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.check, size: 18, color: Colors.black54),
              ),
              Expanded(child: Text(tip)),
            ],
          ),
        ),
    ],
    const SizedBox(height: 12),
    const AiDisclaimer(),
  ];
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: 'Kurangi',
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
      ),
      SizedBox(
        width: 28,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      IconButton(
        tooltip: 'Tambah',
        icon: const Icon(Icons.add_circle_outline),
        onPressed: value < max ? () => onChanged(value + 1) : null,
      ),
    ],
  );
}
