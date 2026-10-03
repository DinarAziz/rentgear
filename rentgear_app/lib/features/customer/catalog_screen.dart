import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/maps.dart';
import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/blacklist_notice.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/photo_widgets.dart';
import 'equipment_cards.dart';
import 'provider_store_screen.dart';
import 'store_map_screen.dart';

/// Halaman awal penyewa. Tanpa kata kunci: daftar toko, seperti di aplikasi
/// belanja. Saat mengetik atau memilih kategori: alat dari semua toko.
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

  static const double _maxWidth = 1280;

  bool get _searching => _query.isNotEmpty || _categoryId != null;

  @override
  void initState() {
    super.initState();
    // Pakai lokasi hanya bila izinnya sudah pernah diberikan. Dialog izin
    // baru muncul saat pengguna menekan tombol lokasi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.locationStatus == LocationStatus.unknown) {
        state.locate(ask: false);
      }
    });
  }

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
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Peta'),
            onPressed: () {
              dismissKeyboard();
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const StoreMapScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          // Di layar lebar pencarian, chip, dan grid sejajar dalam satu kolom tengah.
          final gutter = centeredPadding(c.maxWidth, maxWidth: _maxWidth);
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter.left),
                child: const BlacklistNotice(),
              ),
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
                      _chip('Toko', null),
                      for (final c in cats) _chip(c.name, c.id),
                    ],
                  ),
                ),
              ),
              if (!_searching)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter.left, 4, gutter.right, 0),
                  child: const _LocationBar(),
                ),
              Expanded(
                child: _searching
                    ? _results(state, gutter, c.maxWidth)
                    : _StoreList(gutter: gutter),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _results(AppState state, EdgeInsets gutter, double width) =>
      AsyncView<List<Equipment>>(
        deps: (_query, _categoryId),
        load: () =>
            state.repo.searchEquipment(query: _query, categoryId: _categoryId),
        builder: (context, items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              message: _query.isEmpty
                  ? 'Belum ada alat di kategori ini.'
                  : 'Tidak ada alat yang cocok dengan "$_query".',
            );
          }
          return EquipmentCollection(
            items: items,
            width: width,
            padding: FormFactor.fromWidth(width) == FormFactor.phone
                ? const EdgeInsets.all(16)
                : EdgeInsets.fromLTRB(gutter.left, 8, gutter.right, 24),
          );
        },
      );

  Widget _chip(String label, String? id) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _categoryId == id,
      onSelected: (_) => setState(() => _categoryId = id),
    ),
  );
}

typedef _Stores = (List<ProviderProfile>, List<Equipment>, Set<String>);

class _StoreList extends StatelessWidget {
  const _StoreList({required this.gutter});

  final EdgeInsets gutter;

  Future<_Stores> _load(AppState state) async {
    final providers = await state.repo.providers();
    final followed = await state.repo.followedProviders(state.currentUser.id);
    final stores = providers
        .where((p) => p.status == ProviderStatus.verified)
        .toList();
    return (stores, await state.repo.searchEquipment(), followed);
  }

  /// Toko yang diikuti tampil lebih dulu. Sisanya urut dari yang terdekat
  /// bila lokasi pengguna diketahui, selain itu urut rating.
  static List<ProviderProfile> _ordered(
    List<ProviderProfile> stores,
    Set<String> followed,
    LatLng? user,
  ) {
    final sorted = sortStores(stores, user);
    return [
      ...sorted.where((s) => followed.contains(s.id)),
      ...sorted.where((s) => !followed.contains(s.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final user = context.select<AppState, LatLng?>((s) => s.location);
    return AsyncView<_Stores>(
      load: () => _load(state),
      builder: (context, data) {
        final (verified, equipment, followed) = data;
        final stores = _ordered(verified, followed, user);
        if (stores.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_outlined,
            message: 'Belum ada toko yang terverifikasi.',
          );
        }
        return ResponsiveCardList(
          itemCount: stores.length,
          minItemWidth: 380,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemBuilder: (context, i) {
            final store = stores[i];
            return FadeSlideIn(
              delay: FadeSlideIn.stagger(i),
              child: _StoreCard(
                store: store,
                equipment: equipment
                    .where((e) => e.providerId == store.id)
                    .toList(),
                followed: followed.contains(store.id),
                distance: user == null ? null : distanceKm(user, store.point),
              ),
            );
          },
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.equipment,
    required this.followed,
    required this.distance,
  });

  final ProviderProfile store;
  final List<Equipment> equipment;
  final bool followed;

  /// Jarak dari pengguna dalam km, `null` bila lokasinya belum diketahui.
  final double? distance;

  @override
  Widget build(BuildContext context) {
    final p = store;
    const muted = TextStyle(fontSize: 13, color: Colors.black54);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openProviderStore(context, p.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.storefront_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.businessName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          distance == null
                              ? p.city
                              : '${p.city} · ${jarak(distance!)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  if (followed)
                    Pill(
                      'Diikuti',
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.check,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.reviewCount == 0
                    ? 'Belum ada ulasan'
                    : '★ ${bintang(p.rating)} dari ${p.reviewCount} ulasan',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${p.followerCount} pengikut, ${equipment.length} alat',
                style: muted,
              ),
              if (equipment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final e in equipment.take(4)) ...[
                      ItemThumb(
                        photo: e.photos.firstOrNull,
                        categoryId: e.categoryId,
                        size: 64,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris status lokasi di atas daftar toko, dengan tombol untuk
/// mengaktifkan lokasi.
class _LocationBar extends StatelessWidget {
  const _LocationBar();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, LocationStatus>(
      (s) => s.locationStatus,
    );
    final (text, action) = switch (status) {
      LocationStatus.found => ('Toko diurutkan dari yang terdekat', null),
      LocationStatus.searching => ('Mencari lokasi Anda…', null),
      LocationStatus.unknown => (
        'Aktifkan lokasi untuk melihat toko terdekat',
        'Aktifkan',
      ),
      LocationStatus.denied => ('Izin lokasi ditolak', 'Coba lagi'),
      LocationStatus.unavailable => (
        'Lokasi tidak didapat. Nyalakan lokasi perangkat.',
        'Coba lagi',
      ),
    };
    final found = status == LocationStatus.found;
    return Row(
      children: [
        Icon(
          found ? Icons.near_me : Icons.location_off_outlined,
          size: 18,
          color: found ? Theme.of(context).colorScheme.primary : Colors.black54,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => context.read<AppState>().locate(ask: true),
            child: Text(action),
          )
        else
          const SizedBox(height: 36),
      ],
    );
  }
}
