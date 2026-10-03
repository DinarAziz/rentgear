import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/maps.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';

/// Penyedia menggeser peta sampai penanda di tengah berada di tokonya.
class StoreLocationScreen extends StatefulWidget {
  const StoreLocationScreen({super.key, required this.provider});

  final ProviderProfile provider;

  @override
  State<StoreLocationScreen> createState() => _StoreLocationScreenState();
}

class _StoreLocationScreenState extends State<StoreLocationScreen> {
  final _map = MapController();
  late LatLng _center = widget.provider.point;
  bool _locating = false;

  static const double _pinSize = 48;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  bool get _moved => _center != widget.provider.point;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    await moveMapToUser(context, _map, zoom: 16);
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final ok = await runAction(
      context,
      () => state.run(
        (repo) => repo.updateProviderLocation(
          widget.provider.id,
          state.currentUser,
          latitude: _center.latitude,
          longitude: _center.longitude,
        ),
      ),
      success: 'Lokasi toko disimpan.',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lokasi Toko')),
    body: Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15,
            interactionOptions: mapGestures,
            onPositionChanged: (camera, _) =>
                setState(() => _center = camera.center),
          ),
          children: [osmTileLayer(), osmAttribution],
        ),
        // Ujung bawah penanda menunjuk tepat ke tengah peta.
        const IgnorePointer(
          child: Padding(
            padding: EdgeInsets.only(bottom: _pinSize),
            child: Icon(Icons.place, size: _pinSize, color: AppColors.forest),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: LocateButton(busy: _locating, onPressed: _useMyLocation),
        ),
      ],
    ),
    bottomNavigationBar: Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Geser peta sampai penanda berada di toko Anda.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  koordinat(_center),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _moved ? _save : null,
                  child: const Text('Simpan lokasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
