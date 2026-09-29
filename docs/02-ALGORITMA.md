# Bagian 2: ALGORITMA UTAMA (inti penilaian)

Tiga algoritma inti:

| Kode | Nama | Sifat | Kompleksitas |
|---|---|---|---|
| **ALG-1** | Smart Rental Matching (scoring + bundling) | Deterministik, dapat dijelaskan | O(n log n) ranking, O(n·B) bundling |
| **ALG-2** | Availability Sweep-Line | Deterministik, bebas double booking | O(k log k) |
| **ALG-3** | Condition Delta & Damage Indication | Deterministik + input AI | O(m) |

---

# ALG-1 — SMART RENTAL MATCHING

## 1.1 Arsitektur algoritma (4 tahap)

```
TripProfile ──► [A] Requirement Engine ──► RequirementList
                                              │
RequirementList ──► [B] Hard Filter ──────────┤ (buang kandidat mustahil)
                                              │
              Kandidat lolos ──► [C] Weighted Scoring ──► kandidat terurut
                                              │
                          ──► [D] Bundle Builder (budget knapsack) ──► PAKET
```

Pemisahan **hard filter** (boolean, wajib) dan **soft scoring** (kontinu,
preferensi) adalah keputusan desain penting: hard filter menjamin **kebenaran**
(tidak mungkin merekomendasikan alat yang tidak tersedia), soft scoring
menjamin **kualitas urutan**.

---

## 1.2 [A] Requirement Engine — kebutuhan → daftar alat

Deterministik, berbasis tabel aturan (disimpan di DB tabel `requirement_rules`
agar bisa diubah admin **tanpa deploy ulang**).

**Rumus kuantitas:**

```
qty(kategori) = ceil( participants / unit_capacity ) * multiplier(trip)
```

Contoh tabel aturan (seed awal):

| Kategori | unit_capacity | Prioritas | Kondisi aktif |
|---|---|---|---|
| Tenda | 4 org/unit | ESSENTIAL | trip_type ∈ {camping, hiking_overnight} |
| Sleeping bag | 1 org/unit | ESSENTIAL | selalu |
| Matras | 1 org/unit | ESSENTIAL | selalu |
| Carrier 60L | 1 org/unit | ESSENTIAL | duration_days ≥ 2 |
| Daypack 30L | 1 org/unit | ESSENTIAL | duration_days = 1 |
| Kompor + nesting | 4 org/unit | ESSENTIAL | special_needs ∋ "masak" OR duration ≥ 2 |
| Headlamp | 1 org/unit | ESSENTIAL | selalu |
| Jaket gunung | 1 org/unit | RECOMMENDED | elevation ∈ {medium, high} |
| Trekking pole | 1 org/unit | OPTIONAL | difficulty ≠ beginner |
| Rain cover / ponco | 1 org/unit | ESSENTIAL | season = rainy |
| Sepatu gunung | 1 org/unit | OPTIONAL | selalu |
| P3K | 4 org/unit | RECOMMENDED | selalu |

Prioritas dipakai di tahap [D] sebagai **bobot nilai (value)** knapsack:
ESSENTIAL = 100, RECOMMENDED = 60, OPTIONAL = 25.

---

## 1.3 [B] Hard Filter — syarat mutlak (semua harus TRUE)

Kandidat `e` (equipment) lolos jika:

```
H1  e.status = 'active' AND e.provider.status = 'verified'
H2  e.category_id ∈ kategori yang dibutuhkan
H3  available_qty(e, start_date, end_date) ≥ 1          ← ALG-2
H4  duration_days ≥ e.min_rental_days
H5  price_per_day(e) ≤ budget_per_item_cap              ← cap = 2 × budget_rata2 kategori
H6  distance(user, e.location) ≤ max_radius_km          ← default 50 km, dapat diubah user
H7  e.condition_score ≥ 50                               ← alat rusak tidak ditawarkan
```

