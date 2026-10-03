import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';

/// Tautan Google Maps untuk satu titik. Membuka aplikasi Maps bila terpasang,
/// atau maps.google.com di browser, tanpa API key.
Uri googleMapsUri(double latitude, double longitude) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$latitude,$longitude'},
);

/// Jarak garis lurus antara dua titik di permukaan bumi, dalam kilometer
/// (rumus haversine). Dipakai untuk mengurutkan toko dari yang terdekat.
double distanceKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double degrees) => degrees * math.pi / 180;

/// "850 m", "2,4 km", "37 km".
String jarak(double km) {
  if (km < 1) return '${(km * 1000 / 50).round() * 50} m';
  if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return '${km.round()} km';
}

/// "-7,93960, 112,62890" untuk ditampilkan ke penyedia.
String koordinat(LatLng p) => [
  p.latitude,
  p.longitude,
].map((v) => v.toStringAsFixed(5).replaceAll('.', ',')).join(', ');

/// Pengganti sumber ubin peta. Tes mengisinya dengan [BlankTileProvider]
/// supaya tidak ada permintaan jaringan.
TileProvider? debugTileProvider;

/// Lapisan peta OpenStreetMap. Tidak butuh API key.
TileLayer osmTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'id.rentgear.rentgear',
  maxNativeZoom: 19,
  tileProvider: debugTileProvider,
);

/// Kredit yang diwajibkan lisensi OpenStreetMap, di sudut kanan bawah peta.
const osmAttribution = Align(
  alignment: Alignment.bottomRight,
  child: ColoredBox(
    color: Color(0xCCFFFFFF),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        '© OpenStreetMap',
        style: TextStyle(fontSize: 10, color: Colors.black87),
      ),
    ),
  ),
);

/// Ubin kosong untuk tes.
class BlankTileProvider extends TileProvider {
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

extension ProviderPoint on ProviderProfile {
  LatLng get point => LatLng(latitude, longitude);
}

/// Peta bisa digeser dan diperbesar, tetapi tidak diputar.
const mapGestures = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);
