# Presentasi sidang RentGear

Deck sidang dalam bentuk halaman web. Buka `index.html` di Chrome dengan klik dua kali. Tidak perlu internet dan
tidak perlu server, karena font, GSAP, screenshot, dan video promo sudah ada di folder ini.

## Kontrol

| Tombol | Fungsi |
|---|---|
| Panah kanan, spasi, Enter, Page Down, atau klik | Langkah berikutnya, lalu slide berikutnya |
| Panah kiri, Page Up, Backspace | Mundur |
| Home / End | Slide pertama / terakhir |
| F | Layar penuh |
| Titik pada jalur di kiri | Lompat ke pos itu |

Clicker presentasi mengirim Page Down dan Page Up, jadi bisa langsung dipakai. Alamat `index.html#9` membuka slide 9.

## Isi

15 slide dengan urutan sidang: judul, latar belakang, rumusan masalah, tujuan dan manfaat, batasan masalah, metode,
perancangan (peran, alur status, algoritma ketersediaan, susunan aplikasi), implementasi (screenshot dan video),
pengujian, kesimpulan dan saran, lalu tanya jawab. Latar gunung ikut naik dari basecamp saat senja sampai puncak
saat matahari terbit.

## Mengubah isi

- Nama, NIM, kelas, dan dosen: array `IDENTITAS` di baris awal `deck.js`. Baris yang kosong tidak ditampilkan.
- Teks slide: `index.html`. Satu `<section class="slide">` adalah satu slide. `data-pos` dan `data-label` muncul di
  jalur kiri.
- Elemen dengan `data-step="1"`, `"2"`, dan seterusnya baru muncul saat tombol lanjut ditekan. Elemen dengan
  `data-in` muncul bersama slide.
- Diagram tahap dan alur status digambar dari data di `deck.js` (`bangunTahap`, `bangunAlur`).
- Screenshot ada di `assets/app/`. Semuanya diambil dari build web di `../webapp/` pada lebar 390 piksel.

## Catatan

- Rumusan masalah, tujuan, dan kesimpulan ditulis untuk fitur yang sudah ada di aplikasi. Rekomendasi paket alat
  dan pemeriksaan kondisi berbantuan AI dari `../docs/` masuk ke batasan dan saran.
- Latar belakang belum punya data survei atau kutipan. Isinya ilustrasi masalah.
- Angka pengujian (30 tes, hasil uji di Redmi 17) berasal dari `../rentgear_app/HANDOFF.md`.
