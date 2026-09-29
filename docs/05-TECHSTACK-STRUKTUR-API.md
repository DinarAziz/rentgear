# Bagian 5: TECH STACK, STRUKTUR FOLDER, DAN ARSITEKTUR API

---

## 1. REKOMENDASI TECH STACK

### 1.1 Pertimbangan pemilihan

Kriteria yang saya pakai, berurutan: **(1) dapat diselesaikan satu orang dalam
satu semester**, (2) materi belajar berbahasa Indonesia melimpah, (3) mudah
dideploy & dipresentasikan, (4) tidak menyembunyikan algoritma Anda di balik
kerumitan framework.

### 1.2 Perbandingan opsi realistis

| Opsi | Stack | Kecepatan pengerjaan | Kurva belajar | Kualitas UI | Risiko |
|---|---|---|---|---|---|
| **A** | Laravel + **Blade** + Alpine.js + Tailwind | ⭐⭐⭐⭐⭐ | Rendah | Cukup | Interaksi kompleks (kalender, keranjang) agak kaku |
| **B (REKOMENDASI)** | Laravel + **Inertia.js + React** + Tailwind | ⭐⭐⭐⭐ | Sedang | Bagus | Perlu paham React dasar |
| **C** | Laravel API + React SPA terpisah (Sanctum token) | ⭐⭐ | Tinggi | Bagus | **2 proyek, 2 deploy, CORS, auth token** — sering bikin mahasiswa tidak selesai |
| **D** | Next.js + Prisma + PostgreSQL | ⭐⭐⭐ | Sedang-Tinggi | Bagus | Kurang cocok bila Anda belum kuat TypeScript |

### 1.3 Keputusan: **Opsi B — Laravel + Inertia.js + React**

**Alasan memilih Laravel:**
- Ekosistem lengkap tanpa tambahan: migration, Eloquent ORM, validasi, queue,
  scheduler (untuk job auto-expire), policy (RBAC), storage, mail — semua bawaan.
  Anda tidak menghabiskan waktu merakit infrastruktur.
- **Transaksi DB + `lockForUpdate()`** tersedia langsung — inti dari ALG-2.
- Dokumentasi & tutorial Indonesia sangat banyak → risiko tersendat rendah.

**Alasan memilih Inertia, bukan API+SPA terpisah:**
- Inertia memberi Anda **UI React modern** dengan **satu proyek, satu deploy,
  satu sistem autentikasi (session-based)**.
- Tidak perlu menulis controller API untuk setiap halaman, tidak perlu
  mengurus CORS, refresh token, atau state management global.
- **Ini penghematan waktu terbesar dalam rancangan ini.** Waktu yang dihemat
  dialihkan ke algoritma — yang justru dinilai dosen.
- Anda **tetap** menyediakan `/api/v1/` REST terpisah untuk integrasi dengan
  proyek mahasiswa lain (lihat bagian 3).

> Jika Anda belum pernah menyentuh React sama sekali dan waktunya mepet,
> **turun ke Opsi A (Blade + Alpine)**. Struktur folder, database, API, dan
> seluruh algoritma dalam dokumen ini **tidak berubah** — hanya lapisan
> presentasi yang berbeda. Rancangan ini sengaja dibuat agar keputusan itu
> bisa diambil belakangan.

