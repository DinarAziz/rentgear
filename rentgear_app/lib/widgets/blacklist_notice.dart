import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../state/app_state.dart';

/// Pemberitahuan untuk penyewa yang masuk blacklist. Tidak memakan tempat
/// selama memuat atau bila penyewa tidak di-blacklist.
class BlacklistNotice extends StatefulWidget {
  const BlacklistNotice({super.key});

  @override
  State<BlacklistNotice> createState() => _BlacklistNoticeState();
}

class _BlacklistNoticeState extends State<BlacklistNotice> {
  Future<BlacklistEntry?>? _future;
  int? _revision;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final revision = context.select<AppState, int>((s) => s.revision);
    if (revision != _revision) {
      _revision = revision;
      _future = state.repo.blacklistOf(state.currentUser.id);
    }
    return FutureBuilder<BlacklistEntry?>(
      future: _future,
      builder: (context, snap) {
        final entry = snap.data;
        if (entry == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            'Akun Anda masuk blacklist, jadi belum bisa membuat booking baru. '
            'Alasan: ${entry.reason} Hubungi admin untuk peninjauan.',
            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
          ),
        );
      },
    );
  }
}
