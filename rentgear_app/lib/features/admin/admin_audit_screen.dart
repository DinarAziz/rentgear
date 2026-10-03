import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Jejak audit untuk admin: siapa melakukan apa, kapan, pada apa. Hanya
/// bisa dibaca.
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

enum _Filter {
  all('Semua'),
  admin('Aksi admin'),
  access('Masuk dan daftar'),
  system('Sistem');

  const _Filter(this.label);
  final String label;

  static const _accessActions = {
    AuditAction.login,
    AuditAction.loginGoogle,
    AuditAction.registerGoogle,
    AuditAction.loginFailed,
  };

  bool matches(AuditEntry e) => switch (this) {
    all => true,
    admin => e.actorRole == 'admin' && !_accessActions.contains(e.action),
    access => _accessActions.contains(e.action),
    system => e.actorRole == 'system' && !_accessActions.contains(e.action),
  };
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  var _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jejak Audit')),
      body: AsyncView<List<AuditEntry>>(
        load: () => state.repo.auditLog(state.currentUser),
        builder: (context, log) {
          final entries = log.where(_filter.matches).toList();
          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(
                        icon: Icons.manage_search,
                        message: 'Belum ada jejak untuk pilihan ini.',
                      )
                    : ReadableListView(
                        children: [
                          for (final e in entries) _AuditTile(e),
                          const SizedBox(height: 8),
                          const Text(
                            'Jejak audit hanya bisa ditambah oleh sistem. '
                            'Tidak ada yang bisa mengubah atau menghapusnya dari aplikasi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile(this.entry);

  final AuditEntry entry;

  static const _roles = {
    'admin': 'Admin',
    'provider': 'Penyedia',
    'customer': 'Penyewa',
  };

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (icon, color) = switch (e.action) {
      AuditAction.loginFailed => (Icons.lock_outline, Colors.red.shade700),
      AuditAction.blacklistAdded => (Icons.block, Colors.red.shade700),
      AuditAction.blacklistRemoved => (
        Icons.lock_open_outlined,
        Colors.green.shade800,
      ),
      AuditAction.providerStatus => (
        Icons.storefront_outlined,
        Colors.blue.shade700,
      ),
      AuditAction.damageFeeDecided => (
        Icons.gavel_outlined,
        Colors.orange.shade800,
      ),
      AuditAction.aiFineOpinion || AuditAction.aiCustomerRisk => (
        Icons.auto_awesome,
        Colors.purple.shade700,
      ),
      _ => (Icons.login, Colors.black54),
    };
    final role = _roles[e.actorRole];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [AuditAction.label(e.action), ?e.target].join(': '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (e.detail case final detail?) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${role == null ? e.actorName : '${e.actorName} ($role)'} · ${tanggalJam(e.at)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
