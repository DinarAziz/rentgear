# RentGear — Aplikasi Flutter

Klien Android/iOS (dan web untuk demo) marketplace sewa alat hiking.
Tiga role: **Penyewa**, **Penyedia**, **Admin**.

Saat ini data berasal dari `MockRentGearRepository` (di memori). Backend
Laravel `/api/v1` belum dibuat; nanti cukup tambah implementasi
`RentGearRepository` berbasis HTTP dan ganti di `lib/main.dart`.

## Menjalankan

```bash
flutter pub get
flutter run            # pilih emulator/perangkat
flutter run -d chrome  # demo cepat di browser
flutter test           # unit + widget test
```

Akun demo (password `password`), atau tekan chip di layar login:

| Role | Email |
|---|---|
| Penyewa | budi@rentgear.id, rina@rentgear.id |
| Penyedia | sari@rentgear.id (Arjuna Outdoor), dewi@rentgear.id (Semeru Camp Rent), agus@rentgear.id (belum diverifikasi) |
| Admin | admin@rentgear.id |

## Struktur

```
lib/
  domain/     model, aturan jaminan (guarantee.dart), ALG-2 (availability.dart),
              state machine transaksi
  data/       kontrak repository, repository mock, data seed
  state/      AppState (sesi login + revisi data)
  widgets/    komponen UI bersama, form & kartu jaminan
  features/   auth, customer, provider, admin, rental (detail transaksi)
```

## Alur jaminan (ringkas)

1. Penyewa pilih tanggal → isi jaminan (jenis, nomor, nama, foto) → kirim booking.
2. Penyedia tandai tiap jaminan Valid/Tolak → konfirmasi booking.
3. Penyewa upload bukti bayar.
4. Penyedia terima dokumen asli → serahkan alat.
5. Alat kembali → penyedia kembalikan dokumen asli → transaksi selesai.

Detail aturan: `../docs/07-JAMINAN-SEWA.md`.