Jika setelah hard filter suatu kategori ESSENTIAL kosong → sistem menandai
`unfulfilled_categories` dan tetap menampilkan paket parsial + peringatan jujur
("Tenda kapasitas 4 tidak tersedia pada tanggal ini di radius 50 km").
**Jangan pernah** mengisi paksa dengan alat yang tidak sesuai.

---

## 1.4 [C] Weighted Scoring — rumus lengkap

### Bentuk umum

```
Score(e) = Σ ( w_k · s_k(e) )   ,  k = 1..6   ,  s_k ∈ [0,1] , Σ w_k = 1
Score_final(e) = 100 × Score(e) × PenaltyFactor(e)
```

### 1.4.1 Penentuan bobot — **AHP (Analytic Hierarchy Process)**

Bobot **tidak ditentukan sembarangan**. Saya menurunkannya dengan AHP
(metode Saaty), agar saat presentasi Anda bisa menjawab "kenapa 0,24?".

**Langkah 1 — matriks perbandingan berpasangan** (skala Saaty 1–9),
berdasarkan penalaran domain: kecocokan spesifikasi & harga paling menentukan
kepuasan penyewa; jarak penting karena pengambilan dilakukan sendiri; rating
dan kondisi setara sebagai proksi kualitas; kesesuaian durasi paling ringan
karena sudah sebagian ditangani hard filter.

|  | C1 Budget | C2 Spec fit | C3 Jarak | C4 Rating | C5 Kondisi | C6 Durasi |
|---|---|---|---|---|---|---|
| **C1 Budget**   | 1 | 1 | 1 | 2 | 2 | 3 |
| **C2 Spec fit** | 1 | 1 | 1 | 2 | 2 | 4 |
| **C3 Jarak**    | 1 | 1 | 1 | 1 | 1 | 3 |
| **C4 Rating**   | 1/2 | 1/2 | 1 | 1 | 1 | 2 |
| **C5 Kondisi**  | 1/2 | 1/2 | 1 | 1 | 1 | 2 |
| **C6 Durasi**   | 1/3 | 1/4 | 1/3 | 1/2 | 1/2 | 1 |

**Langkah 2 — rata-rata geometrik tiap baris, lalu normalisasi:**

| Kriteria | GM baris | Bobot w |
|---|---|---|
| C1 Budget fit | 1,5130 | **0,23** |
| C2 Spec/capacity fit | 1,5874 | **0,24** |
| C3 Jarak | 1,2009 | **0,18** |
| C4 Rating provider | 0,8909 | **0,14** |
| C5 Kondisi alat | 0,8909 | **0,14** |
| C6 Kesesuaian durasi | 0,4368 | **0,07** |
| **Σ** | 6,5199 | **1,00** |

**Langkah 3 — uji konsistensi:**
λmax = 6,077 → CI = (6,077 − 6)/5 = 0,0154 → dengan RI(n=6) = 1,24 →
**CR = 0,012 < 0,1 → matriks konsisten, bobot sah dipakai.**

> Bobot ini disimpan di tabel `scoring_weights` (versi + aktif/tidak), sehingga
> dapat di-tuning admin dan Anda bisa menunjukkan eksperimen A/B sederhana di
> laporan ("bobot v1 vs v2, mana yang menghasilkan konversi lebih tinggi").

### 1.4.2 Fungsi sub-skor s_k (normalisasi ke [0,1])

**s1 — Budget fit** (semakin murah relatif budget, semakin baik, tetapi terlalu murah tidak dihargai berlebihan)
```
cost(e)   = price_per_day(e) × duration_days × qty
ratio     = cost(e) / budget_alloc(kategori)
s1 = 1                       , jika ratio ≤ 0,6
s1 = (1 − ratio) / 0,4       , jika 0,6 < ratio ≤ 1,0
s1 = 0                       , jika ratio > 1,0
```
`budget_alloc(kategori) = budget_total × share(kategori)`, di mana share
diturunkan dari proporsi harga pasar rata-rata kategori tersebut (dihitung dari
data katalog sendiri — jadi adaptif, bukan hardcode).

