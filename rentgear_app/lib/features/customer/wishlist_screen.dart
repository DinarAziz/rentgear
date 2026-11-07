import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'equipment_cards.dart';

/// Alat yang disimpan penyewa untuk disewa nanti.
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  Future<List<Equipment>> _load(AppState state) async {
    final ids = await state.repo.wishlist(state.currentUser.id);
    final items = <Equipment>[];
    for (final id in ids) {
      try {
        items.add(await state.repo.equipment(id));
      } on AppException {
        // Alat yang sudah dihapus toko dilewati saja.
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Favorit')),
      body: AsyncView<List<Equipment>>(
        load: () => _load(state),
        builder: (context, items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.favorite_border,
                message: 'Belum ada alat favorit. Ketuk ikon hati di halaman alat untuk menyimpannya.',
              )
            : LayoutBuilder(
                builder: (context, c) => EquipmentCollection(items: items, width: c.maxWidth),
              ),
      ),
    );
  }
}

/// Ikon hati di halaman alat, hanya untuk penyewa.
class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    if (state.currentUser.role != UserRole.customer) return const SizedBox.shrink();
    return AsyncView<List<String>>(
      load: () => state.repo.wishlist(state.currentUser.id),
      builder: (context, ids) {
        final saved = ids.contains(equipmentId);
        return IconButton(
          tooltip: saved ? 'Hapus dari favorit' : 'Simpan ke favorit',
          icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? Colors.red : null),
          onPressed: () => state.run((repo) => repo.setWishlist(equipmentId, state.currentUser, saved: !saved)),
        );
      },
    );
  }
}
