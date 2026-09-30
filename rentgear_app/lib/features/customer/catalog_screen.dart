import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/photo_widgets.dart';
import 'equipment_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Tunggu pengguna berhenti mengetik agar tidak mencari tiap huruf.
  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${state.currentUser.name.split(' ').first}'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          // Di layar lebar pencarian, chip, dan grid sejajar dalam satu kolom tengah.
          final gutter = centeredPadding(c.maxWidth, maxWidth: _maxWidth);
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter.left, 0, gutter.right, 8),
                child: ListenableBuilder(
                  listenable: _search,
                  builder: (context, _) => TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari tenda, carrier, merek…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _debounce?.cancel();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: _onSearch,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: AsyncView<List<Category>>(
                  load: state.repo.categories,
                  builder: (context, cats) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: gutter.left),
                    children: [
                      _chip('Semua', null),
                      for (final c in cats) _chip(c.name, c.id),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AsyncView<List<Equipment>>(
                  deps: (_query, _categoryId),
                  load: () => state.repo.searchEquipment(
                    query: _query,
                    categoryId: _categoryId,
                  ),
                  builder: (context, items) {
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: Icons.search_off,
                        message: _query.isEmpty
                            ? 'Belum ada alat di kategori ini.'
                            : 'Tidak ada alat yang cocok dengan "$_query".',
                      );
                    }
                    if (FormFactor.fromWidth(c.maxWidth) != FormFactor.phone) {
                      return _grid(context, items, gutter, c.maxWidth);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => FadeSlideIn(
                        delay: FadeSlideIn.stagger(i),
                        child: _EquipmentCard(items[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const double _maxWidth = 1280;

  /// Tablet dan desktop: grid kartu berfoto besar, 2–5 kolom sesuai lebar.
  Widget _grid(
    BuildContext context,
    List<Equipment> items,
    EdgeInsets gutter,
    double width,
  ) {
    const gap = 14.0;
    final inner = width - gutter.horizontal;
    final columns = ((inner + gap) / (220 + gap)).floor().clamp(2, 5);
    final cellWidth = (inner - gap * (columns - 1)) / columns;
    // Foto 4:3 + blok teks yang ikut membesar dengan ukuran huruf sistem.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(gutter.left, 8, gutter.right, 24),
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
        child: _EquipmentTile(items[i]),
      ),
    );
  }

  Widget _chip(String label, String? id) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _categoryId == id,
      onSelected: (_) => setState(() => _categoryId = id),
    ),
  );
}

void _openDetail(BuildContext context, Equipment e) {
  dismissKeyboard();
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EquipmentDetailScreen(equipmentId: e.id),
    ),
  );
}

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
class _EquipmentTile extends StatelessWidget {
  const _EquipmentTile(this.e);
  final Equipment e;

  @override
  Widget build(BuildContext context) {
    final photo = e.photos.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context, e),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
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

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard(this.e);
  final Equipment e;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context, e),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
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
