# Bagian 3: BUSINESS FLOW & USE CASE

---

## 1. STATE MACHINE TRANSAKSI (fondasi seluruh flow)

Sebelum menggambar alur, tetapkan dulu **status transaksi**. Semua alur hanyalah
perpindahan antar status ini. Dengan state machine, tidak ada status ambigu dan
Anda mudah menjawab pertanyaan penguji "kalau customer tidak datang bagaimana?".

```mermaid
stateDiagram-v2
    [*] --> DRAFT
    DRAFT --> PENDING_CONFIRMATION : customer submit booking
    PENDING_CONFIRMATION --> REJECTED : provider tolak
    PENDING_CONFIRMATION --> EXPIRED : provider diam > 12 jam (job)
    PENDING_CONFIRMATION --> AWAITING_PAYMENT : provider konfirmasi
    AWAITING_PAYMENT --> CANCELLED : customer batal / tidak bayar 24 jam (job)
    AWAITING_PAYMENT --> PAID : bukti bayar diverifikasi
    PAID --> PICKED_UP : serah terima + snapshot PRE_RENTAL
    PAID --> NO_SHOW : lewat tanggal mulai, tidak diambil (job)
    PICKED_UP --> RETURNED : alat dikembalikan + snapshot POST_RENTAL
    PICKED_UP --> OVERDUE : lewat tanggal selesai (job)
    OVERDUE --> RETURNED : dikembalikan terlambat (+denda keterlambatan)
    RETURNED --> INSPECTION : AI inspection + review manusia
    INSPECTION --> COMPLETED : tidak ada kerusakan / denda disepakati
    INSPECTION --> DISPUTED : selisih AI-manusia / customer membantah
    DISPUTED --> COMPLETED : admin memutuskan
    COMPLETED --> [*]
    REJECTED --> [*]
    CANCELLED --> [*]
    EXPIRED --> [*]
    NO_SHOW --> [*]
```

**Aturan transisi (tegakkan di kode, bukan hanya di dokumen):**
- Transisi hanya boleh lewat satu kelas `RentalStateMachine::transition($t, $to, $actor)`.
- Setiap transisi dicatat di tabel `transaction_status_logs` (siapa, kapan, dari→ke, catatan).
- Status yang mengunci stok (menyumbang okupansi di ALG-2):
  `PENDING_CONFIRMATION, AWAITING_PAYMENT, PAID, PICKED_UP, OVERDUE, RETURNED, INSPECTION`.
  Status yang **melepas** stok: `REJECTED, EXPIRED, CANCELLED, NO_SHOW, COMPLETED, DISPUTED(selesai)`.

> Catatan: `PENDING_CONFIRMATION` **ikut mengunci stok** (soft-hold). Tanpa ini,
> 10 orang bisa membooking 1 tenda dan 9 kecewa. Karena itu harus ada job
> `EXPIRED` agar stok tidak tersandera selamanya.

---

## 2. FLOW CUSTOMER

```mermaid
flowchart TD
    A[Register] --> B[Verifikasi email]
    B --> C[Login]
    C --> D{Cara mencari?}
    D -->|Tahu alatnya| E[Katalog + filter]
    D -->|Tidak tahu| F[Form kebutuhan perjalanan]
    F --> G[AI Need Parser - Gemini]
    G -->|gagal| G2[Fallback form manual]
    G --> H[Requirement Engine]
    G2 --> H
    H --> I[Hard Filter + Scoring - ALG-1]
    I --> J[Bundle Builder]
    J --> K[Halaman rekomendasi + penjelasan skor]
    E --> L[Detail alat + kalender ketersediaan]
    K --> L
    L --> M[Pilih tanggal + qty]
    M --> N[Cek availability - ALG-2]
    N -->|tidak tersedia| M
    N -->|tersedia| O[Keranjang, dipecah per provider]
    O --> P[Buat booking - transaksi + lock]
    P --> Q[PENDING_CONFIRMATION]
    Q --> R{Provider konfirmasi?}
    R -->|tolak/timeout| S[REJECTED / EXPIRED]
    R -->|ya| T[AWAITING_PAYMENT]
    T --> U[Upload bukti bayar - sewa + deposit]
    U --> V[PAID]
    V --> W[Ambil alat + cek snapshot PRE_RENTAL bersama provider]
    W --> X[PICKED_UP]
    X --> Y[Kembalikan alat]
    Y --> Z[Snapshot POST_RENTAL - foto]
    Z --> AA[AI Inspection - Gemini Vision]
    AA --> AB[Delta Engine - ALG-3]
    AB --> AC{Ada kerusakan?}
    AC -->|tidak| AD[COMPLETED, deposit kembali penuh]
    AC -->|ya| AE[Usulan denda oleh provider]
    AE --> AF[Validasi ADMIN - final]
    AF --> AD
    AF -->|customer membantah| AG[DISPUTED]
    AG --> AF
    AD --> AH[Beri review & rating]
```

