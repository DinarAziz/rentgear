import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Hasil mencari lokasi pengguna.
enum LocationStatus {
  /// Belum pernah dicoba.
  unknown,

  /// Sedang menunggu izin atau sinyal.
  searching,

  /// Lokasi didapat.
  found,

  /// Izin ditolak pengguna.
  denied,

  /// GPS mati, tidak ada sinyal, atau perangkat tidak mendukung.
  unavailable,
}

typedef LocationResult = ({LocationStatus status, LatLng? point});

/// Mencari lokasi pengguna. [ask] false: hanya memakai izin yang sudah ada,
/// tanpa memunculkan dialog izin.
typedef LocationFinder = Future<LocationResult> Function({required bool ask});

const LocationResult _denied = (status: LocationStatus.denied, point: null);
const LocationResult _unavailable = (
  status: LocationStatus.unavailable,
  point: null,
);

/// Lokasi dari GPS atau browser. Semua galat (plugin tidak ada, waktu habis)
/// dijawab sebagai tidak tersedia, supaya aplikasi tetap jalan tanpa lokasi.
Future<LocationResult> deviceLocation({required bool ask}) async {
  // Percobaan diam-diam saat aplikasi dibuka tidak melaporkan kegagalan;
  // pengguna belum meminta apa pun.
  final failed = ask
      ? _unavailable
      : (status: LocationStatus.unknown, point: null);
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!ask) return (status: LocationStatus.unknown, point: null);
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _denied;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return failed;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return (
      status: LocationStatus.found,
      point: LatLng(p.latitude, p.longitude),
    );
  } catch (_) {
    return failed;
  }
}