### 1.4 Stack lengkap

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Bahasa/Framework | **PHP 8.3 + Laravel 11/12** | Ekosistem lengkap, familiar, hosting murah |
| Frontend | **React 18 + Inertia.js + Vite** | Satu proyek, UI modern |
| Styling | **Tailwind CSS** + shadcn/ui (opsional) | Cepat, konsisten, tidak perlu desainer |
| Database | **MySQL 8** (atau PostgreSQL 16) | Familiar; PostgreSQL bila ingin exclusion constraint & PostGIS |
| Auth | **Laravel Breeze (session + cookie)** | Bawaan, aman, cepat. Sanctum token khusus `/api/v1` |
| Otorisasi | **Laravel Policy + Gate + middleware role** | RBAC sederhana, teruji |
| Penyimpanan gambar | **Laravel Storage** — lokal saat dev, **Cloudinary / S3-compatible (Cloudflare R2)** saat produksi | Gratis di tier awal, CDN, resize otomatis |
| AI | **Gemini API** (`gemini-2.x-flash` untuk teks, model vision untuk foto) via `Http::` client + **Queue job** | Flash cukup, murah, cepat. Queue agar request web tidak menunggu |
| Antrean & jadwal | **Laravel Queue (database driver)** + **Scheduler** | Tanpa Redis, cukup untuk skala skripsi |
| Peta/geocoding | Input lat-lng manual + **Leaflet + OpenStreetMap** | Gratis, tanpa kartu kredit (Google Maps butuh billing) |
| Testing | **Pest / PHPUnit** — fokus pada unit test 3 algoritma | Bukti kebenaran untuk laporan |
| Deployment | **Railway / Render / VPS Rp50rb-an (Contabo, Biznet)** + GitHub | Mudah, bisa diakses kelompok lain |
| Dokumentasi API | **Scribe** (auto-generate dari anotasi) | Tanpa menulis manual |
| Versioning | Git + GitHub, branch `main` / `dev` | Wajib untuk bukti proses |

**Estimasi biaya bulanan:** Rp 0 – Rp 75.000 (Gemini free tier + hosting murah).

---

## 2. STRUKTUR FOLDER

Prinsip: **framework standard di luar, domain logic terisolasi di dalam.**
Saya *tidak* menyarankan arsitektur hexagonal/DDD penuh — terlalu berat.
Yang saya pakai: **Laravel standar + satu folder `Domain/`** yang berisi
seluruh algoritma, terpisah total dari HTTP dan UI.

Keuntungan konkret: algoritma Anda dapat di-unit-test **tanpa database dan
tanpa browser**, dan saat presentasi Anda bisa menunjuk satu folder dan
berkata "inilah kontribusi algoritmik saya".

