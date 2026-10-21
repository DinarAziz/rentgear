# Requirement dosen dan pengerjaan RentGear

Catatan kerja untuk melanjutkan proyek dan bahan diskusi kelompok 4. Isinya: apa yang diminta dosen lewat tabel
penilaian, apa yang sudah dikerjakan untuk memenuhinya, status deploy, dan hal yang masih perlu diputuskan bersama.

Status per 21 Oktober 2026, commit terakhir `ccce7be` di branch `master` (belum di-push ke GitHub).

## 1. Requirement dari dosen

Dosen mengirim "Tabel penilaian proyek mahasiswa". Tabel itu berisi empat proyek (Mount Tracker, Cash Alert, Lost and
Found Campus, dan RENT GEAR). Kolom yang berlaku untuk kita adalah RENT GEAR. Penilaian mengikuti lima tahap
Waterfall dengan bobot di bawah, dan setiap tahap **dinilai berdasarkan bukti**: harus ada dokumen, kode, hasil uji,
atau tampilan aplikasi yang bisa ditunjukkan.

Setiap tahap punya dua baris: isi utama tahap itu, lalu "sistem yang perlu ditambahkan".

| Tahap | Bobot | Isi utama (kolom RENT GEAR) | Sistem yang perlu ditambahkan |
|---|---|---|---|
| 1. Analisis kebutuhan | 15% | Identifikasi kebutuhan penyewaan, stok, durasi, dan pembayaran. | Data penyewa, katalog, durasi sewa, dan ketentuan pengembalian. |
| 2. Desain sistem | 20% | Use case, activity diagram pemesanan, class diagram, dan ERD. | Relasi Customer–Gear–Rental–Payment dan rancangan ketersediaan stok. |
| 3. Implementasi | 25% | Modul katalog, pemesanan, perhitungan biaya, dan pengembalian. | Dashboard admin, riwayat penyewaan, dan status barang tersedia/disewa. |
| Penerapan PBO | termasuk implementasi | Class Customer, Gear, Rental, dan Payment. | |
| 4. Pengujian | 20% | Uji stok habis, pemesanan bersamaan, biaya, dan keterlambatan. | Validasi tanggal, pencegahan pemesanan ganda, dan pengujian pengembalian. |
| 5. Deployment dan maintenance | 15% | Aplikasi dapat dijalankan, panduan penyewa/admin, dan pemeliharaan stok. | Panduan operasional, pencatatan kerusakan barang, dan prosedur pembaruan stok. |
| Total | 100% | Dinilai berdasarkan bukti | |

## 2. Status pemenuhan per kriteria

Semua kriteria sudah punya bukti. Pemetaan rinci (butir ke berkas) ada di `docs/00-KESESUAIAN-PENILAIAN.md`.
Nomor slide di bawah mengikuti deck web (37 slide).

| Kriteria | Status | Bukti utama | Slide |
|---|---|---|---|
| Kebutuhan penyewaan, stok, durasi, pembayaran | Ada sejak awal | `docs/01-KONSEP-DAN-ANALISIS.md` | 3–10 |
| Data penyewa, katalog, durasi, ketentuan pengembalian | Ada sejak awal | aplikasi, `docs/07-JAMINAN-SEWA.md`, `docs/08-RENCANA-KERJA.md` | 12–13, 30 |
| Use case | Ada sejak awal | `docs/03-FLOW-DAN-USECASE.md` bagian 5 | |
| Activity diagram | Ditambah 21 Okt | `docs/10-ACTIVITY-DIAGRAM.md` (4 diagram dengan swimlane) | 17 |
| Class diagram | Ditambah 21 Okt | `docs/09-DIAGRAM-KELAS-DAN-PBO.md` | 24 |
| ERD | Ada, diperbarui | `docs/04-DATABASE.md`, tabel `payments` ditambahkan | 22–23 |
| Relasi Customer–Gear–Rental–Payment | Dilengkapi 21 Okt | kelas `Payment` dan tabel `payments` baru | 23–24 |
| Rancangan ketersediaan stok | Ada sejak awal | `docs/02-ALGORITMA.md` ALG-2 | 19 |
| Modul katalog, pemesanan, biaya, pengembalian | Ada sejak awal | `rentgear_app/`, `rentgear_api/` | 28 |
| Dashboard admin, riwayat sewa | Ada sejak awal | menu admin, Sewa Saya, riwayat status | 28 |
| Status barang tersedia/disewa | Ditambah 21 Okt | layar admin "Status Alat Hari Ini", layar Alat penyedia | 31 |
| Class Customer, Gear, Rental, Payment (PBO) | Dilengkapi 21 Okt | `AppUser`, `Equipment`, `Rental`, `Payment`; empat prinsip PBO di Bagian 9 | 24 |
| Uji stok habis, bersamaan, biaya, keterlambatan | Dilengkapi 21 Okt | `docs/11-LAPORAN-PENGUJIAN.md` (38 kasus), `docs/hasil-uji/` | 32–33 |
| Validasi tanggal, pemesanan ganda, pengembalian | Ada, dilaporkan 21 Okt | kasus 7–11 dan 23–33 di laporan pengujian | 32 |
| Aplikasi dapat dijalankan | Ada | `https://rentgear.serverbaik.my.id`, APK, `docs/13-PANDUAN-OPERASIONAL.md` bagian 1 | 34 |
| Panduan penyewa/admin | Ditambah 21 Okt | `docs/12-PANDUAN-PENGGUNA.md`, video cara pakai | 34 |
| Pemeliharaan stok, prosedur pembaruan stok | Ditambah 21 Okt | aturan stok di kode, `docs/13-PANDUAN-OPERASIONAL.md` bagian 4 | 34 |
| Panduan operasional | Ditambah 21 Okt | `docs/13-PANDUAN-OPERASIONAL.md` | 34 |
| Pencatatan kerusakan barang | Ditambah 21 Okt | "Catatan kerusakan" di form alat, `docs/13` bagian 5 | 34 |

