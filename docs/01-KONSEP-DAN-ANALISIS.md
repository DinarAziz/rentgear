# RANCANGAN SISTEM — MARKETPLACE PENYEWAAN ALAT HIKING/CAMPING
### Bagian 1: Konsep, Analisis, Aktor, dan Fitur

Status dokumen: **DRAFT DESAIN — belum diimplementasikan**
Peran penulis: Software Architect / System Analyst
Tanggal: 2026-09-20

---

## 1. RINGKASAN KONSEP APLIKASI

**Nama kerja:** *RentGear* (bebas diganti, mis. "Sewain", "CampKit", "Bivak").

Aplikasi web marketplace **multi-provider** untuk penyewaan alat hiking/camping.
Berbeda dengan e-commerce jual-beli, objek transaksi di sini adalah **hak pakai
barang fisik dalam rentang waktu tertentu**, dan barang itu **harus kembali**.

Tiga konsekuensi arsitektural yang membedakannya dari e-commerce biasa:

| Aspek | E-commerce jual-beli | Marketplace penyewaan (aplikasi ini) |
|---|---|---|
| Unit stok | Jumlah berkurang permanen | Jumlah dipinjam sementara, lalu kembali |
| Dimensi ketersediaan | Skalar (qty) | **Skalar × interval waktu** |
| Akhir transaksi | Barang diterima pembeli | Barang **dikembalikan + diperiksa kondisinya** |
| Risiko utama | Barang tidak sampai | **Double booking** & **kerusakan barang** |

Dua kebaruan (selling point untuk dosen):
1. **Time-aware availability engine** (sweep-line) yang mencegah double booking.
2. **Siklus kondisi barang berbasis snapshot + delta**, dengan AI sebagai
   *advisor*, bukan pengambil keputusan.

---

## 2. PROBLEM STATEMENT

Fakta lapangan (asumsi kerja, sebaiknya divalidasi dengan survei kecil 15–30
responden agar bab Latar Belakang laporan Anda punya data):

1. **Sisi customer**
   - Pendaki pemula **tidak tahu apa saja yang harus dibawa**. Mereka tahu
     tujuan ("Gunung Prau, 2 hari, 4 orang"), bukan daftar alat.
   - Informasi persewaan tersebar di WhatsApp/Instagram per toko. Tidak ada
     satu tempat untuk membandingkan harga, jarak, dan ketersediaan.
   - **Ketersediaan pada tanggal tertentu tidak transparan.** Customer harus
     chat satu per satu, dan sering dijawab "maaf sudah dibooking".
2. **Sisi provider**
   - Pencatatan booking manual (buku/WhatsApp/Excel) → **double booking**,
     konflik jadwal, dan kehilangan pendapatan.
   - Sengketa kerusakan alat saat pengembalian: tidak ada **bukti kondisi
     awal** yang objektif, sehingga penentuan denda jadi subjektif dan
     memicu konflik dengan customer.
3. **Sisi ekosistem**
   - Tidak ada mekanisme reputasi. Customer tidak tahu provider mana yang
     alatnya terawat.

**Rumusan masalah:**
> Bagaimana merancang sebuah marketplace penyewaan alat hiking yang (a) dapat
> menerjemahkan kebutuhan perjalanan customer menjadi rekomendasi paket alat
> yang benar-benar tersedia pada tanggal yang diminta, (b) menjamin tidak
> terjadi double booking pada stok terbatas, dan (c) menyediakan proses
> pemeriksaan kondisi alat yang objektif dan dapat diaudit?

---

## 3. TUJUAN APLIKASI

**Tujuan umum**
Menyediakan platform web terpusat yang mempertemukan penyedia alat hiking
dengan penyewa, dengan proses penyewaan yang terjadwal, transparan, dan
dapat dipertanggungjawabkan.

**Tujuan khusus (terukur — pakai ini sebagai kriteria pengujian)**
| # | Tujuan | Kriteria keberhasilan (dapat diuji) |
|---|---|---|
| T1 | Mencegah double booking | Uji beban 50 request booking bersamaan pada 1 unit stok → tepat 1 sukses |
| T2 | Rekomendasi paket otomatis | Input kebutuhan → sistem menghasilkan daftar alat berikut alasan skor, ≤ 3 detik |
| T3 | Transparansi ketersediaan | Kalender ketersediaan per alat akurat 100% terhadap data transaksi |
| T4 | Pemeriksaan kondisi terdokumentasi | Setiap transaksi selesai memiliki ≥1 snapshot kondisi sebelum & sesudah |
| T5 | AI tidak otonom | 100% hasil AI berstatus `pending_review` sebelum berdampak finansial |
| T6 | Keamanan peran | Uji akses lintas-role → semua ditolak 403 |

