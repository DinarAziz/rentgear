# Bagian 8: Rencana kerja setelah tahap aplikasi lokal

Disusun 1 Oktober 2026 dari keputusan pemilik proyek. Dokumen ini mencatat urutan kerja dan keputusan yang sudah
diambil, supaya tiap tahap bisa dikerjakan terpisah.

## Urutan

| Tahap | Isi | Status |
|---|---|---|
| 1 | Denda dan blacklist di aplikasi Flutter (tanpa server) | Selesai, lihat bagian 1 |
| 2 | Katalog per penyedia: halaman toko, rating, komentar, follow, lokasi di peta | Selesai, lihat bagian 2 |
| 3 | Server Laravel + MySQL, lalu Flutter bisa memilih data lokal atau server | Selesai, lihat bagian 3 |
| 4 | Daftar akun, login dengan akun Google, dan jejak audit admin | Selesai, lihat bagian 4 |
| 5 | Fitur AI dengan Gemini | Selesai: tiga saran AI dan perbandingan foto kondisi, lihat bagian 5 |
| 6 | Aturan denda yang bisa diatur penyedia | Selesai, lihat bagian 6 |
| 7 | Payment gateway dan versi iOS | Menyusul |

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

Peta di dalam aplikasi (ditambahkan 3 Oktober 2026), memakai OpenStreetMap lewat paket `flutter_map`, jadi tidak
butuh API key atau akun penagihan:

- Tombol "Peta" di halaman awal penyewa membuka peta semua toko terverifikasi. Kartu toko di bawah peta bisa digeser,
  dan peta ikut pindah ke toko yang dipilih. Di layar lebar daftar toko ada di samping peta.
- Bila penyewa mengizinkan lokasi, daftar toko diurutkan dari yang terdekat (toko yang diikuti tetap di atas) dan tiap
  kartu menampilkan jaraknya. Jarak dihitung garis lurus dengan rumus haversine di `rentgear_app/lib/core/maps.dart`.
  Lokasi penyewa hanya dipakai di perangkat, tidak disimpan dan tidak dikirim ke server.
- Halaman toko menampilkan peta kecil lokasi toko. Tombol "Buka di Google Maps" tetap ada untuk petunjuk arah.
- Penyedia mengatur titik tokonya di Profil, "Lokasi toko di peta", dengan menggeser peta. Di server: `PUT
  /api/v1/provider/location`.

Balasan toko atas ulasan (ditambahkan 3 Oktober 2026): pemilik toko membuka "Halaman toko dan ulasan" dari Profil,
lalu menekan "Balas" pada sebuah ulasan. Satu ulasan punya satu balasan, dan balasan baru menggantikan yang lama.
Balasan tampil di bawah ulasan untuk semua pengguna. Di server: `PUT /api/v1/reviews/{id}/reply`.

Belum dibuat: rute dan perkiraan waktu tempuh di dalam aplikasi, dan pencarian alamat di peta. Ubin peta diambil dari server publik OpenStreetMap, yang cukup untuk demo; untuk pemakaian ramai perlu
penyedia ubin sendiri.

## 3. Server Laravel (selesai)

Kodenya ada di `rentgear_api/`, cara menjalankannya di `rentgear_api/README.md`, rancangannya di
`docs/superpowers/specs/2026-10-01-laravel-api-design.md`.

- REST `/api/v1` dengan token Sanctum. Satu endpoint untuk tiap operasi aplikasi, jadi layar Flutter tidak berubah.
- Aturan stok, status, denda, blacklist, dan jaminan disalin ke `app/Domain/` dan diuji dengan kasus yang sama
  seperti tes Dart.
- Booking berjalan dalam transaksi database dengan baris alat terkunci, sehingga unit terakhir hanya jatuh ke satu
  booking.
- Aplikasi Flutter dibangun dengan `--dart-define=API_URL=...` untuk memakai server. Tanpa itu aplikasi tetap
  memakai data di perangkat.
- Dalam mode server, layar memuat ulang tiap 8 detik, sehingga perubahan dari perangkat lain ikut tampil.

Satu penyimpangan dari `04-DATABASE.md`: peran pengguna disimpan di satu kolom `role`, bukan tabel `user_roles`.

Hosting publik (4 Oktober 2026): server dan situs berjalan di HP Redmi pemilik proyek, di
`https://rentgear.serverbaik.my.id` (situs di `/`, API di `/api`), lewat Termux, Ubuntu, nginx, dan Cloudflare Tunnel.
Database di sana SQLite. Situs publik sekarang memakai server, jadi semua perangkat melihat data yang sama. Password
admin di server publik berbeda dari akun demo lain. Cara memasang dan memperbarui ada di `rentgear_api/README.md`.