```
rentgear/
│
├── app/
│   ├── Domain/                      ← ★ INTI: business logic murni, bebas framework
│   │   ├── Matching/
│   │   │   ├── SmartMatchService.php          # orkestrator ALG-1
│   │   │   ├── RequirementEngine.php          # kebutuhan → daftar kategori
│   │   │   ├── ScoringEngine.php              # rumus skor & bobot
│   │   │   ├── BundleBuilder.php              # knapsack 0/1
│   │   │   ├── Scorers/                       # satu file per sub-skor (mudah diuji)
│   │   │   │   ├── BudgetScorer.php
│   │   │   │   ├── SpecFitScorer.php
│   │   │   │   ├── DistanceScorer.php
│   │   │   │   ├── RatingScorer.php           # Bayesian average
│   │   │   │   ├── ConditionScorer.php
│   │   │   │   └── DurationScorer.php
│   │   │   └── DTO/ (TripProfile, Requirement, ScoredCandidate, Bundle)
│   │   │
│   │   ├── Availability/
│   │   │   ├── AvailabilityService.php        # ALG-2 sweep-line
│   │   │   ├── BookingLockService.php         # transaksi + lockForUpdate
│   │   │   ├── CalendarBuilder.php            # kalender 90 hari
│   │   │   └── DTO/ (DateRange, OccupancyEvent)
│   │   │
│   │   ├── Condition/
│   │   │   ├── ChecklistScorer.php            # skor berbobot komponen
│   │   │   ├── ConditionDeltaService.php      # ALG-3 delta PRE vs POST
│   │   │   ├── DamageFeeCalculator.php        # tabel tarif deterministik
│   │   │   └── AiHumanFusionResolver.php      # aturan penggabungan AI ↔ manusia
│   │   │
│   │   ├── Rental/
│   │   │   ├── RentalStateMachine.php         # SATU-SATUNYA pintu ubah status
│   │   │   ├── PriceCalculator.php            # harga dihitung di server, selalu
│   │   │   └── LateFeeCalculator.php
│   │   │
│   │   └── Shared/
│   │       ├── Geo/HaversineCalculator.php
│   │       └── Money.php
│   │
│   ├── Services/
│   │   └── Ai/                      ← ★ Seluruh sentuhan ke Gemini terisolasi di sini
│   │       ├── GeminiClient.php               # HTTP, retry, timeout, logging
│   │       ├── Contracts/AiProvider.php       # interface → mudah diganti/di-mock
│   │       ├── NeedParserService.php          # AI #1
│   │       ├── ConditionInspectionService.php # AI #2
│   │       ├── CatalogAutofillService.php     # AI #3 (should-have)
│   │       ├── Prompts/                       # prompt ber-VERSI, bukan hardcode
│   │       │   ├── need_parser.v1.txt
│   │       │   └── condition_inspect.v1.txt
│   │       ├── Schemas/                       # JSON schema validasi output
│   │       └── Fallback/                      # jalur deterministik saat AI gagal
│   │
│   ├── Models/                      # Eloquent: User, Provider, Equipment, ...
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Web/                 # controller untuk halaman Inertia
│   │   │   │   ├── Customer/
│   │   │   │   ├── Provider/
│   │   │   │   └── Admin/
│   │   │   └── Api/V1/              # REST untuk integrasi luar
│   │   ├── Requests/                # validasi input (Form Request)
│   │   ├── Resources/               # transformasi JSON (sembunyikan field sensitif)
│   │   └── Middleware/ (EnsureRole, EnsureProviderVerified, AiRateLimit)
│   ├── Policies/                    # EquipmentPolicy, TransactionPolicy, ...
│   ├── Jobs/                        # RunAiInspection, ExpireBookings, SendReminder
│   ├── Console/Commands/            # rental:expire, rental:overdue
│   ├── Events/ & Listeners/         # BookingConfirmed → kirim notifikasi
│   └── Exceptions/                  # DoubleBookingException, AiUnavailableException
│
├── resources/
│   ├── js/
│   │   ├── Pages/                   # halaman Inertia (1 file = 1 halaman)
│   │   │   ├── Public/ (Home, Catalog, EquipmentDetail, ProviderProfile)
│   │   │   ├── SmartMatch/ (TripForm, Result)
│   │   │   ├── Customer/ (Checkout, MyRentals, RentalDetail, ReturnUpload, Review)
│   │   │   ├── Provider/ (Dashboard, Equipment*, Orders, Handover, ReturnInspect)
│   │   │   └── Admin/ (Dashboard, ProviderVerify, AiReviewQueue, Disputes, Settings)
│   │   ├── Components/              # UI reusable
│   │   │   ├── ui/                  # Button, Card, Modal, Badge
│   │   │   ├── AvailabilityCalendar.jsx
│   │   │   ├── ScoreBreakdownCard.jsx   # menampilkan "kenapa direkomendasikan"
│   │   │   ├── PhotoCompareSlider.jsx   # PRE vs POST bersebelahan
│   │   │   └── ConditionChecklist.jsx
│   │   ├── Layouts/ (Guest, Customer, Provider, Admin)
│   │   ├── hooks/ & lib/
│   │   └── app.jsx
│   ├── css/app.css
│   └── views/app.blade.php          # satu-satunya blade (root Inertia)
│
├── routes/
│   ├── web.php          # halaman Inertia
│   ├── api.php          # /api/v1 untuk integrasi
│   ├── auth.php
│   └── console.php      # jadwal scheduler
│
├── database/
│   ├── migrations/      # urut & atomik, satu perubahan satu file
│   ├── seeders/         # RoleSeeder, CategorySeeder, RequirementRuleSeeder,
│   │                    # ScoringWeightSeeder, DemoDataSeeder (WAJIB untuk demo)
│   └── factories/
│
├── tests/
│   ├── Unit/Domain/     # ★ paling penting: uji 3 algoritma tanpa DB
│   │   ├── ScoringEngineTest.php            # verifikasi contoh perhitungan manual
│   │   ├── AvailabilitySweepLineTest.php    # kasus tepi interval
│   │   └── ConditionDeltaTest.php
│   ├── Feature/         # alur end-to-end: booking, konfirmasi, inspeksi
│   └── Concurrency/DoubleBookingTest.php    # ★ bukti anti double-booking
│
├── docs/                ← dokumentasi untuk laporan & dosen
│   ├── 01-konsep.md  02-algoritma.md  03-flow.md  04-database.md
│   ├── erd.mmd  state-machine.mmd
│   ├── api.md (hasil Scribe)
│   └── perhitungan-manual.xlsx     # validasi rumus skor
│
├── storage/app/public/  # equipment/, conditions/, ktp/ (KTP: disk PRIVAT!)
├── public/
├── .env.example
├── README.md
└── composer.json / package.json
```

