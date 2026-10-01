# Rancangan: server Laravel untuk RentGear (tahap 3)

Tanggal: 1 Oktober 2026. Status: menunggu persetujuan pemilik proyek.

## Tujuan

Aplikasi Flutter sekarang menyimpan semua data di perangkat, jadi penyewa dan penyedia di HP yang berbeda tidak
melihat data yang sama. Tahap ini membuat server yang menyimpan data bersama, dengan aturan bisnis yang sama persis
seperti di aplikasi. Hasilnya: booking yang dibuat di satu HP muncul di HP penyedia.

Ukuran berhasil:

1. Semua alur yang sekarang lulus di aplikasi lokal (booking, jaminan, bukti transfer, serah terima, denda, blacklist,
   toko, ulasan, follow) lulus juga lewat server, diuji dengan tes otomatis di sisi Laravel.
2. Aplikasi Flutter yang sama bisa dibangun dalam dua mode: data lokal (seperti sekarang) atau server.
3. Dua perangkat yang login ke server yang sama melihat transaksi yang sama.

## Yang tidak termasuk tahap ini

Login Google (tahap 4), fitur AI (tahap 5), payment gateway, deploy ke hosting publik, dan panel admin berbasis web.
Server dijalankan di Mac pengembang dan diakses HP lewat jaringan lokal atau `adb reverse`.

## Keputusan utama

| Hal | Keputusan | Alasan |
|---|---|---|
| Letak kode | Folder baru `rentgear_api/` di repo yang sama | Satu repo, mudah dirujuk dari dokumen |
| Versi | PHP dan Laravel versi stabil terbaru dari Homebrew dan Composer | Sesuai `05-TECHSTACK-STRUKTUR-API.md` |
| Database | MySQL 8 dari Homebrew, database `rentgear` | Keputusan pemilik proyek |
| Bentuk API | REST JSON di `/api/v1`, satu endpoint untuk tiap operasi di `RentGearRepository` | Repository HTTP di Flutter jadi pengganti langsung, layar tidak berubah |
| Autentikasi | Laravel Sanctum, token Bearer, login email dan password | Rancangan lama untuk Flutter; login Google menumpang di sini nanti |
| Peran | Satu kolom `role` di tabel `users` (customer, provider, admin) | Sama dengan aplikasi sekarang. Rancangan `user_roles` di `04-DATABASE.md` ditunda sampai benar-benar perlu |
| Aturan bisnis | Folder `app/Domain/`, kelas PHP murni tanpa Eloquent | Bisa diuji tanpa database, dan mudah ditunjuk saat sidang |
| Format galat | `{ "success": false, "error": { "code": "...", "message": "..." } }` dengan kode yang sama seperti `AppException` di Flutter | Pesan galat di layar tetap sama |
| Foto | Disimpan di disk server. Foto alat lewat URL publik. Foto jaminan dan bukti transfer lewat endpoint yang memeriksa hak akses | Foto KTP adalah data pribadi (`07-JAMINAN-SEWA.md` bagian 6) |
| Nomor dokumen jaminan | Disimpan terenkripsi, API hanya mengirim versi tersamar | Sama dengan aturan di `07-JAMINAN-SEWA.md` |

## Susunan

```
rentgear_api/
  app/Domain/
    Availability/AvailabilityService.php   ALG-2: puncak pemakaian per rentang tanggal
    Rental/RentalStateMachine.php          transisi status dan syarat jaminan
    Rental/PriceCalculator.php             total sewa dan deposit, selalu dihitung server
    Fines/FineCalculator.php               denda telat, batas denda kerusakan, tinjauan admin
    Fines/BlacklistPolicy.php              hitung pelanggaran, blacklist otomatis
    Guarantee/GuaranteePolicy.php          validasi dokumen jaminan
  app/Models/        User, Provider, Category, Equipment, EquipmentSize, EquipmentPhoto,
                     Rental, RentalStatusLog, Guarantee, Review, Follow, BlacklistEntry
  app/Http/Controllers/Api/V1/   pengendali tipis: validasi, panggil layanan, bentuk respons
  app/Services/      BookingService, RentalFlowService, StoreService (transaksi DB dan Eloquent)
  app/Console/Commands/RunRentalJobs.php   kedaluwarsa, batal, tidak diambil, terlambat
  database/migrations, database/seeders    data demo yang sama dengan aplikasi
  tests/Unit/Domain   salinan tes Dart untuk tiap kelas Domain
  tests/Feature       alur lengkap lewat HTTP
```

Tiap kelas `Domain` adalah terjemahan langsung dari berkas Dart yang sudah ada dan sudah diuji:
`availability.dart`, `rental_state_machine.dart`, `fines.dart`, `guarantee.dart`. Tes PHP memakai kasus yang sama
dengan tes Dart, supaya dua implementasi terbukti menghasilkan angka yang sama.

## Tabel

