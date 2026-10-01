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
- Server ini untuk pengembangan dan demo di jaringan lokal (http). Sebelum dipasang di internet perlu https,
  password akun demo diganti, dan `APP_DEBUG=false`.
