# Bagian 10: Activity diagram

Diagram di bawah menggambarkan alur yang benar-benar berjalan di aplikasi per 21 Oktober 2026, bukan rancangan awal di
Bagian 3. Tiap kolom (swimlane) adalah satu pelaku: penyewa, sistem (server RentGear), penyedia, atau admin. Lingkaran
hitam adalah titik mulai, dan lingkaran bergaris ganda adalah titik selesai. Belah ketupat adalah keputusan.

Mermaid belum punya jenis activity diagram UML, jadi swimlane digambar dengan `subgraph`. Nama status di kurung siku
sama dengan nilai `RentalStatus` di kode.

## 1. Pemesanan dan pembayaran

```mermaid
flowchart TB
    start((●))

    subgraph Penyewa
        A1[Pilih alat, ukuran, dan tanggal]
        A2[Isi jaminan: jenis, nama, nomor, foto]
        A3[Kirim booking]
        A7[Transfer sesuai nominal]
        A8[Unggah foto bukti transfer]
    end

    subgraph Sistem
        S1{Stok cukup pada tanggal itu?<br/>ALG-2 sweep-line}
        S2[Kunci harga, deposit, aturan denda, diskon<br/>status: pendingConfirmation]
        S3{Penyedia menjawab dalam 12 jam?}
        S4[status: expired, stok dilepas]
        S5{Dibayar dalam 24 jam?}
        S6[status: cancelled, stok dilepas]
        S7[Buat Payment baru dengan nominal terkunci<br/>status: paymentReview]
        S9[Tampilkan pesan stok tidak cukup]
    end

    subgraph Penyedia
        P1[Periksa foto jaminan]
        P2{Semua jaminan valid?}
        P3[Tolak booking dengan alasan<br/>status: rejected]
        P4[Konfirmasi booking<br/>status: awaitingPayment]
        P5{Bukti transfer cocok dengan mutasi?}
        P6[Tolak bukti dengan alasan<br/>Payment: rejected]
        P7[Terima bukti<br/>Payment: accepted, status: paid]
    end

    stop(((selesai)))

    start --> A1 --> A2 --> A3 --> S1
    S1 -- tidak --> S9 --> A1
    S1 -- ya --> S2 --> S3
    S3 -- tidak --> S4 --> stop
    S3 -- ya --> P1 --> P2
    P2 -- tidak --> P3 --> stop
    P2 -- ya --> P4 --> S5
    S5 -- tidak --> S6 --> stop
    S5 -- ya --> A7 --> A8 --> S7 --> P5
    P5 -- tidak --> P6 --> A7
    P5 -- ya --> P7 --> stop
```

Catatan:

- Booking yang dikirim dua kali dengan `Idempotency-Key` yang sama hanya tercatat satu kali.
- Booking yang datang bersamaan untuk unit terakhir mengantre di database (transaksi `IMMEDIATE`). Satu berhasil, yang
  lain mendapat pesan stok tidak cukup. Hasil ujinya ada di Bagian 11.
- Bukti transfer yang ditolak tetap tersimpan sebagai `Payment` berstatus `rejected`, jadi riwayatnya bisa dilihat.

## 2. Serah terima, pengembalian, dan denda

```mermaid
flowchart TB
    start((●))

    subgraph Penyewa
        C1[Datang ke toko dengan dokumen asli jaminan]
        C2{Barang sesuai pesanan?}
        C3[Laporkan barang tidak sesuai<br/>hanya pada hari diterima]
        C4[Pakai alat]
        C5[Kembalikan alat]
        C6{Setuju dengan denda kerusakan?}
        C7[Ajukan keberatan]
        C8[Beri ulasan toko]
    end

    subgraph Penyedia
        P1[Terima dokumen asli, foto kondisi alat<br/>status: pickedUp]
        P2[Periksa kondisi: baik, rusak ringan,<br/>rusak berat, atau hilang]
        P3[Isi denda kerusakan dan catatan, foto kondisi<br/>status: returned]
        P4[Kembalikan dokumen jaminan<br/>status: completed]
    end

    subgraph Sistem
        S1{Lewat tanggal selesai?}
        S2[status: overdue]
        S3[Hitung denda terlambat dari tanggal server<br/>hari x tarif x unit x pengali toko]
        S4{Denda kerusakan lebih dari separuh deposit?}
        S5[Masuk tinjauan admin]
        S6[Hitung pengembalian deposit:<br/>deposit dikurangi denda]
    end

    subgraph Admin
        D1[Putuskan laporan barang tidak sesuai:<br/>refund, tukar, atau tolak]
        D2[Tetapkan denda akhir, 0 sampai deposit]
    end

    stop(((selesai)))

    start --> C1 --> P1 --> C2
    C2 -- tidak --> C3 --> D1
    D1 -- refund --> stop
    D1 -- tukar atau tolak --> C4
    C2 -- ya --> C4 --> S1
    S1 -- ya --> S2 --> C5
    S1 -- tidak --> C5
    C5 --> P2 --> P3 --> S3 --> S4
    S4 -- ya --> S5 --> D2 --> S6
    S4 -- tidak --> C6
    C6 -- tidak --> C7 --> S5
    C6 -- ya --> S6
    S6 --> P4 --> C8 --> stop
```