`users` (role, nomor HP, kota), `providers` (pemilik, nama toko, alamat, koordinat, status, rekening, aturan jaminan),
`categories`, `equipment`, `equipment_sizes`, `equipment_photos`, `rentals` (harga dan deposit dikunci saat booking,
kolom denda), `rental_status_logs`, `guarantees`, `reviews`, `follows`, `blacklist_entries`, `idempotency_keys`,
ditambah tabel bawaan Sanctum.

Rating toko, jumlah ulasan, dan jumlah pengikut dihitung dari `reviews` dan `follows`, tidak disimpan sebagai kolom.

## Endpoint

Semua di bawah `/api/v1`, semua kecuali login butuh token.

| Kelompok | Endpoint |
|---|---|
| Sesi | `POST auth/login`, `POST auth/logout`, `GET auth/me` |
| Katalog | `GET categories`, `GET equipment`, `GET equipment/{id}`, `GET equipment/{id}/availability` |
| Toko | `GET providers`, `GET providers/{id}`, `GET providers/{id}/equipment`, `GET providers/{id}/reviews`, `PUT providers/{id}/follow`, `DELETE providers/{id}/follow`, `GET me/follows` |
| Alat penyedia | `POST equipment`, `PUT equipment/{id}`, `PUT provider/guarantee-policy` |
| Booking | `POST rentals` (dengan `Idempotency-Key`), `GET rentals`, `GET rentals/{id}` |
| Alur sewa | `POST rentals/{id}/guarantees/{gid}/review`, `.../confirm`, `.../reject`, `.../cancel`, `.../payment`, `.../handover`, `.../return`, `.../complete`, `.../review` |
| Denda | `POST rentals/{id}/damage-objection`, `POST rentals/{id}/damage-decision` |
| Admin | `PUT providers/{id}/status`, `GET customers`, `PUT customers/{id}/blacklist`, `DELETE customers/{id}/blacklist` |
| Berkas | `GET files/guarantees/{gid}`, `GET files/payments/{rentalId}` |

## Booking tanpa dobel

`POST rentals` berjalan di dalam satu transaksi database:

1. Kunci baris alat (dan baris ukuran, bila ada) dengan `lockForUpdate`.
2. Hitung ulang ketersediaan dengan `AvailabilityService` dari transaksi yang masih mengunci stok.
3. Tolak dengan `SLOT_UNAVAILABLE` bila stok kurang, lalu simpan.
4. `Idempotency-Key` yang sama mengembalikan booking yang sama.

Tes fitur menjalankan beberapa permintaan untuk satu unit stok dan memeriksa bahwa hanya satu yang berhasil.

## Pekerjaan terjadwal

Perintah `rentgear:run-jobs` menjalankan empat aturan yang sekarang dijalankan aplikasi saat dibuka: booking tidak
direspons 12 jam menjadi kedaluwarsa, tidak dibayar 24 jam menjadi batal, tidak diambil sampai tanggal mulai lewat,
dan terlambat setelah tanggal selesai. Didaftarkan di scheduler tiap 10 menit, dan bisa dipanggil manual saat demo.

## Sisi Flutter

- `HttpRentGearRepository` mengimplementasikan `RentGearRepository` dengan paket `http`.
- Mode dipilih saat build: `--dart-define=API_URL=http://alamat:8000`. Tanpa nilai itu, aplikasi memakai repository
  lokal seperti sekarang.
- `ItemPhoto` mendapat varian ketiga, `NetworkPhoto`, untuk foto dari server.
- Token disimpan di perangkat supaya sesi bertahan setelah aplikasi ditutup.
- Galat jaringan ditampilkan sebagai pesan "Tidak bisa terhubung ke server", dengan tombol coba lagi yang sudah ada.

## Pengujian

- Tes unit `Domain` di PHP, kasusnya sama dengan tes Dart.
- Tes fitur untuk tiap alur: sewa lengkap, penolakan, denda dan tinjauan admin, blacklist, ulasan, follow, hak akses
  lintas peran (penyedia lain ditolak 403).
- Tes Flutter yang ada tetap memakai repository lokal. Repository HTTP diuji dengan klien tiruan untuk pemetaan
  JSON dan kode galat.
- Uji ujung ke ujung: server jalan di Mac, satu emulator sebagai penyewa dan Chrome sebagai penyedia, satu sewa
  lengkap.

## Urutan pengerjaan

1. Kerangka proyek, migrasi, seeder data demo.
2. Kelas `Domain` dan tes unitnya.
3. Login dan endpoint katalog serta toko.
4. Booking dan alur sewa.
5. Denda, blacklist, ulasan, follow, endpoint admin.
6. Pekerjaan terjadwal.
7. Repository HTTP di Flutter dan mode build.
8. Uji ujung ke ujung dua perangkat.

## Risiko

- Mengubah `ItemPhoto` menyentuh banyak layar. Varian baru ditambahkan tanpa mengubah dua varian lama.
- Waktu di server dan di HP bisa berbeda. Semua tanggal sewa dikirim sebagai tanggal kalender (tanpa jam), dan
  hitungan telat dilakukan server.
- HP sungguhan harus satu jaringan dengan Mac, atau memakai `adb reverse tcp:8000 tcp:8000`.