### 2.1 Penjelasan folder kunci

| Folder | Fungsi | Kenapa penting untuk nilai Anda |
|---|---|---|
| **`app/Domain/`** | Seluruh algoritma, tanpa ketergantungan Laravel/HTTP | Ini yang dinilai dosen. Bisa diuji, bisa ditunjuk, bisa dijelaskan |
| **`app/Services/Ai/`** | Satu-satunya tempat kode menyentuh Gemini | Ganti provider AI = ubah 1 file. Mudah di-mock saat testing |
| **`Prompts/*.v1.txt`** | Prompt disimpan sebagai file berversi | Anda bisa menunjukkan evolusi prompt di laporan; reproducible |
| **`Http/Controllers/`** | **Tipis** — hanya validasi, panggil Domain, kembalikan response | Aturan: controller maksimal ~30 baris. Logika di controller = kesalahan arsitektur |
| **`Policies/`** | Otorisasi terpusat | Mencegah bug "provider A mengedit alat provider B" |
| **`tests/Unit/Domain/`** | Bukti algoritma benar | Screenshot hasil test di laporan jauh lebih meyakinkan daripada klaim |
| **`database/seeders/`** | Data demo realistis | Demo dengan 3 data terlihat lemah; siapkan 10 provider, 60 alat, 40 transaksi |

**Aturan arus ketergantungan (satu arah, jangan dilanggar):**
```
UI (React) → Controller → Domain Service → Model/Repository → Database
                              ↑
                    Services/Ai (dipanggil, tidak memanggil balik)
```
`Domain/` **tidak boleh** meng-import Controller, Request, atau apa pun dari
`Http/`. Jika terjadi, berarti ada logika yang salah tempat.

---

## 3. ARSITEKTUR API

### 3.1 Dua permukaan (surface) yang berbeda

| Permukaan | Untuk | Auth | Format |
|---|---|---|---|
| **Inertia (routes/web.php)** | UI aplikasi sendiri | Session + CSRF | Props Inertia |
| **REST (routes/api.php, `/api/v1`)** | Integrasi proyek lain, mobile di masa depan | Sanctum token + rate limit | JSON |

Keduanya **memanggil `Domain/` yang sama**. Tidak ada duplikasi logika.
Inilah manfaat memisahkan Domain sejak awal.

### 3.2 Konvensi

- Versi di URL: `/api/v1/...` (bukan di header — lebih mudah dijelaskan & diuji).
- Identifier publik: **ULID `public_id`**, bukan auto-increment id, bukan NIK.
- Bentuk respons konsisten:
```json
{ "success": true, "data": {...}, "meta": {"page":1,"total":120} }
{ "success": false, "error": {"code":"SLOT_UNAVAILABLE","message":"...","details":{}} }
```
- Kode status: 200/201, 400 validasi, 401 belum login, 403 role salah,
  **409 Conflict** (double booking — pakai ini, jangan 400), 422 validasi Laravel,
  429 rate limit, 503 AI tidak tersedia.
