# Bagian 13: Panduan operasional dan pemeliharaan

Panduan ini untuk tim yang menjalankan RentGear: cara menjalankan aplikasi, memperbarui server, mencadangkan dan
memulihkan data, memelihara stok, mencatat kerusakan barang, dan menangani galat. Panduan untuk penyewa, penyedia, dan
admin ada di Bagian 12.

## 1. Menjalankan aplikasi

### Di komputer pengembang

Server API (Laravel, butuh PHP 8.5 dan Composer):

```bash
cd rentgear_api && composer install && php artisan migrate --seed && php artisan serve
```

Aplikasi (Flutter). Tanpa `API_URL`, aplikasi memakai data demo di perangkat:

```bash
cd rentgear_app && flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

Detail lain (login Google, email, Gemini) ada di `rentgear_api/README.md`.

### Server publik

Situs dan API berjalan di HP Redmi: Termux, Ubuntu lewat `proot-distro`, nginx, dan Cloudflare Tunnel, di alamat
`https://rentgear.serverbaik.my.id`. API berjalan dengan `php artisan serve` (4 pekerja) di `127.0.0.1:8000`, dan
`php artisan schedule:work` menjalankan pekerjaan terjadwal: kedaluwarsa booking (12 jam), pembatalan karena belum
dibayar (24 jam), tidak datang, dan terlambat, setiap 10 menit.

Bila situs menjawab galat 502, 530, atau "error code: 1033", berarti Termux atau API berhenti. Buka Termux di HP, lalu:

```bash
sh /sdcard/rg/hidup.sh
```

Skrip itu menyalakan nginx dan tunnel, lalu API bila belum berjalan. Hasilnya di `/sdcard/rg/hidup.log`.

## 2. Memperbarui server

1. Jalankan semua tes di komputer pengembang (Bagian 11). Jangan memperbarui bila ada yang gagal.
2. Bangun web untuk alamat publik dengan nama berkas ber-hash, supaya Cloudflare tidak menyajikan versi lama
   (`rentgear_app/tool/build_web.sh` menunjukkan langkahnya).
3. Kemas kode API dari commit terakhir, tanpa `.env`, `vendor`, `storage`, dan database:
   `git archive --format=tar.gz -o api.tgz HEAD rentgear_api rentgear_app/assets`.
4. Kirim `api.tgz`, `web.zip`, dan skrip pembaruan ke `/sdcard/rg/` dengan `adb push`.
5. Di Termux, jalankan `sh /sdcard/rg/run.sh <nama-skrip>`, lalu `sh /sdcard/rg/hidup.sh`. Skrip pembaruan selalu:
   - menyalin database ke `/root/rentgear/backup/db-<waktu>.sqlite` dan situs lama ke `site-<waktu>.tgz`;
   - membuka `api.tgz`, menjalankan `composer install` dan `php artisan migrate --force`;
   - menyimpan ulang cache konfigurasi dan rute;
   - mengganti isi situs (kecuali `/presentasi/`) dan mematikan API lama.
6. Periksa dari luar: halaman utama menjawab 200 dan memuat nama berkas `main.dart.<hash>.js` yang baru, dan
   `/api/v1/categories` menjawab 401 JSON tanpa token.
7. Catat tanggal, commit, dan hasil pemeriksaan di `rentgear_app/HANDOFF.md`.

`.env` server tidak ikut dikirim dan tidak ditimpa saat pembaruan. Kunci rahasia (Gemini, Gmail, Google) hanya ada di
sana.

## 3. Cadangan dan pemulihan data

Data penting ada di dua tempat di dalam Ubuntu pada HP:

- database: `/root/rentgear/rentgear_api/database/database.sqlite`;
- unggahan: `/root/rentgear/rentgear_api/storage/app/` (foto jaminan, bukti transfer, dokumen toko, foto kondisi,
  dan foto alat).

Setiap pembaruan otomatis mencadangkan database dan situs. Unggahan tidak ikut otomatis, jadi cadangkan seminggu
sekali dan sebelum perubahan besar, di dalam Ubuntu:

```bash
tar czf /root/rentgear/backup/storage-$(date +%Y%m%d).tgz -C /root/rentgear/rentgear_api storage/app
```

Memulihkan database dari cadangan:

1. Hentikan API: `pkill -f "artisan serve"`.
2. Salin cadangan ke tempatnya:
   `cp /root/rentgear/backup/db-<waktu>.sqlite /root/rentgear/rentgear_api/database/database.sqlite`.
3. Bila perlu, pulihkan unggahan: `tar xzf /root/rentgear/backup/storage-<tanggal>.tgz -C /root/rentgear/rentgear_api`.
4. Nyalakan lagi dengan `sh /sdcard/rg/hidup.sh` di Termux, lalu periksa seperti langkah 6 di bagian 2.

Data yang dibuat setelah cadangan itu hilang, jadi pilih cadangan terbaru yang masih sehat. Cadangan berisi data
pribadi (foto KTP, NIK terenkripsi), jadi jangan disalin ke luar HP tanpa izin pemilik proyek.

## 4. Pemeliharaan stok

Stok dikelola tiap penyedia di menu Alat. Server menjaga dua aturan:

- stok total minimal 1 unit, dan stok tiap ukuran tidak boleh negatif;
- stok tidak bisa diturunkan di bawah unit yang sudah dipesan atau sedang disewa. Contoh: bila 3 tenda sudah dipesan
  untuk minggu depan, stok tenda tidak bisa diubah menjadi 2 sampai salah satu sewa selesai. Pesan galatnya menyebut
  jumlah unit dan tanggal terakhir pesanan.

Prosedur pembaruan stok untuk penyedia:

1. Alat baru datang: buka Alat > pilih alat > tambah stok (atau stok per ukuran) > "Simpan perubahan". Stok baru
   langsung bisa dipesan.
2. Alat rusak dan perlu diperbaiki: kurangi stok sebanyak unit yang rusak. Bila semua unit rusak, matikan
   "Tampilkan di katalog" supaya tidak bisa dipesan.
3. Alat hilang atau tidak bisa diperbaiki: kurangi stok secara permanen.
4. Alat selesai diperbaiki: tambahkan kembali stoknya, dan nyalakan lagi "Tampilkan di katalog" bila tadi dimatikan.
5. Bila pengurangan stok ditolak karena pesanan yang sudah ada, ulangi setelah sewa yang disebut di pesan selesai.

Pantau stok setiap hari:

- penyedia: layar Alat menampilkan unit tersedia hari ini, sedang disewa, dipesan hari ini, dan kerusakan terakhir;
- admin: Dashboard > "Status alat hari ini" menampilkan semua toko sekaligus.

## 5. Pencatatan kerusakan barang

Kerusakan dicatat saat alat kembali, oleh penyedia, di layar transaksi > "Terima pengembalian alat":

1. Ambil foto kondisi alat saat diterima kembali. Foto saat serah terima sudah diambil sebelumnya, jadi keduanya bisa
   dibandingkan. Foto tidak bisa dihapus.
2. Pilih kondisi: baik, rusak ringan, rusak berat, atau hilang.
3. Isi catatan kerusakan (bagian yang rusak) dan denda kerusakan. Aplikasi mengisi awal denda dari pedoman toko dalam
   persen deposit; nominal bisa diubah, tetapi tidak boleh melebihi deposit dan tidak boleh lebih dari 0 bila
   kondisinya baik.
4. Denda lebih dari separuh deposit, atau denda yang diberi keberatan oleh penyewa, ditinjau admin sebelum transaksi
   ditutup. Admin bisa meminta pendapat AI yang membandingkan foto sebelum dan sesudah; keputusan tetap di admin.

Hasilnya tersimpan di beberapa tempat:

- transaksi itu: kondisi, catatan, denda, foto, dan riwayat status;
- form alat > "Catatan kerusakan": semua pengembalian rusak atau hilang untuk alat itu, terbaru lebih dulu;
- layar Alat: label "Kerusakan terakhir" pada alat yang pernah kembali rusak;
- riwayat penyewa di menu admin Penyewa: jumlah kerusakan, yang ikut dihitung untuk blacklist otomatis;
- jejak audit: keputusan admin atas denda.

Setelah mencatat kerusakan, ikuti prosedur stok di bagian 4 (kurangi stok atau sembunyikan alat sampai diperbaiki).

## 6. Pencatatan galat dan kendala

| Tempat | Isi |
|---|---|
| `storage/logs/laravel.log` (di dalam Ubuntu, folder API) | Galat server, kegagalan Gemini dan email. Pesan tidak memuat kunci API. Di server publik `APP_DEBUG=false`, jadi pengguna tidak melihat detail galat. |
| `storage/logs/schedule.log` | Keluaran pekerjaan terjadwal. |
| `~/rentgear-api.log` di Termux | Keluaran `php artisan serve`. |
| `/sdcard/rg/*.log` | Hasil skrip pembaruan dan `hidup.sh`. |
| Jejak audit (menu admin) | Masuk, gagal masuk, daftar, buka toko, kirim dokumen toko, keputusan admin, blacklist, permintaan AI. Tidak bisa diubah atau dihapus lewat API. |

Saat ada kendala:

1. Catat waktu, akun yang dipakai, layar, dan pesan yang tampil.
2. Cari baris pada waktu itu di `laravel.log`. Kode galat API (mis. `SLOT_UNAVAILABLE`, `AI_UNAVAILABLE`) sama di
   aplikasi dan server, jadi bisa dicocokkan.
3. Bila penyebabnya bug, tambahkan tes yang menunjukkan bug itu, perbaiki, jalankan semua tes, lalu perbarui server
   (bagian 2).
4. Catat kendala dan perbaikannya di `rentgear_app/HANDOFF.md`.

## 7. Jadwal pemeliharaan

| Kapan | Siapa | Kegiatan |
|---|---|---|
| Setiap hari | Admin | Periksa Dashboard: penyedia menunggu verifikasi, denda ditinjau, laporan barang, dan status alat. |
| Setiap hari | Penyedia | Periksa Pesanan (tab Aksi) dan layar Alat; perbarui stok bila ada alat rusak, hilang, atau baru. |
| Setiap minggu | Tim teknis | Cadangkan `storage/app`, periksa ukuran `laravel.log`, dan pastikan situs serta API menjawab. |
| Setiap pembaruan | Tim teknis | Jalankan tes, ikuti bagian 2, dan catat hasilnya di `HANDOFF.md`. |
| Bila kunci bocor | Pemilik proyek | Ganti kunci di `.env` server (Gemini, Gmail App Password), lalu nyalakan ulang API. |
