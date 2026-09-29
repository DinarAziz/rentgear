# Bagian 4: DATABASE DESIGN

---

## 1. ANALISIS KRITIS: NIK SEBAGAI PRIMARY KEY

Anda meminta NIK sebagai primary key / identitas utama user, dan meminta saya
menganalisis konsekuensinya sebelum mengubah keputusan. **Saya tidak mengubah
keputusan Anda secara sepihak** — berikut analisisnya, lalu rekomendasi, dan
keputusan akhir tetap di tangan Anda.

### 1.1 Apa itu NIK secara teknis
NIK = 16 digit numerik, terstruktur (kode provinsi/kab/kec + tanggal lahir +
nomor urut). Sifatnya: unik nasional, tidak berubah seumur hidup, dan
**merupakan data pribadi yang dilindungi UU No. 27/2022 (PDP)** sebagai data
pribadi spesifik/identitas tunggal.

### 1.2 Konsekuensi teknis bila NIK dijadikan PRIMARY KEY

| # | Konsekuensi | Dampak | Tingkat |
|---|---|---|---|
| K1 | **NIK menyebar ke seluruh database** sebagai foreign key: di `rental_transactions`, `reviews`, `notifications`, `audit_logs`, dst. | Data pribadi terduplikasi di 10+ tabel. Kebocoran satu tabel = kebocoran identitas. Penghapusan data (hak "dilupakan" PDP) jadi sangat sulit. | 🔴 Tinggi |
| K2 | **NIK bocor lewat URL dan API**: `/api/users/3201234567890001`, `/transactions?user=...` | Terekam di log server, riwayat browser, analytics, Referer header. Bisa dienumerasi. | 🔴 Tinggi |
| K3 | **Ukuran index membengkak.** PK CHAR(16) = 16 byte vs BIGINT = 8 byte. Pada InnoDB, **PK disalin ke setiap secondary index**. | Dengan ~10 tabel anak dan beberapa index per tabel, index membesar ±2×. Performa join & cache buffer pool menurun. | 🟡 Sedang |
| K4 | **Tidak bisa registrasi tanpa NIK.** Padahal browsing/wishlist tidak butuh NIK. | Friksi pendaftaran tinggi → konversi turun. Anda juga tidak bisa membuat akun demo untuk pengujian/presentasi. | 🟡 Sedang |
| K5 | **NIK tidak dapat diverifikasi** tanpa akses Dukcapil. | Data NIK di sistem Anda adalah **klaim**, bukan fakta. Menjadikan klaim tak terverifikasi sebagai PK itu rapuh. | 🔴 Tinggi |
| K6 | **Salah input = malapetaka.** Mengubah PK berarti cascade update ke seluruh tabel anak. | Satu typo saat registrasi butuh migrasi data. | 🔴 Tinggi |
| K7 | **NIK tidak selalu benar-benar unik di lapangan** (kasus NIK ganda/kembar tercatat nyata di Indonesia). | Constraint UNIQUE bisa memblokir pengguna sah. | 🟡 Sedang |
| K8 | **Menghalangi integrasi** dengan proyek mahasiswa lain — yang Anda sebut sebagai kebutuhan eksplisit. Sistem lain mungkin tidak punya NIK, atau tidak boleh menerimanya. | Sharing data jadi berisiko hukum & teknis. | 🔴 Tinggi |
| K9 | **Enkripsi jadi sulit.** Praktik baik PDP: data pribadi dienkripsi at-rest. Kolom terenkripsi **tidak bisa** dijadikan PK/index yang efisien. | Anda terpaksa memilih: patuh PDP **atau** NIK sebagai PK. Tidak bisa dua-duanya. | 🔴 Tinggi |

### 1.3 Rekomendasi saya

> **Pertahankan NIK sebagai identitas utama bisnis, tetapi JANGAN jadikan
> primary key teknis.** Gunakan pola *surrogate key + natural unique key*.

```sql
users (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,  -- kunci teknis internal
  public_id   CHAR(26) UNIQUE NOT NULL,   -- ULID, dipakai di URL & API publik
  nik_hash    CHAR(64) UNIQUE NOT NULL,   -- SHA-256(NIK + pepper) → jaminan keunikan
  nik_enc     VARBINARY(255) NOT NULL,    -- AES-256-GCM(NIK) → untuk ditampilkan admin
  nik_masked  CHAR(16) NOT NULL,          -- '3201********0001' → tampilan sehari-hari
  ...
)
```