- Pagination: `?page=&per_page=` (maks 100).
- **Idempotency:** endpoint `POST /bookings` menerima header `Idempotency-Key`.

### 3.3 Daftar endpoint utama

**Publik**
```
GET    /api/v1/categories
GET    /api/v1/equipment?category=&city=&min_price=&max_price=&start=&end=&sort=
GET    /api/v1/equipment/{public_id}
GET    /api/v1/equipment/{public_id}/availability?start=&end=     → kalender harian
GET    /api/v1/providers/{slug}
GET    /api/v1/equipment/{public_id}/reviews
```

**Smart Matching** *(rate-limited — ada biaya AI)*
```
POST   /api/v1/match/parse        { raw_text | form fields }        → TripProfile
POST   /api/v1/match/recommend    { trip_profile, start, end, lat, lng }
       → { bundle, alternatives[], unfulfilled[], score_breakdown[], explanation }
GET    /api/v1/match/requests/{id}
```

**Customer** *(auth: customer)*
```
POST   /api/v1/bookings                 (Idempotency-Key)  → 201 | 409
GET    /api/v1/bookings?status=
GET    /api/v1/bookings/{code}
POST   /api/v1/bookings/{code}/cancel
POST   /api/v1/bookings/{code}/payments          (upload bukti)
POST   /api/v1/bookings/{code}/agree-pre-condition
POST   /api/v1/bookings/{code}/return-photos
POST   /api/v1/bookings/{code}/review
POST   /api/v1/bookings/{code}/dispute
```

**Provider** *(auth: provider + verified)*
```
POST   /api/v1/provider/apply
GET    /api/v1/provider/equipment
POST   /api/v1/provider/equipment
PATCH  /api/v1/provider/equipment/{id}
POST   /api/v1/provider/equipment/{id}/units
POST   /api/v1/provider/equipment/{id}/images
POST   /api/v1/provider/equipment/autofill          (AI #3, berkuota)
GET    /api/v1/provider/orders?status=
POST   /api/v1/provider/orders/{code}/confirm | /reject
POST   /api/v1/provider/orders/{code}/handover      (snapshot PRE + foto)
POST   /api/v1/provider/orders/{code}/receive-return(snapshot POST + foto)
POST   /api/v1/provider/orders/{code}/ai-inspect    (berkuota, async → job)
POST   /api/v1/provider/orders/{code}/damage-claim  (MENGUSULKAN saja)
```

**Admin** *(auth: admin)*
```
GET    /api/v1/admin/stats
GET    /api/v1/admin/providers?status=pending
POST   /api/v1/admin/providers/{id}/verify | /reject
GET    /api/v1/admin/ai-inspections?status=pending_review&sort=priority
POST   /api/v1/admin/ai-inspections/{id}/decide   { decision, final_score, reason }
GET    /api/v1/admin/disputes
POST   /api/v1/admin/disputes/{id}/resolve
GET    /api/v1/admin/audit-logs
PATCH  /api/v1/admin/settings/scoring-weights
```

### 3.4 Pola asinkron untuk AI (penting)

Panggilan Gemini Vision bisa memakan 3–15 detik. **Jangan** menahan HTTP request.

```
POST /ai-inspect  →  202 Accepted { job_id, status: "queued" }
                     └→ Queue job memanggil Gemini, menyimpan ai_inspections
GET  /ai-inspect/{job_id}  →  { status: "queued|processing|done|failed", result }
```
Frontend melakukan polling tiap 2 detik (cukup; tidak perlu WebSocket).
Jika gagal 3× → status `failed`, provider tetap bisa melanjutkan secara manual.
**Kegagalan AI tidak boleh memblokir proses bisnis.**
