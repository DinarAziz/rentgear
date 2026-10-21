# Video demo dan cara pakai RentGear

Video 1920x1080, sekitar 3 menit, dibuat dengan Remotion. Isinya rekaman layar asli aplikasi, bukan mockup: toko
mengatur diskon, penyewa memesan dengan jaminan, toko memeriksa jaminan, penyewa membayar, serah terima, pengembalian,
ulasan, lalu dashboard admin. Narasi memakai suara Matilda dari ElevenLabs (model multilingual v2) yang membaca naskah
Bahasa Indonesia, dan subtitle ikut tampil.

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
   ElevenLabs butuh API key di `elevenlabs.key` (satu baris, diabaikan git), misalnya dengan menyalin key lalu
   menjalankan `pbpaste > elevenlabs.key`. Naskah lengkap sekitar 2.100 karakter; kuota gratis 10.000 per bulan.

   ```bash
   node capture/voice.mjs
   ```

   Akun gratis hanya bisa memakai suara bawaan ElevenLabs lewat API. Suara Indonesia asli dari Voice Library (misalnya
   Arunika) perlu paket berbayar; `node capture/voice.mjs voices` menampilkan daftarnya. Untuk kembali ke suara macOS
   tanpa internet, ubah `voice.engine` di `src/script.json` menjadi `"mac"`.

4. Pratinjau atau render:

   ```bash
   npm run studio
   npm run render
   ```

## Mengubah isi

- Naskah, judul bagian, langkah di panel kanan, urutan screenshot, dan sorotan ada di `src/script.json`. Angka di
  belakang titik dua (`"sewa-ringkasan:2.6"`) adalah bobot lama tampil. `at` pada kalimat menyebut screenshot yang
  tampil saat kalimat itu mulai. `focus.box` menyorot satu area (x, y, lebar, tinggi dalam koordinat layar 390x844
  untuk HP); kotak setiap elemen ada di `nodes` pada `public/shots/manifest.json`.
- `speak` dipakai bila yang diucapkan perlu berbeda dari subtitle, misalnya alamat situs.
- Setelah mengubah naskah, jalankan lagi `node capture/voice.mjs`. Panjang adegan mengikuti panjang suara.
- Tanggal sewa di rekaman mengikuti hari perekaman (hari ini sampai lusa, 3 hari), supaya diskon 3 hari terlihat.