Dengan pola ini Anda tetap mendapatkan **100% tujuan yang Anda inginkan**:
- ✅ NIK tetap identitas utama pengguna (satu NIK = satu akun, dijamin `nik_hash UNIQUE`)
- ✅ Tidak mungkin ada akun ganda dengan NIK sama
- ✅ Verifikasi provider tetap berbasis NIK + KTP
- ✅ Integrasi antar-proyek tetap mungkin (lewat `public_id`, atau `nik_hash` bila memang perlu pencocokan identitas)

…sambil **menghilangkan semua 9 konsekuensi negatif** di atas.

**Cara mencari user berdasarkan NIK:** `WHERE nik_hash = SHA256(input + pepper)` —
tetap O(1) lewat index unik, tanpa pernah menyimpan NIK terbuka di index.

### 1.4 Jika Anda tetap memilih NIK sebagai PK

Itu keputusan yang sah (mis. karena dosen mensyaratkannya). Minimal lakukan ini:

1. Tipe data: `CHAR(16)` **bukan** `BIGINT` — NIK bisa berawalan 0, dan bukan
   bilangan yang dioperasikan secara aritmetika.
2. Wajib `CHECK (nik REGEXP '^[0-9]{16}$')` dan validasi checksum tanggal lahir.
3. **Jangan pernah** menampilkan NIK di URL/API. Tambahkan `public_id` (ULID)
   untuk routing, sehingga NIK hanya hidup di dalam database.
4. Aktifkan enkripsi at-rest pada level penyimpanan, bukan level kolom.
5. `ON UPDATE CASCADE` di semua FK, agar koreksi NIK masih mungkin.
6. Siapkan mekanisme penghapusan data pribadi (anonimisasi) untuk kepatuhan PDP.
7. Tulis di laporan bahwa trade-off ini Anda sadari — dosen menghargai mahasiswa
   yang tahu konsekuensi pilihannya.

**ERD di bawah menggunakan rekomendasi saya (surrogate PK + NIK unique).**
Jika Anda memilih opsi 1.4, cukup ganti `users.id` menjadi `users.nik` dan
seluruh `user_id` menjadi `user_nik` — struktur relasinya tidak berubah.

---

## 2. KEPUTUSAN DESAIN DATABASE LAINNYA

| Keputusan | Pilihan | Alasan |
|---|---|---|
| DBMS | **MySQL 8 / MariaDB** (PostgreSQL bila ingin exclusion constraint) | Paling familiar untuk mahasiswa, tersedia di semua hosting |
| Uang | `DECIMAL(12,2)`, **jangan FLOAT** | FLOAT menimbulkan galat pembulatan pada uang |
| Tanggal sewa | `DATE` (bukan DATETIME) | Sewa berbasis hari, bukan jam. Menghindari bug timezone |
| Timezone | Simpan UTC, tampilkan WIB | Konsisten & siap multi-wilayah |
| Soft delete | `deleted_at` pada tabel master | Jangan hard-delete data yang punya riwayat transaksi |
| Enum | Kolom `VARCHAR` + constraint, atau tabel referensi | ENUM MySQL sulit diubah (butuh ALTER TABLE) |
| Audit | Tabel `audit_logs` + `transaction_status_logs` (append-only) | Wajib untuk sengketa & untuk membuktikan AI tidak otonom |
| Unit fisik | Tabel `equipment_units` terpisah | Kondisi melekat pada unit, bukan model (lihat ALG-3) |

---

## 3. DAFTAR TABEL + FIELD PENTING + INDEX

### 3.1 Identitas & akses

**users** — PK `id` BIGINT
`public_id` CHAR(26) UNIQUE · `nik_hash` CHAR(64) UNIQUE · `nik_enc` VARBINARY ·
`nik_masked` CHAR(16) · `full_name` VARCHAR(120) · `email` VARCHAR(160) UNIQUE ·
`phone` VARCHAR(20) UNIQUE · `password_hash` VARCHAR(255) · `avatar_path` ·
`status` ENUM(active, suspended, banned) · `email_verified_at` ·
`created_at`/`updated_at`/`deleted_at`
Index: `(email)`, `(phone)`, `(nik_hash)`, `(status)`

