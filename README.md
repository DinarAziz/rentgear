# Dokumen Rancangan Sistem — Marketplace Penyewaan Alat Hiking/Camping

Status: **Implementasi berjalan.** Aplikasi Flutter ada di [`rentgear_app/`](rentgear_app/README.md), server Laravel di [`rentgear_api/`](rentgear_api/README.md), presentasi sidang di [`presentasi/`](presentasi/README.md). Urutan kerja selanjutnya: [`docs/08-RENCANA-KERJA.md`](docs/08-RENCANA-KERJA.md).

## Daftar Dokumen

| File | Isi | Poin permintaan |
|---|---|---|
| [01-KONSEP-DAN-ANALISIS.md](docs/01-KONSEP-DAN-ANALISIS.md) | Ringkasan konsep, problem statement, tujuan, aktor & role, daftar fitur, fitur AI + alasan & alternatif | 1–6 |
| [02-ALGORITMA.md](docs/02-ALGORITMA.md) | ALG-1 Smart Matching (AHP, rumus, contoh hitung, pseudocode), ALG-2 Availability sweep-line + anti race condition, ALG-3 Condition Delta | 7–9 |
| [03-FLOW-DAN-USECASE.md](docs/03-FLOW-DAN-USECASE.md) | State machine transaksi, flow customer/provider/admin, use case diagram + spesifikasi naratif | 10–11 |
| [04-DATABASE.md](docs/04-DATABASE.md) | Analisis NIK sebagai PK, seluruh tabel + index + kardinalitas, ERD Mermaid | 12–13 |
| [05-TECHSTACK-STRUKTUR-API.md](docs/05-TECHSTACK-STRUKTUR-API.md) | Perbandingan & rekomendasi tech stack, struktur folder lengkap, arsitektur API | 14–16 |
| [06-KEAMANAN-PRIORITAS-ROADMAP.md](docs/06-KEAMANAN-PRIORITAS-ROADMAP.md) | 9 kelompok risiko keamanan + solusi, MoSCoW, roadmap 12 sprint, risiko teknis, **REKOMENDASI FINAL ARCHITECTURE** | 17–20 |
| [07-JAMINAN-SEWA.md](docs/07-JAMINAN-SEWA.md) | Jaminan sewa wajib (KTP, SIM, KTM, ijazah, dll.): aturan, status, tabel, endpoint, privasi | tambahan |
| [08-RENCANA-KERJA.md](docs/08-RENCANA-KERJA.md) | Urutan kerja setelah aplikasi lokal: denda dan blacklist (selesai), halaman toko penyedia, server Laravel, login Google, fitur AI | tambahan |

## Tiga Inti Teknis

1. **ALG-2 Availability Sweep-Line** — okupansi puncak, bukan penjumlahan stok naif; berlapis anti double booking (lock + cek ulang + idempotency + constraint DB + uji konkurensi).
2. **ALG-1 Smart Matching** — hard filter + skor berbobot 6 kriteria, bobot diturunkan dengan **AHP (CR = 0,012)**, ditutup knapsack 0/1 dalam batas budget.
3. **ALG-3 Condition Delta** — snapshot PRE/POST append-only, checklist berbobot, AI sebagai *advisor* dengan aturan fusion yang **mengeskalasi ke admin saat berbeda, bukan merata-ratakan**.

## Lima Keputusan yang Menunggu Anda

1. NIK sebagai primary key murni, atau surrogate key + NIK unique (rekomendasi)?
2. React + Inertia, atau Blade + Alpine?
3. Unit fisik individual (rekomendasi) atau stok agregat?
4. AI #3 auto-fill katalog: masuk atau dicoret?
5. Roadmap 12 minggu × 15 jam: realistis?