**Batas tegas (non-goals) tahap ini**
- Bukan payment gateway sungguhan (pakai simulasi/manual transfer + bukti).
- Bukan aplikasi mobile native.
- Bukan sistem pengiriman/logistik (ambil di tempat provider).
- Bukan chat real-time (cukup notifikasi + kontak provider).

---

## 4. AKTOR DAN ROLE

### 4.1 Daftar aktor

| Aktor | Deskripsi | Cara memperoleh role |
|---|---|---|
| **Guest** | Pengunjung belum login | default |
| **Customer** | Menyewa alat | registrasi |
| **Provider** | Pemilik/penyedia alat | registrasi + **verifikasi admin** |
| **Admin** | Pengelola platform | di-seed manual, tidak bisa registrasi |
| **System (cron/job)** | Aktor non-manusia: pengingat jatuh tempo, auto-cancel booking tak dibayar, hitung denda keterlambatan | — |
| **Gemini API** | Layanan eksternal, aktor pendukung (advisory) | — |

### 4.2 Model role: **satu user boleh punya banyak role**

Keputusan: gunakan tabel pivot `user_roles`, **bukan** kolom `role` tunggal
di tabel users.

Alasan:
- Realistis: pemilik toko juga bisa menyewa dari toko lain.
- Menghindari duplikasi akun (dan duplikasi NIK — penting, lihat Bagian 4 DB).
- Biaya kompleksitas kecil (satu tabel pivot + satu middleware).

Matriks hak akses ringkas (RBAC sederhana, **bukan** ACL penuh):

| Kemampuan | Guest | Customer | Provider | Admin |
|---|:--:|:--:|:--:|:--:|
| Lihat katalog & detail alat | ✅ | ✅ | ✅ | ✅ |
| Smart matching (rekomendasi) | ✅ (terbatas) | ✅ | ✅ | ✅ |
| Booking | ❌ | ✅ | ✅ | ❌ |
| CRUD alat milik sendiri | ❌ | ❌ | ✅ | ✅ |
| Konfirmasi/tolak booking | ❌ | ❌ | ✅ (miliknya) | ✅ |
| Upload foto kondisi | ❌ | ✅ (saat kembali) | ✅ | ✅ |
| Menjalankan AI inspection | ❌ | ❌ | ✅ (kuota) | ✅ |
| **Menyetujui hasil AI / menetapkan denda** | ❌ | ❌ | ⚠️ mengusulkan | ✅ **final** |
| Verifikasi provider | ❌ | ❌ | ❌ | ✅ |
| Lihat data NIK user lain | ❌ | ❌ | ❌ | ✅ (tersamar + audit log) |

> Catatan desain penting: **provider mengusulkan, admin memutuskan** untuk hal
> yang berdampak uang (denda). Ini mencegah provider nakal memanfaatkan output
> AI untuk memeras customer, sekaligus memenuhi syarat "AI tidak menggantikan
> admin".

---

## 5. DAFTAR FITUR (lengkap, prioritas dibahas di Bagian 9)

### 5.1 Modul Autentikasi & Akun
- F-01 Registrasi customer (email, password, nama, NIK, no. HP)
- F-02 Login / logout / lupa password
- F-03 Pengajuan menjadi provider (upload KTP + foto toko/lokasi)
- F-04 Verifikasi provider oleh admin (approve / reject + alasan)
- F-05 Manajemen profil & alamat

### 5.2 Modul Katalog
- F-06 Kategori alat berjenjang (tenda → tenda kapasitas 4, dst.)
- F-07 CRUD alat oleh provider (nama, deskripsi, spesifikasi, kapasitas orang, berat, harga/hari, deposit)
- F-08 Upload multi-foto alat
- F-09 Manajemen stok (jumlah unit)
- F-10 Pencarian + filter (kategori, harga, lokasi, rating, tanggal)
- F-11 Halaman detail alat + **kalender ketersediaan**
- F-12 Halaman profil publik provider