**roles** — PK `id` · `name` UNIQUE (customer/provider/admin) · `description`

**user_roles** — PK gabungan `(user_id, role_id)` · `assigned_at` · `assigned_by`
Index: `(role_id)`

### 3.2 Lokasi

**locations** — PK `id`
`user_id` FK NULL · `provider_id` FK NULL · `label` · `address_line` ·
`city` · `province` · `postal_code` · `latitude` DECIMAL(10,8) ·
`longitude` DECIMAL(11,8) · `is_primary` BOOL
Index: `(latitude, longitude)` untuk *bounding box* pra-filter jarak,
`(city)`, `(provider_id)`

> Untuk pencarian radius: pra-filter dengan bounding box
> (`lat BETWEEN ? AND ?`), lalu hitung Haversine tepat di aplikasi.
> Cara ini memanfaatkan index B-Tree biasa dan cukup untuk skala skripsi.

### 3.3 Provider

**providers** — PK `id`
`user_id` FK UNIQUE (1:1 dengan users) · `business_name` · `slug` UNIQUE ·
`description` · `ktp_image_path` · `store_image_path` · `location_id` FK ·
`status` ENUM(pending, verified, rejected, suspended) ·
`verified_at` · `verified_by` FK users · `rejection_reason` ·
`rating_avg` DECIMAL(3,2) · `rating_count` INT ·
`response_rate` DECIMAL(5,2) · `cancellation_count` INT
Index: `(status)`, `(slug)`, `(rating_avg)`

### 3.4 Katalog

**equipment_categories** — PK `id`
`parent_id` FK self NULL · `name` · `slug` UNIQUE · `icon` ·
`unit_capacity` INT (dipakai Requirement Engine) ·
`checklist_template_json` (komponen + bobot untuk ALG-3) · `is_active`
Index: `(parent_id)`, `(slug)`

**equipment** — PK `id`
`provider_id` FK · `category_id` FK · `name` · `slug` · `description` ·
`brand` · `specs_json` · `capacity_person` INT · `weight_gram` INT ·
`price_per_day` DECIMAL(12,2) · `deposit_amount` DECIMAL(12,2) ·
`min_rental_days` INT · `max_rental_days` INT ·
`stock_total` INT (= COUNT unit aktif, *denormalisasi terkendali*) ·
`condition_score` TINYINT (rata-rata unit, dipakai s5 ALG-1) ·
`rating_avg` DECIMAL(3,2) · `rating_count` INT · `rented_count` INT ·
`status` ENUM(draft, active, inactive, banned) · `deleted_at`
Index: **`(category_id, status)`** (utama untuk ALG-1), `(provider_id)`,
`(price_per_day)`, `(status, rating_avg)`, FULLTEXT `(name, description)`

**equipment_units** — PK `id`
`equipment_id` FK · `unit_code` VARCHAR(40) UNIQUE (mis. `TND-EIG-004`) ·
`condition_score` TINYINT · `status` ENUM(available, rented, maintenance, retired) ·
`acquired_at` · `notes`
Index: `(equipment_id, status)`

**equipment_images** — PK `id`
`equipment_id` FK · `path` · `alt_text` · `sort_order` · `is_primary`
Index: `(equipment_id, sort_order)`

### 3.5 Transaksi

**rental_transactions** — PK `id`
`invoice_code` VARCHAR(30) UNIQUE (mis. `INV-20260920-0001`) ·
`user_id` FK (penyewa) · `provider_id` FK ·
`start_date` DATE · `end_date` DATE · `duration_days` INT ·
`subtotal` · `deposit_total` · `discount` · `late_fee` · `damage_fee` ·
`grand_total` DECIMAL(12,2) ·
`status` VARCHAR(30) (lihat state machine) ·
`idempotency_key` VARCHAR(64) UNIQUE NULL ·
`confirmed_at` · `picked_up_at` · `returned_at` · `completed_at` ·
`cancel_reason` · `notes`
Index: **`(status, start_date)`** (untuk job harian), `(user_id, status)`,
`(provider_id, status)`, `(invoice_code)`

