# RentGear API

Server Laravel untuk aplikasi RentGear. Menyimpan data bersama di MySQL dan menjalankan aturan yang sama dengan
aplikasi Flutter di `../rentgear_app/`. Rancangannya ada di
`../docs/superpowers/specs/2026-10-01-laravel-api-design.md`.

## Menjalankan di Mac

PHP, Composer, dan MySQL dipasang lewat Homebrew (`brew install php composer mysql`).

```bash
brew services start mysql
mysql -u root -e "CREATE DATABASE IF NOT EXISTS rentgear CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

composer install
cp .env.example .env        # sekali saja, lalu: php artisan key:generate
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

`migrate:fresh --seed` mengosongkan database lalu mengisi data demo yang sama dengan aplikasi (akun `budi`, `rina`,
`sari`, `dewi`, `agus`, `admin` di `@rentgear.id`, password `password`). Foto alat disalin dari
`../rentgear_app/assets/equipment/`.

Perubahan status otomatis (kedaluwarsa, batal, tidak diambil, terlambat):

```bash
php artisan rentgear:run-jobs     # sekali jalan, cocok saat demo
php artisan schedule:work         # tiap 10 menit selama perintah ini hidup
```

## Menghubungkan aplikasi Flutter

Aplikasi memakai server bila dibangun dengan `API_URL`. Tanpa nilai itu aplikasi tetap memakai data di perangkat.

```bash
# Chrome di Mac yang sama
flutter run -d chrome --dart-define=API_URL=http://localhost:8000

# Emulator Android (10.0.2.2 adalah alamat Mac dari dalam emulator)
flutter run --dart-define=API_URL=http://10.0.2.2:8000

# HP sungguhan lewat USB
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_URL=http://localhost:8000
```

Untuk HP di Wi-Fi yang sama tanpa kabel, pakai alamat IP Mac, misalnya `API_URL=http://192.168.1.10:8000`.

## Login Google

Server memeriksa ID token dari tombol "Masuk dengan Google". Yang perlu disiapkan sekali di
[Google Cloud Console](https://console.cloud.google.com/), menu APIs & Services:

1. Buat proyek, lalu isi "OAuth consent screen" (jenis External, tambahkan akun Google penguji).
2. Di "Credentials", buat tiga OAuth client ID:
   - **Web application**. Authorized JavaScript origins: alamat aplikasi web, misalnya `http://localhost:8081`.
     Client ID inilah yang dipakai aplikasi dan server.
   - **Android**. Package name `id.rentgear.rentgear`, dan SHA-1 dari kunci yang menandatangani APK. Untuk APK debug
     di Mac ini: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`.
     Client ini tidak ditulis di mana pun; Google hanya memakainya untuk mengenali APK.
   - **iOS**, nanti saat versi iOS dibuat.
3. Tulis client ID web di `.env` server, lalu jalankan ulang server:

   ```
   GOOGLE_CLIENT_IDS=xxxx.apps.googleusercontent.com
   ```

4. Bangun aplikasi dengan client ID yang sama:

   ```bash
   flutter run --dart-define=API_URL=http://localhost:8000 --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
   ```

Tanpa `GOOGLE_CLIENT_ID` tombolnya tidak tampil, dan tanpa `GOOGLE_CLIENT_IDS` server menjawab `GOOGLE_NOT_CONFIGURED`.
Akun Google baru menjadi penyewa. Akun admin hanya bisa masuk dengan password.

## Fitur AI (Gemini)

Isi `GEMINI_API_KEY` di `.env` dengan kunci dari [aistudio.google.com](https://aistudio.google.com/). Model bisa
diganti dengan `GEMINI_MODEL` (bawaan `gemini-2.5-flash`). Tiga rute, semuanya hanya memberi saran:

- `POST /api/v1/ai/recommend` `{trip, people, days}`: paket alat untuk penyewa.
- `POST /api/v1/ai/rentals/{id}/fine-opinion`: pendapat atas denda kerusakan, admin saja.
- `POST /api/v1/ai/customers/{id}/risk`: tingkat risiko penyewa, admin saja.

Tanpa kunci, bila Gemini tidak menjawab, atau bila kuotanya habis (429), rute ini menjawab `AI_UNAVAILABLE` (503) dan
rute lain tetap jalan. Sebabnya dicatat di `storage/logs/laravel.log`. Identitas penyewa tidak dikirim ke Gemini.

Foto kondisi alat (`POST /api/v1/rentals/{id}/condition-photos`, isian `phase` = `handover` atau `return`, dan
`photo`) disimpan di disk privat dan ikut dikirim ke Gemini saat admin meminta pendapat atas denda.

## Jejak audit

Tabel `audit_logs` mencatat masuk, gagal masuk, dan semua aksi admin. Admin membacanya lewat `GET /api/v1/audit`.
Tidak ada rute untuk mengubah atau menghapus baris. Password tidak pernah dicatat.

## Susunan

- `app/Domain/`: aturan bisnis, PHP murni tanpa database. Salinan dari `rentgear_app/lib/domain/`.
  `Availability` (ALG-2), `Rental` (mesin status, harga), `Fines` (denda, blacklist), `Guarantee` (aturan jaminan).
- `app/Services/`: transaksi database. `BookingService`, `RentalFlowService`, `BlacklistService`,
  `EquipmentService`, `RentalJobs`, `AvailabilityQuery`.
- `app/Http/Controllers/Api/V1/`: pengendali tipis. `app/Http/Presenters/Present.php` menentukan bentuk JSON.
- `app/Support/ApiException.php`: galat bisnis. Semua jawaban memakai amplop `{ success, data }` atau
  `{ success, error: { code, message } }`, dengan kode yang sama seperti `AppException` di Flutter.
- `routes/api.php`: semua endpoint di bawah `/api/v1`.

## Tes

```bash
php artisan test
```

Tes memakai SQLite di memori, jadi tidak menyentuh database `rentgear`. `tests/Unit/Domain` memakai kasus yang sama
dengan tes Dart. `tests/Feature` menguji tiap alur lewat HTTP.

## Catatan keamanan

- Nomor dokumen jaminan disimpan terenkripsi (`number_enc`); API hanya mengirim versi tersamar.
- Foto jaminan dan bukti transfer ada di disk privat dan hanya bisa diunduh penyewa, pemilik toko, atau admin.
- Foto alat bersifat publik lewat `/api/v1/media/equipment/...`.
- Harga, deposit, dan denda dihitung server. Tanggal kembali untuk denda memakai jam server (Asia/Jakarta).
- Kunci API (Gemini) hanya ada di `.env`, yang diabaikan git. Jangan menulisnya di kode, di `.env.example`, atau di
  perintah build aplikasi. Client ID Google bukan rahasia.
- Rute masuk dibatasi 20 percobaan per menit per alamat IP.
- Server ini untuk pengembangan dan demo di jaringan lokal (http). Sebelum dipasang di internet perlu https,
  password akun demo diganti, dan `APP_DEBUG=false`.
