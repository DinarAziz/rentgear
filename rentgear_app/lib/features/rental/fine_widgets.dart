import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/fines.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

const _hint = TextStyle(fontSize: 13, color: Colors.black54);

/// Denda pada detail transaksi: perkiraan selama masih terlambat, lalu rincian
/// akhir dan nasib deposit setelah alat diterima kembali.
class FineSection extends StatelessWidget {
  const FineSection({super.key, required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final now = DateTime.now();
    final days = r.lateDaysAt(now);
    final returned = r.returnedAt != null;
    final notes = [
      if (r.damageNote case final note? when note.isNotEmpty)
        'Catatan penyedia: $note',
      ?r.reviewReason,
      if (r.reviewNote case final note? when note.isNotEmpty)
        'Keputusan admin: $note',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(returned ? 'Denda dan deposit' : 'Denda berjalan'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: returned
                  ? [
                      InfoRow('Kondisi alat', r.returnCondition?.label ?? '-'),
                      InfoRow(
                        'Denda terlambat',
                        r.lateFee > 0
                            ? '${rupiah(r.lateFee)} ($days hari)'
                            : 'Tidak ada',
                      ),
                      InfoRow(
                        'Denda kerusakan',
                        r.damageFee > 0 ? rupiah(r.damageFee) : 'Tidak ada',
                      ),
                      if (r.damageReview != DamageReview.none)
                        InfoRow('Status denda kerusakan', r.damageReview.label),
                      const Divider(),
                      if (r.fineShortfall > 0)
                        InfoRow(
                          'Kekurangan dibayar penyewa',
                          rupiah(r.fineShortfall),
                          bold: true,
                        )
                      else
                        InfoRow(
                          'Deposit kembali',
                          rupiah(r.depositRefund),
                          bold: true,
                        ),
                      for (final note in notes) ...[
                        const SizedBox(height: 6),
                        Text(note, style: _hint),
                      ],
                    ]
                  : [
                      InfoRow('Terlambat', '$days hari'),
                      InfoRow(
                        'Perkiraan denda',
                        rupiah(r.lateFeeAt(now)),
                        bold: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Denda bertambah ${kali(r.finePolicy.lateMultiplier)} tarif harian '
                        'untuk tiap hari terlambat, sampai alat dikembalikan.',
                        style: _hint,
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

typedef ReturnCheck = ({
  ReturnCondition condition,
  double damageFee,
  String? note,
});

/// Penyedia memeriksa alat yang kembali: kondisi, denda kerusakan, catatan.
/// `null` bila dibatalkan.
Future<ReturnCheck?> askReturnCheck(BuildContext context, Rental rental) {
  dismissKeyboard();
  return showDialog<ReturnCheck>(
    context: context,
    builder: (_) => _ReturnCheckDialog(rental: rental),
  );
}

class _ReturnCheckDialog extends StatefulWidget {
  const _ReturnCheckDialog({required this.rental});

  final Rental rental;

  @override
  State<_ReturnCheckDialog> createState() => _ReturnCheckDialogState();
}

class _ReturnCheckDialogState extends State<_ReturnCheckDialog> {
  final _fee = TextEditingController();
  final _note = TextEditingController();
  var _condition = ReturnCondition.good;

  @override
  void dispose() {
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    final damaged = _condition != ReturnCondition.good;
    final fee = damaged ? (parseRibuan(_fee.text) ?? 0) : 0.0;
    final error = damageFeeError(_condition, fee, r.depositTotal);
    final now = DateTime.now();
    final days = r.lateDaysAt(now);

    return AlertDialog(
      title: const Text('Terima pengembalian'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periksa ${r.itemLabel}, lalu pilih kondisinya.'),
            if (days > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Terlambat $days hari. Denda terlambat '
                '${rupiah(r.lateFeeAt(now))} dihitung otomatis.',
                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in ReturnCondition.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _condition == c,
                    // Nominal diisi dari pedoman toko; penyedia boleh mengubahnya.
                    onSelected: (_) => setState(() {
                      _condition = c;
                      final guide = r.finePolicy.guidelineFee(
                        c,
                        r.depositTotal,
                      );
                      _fee.text = guide > 0 ? ribuan(guide) : '';
                    }),
                  ),
              ],
            ),
            if (damaged) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                inputFormatters: [RibuanInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Denda kerusakan',
                  prefixText: 'Rp ',
                  helperText:
                      'Pedoman toko untuk ${_condition.label.toLowerCase()}: '
                      '${rupiah(r.finePolicy.guidelineFee(_condition, r.depositTotal))}. '
                      'Maksimal ${rupiah(r.depositTotal)} (sebesar deposit). '
                      'Di atas ${rupiah(r.depositTotal * damageReviewShare)} ditinjau admin.',
                  helperMaxLines: 5,
                  errorText: _fee.text.isEmpty ? null : error,
                  errorMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan kerusakan',
                  hintText: 'Mis. flysheet sobek 5 cm',
                ),
              ),
            ],
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
          onPressed: error != null
              ? null
              : () => Navigator.pop(context, (
                  condition: _condition,
                  damageFee: fee,
                  note: damaged ? _note.text.trim() : null,
                )),
          child: const Text('Terima alat'),
        ),
      ],
    );
  }
}

typedef DamageDecision = ({double amount, String? note});

/// Admin menetapkan nominal akhir denda kerusakan. `null` bila dibatalkan.
Future<DamageDecision?> askDamageDecision(BuildContext context, Rental rental) {
  dismissKeyboard();
  return showDialog<DamageDecision>(
    context: context,
    builder: (_) => _DamageDecisionDialog(rental: rental),
  );
}

class _DamageDecisionDialog extends StatefulWidget {
  const _DamageDecisionDialog({required this.rental});

  final Rental rental;

  @override
  State<_DamageDecisionDialog> createState() => _DamageDecisionDialogState();
}

class _DamageDecisionDialogState extends State<_DamageDecisionDialog> {
  late final _amount = TextEditingController(
    text: ribuan(widget.rental.damageFee),
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    final amount = parseRibuan(_amount.text);
    final valid = amount != null && amount <= r.depositTotal;

    return AlertDialog(
      title: const Text('Putuskan denda kerusakan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Penyedia mengusulkan ${rupiah(r.damageFee)} untuk kondisi '
              '"${r.returnCondition?.label ?? '-'}".',
            ),
            if (r.reviewReason != null) ...[
              const SizedBox(height: 6),
              Text(r.reviewReason!, style: _hint),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Denda akhir',
                prefixText: 'Rp ',
                helperText:
                    'Isi 0 untuk membatalkan denda. Maksimal ${rupiah(r.depositTotal)}.',
                helperMaxLines: 2,
                errorText: valid || amount == null ? null : 'Melebihi deposit.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan keputusan'),
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
          onPressed: valid
              ? () => Navigator.pop(context, (
                  amount: amount,
                  note: _note.text.trim(),
                ))
              : null,
          child: const Text('Tetapkan'),
        ),
      ],
    );
  }
}

