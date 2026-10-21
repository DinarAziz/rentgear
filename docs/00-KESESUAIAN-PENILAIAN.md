# Kesesuaian dengan tabel penilaian proyek

Tabel di bawah mengikuti kolom RENT GEAR pada "Tabel penilaian proyek mahasiswa" dari dosen. Setiap baris menyebut
bukti yang bisa dibuka: dokumen di folder `docs/`, berkas kode, atau hasil uji. Diperbarui 21 Oktober 2026.

## 1. Analisis kebutuhan (15%)

| Kriteria | Bukti |
|---|---|
| Identifikasi kebutuhan penyewaan, stok, durasi, dan pembayaran | `docs/01-KONSEP-DAN-ANALISIS.md`: problem statement, tujuan, aktor dan peran, daftar fitur. |
| Data penyewa | Akun penyewa (`AppUser`, tabel `users`), riwayat penyewa untuk admin (menu Penyewa), jaminan per sewa (`docs/07-JAMINAN-SEWA.md`). |
| Katalog | Katalog per toko, kategori, pencarian, stok per ukuran (`catalog_screen.dart`, `provider_store_screen.dart`). |
| Durasi sewa | Tanggal mulai dan selesai inklusif, diskon sewa panjang, ganti tanggal dengan persetujuan toko (`docs/02-ALGORITMA.md` ALG-2, `docs/08-RENCANA-KERJA.md`). |
| Ketentuan pengembalian | Aturan denda per toko, masa tenggang, pedoman denda kerusakan, tinjauan admin (`docs/08-RENCANA-KERJA.md` bagian 1 dan 6, `docs/12-PANDUAN-PENGGUNA.md` bagian 2.4). |

## 2. Desain sistem (20%)

| Kriteria | Bukti |
|---|---|
| Use case | `docs/03-FLOW-DAN-USECASE.md` bagian 5 (use case diagram dan spesifikasi naratif). |
| Activity diagram pemesanan | `docs/10-ACTIVITY-DIAGRAM.md`: pemesanan dan pembayaran, pengembalian dan denda, verifikasi toko, saran AI. Semua dengan swimlane per pelaku. |
| Class diagram | `docs/09-DIAGRAM-KELAS-DAN-PBO.md`: kelas inti dan lapisan data. |
| ERD | `docs/04-DATABASE.md` bagian 5. |
| Relasi Customer–Gear–Rental–Payment | Diagram kelas (Bagian 9) dan tabel `users`, `equipment`, `rentals`, `payments` di `rentgear_api/database/migrations/`. Pemetaan nama kelas ada di Bagian 9 bagian 1. |
| Rancangan ketersediaan stok | `docs/02-ALGORITMA.md` ALG-2 (sweep-line, okupansi puncak), `GearStatus` (`rentgear_app/lib/domain/gear_status.dart`). |

## 3. Implementasi (25%)

| Kriteria | Bukti |
|---|---|
| Modul katalog | Aplikasi Flutter (`rentgear_app/`) dan API (`rentgear_api/`), di `https://rentgear.serverbaik.my.id`. |
| Modul pemesanan | `booking_screen.dart`, `BookingService.php` (kunci harga, cek stok, jaminan, Idempotency-Key). |
| Perhitungan biaya | `Rental.subtotal`, `discount`, `grandTotal`, `depositRefund`; `PriceCalculator.php`; denda di `FinePolicy`. |
| Modul pengembalian | Serah terima, terima pengembalian, denda, kembalikan jaminan (`rental_detail_screen.dart`, `RentalFlowService.php`). |
| Dashboard admin | Menu admin Dashboard: ringkasan, perlu tindakan, transaksi terbaru, jejak audit. |
| Riwayat penyewaan | Sewa Saya (penyewa), tab Riwayat di Pesanan (penyedia), menu Transaksi dan Penyewa (admin), riwayat status di tiap transaksi. |
| Status barang tersedia/disewa | Admin: Dashboard > "Status alat hari ini". Penyedia: layar Alat (tersedia, sedang disewa, dipesan hari ini). |

### Penerapan PBO

| Kriteria | Bukti |
|---|---|
| Class Customer, Gear, Rental, Payment | `AppUser` (peran penyewa), `Equipment`, `Rental`, `Payment` di `rentgear_app/lib/domain/models.dart`; model `User`, `Equipment`, `Rental`, `Payment` di `rentgear_api/app/Models/`. |
| Enkapsulasi, abstraksi, pewarisan, polimorfisme | `docs/09-DIAGRAM-KELAS-DAN-PBO.md` bagian 4, dengan lokasi kode tiap contoh. |

## 4. Pengujian (20%)

| Kriteria | Bukti |
|---|---|
| Uji stok habis | `docs/11-LAPORAN-PENGUJIAN.md` kasus 1 sampai 6. |
| Uji pemesanan bersamaan | Kasus 7 sampai 11, termasuk uji serentak 8 penyewa (`rentgear_api/tests/concurrency/bersamaan.sh`, hasil di `docs/hasil-uji/2026-10-21-bersamaan.txt`). |
| Uji biaya | Kasus 12 sampai 17. |
| Uji keterlambatan | Kasus 18 sampai 22. |
| Validasi tanggal | Kasus 23 sampai 26. |
| Pencegahan pemesanan ganda | Kasus 7 sampai 10 (ALG-2, antrean transaksi, Idempotency-Key). |
| Pengujian pengembalian | Kasus 27 sampai 33. |
| Hasil uji | `docs/hasil-uji/`: 177 tes server dan 139 tes aplikasi lulus pada 21 Oktober 2026. |

## 5. Deployment dan maintenance (15%)

| Kriteria | Bukti |
|---|---|
| Aplikasi dapat dijalankan | Situs publik `https://rentgear.serverbaik.my.id`, APK Android, dan cara menjalankan lokal (`docs/13-PANDUAN-OPERASIONAL.md` bagian 1). |
| Panduan penyewa dan admin | `docs/12-PANDUAN-PENGGUNA.md` (penyewa, penyedia, admin) dan video `RentGear-demo-cara-pakai.mp4`. |
| Pemeliharaan stok | `docs/13-PANDUAN-OPERASIONAL.md` bagian 4; aturan stok tidak bisa di bawah pesanan (`stockReductionError` di `equipment_rules.dart` dan `EquipmentService.php`). |
| Panduan operasional | `docs/13-PANDUAN-OPERASIONAL.md`: pembaruan server, cadangan dan pemulihan, galat, jadwal pemeliharaan. |
| Pencatatan kerusakan barang | `docs/13-PANDUAN-OPERASIONAL.md` bagian 5; "Catatan kerusakan" di form alat dan label kerusakan terakhir di layar Alat. |
| Prosedur pembaruan stok | `docs/13-PANDUAN-OPERASIONAL.md` bagian 4, langkah 1 sampai 5. |
