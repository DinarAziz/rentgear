import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/fines.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Riwayat tiap penyewa dan tombol blacklist untuk admin.
class AdminCustomersScreen extends StatelessWidget {
  const AdminCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Penyewa')),
      body: AsyncView<List<CustomerRecord>>(
        load: () => state.repo.customers(state.currentUser),
        builder: (context, records) => ResponsiveCardList(
          itemCount: records.length,
          itemBuilder: (context, i) => FadeSlideIn(
            delay: FadeSlideIn.stagger(i),
            child: _CustomerCard(record: records[i]),
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.record});

  final CustomerRecord record;

  Future<void> _block(BuildContext context) async {
    final state = context.read<AppState>();
    final reason = await askReason(
      context,
      title: 'Blacklist ${record.user.name}',
      hint: 'Mis. tidak mengembalikan alat',
    );
    if (reason == null || !context.mounted) return;
    await runAction(
      context,
      () => state.run(
        (repo) => repo.setBlacklist(
          record.user.id,
          state.currentUser,
          blocked: true,
          reason: reason,
        ),
      ),
      success: '${record.user.name} masuk blacklist.',
    );
  }

  Future<void> _risk(BuildContext context) {
    final state = context.read<AppState>();
    return showAiDialog<AiRisk>(
      context,
      title: 'Risiko ${record.user.name}',
      load: () => state.repo.aiCustomerRisk(record.user.id, state.currentUser),
      builder: (context, risk) => [
        Pill(
          'Risiko ${risk.level}',
          color: switch (risk.level) {
            'tinggi' => Colors.red.shade700,
            'sedang' => Colors.orange.shade800,
            _ => Colors.green.shade800,
          },
        ),
        const SizedBox(height: 10),
        Text(risk.summary),
        const SizedBox(height: 8),
        for (final factor in risk.factors)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $factor', style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  Future<void> _unblock(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'Cabut blacklist ${record.user.name}?',
      message:
          'Penyewa ini bisa membuat booking lagi. Hitungan pelanggaran untuk '
          'blacklist otomatis mulai dari awal.',
      confirmLabel: 'Cabut',
    );
    if (!ok || !context.mounted) return;
    await runAction(
      context,
      () => state.run(
        (repo) => repo.setBlacklist(
          record.user.id,
          state.currentUser,
          blocked: false,
        ),
      ),
      success: 'Blacklist ${record.user.name} dicabut.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = record;
    final blocked = c.blacklist;
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
                    c.user.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusCrossfade(
                  value: blocked != null,
                  child: blocked != null
                      ? Pill('Blacklist', color: Colors.red.shade700)
                      : Pill(
                          c.violations == 0
                              ? 'Bersih'
                              : '${c.violations} pelanggaran',
                          color: c.violations == 0
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                ),
              ],
            ),
            Text(
              '${c.user.email}, ${c.user.city}',
              style: const TextStyle(color: Colors.black54),
            ),
            const Divider(height: 20),
            InfoRow('Jumlah sewa', '${c.rentalCount}'),
            InfoRow('Terlambat', '${c.lateCount} kali'),
            InfoRow('Tidak diambil', '${c.noShowCount} kali'),
            InfoRow('Merusak alat', '${c.damageCount} kali'),
            InfoRow('Total denda', rupiah(c.fineTotal)),
            if (blocked != null) ...[
              const SizedBox(height: 6),
              Text(
                'Blacklist oleh ${blocked.by}, ${tanggal(blocked.at)}. ${blocked.reason}',
                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
              ),
            ] else if (c.violations > 0) ...[
              const SizedBox(height: 6),
              const Text(
                'Blacklist otomatis berlaku pada $autoBlacklistAfter pelanggaran.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            if (context.read<AppState>().repo.isRemote) ...[
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Analisis risiko AI'),
                  onPressed: () => _risk(context),
                ),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    blocked != null ? _unblock(context) : _block(context),
                child: Text(
                  blocked != null ? 'Cabut blacklist' : 'Masukkan blacklist',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