### 5.3 Modul Smart Matching (inti inovasi)
- F-13 Form kebutuhan perjalanan (jumlah orang, durasi, tujuan, budget, jenis trip, musim)
- F-14 **AI Need Parser** (Gemini): teks bebas → kebutuhan terstruktur
- F-15 **Rule-based Equipment Requirement Engine**: kebutuhan → daftar kategori alat + qty
- F-16 **Scoring & Ranking Engine**: cari kandidat alat nyata, beri skor
- F-17 **Bundle Builder**: susun paket optimal dalam batas budget
- F-18 Penjelasan skor ("kenapa alat ini direkomendasikan") — *explainable*

### 5.4 Modul Ketersediaan & Booking
- F-19 **Availability Engine** (sweep-line) per alat per rentang tanggal
- F-20 Keranjang sewa multi-item (boleh lintas provider → dipecah per provider)
- F-21 Pembuatan booking + perhitungan biaya (sewa + deposit - diskon durasi)
- F-22 Konfirmasi/penolakan oleh provider (dengan batas waktu)
- F-23 Pembayaran (simulasi: upload bukti transfer → verifikasi provider/admin)
- F-24 Auto-cancel booking yang tak dibayar dalam N jam (scheduled job)
- F-25 Timeline status transaksi untuk customer

### 5.5 Modul Serah Terima & Kondisi Alat
- F-26 **Snapshot kondisi PRE-RENTAL** (foto + checklist saat serah terima)
- F-27 Penandaan pengambilan (handover) dengan kode/OTP sederhana
- F-28 **Snapshot kondisi POST-RENTAL** (foto saat pengembalian)
- F-29 **AI Equipment Condition Inspection** (Gemini Vision)
- F-30 **Condition Delta Engine**: bandingkan pre vs post → indikasi perubahan
- F-31 Usulan denda oleh provider → **persetujuan final admin**
- F-32 Perhitungan denda keterlambatan (otomatis, deterministik, bukan AI)
- F-33 Pengembalian deposit

### 5.6 Modul Reputasi & Pelaporan
- F-34 Review & rating customer → alat/provider (hanya setelah transaksi selesai)
- F-35 Skor kondisi alat historis (turun jika sering rusak)
- F-36 Pelaporan masalah (dispute) ke admin
- F-37 Notifikasi in-app (+ email opsional)

### 5.7 Modul Admin
- F-38 Dashboard statistik (transaksi, GMV, provider aktif, alat terbanyak disewa)
- F-39 Manajemen user & provider (suspend, verifikasi)
- F-40 Moderasi katalog
- F-41 **Antrean validasi hasil AI**
- F-42 Penanganan dispute
- F-43 **Audit log** (siapa mengubah apa, kapan)

---

## 6. FITUR AI DAN ALASAN PENGGUNAANNYA

### 6.1 Prinsip desain AI dalam sistem ini

Empat aturan yang saya tegakkan di seluruh rancangan:

1. **AI tidak pernah menjadi sumber kebenaran data.** Stok, harga, tanggal,
   dan ketersediaan **selalu** dari database. AI tidak boleh "mengarang" alat.
2. **AI berada di tepi (edge), bukan di jalur kritis.** Jika Gemini down,
   aplikasi tetap berfungsi penuh lewat jalur fallback deterministik.
3. **Output AI selalu terstruktur (JSON schema) dan tervalidasi** sebelum
   masuk sistem. Field tak dikenal dibuang.
4. **Setiap output AI yang berdampak finansial wajib melewati manusia.**
   Status awal selalu `pending_review`.

### 6.2 AI #1 — Smart Rental Need Parser (bukan "recommender")

> **Klarifikasi desain penting:** Fitur A yang Anda usulkan sebaiknya **dipecah
> dua**. AI hanya menangani bagian yang memang butuh pemahaman bahasa;
> pencocokan dengan katalog dikerjakan algoritma deterministik.

