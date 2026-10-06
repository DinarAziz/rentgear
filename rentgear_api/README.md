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

## Hosting di HP Redmi (rentgear.serverbaik.my.id)

Situs publik dan API berjalan di HP Redmi: Termux, Ubuntu lewat `proot-distro`, nginx, dan Cloudflare Tunnel. Situs
ada di `/`, API di `/api`, jadi keduanya satu alamat dan tidak butuh pengaturan Cloudflare tambahan.

- Kode di dalam Ubuntu: `/root/rentgear/rentgear_api`. Database SQLite di `database/database.sqlite`, foto unggahan
  di `storage/app`. PHP 8.5 dan Composer dari apt.
- API dijalankan `php artisan serve` di `127.0.0.1:8000` (4 pekerja) dan diteruskan nginx. Konfigurasi nginx ada di
  `deploy/nginx-rentgear.conf`.
- `.env` di HP dibuat dari `rentgear_api/.env.redmi` di Mac (diabaikan git). Isinya `APP_DEBUG=false`, kunci Gemini,
  client ID Google, dan `DEMO_ADMIN_PASSWORD`: password akun admin di server publik. Akun demo penyewa dan penyedia
  tetap memakai `password`, dan tombol demo Admin tidak tampil pada build yang memakai alamat https.
- API ikut menyala saat HP dinyalakan lewat `~/.termux/boot/start-nginx.sh`. Log: `~/rentgear-api.log` di Termux.

Memperbarui setelah kode berubah (HP tersambung USB, Termux terbuka):

```bash
# di Mac: bangun web untuk alamat publik, lalu kemas dan kirim
flutter build web --release --dart-define=API_URL=https://rentgear.serverbaik.my.id --dart-define=GOOGLE_CLIENT_ID=...
(cd build/web && zip -qr /tmp/web.zip .)
tar czf /tmp/api.tgz --exclude=vendor --exclude=.env --exclude=.env.redmi --exclude=storage \
    --exclude=database/database.sqlite --exclude=tests rentgear_api rentgear_app/assets/equipment
adb push /tmp/api.tgz /sdcard/rg/api.tgz && adb push /tmp/web.zip /sdcard/rg/web.zip
adb push rentgear_api/deploy/install.sh /sdcard/rg/install.sh

# di Termux pada HP
proot-distro login ubuntu -- bash /sdcard/rg/install.sh        # tambah "seed" untuk mengosongkan data
sh /sdcard/rg/startapi.sh                                       # salinan deploy/termux-start-api.sh
```

`install.sh` menyimpan cadangan situs dan konfigurasi nginx lama di `/root/rentgear/backup/` sebelum menggantinya, dan
mengembalikan konfigurasi lama bila nginx menolaknya. Database dan `.env` tidak ditimpa saat memperbarui.

Batasnya: HP harus menyala dan tersambung internet, `php artisan serve` bukan server untuk beban berat, dan database
SQLite tidak mengunci baris seperti MySQL, jadi jaminan "unit terakhir hanya untuk satu booking" di sini bergantung
pada kunci tulis SQLite.

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

## Lupa password

Pengguna meminta kode 6 angka lewat `POST /api/v1/auth/forgot-password`, lalu menukarnya dengan password baru lewat
`POST /api/v1/auth/reset-password`. Kode berlaku 15 menit, batal setelah 5 tebakan salah, dan untuk satu email hanya
bisa diminta sekali per 60 detik. Aturannya ada di `app/Services/PasswordResetService.php`.

Kode dikirim lewat email, jadi server perlu satu akun pengirim. Bawaannya `MAIL_MAILER=log`: email tidak dikirim,
isinya ditulis ke `storage/logs/laravel.log` pada tingkat `debug`. Itu cukup untuk mencoba di Mac. Di server publik
tingkat log adalah `warning`, jadi kode tidak tercatat di mana pun sampai pengirim sungguhan diisi. Untuk mengirim sungguhan lewat Gmail
(gratis, sampai 500 email per hari):

1. Di akun Google pengirim, nyalakan Verifikasi 2 Langkah, lalu buat App Password di
   [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords).
2. Isi di `.env` (dan `.env.redmi` untuk server publik), lalu jalankan ulang server:

   ```
   MAIL_MAILER=smtp
   MAIL_HOST=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USERNAME=alamat@gmail.com
   MAIL_PASSWORD=app-password-16-huruf
   MAIL_FROM_ADDRESS=alamat@gmail.com
   MAIL_FROM_NAME=RentGear
   ```

3. Periksa pengirimnya tanpa membuka aplikasi:

   ```bash
   php artisan rentgear:mail-test alamat-anda@gmail.com
   ```

   Perintah ini mengirim satu email percobaan. Selama `MAIL_MAILER` masih `log`, perintah hanya memberi peringatan
   bahwa email tidak dikirim. Bila SMTP menolak, pesan galatnya ditampilkan.

App Password adalah rahasia, sama seperti kunci Gemini: hanya di `.env`. Bila pengiriman gagal, server menjawab
`MAIL_UNAVAILABLE` dan mencatat galatnya di log. Akun demo memakai alamat `@rentgear.id` yang tidak punya kotak
masuk, jadi kode untuk akun itu tidak akan sampai ke mana pun.

## Jejak audit

Tabel `audit_logs` mencatat masuk, gagal masuk, permintaan kode dan penggantian password, dan semua aksi admin. Admin membacanya lewat `GET /api/v1/audit`.
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
- Rute masuk, daftar, dan lupa password dibatasi 20 percobaan per menit per alamat IP. Setelah 5 kali salah password,
  satu akun terkunci 15 menit dari alamat IP itu.
- Token masuk berlaku 30 hari (`SANCTUM_TOKEN_MINUTES`). Token kedaluwarsa dibuang oleh scheduler tiap hari.
- Unggahan hanya menerima JPG, PNG, dan WebP, diperiksa dari isi berkas, paling besar 8 MB.
- Semua jawaban API membawa `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, dan `Referrer-Policy`.
  Header yang sama untuk situs ada di `deploy/nginx-rentgear.conf`.
- Toko yang belum terverifikasi hanya ada di daftar toko untuk pemiliknya dan admin. Alat yang disembunyikan hanya
  terlihat oleh pemilik toko dan admin.
- Kode ganti password disimpan sebagai hash, dan mengganti password mengakhiri semua sesi lama akun itu.
- Yang masih terbuka di server publik: akun demo penyewa dan penyedia memakai password `password` yang tertulis di
  layar masuk, jadi siapa pun bisa masuk sebagai mereka. Itu disengaja untuk demo; datanya karangan. Server juga
  masih dijalankan dengan `php artisan serve`, yang dibuat untuk pengembangan. `APP_DEBUG` harus tetap `false`.
- Tes keamanan ada di `tests/Feature/SecurityTest.php`, `AccessTest.php`, dan `PasswordResetTest.php`.