**rental_details** — PK `id`
`transaction_id` FK · `equipment_id` FK · `unit_id` FK NULL ·
`qty` INT · `price_per_day_snapshot` DECIMAL(12,2) ·
`deposit_snapshot` DECIMAL(12,2) · `start_date` · `end_date` · `subtotal`
Index: **`(equipment_id, start_date, end_date)`** ← index paling kritis,
dipakai setiap kali ALG-2 berjalan; juga `(transaction_id)`, `(unit_id)`

> **Kenapa ada `price_per_day_snapshot`?** Karena provider bisa mengubah harga
> kapan saja. Harga yang mengikat adalah harga **saat booking dibuat**.
> Tanpa snapshot ini, total transaksi lama akan ikut berubah — cacat serius
> dan sekaligus celah manipulasi harga (lihat Bagian Keamanan).

**transaction_status_logs** — PK `id` (append-only)
`transaction_id` FK · `from_status` · `to_status` · `actor_user_id` FK NULL ·
`actor_type` (user/system) · `note` · `created_at`
Index: `(transaction_id, created_at)`

**payments** — PK `id`
`transaction_id` FK · `type` ENUM(rental, deposit, refund, penalty) ·
`method` ENUM(manual_transfer, gateway) · `amount` DECIMAL(12,2) ·
`proof_image_path` · `reference_no` ·
`status` ENUM(pending, verified, rejected, refunded) ·
`verified_by` FK users · `verified_at` · `paid_at`
Index: `(transaction_id)`, `(status)`

### 3.6 Kondisi & AI

**condition_snapshots** — PK `id` (append-only)
`transaction_id` FK NULL · `unit_id` FK · `equipment_id` FK ·
`phase` ENUM(PRE_RENTAL, POST_RENTAL, PERIODIC) ·
`checklist_json` (komponen, bobot, nilai) · `condition_score` TINYINT ·
`recorded_by` FK users · `customer_agreed` BOOL · `customer_agreed_at` ·
`notes` · `created_at`
Index: `(transaction_id, phase)`, `(unit_id, created_at)`

**condition_photos** — PK `id`
`snapshot_id` FK · `path` · `area_tag` · `sha256` CHAR(64) · `taken_at`
Index: `(snapshot_id)`
> `sha256` berguna untuk membuktikan foto tidak diganti setelah diunggah.

**ai_inspections** — PK `id`
`snapshot_id` FK · `transaction_id` FK ·
`provider_name` ('gemini') · `model` VARCHAR(60) · `prompt_version` VARCHAR(20) ·
`ai_condition_score` TINYINT · `ai_severity` ENUM(normal, minor, major, severe) ·
`ai_confidence` DECIMAL(4,3) · `image_quality` ENUM(good, acceptable, poor) ·
`findings_json` · `areas_need_check_json` · `raw_response_json` ·
`latency_ms` INT · `token_usage` INT ·
`status` ENUM(pending_review, accepted, adjusted, rejected, unusable) ·
`reviewed_by` FK users NULL · `reviewed_at` · `admin_note` ·
`final_condition_score` TINYINT NULL ← **diisi manusia, bukan AI**
Index: `(status, created_at)` (antrean admin), `(transaction_id)`

**damage_claims** — PK `id`
`transaction_id` FK · `unit_id` FK · `proposed_by` FK users (provider) ·
`proposed_amount` DECIMAL(12,2) · `component_breakdown_json` ·
`delta_score` TINYINT · `severity` ·
`status` ENUM(proposed, approved, adjusted, rejected, disputed) ·
`final_amount` DECIMAL(12,2) NULL · `decided_by` FK users (admin) ·
`decided_at` · `decision_reason`
Index: `(status)`, `(transaction_id)`

**ai_usage_logs** — PK `id`
`user_id` FK NULL · `feature` ENUM(need_parser, inspection, autofill, explainer) ·
`tokens_in` · `tokens_out` · `cost_estimate` · `success` BOOL ·
`error_code` · `created_at`
Index: `(user_id, created_at)`, `(feature, created_at)` ← untuk rate limiting & kuota

### 3.7 Matching & konfigurasi