**s2 — Spec / capacity fit** (kecocokan jumlah orang)
```
fit = participants_covered(e) / participants_required
s2 = 1 − |1 − fit| , dibatasi minimum 0
```
Contoh: butuh 4 orang, tenda kapasitas 4 → fit=1 → s2=1.
Tenda kapasitas 6 → fit=1,5 → s2=0,5 (mubazir, berat, mahal).
Tenda kapasitas 2 → fit=0,5 → s2=0,5 (perlu 2 unit).

**s3 — Jarak** (peluruhan eksponensial, lebih realistis daripada linear)
```
s3 = exp( −d / D0 )     ,  d = jarak haversine (km), D0 = 15 km (konstanta peluruhan)
```
d=0 → 1,00 ; d=5 → 0,72 ; d=15 → 0,37 ; d=50 → 0,04.
*Kenapa eksponensial?* Selisih 0→5 km terasa jauh lebih besar bagi pengguna
daripada selisih 40→45 km. Fungsi linear tidak menangkap ini.

**s4 — Rating provider** (dengan **Bayesian average** agar provider baru tidak dihukum/diuntungkan tidak adil)
```
             (v × R) + (m × C)
R_bayes  =   ─────────────────         v = jumlah review provider
                  v + m               R = rata-rata rating provider
                                      C = rata-rata rating global platform
                                      m = 5 (jumlah review minimum kepercayaan)
s4 = (R_bayes − 1) / 4                 → memetakan skala 1..5 ke 0..1
```
*Ini penting:* provider dengan 1 review bintang 5 tidak boleh mengalahkan
provider dengan 200 review rata-rata 4,7.

**s5 — Kondisi alat**
```
s5 = condition_score(e) / 100          condition_score dari ALG-3 (0..100)
```

**s6 — Kesesuaian durasi**
```
s6 = 1                                  , jika min_rental ≤ D ≤ optimal_max
s6 = 1 − 0,1 × (D − optimal_max)        , jika D > optimal_max (dibatasi min 0,3)
```
Memberi keuntungan pada alat yang memang diniatkan untuk durasi tersebut.

### 1.4.3 PenaltyFactor (faktor pengali, bukan penjumlah)

```
PenaltyFactor = P_stock × P_new × P_flag

P_stock = 0,9  jika available_qty = 1 (risiko habis / tidak ada cadangan), selain itu 1,0
P_new   = 0,95 jika provider terverifikasi < 30 hari, selain itu 1,0
P_flag  = 0,7  jika provider punya dispute terbuka, selain itu 1,0
```
Menggunakan perkalian agar satu masalah serius menekan seluruh skor, bukan
sekadar mengurangi sedikit.

---

## 1.5 CONTOH PERHITUNGAN LENGKAP

**Skenario:** 4 orang, 2 hari, Gunung Prau, budget total Rp 500.000,
lokasi user di Wonosobo. Kategori yang sedang dinilai: **Tenda kapasitas 4**.
`budget_alloc(tenda) = 500.000 × 0,30 = 150.000`. Rata-rata rating global C = 4,3.

| | **A — "Tenda Eiger 4P"** | **B — "Tenda Consina 6P"** | **C — "Tenda Lokal 4P"** |
|---|---|---|---|
| Harga/hari | 45.000 | 40.000 | 25.000 |
| Kapasitas | 4 | 6 | 4 |
| Jarak | 3 km | 12 km | 28 km |
| Rating provider | 4,8 (v=50) | 4,5 (v=8) | 5,0 (v=1) |
| Condition score | 90 | 78 | 65 |
| Durasi cocok | ya | ya | ya |
| Stok tersedia | 3 | 2 | 1 |

