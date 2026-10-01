import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/photo_widgets.dart';
import 'equipment_detail_screen.dart';

/// Daftar alat: kartu mendatar di HP, grid kartu berfoto besar (2–5 kolom) di
/// tablet dan desktop. [width] adalah lebar area yang tersedia.
/// [shrinkWrap] dipakai bila daftar ini berada di dalam daftar gulir lain.
class EquipmentCollection extends StatelessWidget {
  const EquipmentCollection({
    super.key,
    required this.items,
    required this.width,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  final List<Equipment> items;
  final double width;
  final EdgeInsets padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final physics = shrinkWrap ? const NeverScrollableScrollPhysics() : null;
    if (FormFactor.fromWidth(width) == FormFactor.phone) {
      return ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: FadeSlideIn.stagger(i),
          child: EquipmentCard(items[i]),
        ),
      );
    }
    const gap = 14.0;
    final inner = width - padding.horizontal;
    final columns = ((inner + gap) / (220 + gap)).floor().clamp(2, 5);
    final cellWidth = (inner - gap * (columns - 1)) / columns;
    // Foto 4:3 + blok teks yang ikut membesar dengan ukuran huruf sistem.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        mainAxisExtent: cellWidth * 3 / 4 + 112 * textScale,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: FadeSlideIn.stagger(i),
        child: EquipmentTile(items[i]),
      ),
    );
  }
}

void openEquipmentDetail(BuildContext context, Equipment e) {
  dismissKeyboard();
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EquipmentDetailScreen(equipmentId: e.id),
    ),
  );
}

const _name = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);
const _muted = TextStyle(fontSize: 13, color: Colors.black54);

Widget _price(BuildContext context, Equipment e) => Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: rupiah(e.pricePerDay),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const TextSpan(text: ' /hari', style: _muted),
    ],
  ),
);

Widget _meta(Equipment e) => Wrap(
  spacing: 10,
  children: [
    if (e.rating > 0)
      Text(
        '★ ${e.rating.toStringAsFixed(1)}',
        style: const TextStyle(fontSize: 13),
      ),
    Text(
      e.hasSizes ? 'Ukuran ${e.sizeRange}' : 'Stok ${e.stockTotal}',
      style: _muted,
    ),
  ],
);

/// Kartu vertikal untuk grid tablet/desktop: foto di atas, info di bawah.
class EquipmentTile extends StatelessWidget {
  const EquipmentTile(this.e, {super.key});
  final Equipment e;

  @override
  Widget build(BuildContext context) {
    final photo = e.photos.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEquipmentDetail(context, e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: photo == null
                  ? Center(
                      child: EquipmentThumb(categoryId: e.categoryId, size: 96),
                    )
                  : LayoutBuilder(
                      builder: (context, c) => ItemPhotoView(
                        photo,
                        decodeWidth:
                            (c.maxWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _name,
                    ),
                    Text(
                      e.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _muted,
                    ),
                    const SizedBox(height: 4),
                    _meta(e),
                    const Spacer(),
                    _price(context, e),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu mendatar untuk daftar di HP: foto kecil di kiri, info di kanan.
class EquipmentCard extends StatelessWidget {
  const EquipmentCard(this.e, {super.key});
  final Equipment e;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEquipmentDetail(context, e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ItemThumb(
                photo: e.photos.firstOrNull,
                categoryId: e.categoryId,
                size: 88,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _name,
                    ),
                    Text(e.brand, style: _muted),
                    const SizedBox(height: 4),
                    _meta(e),
                    const SizedBox(height: 6),
                    _price(context, e),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
