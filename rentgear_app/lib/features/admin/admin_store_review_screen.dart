import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/verification_widgets.dart';

/// Admin memeriksa data toko dan dokumen pemiliknya, lalu memverifikasi atau
/// menolak dengan alasan. Toko tanpa dokumen tidak bisa diverifikasi.
class AdminStoreReviewScreen extends StatelessWidget {
  const AdminStoreReviewScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Periksa Toko')),
      body: AsyncView<(ProviderProfile, StoreVerification)>(
        load: () async => (
          await state.repo.provider(providerId),
          await state.repo.storeVerification(providerId, state.currentUser),
        ),
        builder: (context, data) {
          final (p, v) = data;
          Future<void> decide(ProviderStatus status) async {
            String? reason;
            if (status == ProviderStatus.rejected) {
              reason = await askReason(
                context,
                title: 'Tolak ${p.businessName}?',
                hint: 'Alasan, mis. foto KTP buram atau nama rekening beda',
              );
              if (reason == null) return;
            } else {
              final ok = await confirmDialog(
                context,
                title: 'Verifikasi ${p.businessName}?',
                message:
                    'Alat toko ini akan tampil di katalog dan bisa disewa. Pemilik toko mendapat email.',
                confirmLabel: 'Verifikasi',
              );
              if (!ok) return;
            }
            if (!context.mounted) return;
            await runAction(
              context,
              () => state.run(
                (repo) => repo.setProviderStatus(
                  p.id,
                  status,
                  state.currentUser,
                  reason: reason,
                ),
              ),
              success: '${p.businessName}: ${status.label}',
            );
          }

          return ReadableListView(
            maxWidth: 640,
            children: [
              VerificationStatusCard(v, forAdmin: true),
              if (v.sameOwnerStores.isNotEmpty)
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                    ),
                    title: const Text('NIK pemilik juga dipakai toko lain'),
                    subtitle: Text(v.sameOwnerStores.join(', ')),
                  ),
                ),
              const SectionTitle('Data toko'),
              InfoRow('Nama toko', p.businessName),
              InfoRow('Kota', p.city),
              InfoRow('Alamat', p.address),
              InfoRow('Rekening', p.bankAccount ?? '-'),
              if (v.nikMasked case final nik?) InfoRow('NIK pemilik', nik),
              const SectionTitle('Dokumen'),
              if (v.submitted)
                DocumentPhotos(v)
              else
                const Text('Belum dikirim.'),
              const SizedBox(height: 12),
              const Text(
                'Periksa: nama dan NIK di KTP terbaca, wajah di swafoto sama dengan foto KTP, nama rekening '
                'cocok dengan pemilik, dan foto toko menunjukkan alat yang akan disewakan.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (v.submitted && v.status == ProviderStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => decide(ProviderStatus.rejected),
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => decide(ProviderStatus.verified),
                        child: const Text('Verifikasi'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