**Perhitungan A:**
- cost = 45.000 × 2 × 1 = 90.000 ; ratio = 90.000/150.000 = 0,60 → **s1 = 1,00**
- fit = 4/4 = 1 → **s2 = 1,00**
- s3 = exp(−3/15) = exp(−0,2) = **0,819**
- R_bayes = (50×4,8 + 5×4,3)/55 = (240+21,5)/55 = 4,755 → s4 = (4,755−1)/4 = **0,939**
- s5 = 90/100 = **0,90**
- **s6 = 1,00**
- Score = 0,23(1,00) + 0,24(1,00) + 0,18(0,819) + 0,14(0,939) + 0,14(0,90) + 0,07(1,00)
  = 0,230 + 0,240 + 0,1474 + 0,1315 + 0,126 + 0,070 = **0,9449**
- Penalty = 1,0 → **Score_final = 94,49**

**Perhitungan B:**
- cost = 40.000×2 = 80.000 ; ratio = 0,533 ≤ 0,6 → **s1 = 1,00**
- fit = 6/4 = 1,5 → s2 = 1 − 0,5 = **0,50**
- s3 = exp(−12/15) = exp(−0,8) = **0,449**
- R_bayes = (8×4,5 + 5×4,3)/13 = (36+21,5)/13 = 4,423 → s4 = **0,856**
- s5 = 0,78 ; s6 = 1,00
- Score = 0,230 + 0,120 + 0,0808 + 0,1198 + 0,1092 + 0,070 = **0,7298**
- Penalty = 1,0 → **Score_final = 72,98**

**Perhitungan C:**
- cost = 25.000×2 = 50.000 ; ratio = 0,333 → **s1 = 1,00**
- s2 = **1,00**
- s3 = exp(−28/15) = exp(−1,867) = **0,155**
- R_bayes = (1×5,0 + 5×4,3)/6 = 26,5/6 = 4,417 → s4 = **0,854**
- s5 = 0,65 ; s6 = 1,00
- Score = 0,230 + 0,240 + 0,0279 + 0,1196 + 0,091 + 0,070 = **0,7785**
- Penalty: stok=1 → 0,9 → **Score_final = 70,07**

**Peringkat: A (94,5) > B (73,0) > C (70,1)**

Perhatikan bahwa C paling murah tetapi kalah karena jauh dan kondisinya biasa —
**inilah gunanya multi-kriteria**, dan ini kalimat bagus untuk presentasi.

---

## 1.6 [D] Bundle Builder — 0/1 Knapsack dengan batas budget

Setelah tiap kategori punya kandidat terbaik, susun paket agar **total biaya ≤
budget** sambil memaksimalkan nilai.

```
value(item)  = priority_value × (Score_final / 100)
                  ESSENTIAL=100, RECOMMENDED=60, OPTIONAL=25
weight(item) = total_cost(item)  (dibulatkan ke ribuan → mengecilkan dimensi DP)
```

Karena item ESSENTIAL wajib ada, algoritmanya adalah:
1. **Fase wajib:** ambil kandidat skor tertinggi untuk setiap kategori ESSENTIAL.
   Jika totalnya sudah melebihi budget → jalankan *downgrade pass*: ganti item
   dengan alternatif termurah yang skornya masih ≥ 70% skor terbaik, dimulai
   dari item dengan rasio (biaya/skor) terburuk, sampai muat.
2. **Fase opsional:** sisa budget dialokasikan ke RECOMMENDED/OPTIONAL dengan
   **DP 0/1 knapsack**.

```
DP[i][b] = max( DP[i−1][b] , DP[i−1][b − w_i] + v_i )
```

**Kompleksitas:**
- Hard filter + scoring: O(n) per kategori, ranking O(n log n).
- Knapsack: O(N × B) dengan B = budget/1000 (mis. 500 langkah) dan N ≤ 30 →
  ≈ 15.000 operasi → **sangat ringan**, aman untuk request web.
- Total realistis < 200 ms di luar panggilan Gemini.

---

## 1.7 PSEUDOCODE — ALG-1

