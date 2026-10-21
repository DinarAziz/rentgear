# Video demo dan cara pakai RentGear

Video 1920x1080, sekitar 3 menit, dibuat dengan Remotion. Isinya rekaman layar asli aplikasi, bukan mockup: toko
mengatur diskon, penyewa memesan dengan jaminan, toko memeriksa jaminan, penyewa membayar, serah terima, pengembalian,
ulasan, lalu dashboard admin. Narasi memakai suara Bahasa Indonesia bawaan macOS (Damayanti), dan subtitle ikut tampil.

Hasil render: `out/rentgear-demo.mp4`.

## Membuat ulang

Semua perintah dijalankan dari folder ini.

1. Bangun web build mode lokal (tanpa `API_URL`, data demo di browser) dan sajikan di port 8090:

   ```bash
   (cd ../rentgear_app && flutter build web --release)
   python3 -m http.server 8090 --bind 127.0.0.1 --directory ../rentgear_app/build/web
   ```

2. Rekam layar. Chrome headless menjalankan alur sewa lengkap lewat pohon aksesibilitas Flutter dan menyimpan satu
   screenshot per langkah (resolusi 3x) di `public/shots/`, beserta `manifest.json` yang mencatat titik setiap ketukan.

   ```bash
   node capture/run.mjs
   ```

   Gambar spesimen untuk unggahan (KTP bertanda SPESIMEN dengan data fiktif, bukti transfer) dibuat oleh
   `node capture/specimen/make.mjs`.

3. Buat narasi dari `src/script.json`. Hasilnya di `public/voice/`, dan panjang tiap kalimat di `src/timing.json`.

   ```bash
   node capture/voice.mjs
   ```

4. Pratinjau atau render:

   ```bash
   npm run studio
   npm run render
   ```

## Mengubah isi

- Naskah, judul bagian, langkah di panel kanan, urutan screenshot, dan zoom ada di `src/script.json`. Angka di belakang
  titik dua (`"sewa-ringkasan:2.6"`) adalah bobot lama tampil. `focus` memperbesar layar ke titik tertentu (koordinat
  layar 390x844 untuk HP).
- `speak` dipakai bila pengucapan perlu berbeda dari subtitle, misalnya "Rent Gear" dan "dasbor".
- Setelah mengubah naskah, jalankan lagi `node capture/voice.mjs`. Panjang adegan mengikuti panjang suara.
- Tanggal sewa di rekaman mengikuti hari perekaman (hari ini sampai lusa, 3 hari), supaya diskon 3 hari terlihat.
