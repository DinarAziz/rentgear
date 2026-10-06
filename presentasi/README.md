# Presentasi sidang RentGear

Deck sidang dalam bentuk halaman web. Buka `index.html` di Chrome dengan klik dua kali. Tidak perlu internet dan
tidak perlu server, karena font, GSAP, three.js, screenshot, dan video promo sudah ada di folder ini.

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

22 slide dengan urutan sidang: judul, filosofi logo, latar belakang (data usaha sewa alat, kasus nyata di toko sewa,
ringkasan masalah), rumusan masalah, tujuan dan manfaat, inovasi, batasan masalah, metode, perancangan (alur bisnis, peran, alur
status, jenis algoritma yang dipakai, algoritma ketersediaan, susunan aplikasi), implementasi (screenshot dan video), pengujian, kesimpulan dan
rencana lanjutan, sumber data, lalu tanya jawab. Latar gunung ikut naik dari basecamp saat senja sampai puncak saat matahari
terbit.

## Gerak

- Latar gunung adalah adegan 3D yang digambar three.js di `gunung3d.js`: medan berpoligon rendah, pohon, tenda, dan api
  unggun di basecamp. Kamera mendaki dari lapangan kemah ke puncak mengikuti nomor slide, dan cahayanya berubah dari
  senja ke malam lalu fajar. Rute kamera ada di `rute` dan `pandang`, bentuk gunung di fungsi `tinggi`. Kalau browser
  tidak punya WebGL, deck memakai punggungan SVG yang datar.
- Pindah pos (misalnya dari Pos 1 ke Pos 2) memakai sapuan punggungan gelap. Pindah slide di dalam pos yang sama
  hanya bergeser.
- Slide implementasi menampilkan HP dalam ruang 3D: masuk dari kedalaman, maju satu per satu, lalu melayang. Sikap tiap
  HP diatur di `SIKAP_HP`, `SIKAP_WEB`, dan `SIKAP_ADMIN` pada `deck.js`. Menggerakkan mouse menggeser titik pandangnya.
- Gerak 3D lain: huruf judul berdiri dari posisi rebah, kartu ilustrasi latar belakang berganti dengan berputar, kartu
  kasus dan kartu peran terbuka seperti pintu (`pintu` di `deck.js`), papan di slide batasan dan kesimpulan juga, lapisan
  di slide susunan aplikasi jatuh lalu berayun, dan layar video datang dari kedalaman.
- Slide "Mencegah booking dobel" punya tujuh keadaan (langkah 0 sampai 6) dengan nama orang, bukan huruf: Andi dan
  Sinta sudah menyewa, Raka diterima, Dewi ditolak, lalu Yoga dan Bima berebut tenda terakhir. Geraknya diatur di
  `adegan.algoritma` pada `deck.js`; angka di baris "Kosong" ditulis dari larik `kosong` di sana.
- Enam diagram di slide "Jenis algoritma yang dipakai" bergerak terus (`adegan.jenis`). Di slide alur bisnis ada butir
  yang berjalan di panah (`.koin` di `deck.css`), dan di slide susunan aplikasi lapisannya menyala bergiliran turun
  lalu naik (`this.arus` di `adegan.susunan`).
- Konfeti muncul di slide pengujian, kesimpulan, dan tanya jawab (`ledakkan` di `deck.js`). Tiap langkah baru diberi
  percikan kecil (`percik`).
- Latar punya kunang-kunang, burung, dan bintang jatuh. Semua gerak ini mati sendiri kalau sistem memakai setelan
  "kurangi gerakan".

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

- Rumusan masalah, tujuan, dan kesimpulan ditulis untuk fitur yang sudah ada di aplikasi. Payment gateway dan iOS ditulis
  sebagai rencana kerja ("dikerjakan setelah tahap ini"), bukan saran. Server Laravel yang sudah online, saran AI, peta
  di dalam aplikasi, daftar akun, login Google, denda, blacklist, dan halaman toko sudah dibuat. Rencana lengkapnya ada di `../docs/08-RENCANA-KERJA.md`.
- Slide "Jenis algoritma yang dipakai" mengikuti pembagian jenis algoritma dari kuliah (sequential, selection, iteration,
  searching, sorting, machine learning). Hanya jenis yang benar-benar ada di kode yang dimasukkan. Machine learning di
  sini berarti aplikasi memakai model Gemini milik Google, bukan melatih model sendiri.
- Semua sumber latar belakang membahas usaha sewa alat, tidak ada data jumlah pendaki atau kecelakaan. Tiap sumber
  ditulis dengan URL di slide tempat ia dipakai dan di slide "Sumber data". Tautannya bisa diklik.
- Skor risiko Lentera Camp (Ramadhan dkk. 2025, Tabel 5), masalah PT ABC (Nurjanah dkk. 2025), dan artikel detikFinance
  (28 April 2018) dibaca langsung dari PDF dan halaman aslinya pada 2 Oktober 2026. Grafik menampilkan nilai
  kemungkinan (likelihood) untuk 4 dari 18 risiko di tabel itu. Kasus Opak Adventure, Dahlia Adventure, dan EX Adventure
  Solo dibaca dari jurnalnya. Buka lagi tautannya sebelum sidang.
- DOI artikel Opak Adventure (10.48144/suryainformatika.v7i1.379) tidak terdaftar di doi.org, jadi slide memakai
  alamat halaman jurnalnya.
- Belum ada sumber untuk klaim "penyewa tidak tahu tempat sewa". Klaim itu tidak ada di slide.
- Makna logo dan "arah berikutnya" di slide alur bisnis (komisi per transaksi) adalah usulan, belum keputusan.
- Slide judul memuat kode QR ke `https://rentgear.serverbaik.my.id`. Kodenya SVG yang tertanam di `index.html`, jadi
  tetap tampil tanpa internet. Kalau alamatnya berubah, kodenya harus dibuat ulang. Gerak deck mati kalau sistem
  memakai "Reduce motion"; matikan setelan itu di laptop yang dipakai presentasi.
- Slide batasan menyebut 9 toko contoh dan 58 alat di server publik (keadaan 6 Oktober 2026). Lupa password ditulis
  sebagai rencana, karena pengirim email belum dipasang dan kodenya belum sampai ke siapa pun.
- Di slide "Mencegah booking dobel", langkah terakhir (dua orang memesan pada detik yang sama) hanya berlaku di mode
  server: server mengunci baris alat selama booking diproses.
- Angka pengujian (246 tes: 105 aplikasi dan 141 server, hasil uji di Redmi 17 dan browser) berasal dari `../rentgear_app/HANDOFF.md`. Kalau jumlah tes
  berubah, perbarui slide Pengujian dan angka di `adegan.pengujian` pada `deck.js`.