```
FUNCTION SmartMatch(tripInput, user):

  // ---------- Tahap 1: pahami kebutuhan ----------
  profile ← GeminiNeedParser(tripInput)          // AI, boleh gagal
  IF profile IS INVALID THEN
      profile ← ParseFormFallback(tripInput)     // jalur deterministik
  END IF
  LogAiCall("need_parser", profile)

  // ---------- Tahap 2: kebutuhan → daftar kategori ----------
  requirements ← []
  FOR EACH rule IN ActiveRequirementRules():
      IF EvaluateCondition(rule.condition, profile) THEN
          qty ← CEIL(profile.participants / rule.unit_capacity) * rule.multiplier
          requirements.APPEND({category: rule.category_id,
                               qty: qty,
                               priority: rule.priority})
      END IF
  END FOR

  weights ← LoadActiveWeights()                  // dari tabel scoring_weights
  results ← []

  // ---------- Tahap 3: hard filter + scoring ----------
  FOR EACH req IN requirements:

      candidates ← QueryEquipment(category = req.category,
                                  status   = 'active',
                                  radius   = user.max_radius)   // index: (category_id, status)

      scored ← []
      FOR EACH e IN candidates:

          // --- HARD FILTER ---
          IF NOT ProviderVerified(e)                   THEN CONTINUE
          IF AvailableQty(e, profile.start, profile.end) < req.qty THEN CONTINUE   // ALG-2
          IF profile.duration < e.min_rental_days      THEN CONTINUE
          IF e.condition_score < 50                    THEN CONTINUE
          d ← Haversine(user.lat, user.lng, e.lat, e.lng)
          IF d > user.max_radius                       THEN CONTINUE

          // --- SOFT SCORING ---
          cost  ← e.price_per_day * profile.duration * req.qty
          alloc ← profile.budget * CategoryShare(req.category)

          s1 ← BudgetScore(cost, alloc)
          s2 ← 1 − ABS(1 − (e.capacity * req.qty) / profile.participants)
          s2 ← MAX(s2, 0)
          s3 ← EXP(−d / 15)
          s4 ← (BayesianRating(e.provider, m=5) − 1) / 4
          s5 ← e.condition_score / 100
          s6 ← DurationScore(profile.duration, e)

          raw ← weights.w1*s1 + weights.w2*s2 + weights.w3*s3
              + weights.w4*s4 + weights.w5*s5 + weights.w6*s6

          penalty ← PenaltyFactor(e)
          score   ← 100 * raw * penalty

          scored.APPEND({equipment: e, score: score, cost: cost,
                         breakdown: {s1..s6}})      // untuk fitur "kenapa"
      END FOR

      SORT scored BY score DESC                     // O(n log n)

      IF scored IS EMPTY AND req.priority = 'ESSENTIAL' THEN
          results.APPEND({category: req.category, status: 'UNFULFILLED'})
      ELSE
          results.APPEND({category: req.category,
                          top: scored[0 .. 4],      // 5 alternatif
                          priority: req.priority})
      END IF
  END FOR

  // ---------- Tahap 4: susun paket dalam batas budget ----------
  bundle ← BuildBundle(results, profile.budget)     // greedy wajib + DP knapsack
  explanation ← GeminiExplain(bundle)               // opsional, boleh gagal

  RETURN {bundle, alternatives: results, explanation, profile}
END FUNCTION
```

```
FUNCTION BuildBundle(results, budget):
  bundle ← []
  FOR EACH r IN results WHERE r.priority = 'ESSENTIAL' AND r.status ≠ 'UNFULFILLED':
      bundle.APPEND(r.top[0])
  END FOR

  WHILE TotalCost(bundle) > budget:
      target ← ITEM IN bundle WITH MAX (cost / score)          // paling tidak efisien
      alt    ← CHEAPEST alternative OF target WHERE alt.score ≥ 0.7 * target.score
      IF alt EXISTS THEN REPLACE target WITH alt
      ELSE MARK bundle AS 'OVER_BUDGET' ; BREAK
      END IF
  END WHILE

  remaining ← budget − TotalCost(bundle)
  optional  ← ALL r.top[0] WHERE r.priority ≠ 'ESSENTIAL'
  bundle    ← bundle + Knapsack01(optional, remaining)          // O(N × B)
  RETURN bundle
END FUNCTION
```

---

