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

21 slide dengan urutan sidang: judul, filosofi logo, latar belakang (data pendaki, kasus nyata di toko sewa, ringkasan
masalah), rumusan masalah, tujuan dan manfaat, inovasi, batasan masalah, metode, perancangan (alur bisnis, peran, alur
status, algoritma ketersediaan, susunan aplikasi), implementasi (screenshot dan video), pengujian, kesimpulan dan
rencana lanjutan, sumber data, lalu tanya jawab. Latar gunung ikut naik dari basecamp saat senja sampai puncak saat matahari
terbit.

## Mengubah isi

- Nama, NIM, kelas, dan dosen: array `IDENTITAS` di baris awal `deck.js`. Baris yang kosong tidak ditampilkan.
- Teks slide: `index.html`. Satu `<section class="slide">` adalah satu slide. `data-pos` dan `data-label` muncul di
  jalur kiri.
- Elemen dengan `data-step="1"`, `"2"`, dan seterusnya baru muncul saat tombol lanjut ditekan. Elemen dengan
  `data-in` muncul bersama slide. `data-hide-at="3"` menyembunyikan elemen mulai langkah 3, dipakai untuk blok
  penjelasan yang bergantian di slide algoritma dan pengujian.
- Baris "Intinya: ..." di slide data, kasus, algoritma, dan pengujian adalah kalimat pegangan untuk presenter.
- Diagram tahap dan alur status digambar dari data di `deck.js` (`bangunTahap`, `bangunAlur`).
- Screenshot ada di `assets/app/`. Semuanya diambil dari build web di `../webapp/` pada lebar 390 piksel.

## Catatan

- Rumusan masalah, tujuan, dan kesimpulan ditulis untuk fitur yang sudah ada di aplikasi. Server Laravel, fitur AI,
  halaman toko penyedia, login Google, payment gateway, dan iOS ditulis sebagai rencana kerja ("dikerjakan setelah tahap ini"), bukan
  saran. Denda, blacklist, dan halaman toko sudah dibuat. Rencana lengkapnya ada di `../docs/08-RENCANA-KERJA.md`.
- Data latar belakang punya sumber, dan daftarnya ada di slide "Sumber data". Jumlah pendaki Gede Pangrango, kasus
  Opak Adventure, Dahlia Adventure, dan EX Adventure Solo dibaca langsung dari PDF jurnalnya. Angka Rinjani (IDN Times)
  dan Basarnas (Kompas.com) dibaca dari artikel berita; buka lagi tautannya sebelum sidang.
- Belum ada sumber untuk klaim "penyewa tidak tahu tempat sewa". Klaim itu tidak ada di slide.
- Makna logo dan "arah berikutnya" di slide alur bisnis (komisi per transaksi) adalah usulan, belum keputusan.
- Angka pengujian (147 tes: 61 aplikasi dan 86 server, hasil uji di Redmi 17 dan Chrome) berasal dari `../rentgear_app/HANDOFF.md`. Kalau jumlah tes
  berubah, perbarui slide Pengujian dan angka di `adegan.pengujian` pada `deck.js`.
