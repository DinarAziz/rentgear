import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/maps.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import 'provider_store_screen.dart';

/// Urutan toko: yang terdekat dulu bila lokasi pengguna diketahui, selain
/// itu menurut rating.
List<ProviderProfile> sortStores(
  Iterable<ProviderProfile> stores,
  LatLng? user,
) => stores.toList()
  ..sort(
    (a, b) => user == null
        ? b.rating.compareTo(a.rating)
        : distanceKm(user, a.point).compareTo(distanceKm(user, b.point)),
  );

/// Peta semua toko terverifikasi, dengan kartu toko yang bisa digeser.
class StoreMapScreen extends StatelessWidget {
  const StoreMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Peta Toko')),
      body: AsyncView<List<ProviderProfile>>(
        load: () async => [
          for (final p in await state.repo.providers())
            if (p.status == ProviderStatus.verified) p,
        ],
        builder: (context, stores) => stores.isEmpty
            ? const EmptyState(
                icon: Icons.storefront_outlined,
                message: 'Belum ada toko yang terverifikasi.',
              )
            : _StoreMap(stores: stores),
      ),
    );
  }
}

class _StoreMap extends StatefulWidget {
  const _StoreMap({required this.stores});

  final List<ProviderProfile> stores;

  @override
  State<_StoreMap> createState() => _StoreMapState();
}

class _StoreMapState extends State<_StoreMap> {
  final _map = MapController();
  final _pages = PageController(viewportFraction: 0.88);
  String? _selectedId;

  /// Toko dalam urutan tampil, diperbarui setiap build.
  List<ProviderProfile> _stores = const [];

  /// Lebar minimum untuk daftar toko di samping peta.
  static const double _wide = 900;

  @override
  void dispose() {
    _map.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _select(ProviderProfile store, {bool fromPager = false}) {
    setState(() => _selectedId = store.id);
    _map.move(store.point, _map.camera.zoom < 13 ? 13 : _map.camera.zoom);
    if (!fromPager && _pages.hasClients) {
      _pages.animateToPage(
        _stores.indexOf(store),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppState, LatLng?>((s) => s.location);
    final searching = context.select<AppState, bool>(
      (s) => s.locationStatus == LocationStatus.searching,
    );
    final stores = _stores = sortStores(widget.stores, user);
    final selectedId = _selectedId ?? stores.first.id;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _wide;
        final map = FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [for (final s in stores) s.point, ?user],
              // Ruang di bawah untuk kartu toko di HP.
              padding: EdgeInsets.fromLTRB(56, 72, 56, wide ? 56 : 200),
              maxZoom: 14,
            ),
            interactionOptions: mapGestures,
          ),
          children: [
            osmTileLayer(),
            MarkerLayer(
              markers: [
                if (user != null) userMarker(user),
                // Toko terpilih digambar terakhir supaya tidak tertutup.
                for (final s in stores)
                  if (s.id != selectedId)
                    storeMarker(s.point, onTap: () => _select(s)),
                for (final s in stores)
                  if (s.id == selectedId)
                    storeMarker(
                      s.point,
                      selected: true,
                      onTap: () => _select(s),
                    ),
              ],
            ),
            osmAttribution,
          ],
        );
        final locate = LocateButton(
          busy: searching,
          onPressed: () => moveMapToUser(context, _map, zoom: 13),
        );
        Widget card(ProviderProfile s) => _StoreMapCard(
          store: s,
          distance: user == null ? null : distanceKm(user, s.point),
          selected: s.id == selectedId,
          onSelect: () => _select(s),
        );

        if (wide) {
          return Row(
            children: [
              SizedBox(
                width: 360,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => card(stores[i]),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    map,
                    Positioned(right: 16, top: 16, child: locate),
                  ],
                ),
              ),
            ],
          );
        }
        return Stack(
          children: [
            map,
            Positioned(right: 16, top: 16, child: locate),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 148,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: stores.length,
                    onPageChanged: (i) => _select(stores[i], fromPager: true),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 16),
                      child: card(stores[i]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StoreMapCard extends StatelessWidget {
  const _StoreMapCard({
    required this.store,
    required this.distance,
    required this.selected,
    required this.onSelect,
  });

  final ProviderProfile store;
  final double? distance;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final p = store;
    final scheme = Theme.of(context).colorScheme;
    const muted = TextStyle(fontSize: 13, color: Colors.black54);
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        p.reviewCount == 0
                            ? 'Belum ada ulasan'
                            : '★ ${bintang(p.rating)} (${p.reviewCount})',
                        if (distance != null) jarak(distance!),
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => openProviderStore(context, p.id),
                child: const Text('Lihat toko'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
