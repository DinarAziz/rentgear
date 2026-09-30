import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/availability.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/photo_widgets.dart';
import 'equipment_form_screen.dart';

class ProviderEquipmentScreen extends StatelessWidget {
  const ProviderEquipmentScreen({super.key});

  Future<List<(Equipment, int)>> _load(AppState state) async {
    final items = await state.repo.providerEquipment(
      state.currentUser.providerId!,
    );
    final today = dateOnly(DateTime.now());
    return [
      for (final e in items)
        (e, await state.repo.availableQty(e.id, today, today)),
    ];
  }

  void _open(BuildContext context, [Equipment? e]) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => EquipmentFormScreen(initial: e)),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alat Saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah alat'),
      ),
      body: AsyncView<List<(Equipment, int)>>(
        load: () => _load(state),
        builder: (context, items) => items.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Belum ada alat. Tambahkan alat pertama Anda.',
                action: TextButton(
                  onPressed: () => _open(context),
                  child: const Text('Tambah alat'),
                ),
              )
            : ResponsiveCardList(
                bottomPadding: 96,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final (e, available) = items[i];
                  return FadeSlideIn(
                    delay: FadeSlideIn.stagger(i),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(context, e),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: e.isActive ? 1 : 0.4,
                                child: ItemThumb(
                                  photo: e.photos.firstOrNull,
                                  categoryId: e.categoryId,
                                  size: 64,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${rupiah(e.pricePerDay)}/hari · deposit ${rupiah(e.depositAmount)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (e.hasSizes)
                                      Text(
                                        'Ukuran: ${e.sizes.map((s) => '${s.label}(${s.stock})').join(' ')}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    if (!e.isActive)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Pill(
                                          'Disembunyikan',
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$available/${e.stockTotal}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Text(
                                    'tersedia\nhari ini',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
