import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/location.dart';
import '../core/maps.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// Penanda toko di peta: bulatan berikon dengan ujung lancip di titik toko.
class StorePin extends StatelessWidget {
  const StorePin({super.key, this.selected = false});

  final bool selected;

  static const double width = 44;
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : Colors.white;
    final onColor = selected ? Colors.white : AppColors.forest;
    return AnimatedScale(
      scale: selected ? 1.15 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 160),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 2,
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 16, height: 16, color: color),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.forest, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.storefront, size: 22, color: onColor),
          ),
        ],
      ),
    );
  }
}

/// Titik biru lokasi pengguna.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  static const double size = 22;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.blue.shade600,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
  );
}

Marker storeMarker(
  LatLng point, {
  bool selected = false,
  VoidCallback? onTap,
}) => Marker(
  point: point,
  width: StorePin.width,
  height: StorePin.height,
  alignment: Alignment.topCenter,
  child: GestureDetector(
    onTap: onTap,
    child: StorePin(selected: selected),
  ),
);

Marker userMarker(LatLng point) => Marker(
  point: point,
  width: UserDot.size,
  height: UserDot.size,
  child: const UserDot(),
);

/// Tombol "Lokasi saya" di atas peta. Saat [busy], tombol mati dan
/// menampilkan putaran tunggu.
class LocateButton extends StatelessWidget {
  const LocateButton({super.key, required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
    tooltip: 'Lokasi saya',
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.my_location),
  );
}

/// Pesan untuk pengguna saat lokasi tidak didapat. `null` bila tidak ada
/// yang perlu disampaikan.
String? locationProblem(LocationStatus status) => switch (status) {
  LocationStatus.denied =>
    'Izin lokasi ditolak. Izinkan lokasi untuk RentGear di pengaturan.',
  LocationStatus.unavailable =>
    'Lokasi tidak didapat. Nyalakan GPS lalu coba lagi.',
  _ => null,
};

/// Mencari lokasi pengguna (dialog izin boleh muncul), lalu memindahkan
/// peta ke sana. Bila lokasi tidak didapat, masalahnya tampil di snackbar.
Future<void> moveMapToUser(
  BuildContext context,
  MapController map, {
  required double zoom,
}) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  await state.locate(ask: true);
  if (!context.mounted) return;
  final user = state.location;
  if (user != null) {
    map.move(user, zoom);
  } else if (locationProblem(state.locationStatus) case final problem?) {
    messenger.showSnackBar(SnackBar(content: Text(problem)));
  }
}

/// Peta kecil satu toko, tidak bisa digeser. Ketuk untuk [onTap].
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.point,
    this.user,
    this.height = 160,
    this.onTap,
  });

  final LatLng point;
  final LatLng? user;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: height,
      child: FlutterMap(
        // Titik toko berubah saat penyedia memindahkannya.
        key: ValueKey(point),
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
          onTap: onTap == null ? null : (_, _) => onTap!(),
        ),
        children: [
          osmTileLayer(),
          MarkerLayer(
            markers: [
              if (user != null) userMarker(user!),
              storeMarker(point, selected: true, onTap: onTap),
            ],
          ),
          osmAttribution,
        ],
      ),
    ),
  );
}