# ALG-2 — AVAILABILITY ENGINE (anti double booking)

## 2.1 Definisi masalah

Alat `e` punya `stock_total = S`. Terdapat sekumpulan booking aktif, masing-masing
berupa interval `[start_i, end_i]` dengan kuantitas `q_i`.
Permintaan baru: interval `[A, B]` dengan kuantitas `q`.

**Kesalahan umum mahasiswa** (hindari ini, dan sebut di laporan sebagai
pembanding):
```sql
-- SALAH: hanya menjumlahkan semua booking yang beririsan
SELECT SUM(qty) FROM rental_details WHERE overlaps(A,B)
```
Ini salah karena dua booking yang sama-sama beririsan dengan `[A,B]` belum tentu
beririsan **satu sama lain**. Contoh: S=1, booking X = 1–3 Jan, booking Y = 5–7 Jan,
permintaan A–B = 1–7 Jan. SUM = 2 > 1 → ditolak, padahal memang benar ditolak.
Tetapi kasus sebaliknya: permintaan 4–4 Jan. SUM juga 2 → **ditolak padahal
seharusnya boleh**. Penjumlahan naif memberi *false negative*.

**Yang benar adalah mencari OKUPANSI PUNCAK (peak concurrent usage)** dalam
rentang yang diminta.

## 2.2 Algoritma Sweep-Line

```
available_qty(e, A, B) = S − max_{t ∈ [A,B]} occupancy(t)
```

Implementasi sweep-line dengan *difference array* pada sumbu waktu:
setiap booking menyumbang `+q` di `start` dan `−q` di `end + 1` (karena end
inklusif — hari terakhir alat masih dipegang penyewa).

**Aturan tanggal yang saya tetapkan (tulis ini di laporan, sering ditanya):**
- Interval **inklusif di kedua ujung**: sewa 1–3 Jan = 3 hari, alat kembali
  di akhir hari ke-3.
- Terdapat **buffer hari** `BUFFER = 1` untuk pembersihan/pengeringan alat.
  Interval efektif yang dikunci adalah `[start, end + BUFFER]`.
  Ini membedakan sistem Anda dari "sekadar cek tanggal".

```
FUNCTION AvailableQty(equipment, A, B):

  S ← equipment.stock_total

  bookings ← SELECT start_date, end_date, qty
             FROM rental_details rd JOIN rental_transactions t
             WHERE rd.equipment_id = equipment.id
               AND t.status IN ('confirmed','paid','picked_up','awaiting_return')
               AND rd.start_date <= B + BUFFER
               AND rd.end_date  + BUFFER >= A            // uji irisan interval
                                                         // index: (equipment_id, start_date, end_date)

  events ← []
  FOR EACH b IN bookings:
      s ← MAX(b.start_date, A)
      e ← MIN(b.end_date + BUFFER, B)
      IF s > e THEN CONTINUE
      events.APPEND({day: s,       delta: +b.qty})
      events.APPEND({day: e + 1,   delta: −b.qty})
  END FOR

  SORT events BY day ASC                                  // O(k log k)

  running ← 0 ; peak ← 0
  FOR EACH ev IN events:
      running ← running + ev.delta
      peak    ← MAX(peak, running)
  END FOR

  RETURN S − peak
END FUNCTION


FUNCTION IsAvailable(equipment, A, B, q):
  RETURN AvailableQty(equipment, A, B) >= q
END FUNCTION
```

**Kompleksitas:** O(k log k) dengan k = jumlah booking yang beririsan
(biasanya < 20). Jauh lebih murah daripada iterasi per hari (O(days × k)).
Untuk kalender ketersediaan 90 hari, gunakan *difference array* berukuran 90 →
O(k + 90), sekali jalan menghasilkan seluruh kalender.

## 2.3 Mencegah RACE CONDITION (ini yang paling sering luput)

Algoritma di atas benar secara logika, tetapi **tetap bisa double booking**
jika dua request tiba bersamaan: keduanya membaca "tersedia 1", keduanya lolos,
keduanya menyimpan. Ini **bug klasik TOCTOU** (Time-Of-Check to Time-Of-Use).