**Detail penting yang sering dilupakan:**
- Customer **wajib melihat dan menyetujui snapshot PRE_RENTAL** saat pengambilan
  (tombol "Saya setuju kondisi alat sesuai foto"). Tanpa persetujuan ini,
  provider tidak bisa mengklaim kerusakan. Ini fitur kecil tapi menyelesaikan
  masalah bisnis terbesar — tekankan di presentasi.
- Keranjang lintas provider **dipecah menjadi beberapa transaksi** (satu per
  provider), karena konfirmasi, pembayaran, dan pengambilan terpisah.
- Denda keterlambatan: `denda = hari_terlambat × tarif_harian × 1,5` (deterministik).

---

## 3. FLOW PROVIDER

```mermaid
flowchart TD
    A[Register akun] --> B[Ajukan jadi provider]
    B --> C[Upload KTP + foto lokasi + data toko]
    C --> D[Status: PENDING_VERIFICATION]
    D --> E{Admin verifikasi}
    E -->|tolak| F[REJECTED + alasan, boleh ajukan ulang]
    E -->|setuju| G[VERIFIED - alat bisa tampil di katalog]
    G --> H[Tambah alat]
    H --> H1[Opsional: AI auto-fill dari foto]
    H1 --> I[Isi kategori, spesifikasi, kapasitas]
    I --> J[Set harga/hari, deposit, replacement_cost per komponen]
    J --> K[Tambah unit fisik + kode unit]
    K --> L[Snapshot kondisi awal tiap unit]
    L --> M[Alat AKTIF di katalog]
    M --> N[Terima notifikasi booking]
    N --> O{Konfirmasi dalam 12 jam?}
    O -->|tidak| P[EXPIRED otomatis - reputasi turun]
    O -->|ya| Q[Konfirmasi - alat dikunci]
    Q --> R[Verifikasi bukti bayar]
    R --> S[Serah terima: foto PRE_RENTAL + checklist + tanda tangan digital]
    S --> T[PICKED_UP]
    T --> U[Terima pengembalian]
    U --> V[Upload foto POST_RENTAL + isi checklist]
    V --> W[Jalankan AI Inspection - berkuota]
    W --> X[Lihat hasil AI: skor, temuan, area perlu dicek]
    X --> Y{Delta menunjukkan kerusakan?}
    Y -->|tidak| Z[Tandai selesai - deposit dikembalikan]
    Y -->|ya| AA[AJUKAN usulan denda + bukti]
    AA --> AB[MENUNGGU KEPUTUSAN ADMIN]
    AB --> Z
```

> **Provider tidak pernah bisa memotong deposit sendiri.** Provider mengajukan,
> admin memutuskan, sistem mengeksekusi. Ini pembatas kekuasaan yang membuat
> marketplace layak dipercaya.

---

## 4. FLOW ADMIN

```mermaid
flowchart TD
    A[Login admin] --> B[Dashboard: transaksi, GMV, antrean kerja]
    B --> C[Antrean verifikasi provider]
    C --> C1[Periksa KTP vs NIK akun, foto lokasi]
    C1 --> C2[Approve / Reject + alasan]
    B --> D[Antrean validasi AI Inspection]
    D --> D1[Bandingkan foto PRE vs POST berdampingan]
    D1 --> D2[Lihat skor manusia vs skor AI + confidence]
    D2 --> D3{Setuju?}
    D3 -->|ya| D4[ACCEPTED - denda sesuai usulan]
    D3 -->|ubah| D5[ADJUSTED - admin menetapkan nilai + alasan]
    D3 -->|tidak| D6[REJECTED - tidak ada denda]
    D4 --> D7[Sistem eksekusi potong deposit + notifikasi]
    D5 --> D7
    D6 --> D7
    B --> E[Monitoring transaksi: OVERDUE, DISPUTED, NO_SHOW]
    B --> F[Penanganan dispute: baca kronologi, putuskan]
    B --> G[Moderasi katalog: alat mencurigakan / foto tidak pantas]
    B --> H[Manajemen user: suspend, reset, lihat audit log]
    B --> I[Konfigurasi: bobot scoring, aturan requirement, tarif denda]
```

**Prioritas antrean admin** (agar dashboard berguna, bukan sekadar cantik):
1. `DISPUTED` (ada uang tertahan)
2. AI inspection `DISCREPANCY` atau `LOW_CONFIDENCE`
3. AI inspection `CONSISTENT` (bisa disetujui massal — *fast track*)
4. Verifikasi provider baru
5. Laporan pengguna