Bukti transfer diperiksa penyedia (7 Oktober 2026). Setelah penyewa mengunggah bukti, status menjadi "Pembayaran
diperiksa". Penyedia menerimanya, lalu status menjadi "Siap diambil", atau menolaknya dengan alasan, lalu penyewa
kembali ke "Menunggu pembayaran" dan bisa mengunggah bukti baru. Jumlah unggah ulang tidak dibatasi. Stok tetap
terkunci selama menunggu. Sebelumnya bukti apa pun langsung dianggap sah.

Belum dibuat: panel admin berbasis web dan pencocokan nominal bukti transfer secara otomatis. Penyedia mencocokkan
nominal sendiri dengan mutasi rekeningnya.

### Toko contoh tambahan (5 Oktober 2026)

Server publik sekarang berisi 8 toko terverifikasi dan 57 alat di katalog (32 sampai 5 Oktober, ditambah 25 pada
6 Oktober, lihat paragraf berikut). Enam toko baru (Probolinggo, Pasuruan,
Kepanjen, Banyuwangi, Magetan, Surabaya) ditambahkan oleh `MoreStoresSeeder`, yang aman dijalankan di database yang
sedang dipakai: `php artisan db:seed --class=MoreStoresSeeder --force`. Nama toko, alamat, rekening, dan ulasannya
adalah contoh, dan fotonya memakai berkas yang sama dengan toko demo awal. Aplikasi mode data lokal tetap berisi tiga
toko awal.

Pada 6 Oktober 2026 katalog ditambah 25 alat dari tujuh jenis baru: matras, trekking pole, hammock, kursi lipat,
flysheet, lentera, dan ponco. Enam jenis pertama masuk kategori baru "Perlengkapan"; lentera masuk "Penerangan".
Alat itu ditambahkan ke delapan toko terverifikasi oleh `MoreGearSeeder`, yang juga aman dijalankan di database yang
sedang dipakai: `php artisan db:seed --class=MoreGearSeeder --force`. Tiga belas fotonya diambil dari Wikimedia
Commons; pembuat dan lisensinya tercatat di `rentgear_app/assets/equipment/credits.json` dan tampil di layar kredit
foto. Nama alat, merek, dan harga adalah contoh.

## 4. Login Google dan jejak audit

### Login Google (selesai)

- Tombol "Masuk dengan Google" di layar login. Tombol hanya tampil bila aplikasi memakai server dan dibangun dengan
  `--dart-define=GOOGLE_CLIENT_ID=...`.
- Aplikasi hanya mengambil ID token dari Google. Server yang memeriksanya (`POST /api/v1/auth/google`): token harus
  dibuat untuk client ID yang terdaftar di `GOOGLE_CLIENT_IDS`, belum kedaluwarsa, dan emailnya sudah terverifikasi.
- Akun Google yang belum dikenal menjadi akun penyewa baru. Akun lama dikenali dari emailnya dan perannya tetap.
- Akun admin tidak bisa masuk dengan Google, hanya dengan password.
- Rute masuk dibatasi 20 percobaan per menit.

Client ID sudah dibuat dan terpasang di server, situs, dan APK. Pada 5 Oktober 2026 ditemukan bahwa yang terpasang
sebelumnya adalah client ID jenis Android, padahal aplikasi dan server harus memakai client ID jenis Web; itu sebabnya
Google menolak di web dan di HP. Setelah diganti, tombol Google tampil di situs tanpa galat, dan pemilik proyek melaporkan
berhasil masuk dengan akun Google pada hari yang sama. Cara membuat client ID ada di `rentgear_api/README.md`, bagian "Login Google".
Yang sudah diuji: sisi server dengan jawaban Google tiruan (5 tes).

### Daftar akun dengan email dan password (selesai, 5 Oktober 2026)

- Layar "Daftar Akun" dibuka dari layar login lewat "Belum punya akun? Daftar". Tombol itu hanya ada bila aplikasi
  memakai server, karena akun baru disimpan di server.
- Pengguna memilih daftar sebagai penyewa atau penyedia. Isian: nama, email, nomor HP, kota, dan password (minimal 8
  karakter). Penyedia juga mengisi nama toko, alamat toko, dan rekening tujuan transfer.
- Penyewa langsung bisa menyewa. Toko penyedia baru berstatus menunggu verifikasi admin, jadi alatnya belum tampil
  di katalog. Titik toko di peta diberi nilai awal (Alun-alun Malang) dan dipindahkan penyedia dari menu Profil.