Tiga lapis pertahanan yang saya rancang:

**Lapis 1 — Transaksi database + pessimistic lock**
```
BEGIN TRANSACTION;
  SELECT * FROM equipment WHERE id = ? FOR UPDATE;   -- kunci baris
  qty ← AvailableQty(...)                            -- baca ulang DI DALAM transaksi
  IF qty < requested THEN ROLLBACK; RETURN error;    -- 409 Conflict
  INSERT INTO rental_details ...;
COMMIT;
```

**Lapis 2 — Constraint di level database (jaring pengaman terakhir)**
Tambahkan *check* melalui trigger atau, pada PostgreSQL, *exclusion constraint*
dengan tipe `daterange` + ekstensi `btree_gist`:
```sql
EXCLUDE USING gist (unit_id WITH =, period WITH &&)
```
(Berlaku jika Anda memodelkan **unit fisik individual**; lihat catatan 2.4.)

**Lapis 3 — Idempotency key** pada endpoint booking, agar double-submit dari
tombol yang diklik dua kali tidak membuat dua transaksi.

**Uji yang wajib ada di laporan:** jalankan 50 request paralel
(`ab`, `k6`, atau skrip sederhana) ke satu alat berstok 1 → hasil harus
**tepat 1 sukses, 49 gagal dengan 409**. Ini bukti konkret, bukan klaim.

## 2.4 Catatan desain: stok agregat vs unit fisik

| Pendekatan | Kelebihan | Kekurangan |
|---|---|---|
| **Stok agregat** (`stock_total = 5`) | Sederhana, cukup untuk skripsi | Tidak bisa melacak "tenda nomor 3 yang robek" |
| **Unit individual** (tabel `equipment_units`, tiap unit punya kode) | Pelacakan kondisi per unit akurat, mendukung exclusion constraint | Data lebih banyak |

**Rekomendasi saya: gunakan unit individual**, karena ALG-3 (kondisi alat)
baru benar-benar bermakna jika kondisi melekat pada unit fisik, bukan pada
"model alat". Tabel `equipment_units` ringan (id, equipment_id, kode, kondisi,
status) dan justru **menyederhanakan** logika kondisi. Availability lalu menjadi:
"berapa unit yang tidak terkunci pada rentang tersebut".

---

# ALG-3 — CONDITION DELTA & DAMAGE INDICATION

## 3.1 Model data kondisi: **snapshot, bukan status**

Kesalahan desain umum: menyimpan satu kolom `condition` di tabel alat lalu
menimpanya. Akibatnya riwayat hilang dan sengketa tidak bisa dibuktikan.

Desain yang saya pilih: **event sourcing ringan**. Setiap peristiwa pemeriksaan
menghasilkan satu baris **snapshot** yang tidak pernah diubah (*append-only*).

```
condition_snapshots
  id, unit_id, transaction_id, phase ∈ {PRE_RENTAL, POST_RENTAL, PERIODIC},
  condition_score (0..100), checklist_json, photos[], recorded_by_user, recorded_at
```

`condition_score` unit saat ini = skor snapshot terakhir yang **tervalidasi**.

## 3.2 Checklist terstruktur (sumber kebenaran manusia)

Tiap kategori punya daftar komponen berbobot. Contoh **tenda**:

| Komponen | Bobot b_i |
|---|---|
| Flysheet (lapisan luar) | 0,25 |
| Inner tent | 0,20 |
| Lantai / groundsheet | 0,20 |
| Frame / tiang | 0,15 |
| Resleting | 0,10 |
| Patok & tali | 0,05 |
| Kebersihan | 0,05 |

Tiap komponen dinilai `g_i ∈ {1,0 baik; 0,7 aus wajar; 0,4 rusak ringan; 0,0 rusak berat}`.

```
condition_score = 100 × Σ ( b_i × g_i )
```

## 3.3 Delta Engine — inti algoritma