**scoring_weights** — PK `id`
`version` VARCHAR(20) · `w_budget` · `w_spec` · `w_distance` · `w_rating` ·
`w_condition` · `w_duration` DECIMAL(4,3) · `is_active` BOOL · `note`
> Memungkinkan eksperimen bobot tanpa mengubah kode — bagus untuk bab
> Pengujian di laporan.

**requirement_rules** — PK `id`
`category_id` FK · `condition_json` (mis. `{"duration_days":{">=":2}}`) ·
`unit_capacity` INT · `multiplier` DECIMAL(3,2) ·
`priority` ENUM(ESSENTIAL, RECOMMENDED, OPTIONAL) · `is_active`

**trip_requests** — PK `id` (menyimpan setiap permintaan matching)
`user_id` FK NULL · `raw_input` TEXT · `parsed_profile_json` ·
`ai_used` BOOL · `result_json` · `selected_bundle_id` NULL · `created_at`
> Tabel ini emas untuk laporan: Anda bisa menganalisis berapa persen
> rekomendasi yang benar-benar dipesan (*conversion rate*) sebagai bukti
> algoritma Anda bekerja.

### 3.8 Reputasi & notifikasi

**reviews** — PK `id`
`transaction_id` FK UNIQUE (satu transaksi satu review) · `user_id` FK ·
`equipment_id` FK · `provider_id` FK · `rating` TINYINT CHECK(1..5) ·
`comment` TEXT · `condition_rating` TINYINT · `is_visible` BOOL · `created_at`
Index: `(equipment_id, is_visible)`, `(provider_id)`, UNIQUE `(transaction_id)`

**notifications** — PK `id`
`user_id` FK · `type` · `title` · `body` · `link_url` · `read_at` · `created_at`
Index: `(user_id, read_at)`

**disputes** — PK `id`
`transaction_id` FK · `opened_by` FK users · `category` · `description` ·
`evidence_json` · `status` ENUM(open, in_review, resolved, closed) ·
`resolution` · `resolved_by` FK users · `resolved_at`
Index: `(status)`

**audit_logs** — PK `id` (append-only)
`actor_user_id` FK NULL · `action` · `entity_type` · `entity_id` ·
`before_json` · `after_json` · `ip_address` · `user_agent` · `created_at`
Index: `(entity_type, entity_id)`, `(actor_user_id, created_at)`

---

## 4. KARDINALITAS UTAMA

| Relasi | Kardinalitas | Catatan |
|---|---|---|
| users ↔ roles | M:N | lewat `user_roles` |
| users → providers | 1:0..1 | satu user maksimal satu toko |
| providers → equipment | 1:N | |
| equipment_categories → equipment | 1:N | kategori boleh bersarang (self-reference) |
| equipment → equipment_units | 1:N | **stok = jumlah unit** |
| equipment → equipment_images | 1:N | |
| users → rental_transactions | 1:N | sebagai penyewa |
| providers → rental_transactions | 1:N | |
| rental_transactions → rental_details | 1:N | |
| equipment ↔ rental_transactions | M:N | lewat `rental_details` |
| rental_transactions → payments | 1:N | sewa, deposit, refund terpisah |
| rental_transactions → condition_snapshots | 1:N | minimal 2 (PRE & POST) |
| condition_snapshots → condition_photos | 1:N | |
| condition_snapshots → ai_inspections | 1:0..N | boleh diulang bila foto diperbaiki |
| rental_transactions → damage_claims | 1:0..N | |
| rental_transactions → reviews | 1:0..1 | |
| users → notifications | 1:N | |

---