- Akun admin tidak bisa dibuat dari sini. Email yang sudah terdaftar ditolak. Pendaftaran tercatat di jejak audit.
- Tidak memakai captcha. Rute daftar dan masuk dibatasi 20 permintaan per menit, dan penyedia baru tetap harus
  diverifikasi admin. Email tidak diverifikasi karena server belum punya pengirim email.
- Server: `POST /api/v1/auth/register`. Tes: 7 di server, 4 di aplikasi. Diuji di situs publik: daftar sebagai
  penyedia dari formulir, dan daftar sebagai penyewa lewat API.

### Lupa password dengan kode email (dibuat 6 Oktober 2026, email belum terkirim sungguhan)

- Layar login punya tombol "Lupa password?". Tombol itu hanya ada bila aplikasi memakai server.
- Langkah 1: pengguna mengisi email, lalu server mengirim kode 6 angka ke email itu. Langkah 2: pengguna mengisi
  kode dan password baru (minimal 8 karakter), lalu langsung masuk.
- Kode berlaku 15 menit dan hanya bisa dipakai sekali. Setelah 5 tebakan salah kode itu batal. Kode baru untuk email
  yang sama bisa diminta lagi setelah 60 detik, dan kode lama tidak berlaku lagi. Server hanya menyimpan hash kode.
- Email yang tidak terdaftar mendapat jawaban yang sama dengan email yang terdaftar, supaya orang tidak bisa
  memeriksa siapa yang punya akun. Akun admin tidak dikirimi kode; password admin diganti di server.
- Setelah password diganti, semua sesi lama akun itu berakhir. Permintaan kode dan penggantian password tercatat di
  jejak audit. Akun yang dibuat lewat Google bisa memakai cara ini untuk membuat password.
- Server: `POST /api/v1/auth/forgot-password` dan `POST /api/v1/auth/reset-password`. Tes: 10 di server, 4 di aplikasi.
- Yang belum: server belum punya pengirim email. Selama `MAIL_MAILER=log`, isi email hanya masuk ke
  `storage/logs/laravel.log` dan tidak sampai ke pengguna. Cara mengisi pengirim Gmail ada di
  `rentgear_api/README.md`, bagian "Lupa password". Fitur ini juga belum dipasang di server publik dan belum dicoba
  di HP.

### Jejak audit (selesai)

- Yang dicatat: masuk, daftar akun, masuk dan daftar dengan Google, gagal masuk, perubahan status penyedia,
  keputusan denda kerusakan, masuk blacklist (oleh admin atau otomatis oleh sistem), dan pencabutan blacklist.
- Tiap baris berisi waktu, pelaku dan perannya, aksi, sasaran, dan rincian. Password tidak pernah dicatat. Server juga
  menyimpan alamat IP.
- Admin membacanya dari tombol "Jejak audit" di Dashboard, dengan saringan aksi admin, masuk dan daftar, dan sistem.
- Jejak hanya bisa ditambah. Tidak ada layar atau rute API untuk mengubah atau menghapusnya (`GET /api/v1/audit` saja).
  Di mode data lokal, "Reset data demo" ikut mengosongkannya, karena itu menghapus semua data di perangkat.

### Kunci dan rahasia

- Kunci API Gemini hanya ada di `rentgear_api/.env` (`GEMINI_API_KEY`). File itu diabaikan git dan hanya bisa dibaca
  pemilik akun di komputer server. Kunci tidak pernah masuk ke APK, build web, atau repositori.
- Client ID Google bukan rahasia, jadi boleh ada di aplikasi.
- Bila kunci pernah terkirim lewat chat, email, atau tangkapan layar, buat kunci baru di aistudio.google.com dan
  hapus yang lama.

## 5. Fitur AI (Gemini)

Dibuat 3 Oktober 2026. Modelnya `gemini-2.5-flash`, dipanggil dari server (`app/Services/GeminiClient.php` dan
`AiAdvisor.php`). Aplikasi tidak pernah memegang kunci API.

Yang sudah ada:

- **Saran paket alat** untuk penyewa (tombol "Saran AI" di halaman awal). Penyewa menulis rencana perjalanan, jumlah
  orang, dan lama sewa. AI memilih paling banyak 6 alat dari katalog toko terverifikasi dan memberi alasan. Server
  memeriksa jawabannya: alat yang tidak ada di katalog dibuang, jumlah dibatasi stok, dan biaya sewa serta deposit
  dihitung server. Penyewa tetap memesan tiap alat sendiri.
- **Pendapat atas denda kerusakan** untuk admin (tombol "Minta pendapat AI" di transaksi yang dendanya ditinjau). AI
  menilai wajar, terlalu tinggi, terlalu rendah, atau perlu bukti, dan memberi nominal saran yang dibatasi sebesar
  deposit. Transaksi tidak berubah; admin tetap yang menetapkan.
