/// Alamat server Laravel, mis. `http://10.0.2.2:8000` untuk emulator Android.
/// Diisi saat build: `flutter run --dart-define=API_URL=http://10.0.2.2:8000`.
/// Kosong berarti aplikasi memakai data lokal di perangkat.
const apiUrl = String.fromEnvironment('API_URL');

/// Client ID OAuth jenis "Web application" dari Google Cloud Console, untuk
/// tombol "Masuk dengan Google". Diisi saat build:
/// `--dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com`.
/// Client ID bukan rahasia. Kosong berarti tombolnya tidak ditampilkan.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