## 5. ERD (Mermaid)

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : memiliki
    ROLES ||--o{ USER_ROLES : diberikan
    USERS ||--o| PROVIDERS : mendaftar_sebagai
    USERS ||--o{ LOCATIONS : menyimpan
    PROVIDERS ||--|| LOCATIONS : berlokasi_di
    PROVIDERS ||--o{ EQUIPMENT : menyediakan
    EQUIPMENT_CATEGORIES ||--o{ EQUIPMENT : mengelompokkan
    EQUIPMENT_CATEGORIES ||--o{ EQUIPMENT_CATEGORIES : subkategori
    EQUIPMENT_CATEGORIES ||--o{ REQUIREMENT_RULES : mendasari
    EQUIPMENT ||--o{ EQUIPMENT_IMAGES : memiliki
    EQUIPMENT ||--o{ EQUIPMENT_UNITS : terdiri_atas
    USERS ||--o{ RENTAL_TRANSACTIONS : menyewa
    PROVIDERS ||--o{ RENTAL_TRANSACTIONS : melayani
    RENTAL_TRANSACTIONS ||--|{ RENTAL_DETAILS : berisi
    EQUIPMENT ||--o{ RENTAL_DETAILS : disewakan_pada
    EQUIPMENT_UNITS ||--o{ RENTAL_DETAILS : dialokasikan
    RENTAL_TRANSACTIONS ||--o{ PAYMENTS : dibayar_via
    RENTAL_TRANSACTIONS ||--o{ TRANSACTION_STATUS_LOGS : dicatat
    RENTAL_TRANSACTIONS ||--o{ CONDITION_SNAPSHOTS : menghasilkan
    EQUIPMENT_UNITS ||--o{ CONDITION_SNAPSHOTS : dinilai
    CONDITION_SNAPSHOTS ||--o{ CONDITION_PHOTOS : berisi
    CONDITION_SNAPSHOTS ||--o{ AI_INSPECTIONS : dianalisis
    USERS ||--o{ AI_INSPECTIONS : memvalidasi
    RENTAL_TRANSACTIONS ||--o{ DAMAGE_CLAIMS : memicu
    USERS ||--o{ DAMAGE_CLAIMS : memutuskan
    RENTAL_TRANSACTIONS ||--o| REVIEWS : diulas
    EQUIPMENT ||--o{ REVIEWS : menerima
    PROVIDERS ||--o{ REVIEWS : menerima
    USERS ||--o{ NOTIFICATIONS : menerima
    USERS ||--o{ TRIP_REQUESTS : mengajukan
    USERS ||--o{ AI_USAGE_LOGS : memicu
    RENTAL_TRANSACTIONS ||--o{ DISPUTES : disengketakan
    USERS ||--o{ AUDIT_LOGS : melakukan

    USERS {
        bigint id PK
        char26 public_id UK "ULID untuk URL"
        char64 nik_hash UK "SHA256(NIK+pepper)"
        varbinary nik_enc "AES-256-GCM"
        char16 nik_masked
        varchar full_name
        varchar email UK
        varchar phone UK
        varchar password_hash
        enum status
        timestamp email_verified_at
        timestamp deleted_at
    }
    ROLES {
        bigint id PK
        varchar name UK
    }
    USER_ROLES {
        bigint user_id PK_FK
        bigint role_id PK_FK
        timestamp assigned_at
    }
    LOCATIONS {
        bigint id PK
        bigint user_id FK
        bigint provider_id FK
        varchar address_line
        varchar city
        varchar province
        decimal latitude "IDX"
        decimal longitude "IDX"
        boolean is_primary
    }
    PROVIDERS {
        bigint id PK
        bigint user_id FK_UK
        varchar business_name
        varchar slug UK
        varchar ktp_image_path
        bigint location_id FK
        enum status "pending|verified|rejected"
        bigint verified_by FK
        decimal rating_avg
        int rating_count
    }
    EQUIPMENT_CATEGORIES {
        bigint id PK
        bigint parent_id FK
        varchar name
        varchar slug UK
        int unit_capacity
        json checklist_template_json
        boolean is_active
    }
    EQUIPMENT {
        bigint id PK
        bigint provider_id FK
        bigint category_id FK "IDX(category,status)"
        varchar name
        json specs_json
        int capacity_person
        int weight_gram
        decimal price_per_day
        decimal deposit_amount
        int min_rental_days
        int stock_total
        tinyint condition_score
        decimal rating_avg
        int rented_count
        enum status
    }
    EQUIPMENT_UNITS {
        bigint id PK
        bigint equipment_id FK
        varchar unit_code UK
        tinyint condition_score
        enum status "available|rented|maintenance|retired"
    }
    EQUIPMENT_IMAGES {
        bigint id PK
        bigint equipment_id FK
        varchar path
        int sort_order
        boolean is_primary
    }
    RENTAL_TRANSACTIONS {
        bigint id PK
        varchar invoice_code UK
        bigint user_id FK
        bigint provider_id FK
        date start_date "IDX(status,start_date)"
        date end_date
        int duration_days
        decimal subtotal
        decimal deposit_total
        decimal late_fee
        decimal damage_fee
        decimal grand_total
        varchar status
        varchar idempotency_key UK
    }
    RENTAL_DETAILS {
        bigint id PK
        bigint transaction_id FK
        bigint equipment_id FK "IDX(equip,start,end)"
        bigint unit_id FK
        int qty
        decimal price_per_day_snapshot
        decimal deposit_snapshot
        date start_date
        date end_date
    }
    PAYMENTS {
        bigint id PK
        bigint transaction_id FK
        enum type "rental|deposit|refund|penalty"
        decimal amount
        varchar proof_image_path
        enum status
        bigint verified_by FK
    }
    TRANSACTION_STATUS_LOGS {
        bigint id PK
        bigint transaction_id FK
        varchar from_status
        varchar to_status
        bigint actor_user_id FK
        timestamp created_at
    }
    CONDITION_SNAPSHOTS {
        bigint id PK
        bigint transaction_id FK
        bigint unit_id FK
        enum phase "PRE_RENTAL|POST_RENTAL"
        json checklist_json
        tinyint condition_score
        bigint recorded_by FK
        boolean customer_agreed
    }
    CONDITION_PHOTOS {
        bigint id PK
        bigint snapshot_id FK
        varchar path
        varchar area_tag
        char64 sha256
    }
    AI_INSPECTIONS {
        bigint id PK
        bigint snapshot_id FK
        varchar model
        varchar prompt_version
        tinyint ai_condition_score
        enum ai_severity
        decimal ai_confidence
        enum image_quality
        json findings_json
        json raw_response_json
        enum status "pending_review|accepted|adjusted|rejected"
        bigint reviewed_by FK
        tinyint final_condition_score "diisi ADMIN"
    }
    DAMAGE_CLAIMS {
        bigint id PK
        bigint transaction_id FK
        bigint proposed_by FK
        decimal proposed_amount
        tinyint delta_score
        enum status
        decimal final_amount
        bigint decided_by FK
    }
    REVIEWS {
        bigint id PK
        bigint transaction_id FK_UK
        bigint user_id FK
        bigint equipment_id FK
        bigint provider_id FK
        tinyint rating
        text comment
        boolean is_visible
    }
    NOTIFICATIONS {
        bigint id PK
        bigint user_id FK
        varchar type
        varchar title
        timestamp read_at
    }
    TRIP_REQUESTS {
        bigint id PK
        bigint user_id FK
        text raw_input
        json parsed_profile_json
        boolean ai_used
        json result_json
    }
    REQUIREMENT_RULES {
        bigint id PK
        bigint category_id FK
        json condition_json
        int unit_capacity
        enum priority "ESSENTIAL|RECOMMENDED|OPTIONAL"
        boolean is_active
    }
    AI_USAGE_LOGS {
        bigint id PK
        bigint user_id FK
        enum feature
        int tokens_in
        int tokens_out
        boolean success
    }
    DISPUTES {
        bigint id PK
        bigint transaction_id FK
        bigint opened_by FK
        enum status
        bigint resolved_by FK
    }
    AUDIT_LOGS {
        bigint id PK
        bigint actor_user_id FK
        varchar action
        varchar entity_type
        bigint entity_id
        json before_json
        json after_json
    }
```

Tabel `SCORING_WEIGHTS` sengaja tidak digambar karena tabel konfigurasi berdiri
sendiri tanpa relasi.

---

## 6. CATATAN INTEGRASI DENGAN PROYEK MAHASISWA LAIN

Karena Anda menyebut kemungkinan integrasi:
1. **Jangan pernah mengekspos `id` internal.** Gunakan `public_id` (ULID) di
   semua API publik. Dengan begitu Anda bisa mengubah struktur internal tanpa
   merusak integrasi pihak lain.
2. **Jangan pernah mengirim NIK ke sistem lain.** Jika perlu mencocokkan
   identitas, tukar `nik_hash` (dengan pepper yang disepakati) — bukan NIK.
3. Sediakan `/api/v1/` dengan versi di URL, dan `updated_at` pada semua resource
   agar sistem lain bisa melakukan sinkronisasi inkremental.
4. Jangan izinkan sistem lain menulis langsung ke tabel. Semua lewat API.