## 3. Pengerjaan yang sudah dilakukan

### Sebelum tabel dosen (21 Oktober pagi)

- Pendaftaran dan verifikasi penyedia: penyedia mengirim NIK (terenkripsi), foto KTP, swafoto dengan KTP, dan 1–3 foto
  toko. Admin memeriksa lalu memverifikasi atau menolak dengan alasan; pemilik toko bisa mengirim ulang dan mendapat
  email hasilnya. Penyewa bisa membuka toko dari Profil. NIK yang dipakai dua toko memunculkan peringatan untuk admin.
- Asisten AI dibatasi: hanya membahas perlengkapan pendakian dan camping, aturan dikirim sebagai `systemInstruction`,
  permintaan di luar topik ditolak (`AI_OFF_TOPIC`), jawaban dipotong, dan tiap akun dapat 20 saran per hari.
- Keduanya sudah dideploy ke server publik.

### Untuk menutup kekurangan tabel dosen (21 Oktober siang)

| Commit | Isi |
|---|---|
| `bc7ba1b` | `Payment` menjadi kelas dan tabel sendiri. Satu bukti transfer satu baris, nominal dikunci server, bukti yang ditolak tetap tersimpan. Detail sewa menampilkan riwayat pembayaran. |
| `0d484d8` | Uji pemesanan bersamaan (`rentgear_api/tests/concurrency/bersamaan.sh`). Temuan: 2 dari 8 penyewa mendapat galat 500. Perbaikan: transaksi SQLite `IMMEDIATE` dan `busy_timeout` 5 detik. Setelah itu 3 putaran lulus. |
| `20d68e2` | Status alat hari ini (disewa, dipesan, tersedia) untuk admin dan penyedia, dan catatan kerusakan per alat. |
| `93c2691` | Stok tidak bisa dikurangi di bawah unit yang sudah dipesan. Server publik dijalankan dengan 4 pekerja (sebelumnya hanya 1). |
| `4fc41ff` | Dokumen 00 dan 09–13: pemetaan penilaian, diagram kelas dan PBO, activity diagram, laporan pengujian, panduan pengguna, panduan operasional. |
| `ccce7be` | Deck web diperbarui (37 slide) dan PowerPoint tanpa animasi. |

Jumlah tes otomatis sekarang 318 (179 server, 139 aplikasi), semuanya lulus.

### Presentasi

- Deck web (`presentasi/`): metode Waterfall 5 tahap; slide baru activity diagram, diagram kelas dan PBO, fitur baru
  (empat layar asli aplikasi), temuan uji serentak, serta deployment dan pemeliharaan. ERD, struktur database, dan
  slide pengujian ikut diperbarui.
- `RentGear-presentasi-kelompok4-tanpa-animasi.pptx`: salinan untuk dosen, 38 slide, tanpa animasi dan transisi.
  Slide implementasi dan pengujian masing-masing menjadi 2 halaman supaya tidak ada panel yang hilang.
- `RentGear-presentasi-kelompok4.pptx`: versi beranimasi, 36 slide.
- Slide video promo tidak dimasukkan ke kedua PowerPoint, sama seperti sebelumnya.

## 4. Status deploy

| Bagian | Status |
|---|---|
| Situs aplikasi (build `main.dart.269a852beb.js`) | Terpasang |
| Migrasi tabel `payments` | Terpasang, 2 bukti transfer lama sudah dipindah |
| API | **Mati (502)** sampai `hidup.sh` dijalankan di HP |
| Deck web baru (37 slide) | Sudah dikirim ke HP sebagai `deck.zip`, belum dipasang |

Yang harus dijalankan di Termux pada HP Redmi, setelah kunci layar dibuka:

```bash
sh /sdcard/rg/hidup.sh
```

```bash
sh /sdcard/rg/run.sh deck
```