```
Input user (teks bebas / form)
        │
        ▼
[1] GEMINI — Need Parser  ..... memahami bahasa & konteks
        │  output: JSON TripProfile (terstruktur, tervalidasi)
        ▼
[2] RULE ENGINE — Requirement  ..... deterministik, dapat dijelaskan
        │  output: daftar {kategori, qty, prioritas}
        ▼
[3] SCORING ENGINE — Matching  ..... algoritma skoring (Bagian 7)
        │  output: kandidat alat nyata dari DB, terurut
        ▼
[4] BUNDLE BUILDER — Knapsack  ..... optimasi dalam batas budget
        │
        ▼
[5] GEMINI (opsional) — Explainer  ..... menarasikan hasil dalam bhs Indonesia
```

**Kenapa desain ini lebih baik daripada "AI merekomendasikan alat"?**
- AI yang langsung merekomendasikan alat akan **berhalusinasi** (menyebut alat
  yang tidak ada di katalog, harga karangan, stok karangan).
- Dengan pemisahan ini, **dosen dapat menguji algoritma Anda**, karena langkah
  2–4 deterministik dan bisa ditelusuri. Ini justru nilai plus: AI dipakai
  tepat sasaran, bukan asal tempel.
- Jika Gemini gagal: langkah 1 diganti parsing form biasa → sistem tetap jalan.

**Kontrak output Gemini #1 (strict JSON):**
```json
{
  "participants": 4,
  "duration_days": 2,
  "destination_text": "Gunung Prau, Dieng",
  "elevation_class": "medium",
  "season": "dry",
  "trip_type": "camping",
  "difficulty": "beginner",
  "budget_total": 500000,
  "special_needs": ["cuaca dingin", "tidak punya alat masak"],
  "confidence": 0.82
}
```
Validasi server: `participants` 1–20, `duration_days` 1–30, enum dicek ketat,
`budget_total` numerik ≥ 0. Jika gagal validasi → fallback form manual.

### 6.3 AI #2 — Equipment Condition Inspection (Gemini Vision)

**Peran:** membaca foto alat dan menghasilkan **indikasi** kondisi, bukan vonis.

**Kontrak output (strict JSON):**
```json
{
  "overall_condition": "minor_damage",
  "condition_score": 72,
  "confidence": 0.64,
  "findings": [
    {"area":"flysheet","issue":"robekan kecil ~3cm","severity":"minor","confidence":0.71},
    {"area":"zipper","issue":"tidak terlihat jelas","severity":"unknown","confidence":0.30}
  ],
  "areas_need_manual_check": ["frame/patok", "jahitan lantai"],
  "cleanliness": "dirty_normal",
  "image_quality": "acceptable",
  "notes": "Foto kurang terang pada bagian sudut kanan."
}
```

**Pengaman yang saya rancang (ini yang dinilai dosen sebagai kematangan):**
- `image_quality: poor` → hasil otomatis ditandai **tidak dapat dipakai**, minta foto ulang.
- `confidence < 0.6` → wajib **dua manusia** (provider + admin) menyetujui.
- AI **tidak pernah** menerima informasi harga/deposit di prompt → tidak bisa
  menyarankan nominal denda. Denda dihitung tabel tarif oleh sistem, disetujui admin.
- Setiap pemanggilan disimpan: prompt hash, model, versi prompt, latency, biaya
  token, raw response → **dapat diaudit & direproduksi** (penting untuk laporan).

### 6.4 Alternatif / tambahan AI yang saya sarankan dipertimbangkan

| Kandidat | Nilai bisnis | Rekomendasi |
|---|---|---|
| **AI #3: Auto-fill katalog** — provider foto alat, Gemini isi draft nama/kategori/spesifikasi/berat | Mengurangi friksi onboarding provider (masalah nyata marketplace: katalog kosong) | **Disarankan** sebagai SHOULD HAVE. Murah, efek "wow" tinggi, tetap butuh konfirmasi provider |
| **AI #4: Review summarizer & sentiment** | Meringkas 50 review jadi 3 poin | NICE TO HAVE |
| **AI #5: Dispute assistant** — meringkas kronologi sengketa untuk admin | Membantu admin, tidak memutuskan | NICE TO HAVE |
| AI chatbot umum | Tidak terhubung proses bisnis | **Tidak disarankan** — persis yang Anda ingin hindari |
| AI penentu harga dinamis | Berisiko & sulit dipertanggungjawabkan pada skala data mahasiswa | **Tidak disarankan** |

**Kesimpulan:** MUST = AI #1 + AI #2. SHOULD = AI #3. Sisanya cadangan.