```
Δ = score_PRE − score_POST
```

| Δ | Klasifikasi | Tindakan sistem |
|---|---|---|
| Δ ≤ 3 | **NORMAL** (toleransi keausan wajar) | Auto-selesai, deposit kembali penuh |
| 3 < Δ ≤ 15 | **MINOR** | Usulan denda ringan → **butuh persetujuan admin** |
| 15 < Δ ≤ 40 | **MAJOR** | Usulan denda berat → admin + notifikasi customer untuk membantah |
| Δ > 40 atau ada komponen g=0 pada komponen vital | **SEVERE / LOSS** | Dispute otomatis, admin wajib turun tangan |

**Denda tidak dihitung AI.** Denda dihitung dari tabel tarif deterministik:
```
denda = Σ ( komponen_rusak.replacement_cost × tingkat_kerusakan )
denda ≤ deposit_amount        // pagar aman, tidak boleh melebihi deposit
```
`replacement_cost` diisi provider saat mendaftarkan alat dan **diverifikasi admin**
— sehingga tidak bisa dimanipulasi setelah kerusakan terjadi.

## 3.4 Di mana AI masuk?

AI mengisi **kolom terpisah**, tidak pernah menimpa nilai manusia:

```
ai_inspections
  id, snapshot_id, model, prompt_version,
  ai_condition_score, ai_severity, ai_confidence,
  findings_json, areas_need_check_json, image_quality,
  raw_response_json, status ∈ {pending_review, accepted, adjusted, rejected},
  reviewed_by_admin, reviewed_at, admin_note
```

**Aturan penggabungan (fusion rule) — deterministik:**

```
FUNCTION ResolveCondition(human_score, ai_result):

  IF ai_result.image_quality = 'poor' THEN
      RETURN {score: human_score, ai_usable: FALSE, action: 'REQUEST_BETTER_PHOTO'}

  IF ai_result.confidence < 0.60 THEN
      RETURN {score: human_score, flag: 'LOW_CONFIDENCE',
              action: 'ADMIN_REVIEW_REQUIRED'}

  gap ← ABS(human_score − ai_result.ai_condition_score)

  IF gap <= 10 THEN
      // manusia dan AI sepakat → keyakinan tinggi
      RETURN {score: human_score, flag: 'CONSISTENT', action: 'FAST_TRACK_APPROVAL'}
  ELSE
      // tidak sepakat → JANGAN dirata-rata, eskalasi ke admin
      RETURN {score: human_score, flag: 'DISCREPANCY',
              action: 'ADMIN_REVIEW_REQUIRED', gap: gap}
  END IF
END FUNCTION
```

> **Keputusan desain yang perlu Anda tekankan saat presentasi:** saat AI dan
> manusia tidak sepakat, sistem **tidak merata-ratakan**. Merata-ratakan akan
> menyembunyikan ketidakpastian. Sistem justru **menaikkan** kasus itu ke admin.
> Nilai akhir yang tersimpan **selalu berasal dari manusia**; AI hanya
> menentukan **seberapa cepat** kasus itu lewat, dan **ke mana** perhatian
> admin diarahkan. Inilah arti "AI membantu, bukan menggantikan".

**Kompleksitas:** O(m) dengan m = jumlah komponen checklist (≤ 10). Tidak signifikan.

## 3.5 Efek balik ke sistem (menutup lingkaran)

- `unit.condition_score` diperbarui dari snapshot POST yang tervalidasi.
- `equipment.condition_score` = rata-rata skor unit aktif → **langsung masuk
  sebagai s5 di ALG-1**. Alat yang sering rusak turun peringkat rekomendasi.
- Provider dengan rata-rata Δ tinggi (alat sering rusak / perawatan buruk)
  mendapat penurunan pada dashboard admin.

Lingkaran inilah yang membuat sistem Anda terasa "hidup": hasil pemeriksaan
kondisi memengaruhi rekomendasi berikutnya. Gambarkan sebagai diagram siklus
di slide presentasi — ini poin yang paling mudah diingat penguji.