Fast-track inilah nilai ekonomis AI: admin tidak perlu memeriksa satu per satu
kasus yang jelas normal, cukup fokus pada kasus yang ditandai AI sebagai ragu.

---

## 5. USE CASE DIAGRAM

```mermaid
flowchart LR
    C((Customer))
    P((Provider))
    A((Admin))
    S((System Job))
    G[[Gemini API]]

    subgraph UC["Sistem Marketplace Penyewaan Alat Hiking"]
        U1[UC-01 Registrasi & Login]
        U2[UC-02 Cari & Filter Alat]
        U3[UC-03 Smart Rental Matching]
        U4[UC-04 Cek Ketersediaan Tanggal]
        U5[UC-05 Membuat Booking]
        U6[UC-06 Membayar & Unggah Bukti]
        U7[UC-07 Melihat Status Penyewaan]
        U8[UC-08 Memberi Review]
        U9[UC-09 Mengajukan Dispute]
        U10[UC-10 Pengajuan & Verifikasi Provider]
        U11[UC-11 Kelola Alat & Unit]
        U12[UC-12 Kelola Stok & Harga]
        U13[UC-13 Konfirmasi Booking]
        U14[UC-14 Serah Terima - Snapshot PRE]
        U15[UC-15 Terima Pengembalian - Snapshot POST]
        U16[UC-16 Jalankan AI Inspection]
        U17[UC-17 Ajukan Usulan Denda]
        U18[UC-18 Validasi Hasil AI - FINAL]
        U19[UC-19 Monitoring Transaksi]
        U20[UC-20 Kelola Pengguna & Moderasi]
        U21[UC-21 Konfigurasi Bobot & Aturan]
        U22[UC-22 Auto-expire & Reminder]
        U23[UC-23 Hitung Denda Keterlambatan]
    end

    C --- U1
    C --- U2
    C --- U3
    C --- U4
    C --- U5
    C --- U6
    C --- U7
    C --- U8
    C --- U9
    P --- U10
    P --- U11
    P --- U12
    P --- U13
    P --- U14
    P --- U15
    P --- U16
    P --- U17
    A --- U10
    A --- U18
    A --- U19
    A --- U20
    A --- U21
    A --- U9
    S --- U22
    S --- U23
    U3 -.->|include| U4
    U3 -.->|uses| G
    U16 -.->|uses| G
    U5 -.->|include| U4
    U17 -.->|precedes| U18
```

### 5.1 Spesifikasi use case naratif (dua yang paling kritis)

**UC-05 — Membuat Booking**
| Bagian | Isi |
|---|---|
| Aktor utama | Customer |
| Prakondisi | Login; alat status aktif; provider terverifikasi |
| Pemicu | Customer menekan "Sewa Sekarang" |
| Alur utama | 1) Pilih tanggal mulai & selesai, qty. 2) Sistem menjalankan ALG-2. 3) Sistem menghitung biaya (sewa × hari × qty + deposit − diskon durasi). 4) Customer meninjau & menyetujui syarat. 5) Sistem **membuka transaksi DB + lock baris**, mengecek ulang ketersediaan, menyimpan transaksi status `PENDING_CONFIRMATION`. 6) Notifikasi ke provider. |
| Alur alternatif | 2a) Tidak tersedia → tampilkan tanggal terdekat yang tersedia + alat alternatif berperingkat tinggi. |
| Alur eksepsi | 5a) Pengecekan ulang gagal (ada yang mendahului) → rollback, HTTP 409, minta pilih ulang. 5b) Idempotency key sudah ada → kembalikan transaksi yang sama, jangan buat baru. |
| Pascakondisi | Transaksi tersimpan, stok ter-hold, log status tercatat |

**UC-18 — Validasi Hasil AI (FINAL)**
| Bagian | Isi |
|---|---|
| Aktor utama | Admin |
| Prakondisi | Terdapat `ai_inspections.status = pending_review` |
| Alur utama | 1) Admin membuka antrean terurut prioritas. 2) Sistem menampilkan foto PRE & POST berdampingan, checklist manusia, skor AI, confidence, temuan, area perlu dicek, dan Δ. 3) Admin memilih ACCEPTED / ADJUSTED / REJECTED dan menulis alasan. 4) Sistem menyimpan keputusan + identitas admin + timestamp (**append-only, tidak bisa diedit**). 5) Sistem menghitung denda dari tabel tarif, dibatasi maksimum nilai deposit. 6) Sistem mengeksekusi pengembalian deposit dan mengirim notifikasi ke kedua pihak. |
| Aturan bisnis | AI **tidak pernah** mengubah status ini secara otomatis. Tanpa keputusan admin, transaksi tidak dapat mencapai `COMPLETED` bila Δ > 3. |
| Pascakondisi | Transaksi `COMPLETED` atau `DISPUTED`; `condition_score` unit diperbarui |