- **Analisis risiko penyewa** untuk admin (tombol "Analisis risiko AI" di tab Penyewa): rendah, sedang, atau tinggi,
  dengan paling banyak tiga alasan dari riwayat sewa.

Aturan yang dipegang:

- AI memberi saran, keputusan yang menyangkut uang tetap di tangan manusia (`01-KONSEP-DAN-ANALISIS.md`).
- Nama, email, nomor dokumen, dan foto penyewa tidak dikirim ke Gemini. Yang dikirim hanya angka riwayat, data alat,
  dan catatan denda.
- Bila AI mati, kuncinya kosong, atau jawabannya rusak, server menjawab `AI_UNAVAILABLE` dan aplikasi menampilkan
  pesan biasa. Semua alur sewa tetap jalan.
- Tombol AI hanya tampil saat aplikasi memakai server. Rute AI dibatasi 15 permintaan per menit.
- Permintaan admin ke AI ikut tercatat di jejak audit.

### Foto kondisi alat (ditambahkan 4 Oktober 2026)

- Toko menambah foto alat "saat diserahkan" (selama alat belum kembali) dan "saat kembali" (setelah alat diterima,
  sebelum transaksi ditutup), paling banyak 4 foto per tahap, dari bagian "Foto kondisi alat" di detail transaksi.
- Foto tidak wajib, dan foto yang sudah tersimpan tidak bisa dihapus. Penyewa, toko, dan admin bisa melihatnya; orang
  lain tidak.
- Saat admin menekan "Minta pendapat AI", foto kedua tahap ikut dikirim. AI menulis apa yang terlihat baru rusak, atau
  mengatakan fotonya tidak cukup jelas. Yang dikirim hanya foto alat, bukan foto orang atau dokumen.
- Di server: `POST /api/v1/rentals/{id}/condition-photos` dan `GET /api/v1/files/condition/{id}`.

Berbeda dari `02-ALGORITMA.md` (ALG-3): foto melekat pada transaksi, bukan pada unit alat, karena aplikasi belum
mencatat unit satu per satu. Skor kondisi 0 sampai 100 dan daftar periksa belum dibuat. Skor dan penyusunan paket yang
sepenuhnya deterministik (ALG-1) juga belum; saat ini pemilihan alat dilakukan AI lalu diperiksa server.

Kunci Gemini yang dipakai adalah paket gratis. Kuotanya habis saat diuji berulang-ulang, dan server lalu menjawab
"Kuota AI sedang habis". Untuk demo, jangan menekan tombol AI berkali-kali dalam satu menit.

## 6. Aturan denda yang bisa diatur penyedia (selesai)

Dibuat 4 Oktober 2026 atas permintaan pemilik proyek: aturan denda jangan kaku, dan penyedia bisa mengaturnya.
Keputusan pemilik proyek pada hari yang sama: penyedia mengatur pengali denda terlambat, masa tenggang, dan pedoman
denda kerusakan; pengali dibatasi 1 sampai 2 kali; aturan dikunci saat booking.

- Penyedia membuka Profil, "Aturan denda", lalu menggeser tiga hal:
  - denda per hari terlambat, 1 sampai 2 kali tarif harian (bawaan 1,5 kali);
  - masa tenggang, 0 sampai 12 jam setelah hari terakhir sewa (bawaan tidak ada);
  - pedoman denda kerusakan dalam persen deposit untuk rusak ringan, rusak berat, dan hilang (bawaan 25, 60, 100).
- Pedoman kerusakan bukan batas. Ia menjadi isian awal saat penyedia menerima alat kembali, dan penyedia tetap boleh
  mengubah nominalnya sesuai kerusakan.
- Penyewa melihat "Aturan denda toko" di halaman detail alat, sebelum memesan.
- Tiap sewa menyimpan salinan aturan saat booking dibuat. Bila toko mengubah aturannya, sewa yang sudah dipesan tidak
  ikut berubah.
- Pendapat AI atas denda memakai pedoman toko sebagai acuan.

Yang tetap diatur platform, sama untuk semua toko, karena melindungi penyewa: denda kerusakan tidak boleh melebihi
deposit, denda di atas separuh deposit ditinjau admin, penyewa boleh mengajukan keberatan, dan blacklist otomatis
berlaku setelah 3 pelanggaran.

Kodenya: `FinePolicy` di `rentgear_app/lib/domain/fines.dart` dan `rentgear_api/app/Domain/Fines/FinePolicy.php`.
Di server: `PUT /api/v1/provider/fine-policy`.
