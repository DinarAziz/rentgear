import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../provider/store_location_screen.dart';
import 'photo_credits_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    // Saat logout, layar ini masih dibangun sekali sebelum diganti login.
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ReadableListView(
        maxWidth: 640,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.forest,
                    child: Text(user.name[0],
                        style: const TextStyle(color: Colors.white, fontSize: 22)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(user.role.label, style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (user.providerId case final providerId?) ...[
            const SizedBox(height: 12),
            AsyncView<ProviderProfile>(
              load: () => state.repo.provider(providerId),
              builder: (context, p) => Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(p.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      // Status di bawah alamat, supaya nama toko tidak terpotong di HP.
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.address),
                          const SizedBox(height: 6),
                          Pill(p.status.label,
                              color: switch (p.status) {
                                ProviderStatus.verified => Colors.green.shade800,
                                ProviderStatus.pending => Colors.orange.shade800,
                                ProviderStatus.rejected => Colors.red.shade700,
                              }),
                        ],
                      ),
                    ),
                    if (p.bankAccount case final bank?)
                      ListTile(
                        leading: const Icon(Icons.account_balance_outlined),
                        title: Text(bank),
                      ),
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Lokasi toko di peta'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => StoreLocationScreen(provider: p)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.mail_outline), title: Text(user.email)),
                ListTile(leading: const Icon(Icons.phone_outlined), title: Text(user.phone)),
                ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(user.city)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Kredit foto'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PhotoCreditsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Keluar dari akun?',
                message: 'Anda perlu masuk lagi untuk memakai aplikasi. Data di HP ini tetap tersimpan.',
                confirmLabel: 'Keluar',
              );
              if (ok && context.mounted) context.read<AppState>().logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
          if (state.canResetDemo) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Reset data demo?',
                  message: 'Semua transaksi, foto jaminan, dan pengaturan yang tersimpan di HP ini '
                      'akan dihapus dan diganti data demo awal.',
                  confirmLabel: 'Reset',
                );
                if (ok) await state.resetDemo();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset data demo'),
            ),
          ],
        ],
      ),
    );
  }
}