Setelah itu periksa: `https://rentgear.serverbaik.my.id/api/v1/categories` menjawab 401 (API hidup), dan
`https://rentgear.serverbaik.my.id/presentasi/` menampilkan 37 slide.

## 5. Bahan diskusi kelompok

Hal-hal di bawah belum diputuskan dan sebaiknya disepakati sebelum presentasi.

1. **Nama kelas.** Di kode, Customer bernama `AppUser` (dengan peran penyewa) dan Gear bernama `Equipment`. Saat ini
   cukup dijelaskan lewat tabel pemetaan di Bagian 9 dan slide 24. Apakah perlu diganti namanya di kode supaya sama
   persis dengan tabel dosen? Mengganti nama menyentuh banyak berkas dan berisiko, jadi saran saya cukup pemetaan.
2. **Bentuk activity diagram.** Diagram dibuat dengan Mermaid dan SVG di slide. Apakah dosen meminta format tertentu
   (mis. gambar UML dari draw.io atau StarUML)?
3. **File yang dikirim ke dosen.** Kirim versi tanpa animasi saja, atau keduanya? Nomor di pojok slide mengikuti deck
   web (mis. "11 / 37"), jadi tidak sama persis dengan nomor halaman PowerPoint tanpa animasi.
4. **Database.** Slide menyebut MySQL sebagai database utama dan SQLite untuk server demo di HP. Server publik
   sekarang memakai SQLite. Siapkan jawaban bila dosen bertanya kenapa, dan bagaimana pemesanan bersamaan tetap aman
   (jawabannya ada di slide 33 dan laporan pengujian).
5. **Pembayaran.** Sekarang transfer manual dengan bukti foto. Payment gateway masih rencana. Perlu disepakati apakah
   ini disebut sebagai batasan atau rencana lanjutan.
6. **APK di HP belum dibangun ulang.** Fitur 21 Oktober (verifikasi toko, riwayat pembayaran, status alat) baru ada di
   versi web. Bila demo memakai HP, APK perlu dibangun ulang dulu.
7. **Pembagian presentasi.** Siapa menjelaskan tiap tahap Waterfall (analisis, desain, implementasi, pengujian,
   deployment).
8. **Push ke GitHub.** Semua commit masih lokal. Perlu keputusan kapan di-push.

## 6. Pekerjaan yang masih terbuka

- Jalankan dua perintah Termux di bagian 4, lalu periksa situs dan API.
- Bangun ulang APK bila demo memakai HP.
- Ganti Gmail App Password dan kunci Gemini (keduanya pernah tertulis di chat).
- Push ke GitHub setelah disepakati.
- Suara bahasa Indonesia untuk video cara pakai (butuh kredit ElevenLabs).

## 7. Cara melanjutkan pekerjaan

Catatan teknis lengkap ada di `rentgear_app/HANDOFF.md`, bagian "Resume here" yang terakhir.

Menjalankan semua tes:

```bash
cd rentgear_api && php artisan test
```

```bash
cd rentgear_app && flutter test
```

Membangun ulang PowerPoint setelah deck web diubah. Butuh `puppeteer-core`, `pptxgenjs`, `sharp`, dan `jszip` yang
dipasang dengan `npm install` di satu folder, lalu folder `node_modules`-nya ditunjuk lewat `NODE_PATH`:

```bash
cd presentasi/ppt && node capture.js "$(cd .. && pwd)" <folder-tangkapan>
```

```bash
cd presentasi/ppt && node build.js <folder-tangkapan> ../../RentGear-presentasi-kelompok4-tanpa-animasi.pptx tanpa-animasi
```

Tanpa argumen `tanpa-animasi`, `build.js` membuat versi beranimasi.

Memperbarui server publik: ikuti `docs/13-PANDUAN-OPERASIONAL.md` bagian 2.

## 8. Daftar berkas penting

| Berkas | Isi |
|---|---|
| `docs/00-KESESUAIAN-PENILAIAN.md` | Pemetaan setiap baris tabel dosen ke bukti |
| `docs/09-DIAGRAM-KELAS-DAN-PBO.md` | Diagram kelas dan empat prinsip PBO |
| `docs/10-ACTIVITY-DIAGRAM.md` | Activity diagram pemesanan, pengembalian, verifikasi toko, saran AI |
| `docs/11-LAPORAN-PENGUJIAN.md` | 38 kasus uji dan temuan |
| `docs/hasil-uji/` | Hasil tes per 21 Oktober 2026 |
| `docs/12-PANDUAN-PENGGUNA.md` | Panduan penyewa, penyedia, admin |
| `docs/13-PANDUAN-OPERASIONAL.md` | Menjalankan, memperbarui, cadangan, stok, kerusakan, galat |
| `presentasi/` | Deck web |
| `RentGear-presentasi-kelompok4-tanpa-animasi.pptx` | PowerPoint untuk dosen |
| `rentgear_app/HANDOFF.md` | Log teknis lengkap per sesi |