Catatan:

- Penyedia tidak bisa menutup transaksi selama denda masih ditinjau admin (`DAMAGE_REVIEW_PENDING`).
- Pengembalian dengan kondisi selain baik muncul di "Catatan kerusakan" pada form alat, sebagai riwayat kerusakan per
  alat.
- Tiga pelanggaran (terlambat, tidak datang, rusak) membuat penyewa masuk blacklist otomatis.

## 3. Pendaftaran dan verifikasi toko

```mermaid
flowchart TB
    start((●))

    subgraph Pemilik toko
        O1{Sudah punya akun penyewa?}
        O2[Daftar sebagai penyedia]
        O3[Profil > Buka toko di RentGear]
        O4[Isi data toko, NIK, foto KTP,<br/>swafoto dengan KTP, 1-3 foto toko]
        O5[Baca alasan penolakan, perbaiki]
    end

    subgraph Sistem
        S1{Ada sewa berjalan atau blacklist?}
        S2[Tolak buka toko]
        S3[Buat toko, status: pending]
        S4[Simpan NIK terenkripsi dan foto di disk privat<br/>catat jejak audit]
        S5[Kirim email hasil ke pemilik]
    end

    subgraph Admin
        D1[Periksa dokumen, NIK tersamar,<br/>peringatan NIK dipakai toko lain]
        D2{Dokumen dan data cocok?}
        D3[Tolak dengan alasan<br/>status: rejected]
        D4[Verifikasi<br/>status: verified]
    end

    stop(((alat tampil di katalog)))

    start --> O1
    O1 -- tidak --> O2 --> S3
    O1 -- ya --> O3 --> S1
    S1 -- ya --> S2
    S1 -- tidak --> S3
    S3 --> O4 --> S4 --> D1 --> D2
    D2 -- tidak --> D3 --> S5 --> O5 --> O4
    D2 -- ya --> D4 --> S5
    S5 -.-> stop
```

Admin tidak bisa memverifikasi toko yang belum mengirim dokumen. Garis putus-putus berarti alat baru tampil setelah
status toko `verified`.

## 4. Saran paket alat dari AI

```mermaid
flowchart TB
    start((●))

    subgraph Penyewa
        A1[Tulis tujuan dan rencana perjalanan<br/>paling banyak 200 huruf]
        A2[Pilih alat dari saran, lalu pesan sendiri]
    end

    subgraph Sistem
        S1{Kuota harian akun masih ada?<br/>20 saran per hari}
        S2{Teks berisi huruf?}
        S3[Kirim aturan sebagai systemInstruction,<br/>rencana sebagai data JSON, dan katalog toko terverifikasi]
        S4{Gemini menandai relevan?}
        S5[Tolak: AI_OFF_TOPIC]
        S6[Buang alat yang tidak ada di katalog,<br/>batasi jumlah ke stok, hitung harga di server,<br/>potong teks yang terlalu panjang]
        S7[Tolak: batas harian habis]
    end

    stop(((selesai)))

    start --> A1 --> S2
    S2 -- tidak --> S5
    S2 -- ya --> S1
    S1 -- tidak --> S7 --> stop
    S1 -- ya --> S3 --> S4
    S4 -- tidak --> S5 --> stop
    S4 -- ya --> S6 --> A2 --> stop
```
