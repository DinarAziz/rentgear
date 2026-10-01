/// Alamat server Laravel, mis. `http://10.0.2.2:8000` untuk emulator Android.
/// Diisi saat build: `flutter run --dart-define=API_URL=http://10.0.2.2:8000`.
/// Kosong berarti aplikasi memakai data lokal di perangkat.
const apiUrl = String.fromEnvironment('API_URL');