/// "1,5 kali", "2 kali".
String kali(double multiplier) {
  final text = multiplier == multiplier.roundToDouble()
      ? multiplier.toStringAsFixed(0)
      : multiplier.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kali';
}

/// Aturan denda toko, ditampilkan ke penyewa sebelum memesan.
class FinePolicyInfo extends StatelessWidget {
  const FinePolicyInfo({super.key, required this.policy});

  final FinePolicy policy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            'Terlambat, per hari',
            '${kali(policy.lateMultiplier)} tarif harian',
          ),
          InfoRow(
            'Masa tenggang',
            policy.graceHours == 0 ? 'Tidak ada' : '${policy.graceHours} jam',
          ),
          const Divider(),
          InfoRow(
            'Rusak ringan',
            'sekitar ${policy.minorDamagePercent}% deposit',
          ),
          InfoRow(
            'Rusak berat',
            'sekitar ${policy.majorDamagePercent}% deposit',
          ),
          InfoRow('Hilang', 'sekitar ${policy.lostPercent}% deposit'),
          const SizedBox(height: 6),
          const Text(
            'Denda kerusakan ditetapkan toko saat alat kembali dan tidak pernah '
            'melebihi deposit. Anda bisa mengajukan keberatan ke admin. Aturan '
            'ini dikunci saat Anda memesan.',
            style: _hint,
          ),
        ],
      ),
    ),
  );
}
