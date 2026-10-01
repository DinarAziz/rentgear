# Bagian 8: Rencana kerja setelah tahap aplikasi lokal

Disusun 1 Oktober 2026 dari keputusan pemilik proyek. Dokumen ini mencatat urutan kerja dan keputusan yang sudah
diambil, supaya tiap tahap bisa dikerjakan terpisah.

## Urutan

| Tahap | Isi | Status |
|---|---|---|
| 1 | Denda dan blacklist di aplikasi Flutter (tanpa server) | Selesai, lihat bagian 1 |
| 2 | Katalog per penyedia: halaman toko, rating, komentar, follow, lokasi di peta | Selesai, lihat bagian 2 |
| 3 | Server Laravel + MySQL, lalu Flutter bisa memilih data lokal atau server | Belum |
| 4 | Daftar dan login dengan akun Google | Belum, butuh tahap 3 |
| 5 | Fitur AI dengan Gemini | Belum, butuh tahap 3 dan API key |
| 6 | Payment gateway dan versi iOS | Menyusul |

## 1. Denda dan blacklist (selesai)

Aturan yang dipakai, semuanya ada di `rentgear_app/lib/domain/fines.dart`:

- Denda keterlambatan = hari terlambat × tarif harian × jumlah unit × 1,5. Dihitung otomatis saat penyedia menerima
  alat kembali. Hari dihitung per tanggal kalender.
- Denda kerusakan diisi penyedia saat menerima alat (kondisi: baik, rusak ringan, rusak berat, hilang). Batas atasnya
  jumlah deposit. Denda langsung berlaku.
- Admin hanya meninjau yang janggal: denda kerusakan di atas 50% deposit, atau denda yang diajukan keberatan oleh
  penyewa. Selama ditinjau, transaksi tidak bisa ditutup. Admin menetapkan nominal akhir (0 berarti dibatalkan).
- Total denda dipotong dari deposit. Bila denda lebih besar dari deposit, selisihnya tercatat sebagai kekurangan yang
  ditagih penyedia saat menutup transaksi.
- Blacklist: admin bisa memasukkan atau mencabut dengan alasan. Penyewa juga masuk blacklist otomatis setelah 3
  pelanggaran (terlambat, tidak mengambil alat, atau merusak alat). Setelah dicabut, hitungan mulai dari awal.
- Penyewa blacklist tetap bisa login dan menyelesaikan sewa yang berjalan, tetapi tidak bisa membuat booking baru.

Yang menunggu tahap 5: AI ikut memeriksa denda kerusakan (membandingkan foto sebelum dan sesudah sewa) dan memberi
tanda risiko untuk blacklist. Sampai saat itu, "janggal" ditentukan aturan tetap di atas.

## 2. Katalog per penyedia (selesai)

- Halaman awal penyewa menampilkan daftar toko yang terverifikasi. Toko yang diikuti tampil lebih dulu, lalu urut
  rating. Mengetik di pencarian atau memilih kategori menampilkan alat dari semua toko.
- Halaman toko berisi alamat, rating, jumlah pengikut, tombol ikuti, tombol "Buka di Google Maps", daftar alat, dan
  ulasan.
- Rating toko adalah rata-rata bintang dari ulasannya. Ulasan hanya bisa diisi penyewa transaksi itu, setelah
  transaksi selesai, satu kali, lewat tombol "Beri ulasan" di detail transaksi.
- Lokasi dibuka lewat tautan Google Maps dari koordinat toko, tanpa API key. Koordinat tiga toko demo adalah titik
  perkiraan di kota masing-masing, karena tokonya fiktif.
- Enam ulasan awal di data demo adalah contoh buatan, supaya halaman toko tidak kosong.

Belum dibuat: peta yang tertanam di dalam aplikasi (butuh Google Maps API key dan akun penagihan Google Cloud), urutan
toko berdasarkan jarak dari penyewa, dan balasan penyedia atas ulasan.

## 3. Server Laravel

Keputusan: PHP, Composer, dan MySQL dipasang lewat Homebrew di Mac pengembang. Rancangan API, struktur folder, dan
database tetap mengikuti `04-DATABASE.md` dan `05-TECHSTACK-STRUKTUR-API.md`. Aturan dari tahap 1 disalin ke server.

Aplikasi Flutter mendapat repository HTTP di samping repository lokal. Mode dipilih saat build, sehingga demo tetap
jalan walau server mati.

## 4. Login Google

Daftar dan login dengan akun Google. Butuh proyek Google Cloud dengan OAuth client untuk Android dan web, dan server
yang memeriksa token. Kredensial ini disiapkan pemilik proyek.

## 5. Fitur AI

Keputusan: Gemini. API key dibuat pemilik proyek di aistudio.google.com dan disimpan di `.env` server, tidak pernah
di dalam APK. Cakupan:

- Rekomendasi paket alat dari kebutuhan perjalanan (ALG-1 di `02-ALGORITMA.md`).
- Pemeriksaan kondisi alat dari foto (ALG-3), yang juga memberi tanda pada denda kerusakan yang janggal.
- Tanda risiko penyewa untuk membantu keputusan blacklist.

Prinsip dari `01-KONSEP-DAN-ANALISIS.md` tetap berlaku: AI memberi saran, keputusan yang menyangkut uang tetap di
tangan manusia, dan aplikasi tetap jalan bila AI mati.
