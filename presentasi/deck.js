/* RentGear, deck sidang.
   Kontrol: panah kanan / spasi / klik = lanjut, panah kiri = mundur,
   Home / End = awal / akhir, F = layar penuh. */

// Isi data diri di sini. Baris yang kosong tidak ditampilkan di slide judul.
const IDENTITAS = [
  ['Nama', 'Dinar Aziz Al Ghifari'],
  ['NIM', ''],
  ['Kelas', ''],
  ['Mata kuliah', 'PTI, Semester 1'],
  ['Dosen', ''],
];

gsap.registerPlugin(SplitText, DrawSVGPlugin);

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const clamp01 = (v) => Math.min(1, Math.max(0, v));
const SVG_NS = 'http://www.w3.org/2000/svg';

const tenang = matchMedia('(prefers-reduced-motion: reduce)').matches;
/** Durasi animasi; hampir nol bila pengguna meminta gerak dikurangi. */
const d = (detik) => (tenang ? 0.01 : detik);
const geser = (px) => (tenang ? 0 : px);

/* ---------- angka acak berbenih, supaya gunung selalu sama ---------- */

function acak(benih) {
  let a = benih >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function derau(benih) {
  const r = acak(benih);
  const kisi = Array.from({ length: 512 }, r);
  const dasar = (x) => {
    const i = Math.floor(x);
    const f = x - i;
    const u = f * f * (3 - 2 * f);
    return kisi[i & 511] * (1 - u) + kisi[(i + 1) & 511] * u;
  };
  return (x) => {
    let jumlah = 0;
    let amp = 0.5;
    let frek = 1;
    for (let o = 0; o < 4; o++) {
      jumlah += amp * dasar(x * frek);
      amp /= 2;
      frek *= 2;
    }
    return jumlah / 0.9375;
  };
}

/* ---------- dunia: punggungan, bintang, kamera ---------- */

const LAPIS = [
  { dasar: 560, amp: 300, frek: 0.0015, warna: '#2c4c4d', turun: 30, pan: 1.5, tajam: true },
  { dasar: 640, amp: 230, frek: 0.0022, warna: '#223f3c', turun: 44, pan: 3, tajam: true },
  { dasar: 720, amp: 170, frek: 0.003, warna: '#18322c', turun: 60, pan: 5 },
  { dasar: 800, amp: 130, frek: 0.004, warna: '#10241d', turun: 80, pan: 8 },
  { dasar: 885, amp: 85, frek: 0.006, warna: '#091611', turun: 106, pan: 11, pohon: true },
];

function bangunPunggungan() {
  const wadah = $('.ridges');
  return LAPIS.map((l, n) => {
    const nilai = derau(101 + n * 37);
    const r = acak(900 + n);
    let jalur = 'M0 1000';
    for (let x = 0; x <= 2400; x += l.pohon ? 16 : 8) {
      let v = nilai(x * l.frek);
      if (l.tajam) v = 1 - Math.abs(2 * v - 1);
      const y = l.dasar - l.amp * v;
      if (l.pohon) {
        const tinggi = 18 + r() * 46;
        jalur += ` L${x - 8} ${y.toFixed(1)} L${x} ${(y - tinggi).toFixed(1)} L${x + 8} ${y.toFixed(1)}`;
      } else {
        jalur += ` L${x} ${y.toFixed(1)}`;
      }
    }
    jalur += ' L2400 1000 Z';
    const el = document.createElement('div');
    el.className = 'ridge';
    el.innerHTML = `<svg viewBox="0 0 2400 1000" preserveAspectRatio="none"><path d="${jalur}" fill="${l.warna}"/></svg>`;
    wadah.append(el);
    return el;
  });
}

/** Rasio piksel layar, dibatasi 2 supaya kanvas tidak terlalu berat. */
function rasioPiksel() {
  return Math.min(2, devicePixelRatio || 1);
}

/** Samakan ukuran kanvas dengan layar. Mengembalikan rasio piksel yang dipakai. */
function ukurKanvas(kanvas) {
  const dpr = rasioPiksel();
  kanvas.width = innerWidth * dpr;
  kanvas.height = innerHeight * dpr;
  return dpr;
}

function gambarBintang() {
  const kanvas = $('.stars');
  const dpr = ukurKanvas(kanvas);
  const c = kanvas.getContext('2d');
  const r = acak(7);
  for (let i = 0; i < 260; i++) {
    const x = r() * kanvas.width;
    const y = r() * r() * kanvas.height * 0.7;
    const ukuran = (0.5 + r() * 1.3) * dpr;
    c.globalAlpha = 0.35 + r() * 0.65;
    c.fillStyle = r() > 0.85 ? '#ffd9a8' : '#eaf3ee';
    c.beginPath();
    c.arc(x, y, ukuran / 2, 0, Math.PI * 2);
    c.fill();
  }
}

/** Bintang berkelip (<i>) dan satu bintang jatuh (<b>), di atas kanvas bintang yang diam. */
function bangunKelip() {
  const r = acak(31);
  const bintang = Array.from({ length: 34 }, () =>
    `<i style="left:${(r() * 100).toFixed(1)}vw;top:${(r() * 46).toFixed(1)}vh;--lama:${(1.6 + r() * 2.6).toFixed(2)}s;--tunda:-${(r() * 4).toFixed(2)}s"></i>`);
  $('.kelip-wrap').innerHTML = bintang.join('') + '<b></b><b></b><b></b>';
}

/** Kawanan burung yang sesekali melintas di langit. */
function bangunBurung() {
  const letak = [[0, 40], [22, 18], [44, 52], [60, 0], [82, 34]];
  $('.burung').innerHTML = letak.map(([x, y], n) =>
    `<svg viewBox="0 0 40 20" style="left:${x}%;top:${y}%"><path style="animation-delay:-${n * 0.11}s" d="M2 10 L20 16 L38 10"/></svg>`).join('');
}

/** Kunang-kunang: titik cahaya yang melayang naik di depan punggungan. */
function nyalakanKunang() {
  if (tenang) return;
  const kanvas = $('.kunang');
  const c = kanvas.getContext('2d');
  const r = acak(77);
  const dpr = rasioPiksel();
  const titik = Array.from({ length: 34 }, () => ({
    x: r(), y: r(), laju: 0.012 + r() * 0.03, fase: r() * 6.28, goyang: 0.5 + r() * 1.5, jari: (0.7 + r() * 1.3) * dpr, hangat: r() > 0.45,
  }));
  let lalu = performance.now();
  const gambar = (kini) => {
    const dt = Math.min(0.05, (kini - lalu) / 1000);
    lalu = kini;
    const { width, height } = kanvas;
    c.clearRect(0, 0, width, height);
    for (const t of titik) {
      t.y -= t.laju * dt;
      t.fase += t.goyang * dt;
      if (t.y < -0.05) t.y = 1.05;
      const x = (t.x + Math.sin(t.fase) * 0.012) * width;
      const y = (0.4 + t.y * 0.6) * height;
      const terang = 0.3 + 0.7 * Math.abs(Math.sin(t.fase * 1.7));
      c.fillStyle = t.hangat ? '#ffb876' : '#bfe8cf';
      c.globalAlpha = terang * 0.12;
      c.beginPath();
      c.arc(x, y, t.jari * 3, 0, Math.PI * 2);
      c.fill();
      c.globalAlpha = terang * 0.9;
      c.beginPath();
      c.arc(x, y, t.jari, 0, Math.PI * 2);
      c.fill();
    }
    requestAnimationFrame(gambar);
  };
  requestAnimationFrame(gambar);
}

/* ---------- pesta: konfeti dan percikan ---------- */

const WARNA_PESTA = ['#f08a3c', '#ffb876', '#8fc3a2', '#f3eddf', '#2e6b4f', '#6fb0c4'];
const pesta = { kanvas: $('.pesta'), keping: [], jalan: false, lalu: 0 };

/** Ledakkan konfeti dari tengah elemen `asal`, atau dari titik {x, y} dalam pecahan layar. */
function ledakkan(asal, jumlah = 90) {
  if (tenang) return;
  const { kanvas, keping } = pesta;
  const kotak = asal.getBoundingClientRect?.();
  const pusat = kotak
    ? { x: (kotak.left + kotak.width / 2) / innerWidth, y: (kotak.top + kotak.height / 2) / innerHeight }
    : asal;
  const x = pusat.x * kanvas.width;
  const y = pusat.y * kanvas.height;
  const satuan = kanvas.height / 900;
  for (let n = 0; n < jumlah; n++) {
    const sudut = -Math.PI / 2 + (Math.random() - 0.5) * 2.6;
    const dorong = (420 + Math.random() * 760) * satuan;
    keping.push({
      x, y,
      vx: Math.cos(sudut) * dorong,
      vy: Math.sin(sudut) * dorong,
      putar: Math.random() * 6.28,
      lajuPutar: (Math.random() - 0.5) * 14,
      lebar: (7 + Math.random() * 9) * satuan,
      tinggi: (10 + Math.random() * 12) * satuan,
      warna: WARNA_PESTA[n % WARNA_PESTA.length],
      umur: 0,
      lama: 1.8 + Math.random() * 1.4,
    });
  }
  if (pesta.jalan) return;
  pesta.jalan = true;
  pesta.lalu = performance.now();
  requestAnimationFrame(gambarPesta);
}

function gambarPesta(kini) {
  const { kanvas } = pesta;
  const c = kanvas.getContext('2d');
  const dt = Math.min(0.05, (kini - pesta.lalu) / 1000);
  const gravitasi = 1500 * (kanvas.height / 900);
  pesta.lalu = kini;
  pesta.keping = pesta.keping.filter((k) => k.umur < k.lama);
  c.clearRect(0, 0, kanvas.width, kanvas.height);
  for (const k of pesta.keping) {
    k.umur += dt;
    k.vy += gravitasi * dt;
    k.vx *= 1 - 1.4 * dt;
    k.x += k.vx * dt;
    k.y += k.vy * dt;
    k.putar += k.lajuPutar * dt;
    c.save();
    c.translate(k.x, k.y);
    c.rotate(k.putar);
    c.globalAlpha = clamp01((k.lama - k.umur) / 0.5);
    c.fillStyle = k.warna;
    // Lebar ikut berayun supaya keping terlihat berputar di udara.
    const lebar = k.lebar * Math.cos(k.putar * 1.3);
    c.fillRect(-lebar / 2, -k.tinggi / 2, lebar, k.tinggi);
    c.restore();
  }
  pesta.jalan = pesta.keping.length > 0;
  if (pesta.jalan) requestAnimationFrame(gambarPesta);
}

/** Percikan kecil yang menyebar dari sudut kiri atas `el`. */
function percik(el, jumlah = 9) {
  if (tenang) return;
  const kotak = el.getBoundingClientRect();
  const x = kotak.left;
  const y = kotak.top + Math.min(kotak.height / 2, 30);
  for (let n = 0; n < jumlah; n++) {
    const titik = document.createElement('i');
    titik.className = 'percik';
    document.body.append(titik);
    const sudut = Math.random() * Math.PI * 2;
    const jarak = 40 + Math.random() * 80;
    gsap.fromTo(titik,
      { x, y, scale: 0.5 + Math.random() * 0.9, autoAlpha: 1 },
      { x: x + Math.cos(sudut) * jarak, y: y + Math.sin(sudut) * jarak, scale: 0.2, autoAlpha: 0, duration: 0.55 + Math.random() * 0.4, ease: 'power3.out', onComplete: () => titik.remove() });
  }
}

const dunia = {
  lapis: bangunPunggungan(),
  // Gunung three.js; null bila WebGL tidak tersedia, lalu punggungan SVG yang tampil.
  gunung: bangunGunung3d($('.gunung3d'), { acak, tenang }),
  senja: $('.sky-dusk'),
  fajar: $('.sky-dawn'),
  bintang: $('.stars'),
  kelip: $('.kelip-wrap'),
  matahari: $('.sun'),
  hangat: $('.warm'),
  kabut: $$('.fog'),
  puncak: $('.puncak-fg'),
  tirai: $('.veil'),
};
$('.world').classList.toggle('tiga-d', Boolean(dunia.gunung));
const kamera = { p: 0 };
// Posisi penunjuk dari tengah layar (-0.5 sampai 0.5), dipakai untuk paralaks.
const tilik = { x: 0, y: 0 };

/** Susun dunia untuk ketinggian p: 0 = basecamp saat senja, 1 = puncak saat fajar. */
function gambarDunia() {
  const p = kamera.p;
  const vh = innerHeight / 100;
  const vw = innerWidth / 100;
  const fajar = clamp01((p - 0.62) / 0.38);
  dunia.lapis.forEach((el, n) => {
    const { pan, turun } = LAPIS[n];
    el.style.transform = `translate3d(${-pan * (p + tilik.x * 0.3) * vw}px, ${turun * p * vh}px, 0)`;
  });
  dunia.gunung?.atur(p, fajar, tilik);
  dunia.senja.style.opacity = clamp01(1 - p / 0.5);
  dunia.fajar.style.opacity = fajar;
  const terangBintang = (0.5 + 0.5 * clamp01(p / 0.4)) * (1 - 0.88 * fajar);
  dunia.bintang.style.opacity = terangBintang;
  dunia.kelip.style.opacity = terangBintang;
  dunia.matahari.style.opacity = fajar;
  dunia.matahari.style.transform = `translate3d(0, ${(74 - 38 * fajar) * vh}px, 0)`;
  dunia.hangat.style.opacity = fajar * 0.9;
  dunia.kabut.forEach((k) => (k.style.opacity = 0.45 + 0.55 * p));
  dunia.puncak.style.transform = `translate3d(0, ${(1 - clamp01((p - 0.86) / 0.14)) * 100}%, 0)`;
}

/* ---------- diagram yang digambar dari data ---------- */

function buat(tag, atribut = {}, induk) {
  const el = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(atribut)) el.setAttribute(k, v);
  induk?.append(el);
  return el;
}

/** Jalur melengkung halus yang melewati semua titik. */
function lengkung(titik) {
  let hasil = `M${titik[0][0]} ${titik[0][1]}`;
  for (let i = 1; i < titik.length; i++) {
    const [x0, y0] = titik[i - 1];
    const [x1, y1] = titik[i];
    const tengah = (x0 + x1) / 2;
    hasil += ` C${tengah} ${y0} ${tengah} ${y1} ${x1} ${y1}`;
  }
  return hasil;
}

function bangunKontur() {
  const svg = $('.kontur');
  const nilai = derau(55);
  for (let cincin = 0; cincin < 10; cincin++) {
    const jari = 70 + cincin * 56;
    let jalur = '';
    for (let s = 0; s <= 120; s++) {
      const sudut = (s / 120) * Math.PI * 2;
      // Derau diambil pada lingkaran supaya ujung dan pangkal garis bertemu.
      const goyang = nilai(40 + Math.cos(sudut) * 1.6 + cincin * 0.22) + nilai(90 + Math.sin(sudut) * 1.6);
      const r = jari * (0.72 + 0.38 * goyang);
      jalur += `${s ? 'L' : 'M'}${(650 + Math.cos(sudut) * r * 1.25).toFixed(1)} ${(450 + Math.sin(sudut) * r * 0.8).toFixed(1)}`;
    }
    buat('path', { d: jalur + 'Z' }, svg);
  }
}

function bangunTahap() {
  const wadah = $('#tahap');
  const tahap = [
    ['Analisis', 'Masalah penyewa dan penyedia, peran pengguna, daftar fitur.'],
    ['Perancangan', 'Algoritma, alur status, use case, rancangan database dan API.'],
    ['Implementasi', 'Aplikasi Flutter untuk Android dan web, server Laravel.'],
    ['Pengujian', 'Tes otomatis dan uji langsung di HP.'],
  ];
  const titik = [[120, 420], [520, 320], [910, 210], [1300, 100]];
  const jalur = lengkung(titik);
  const svg = buat('svg', {}, wadah);
  buat('path', { class: 'dasar', d: jalur }, svg);
  buat('path', { class: 'jejak', d: jalur }, svg);
  titik.forEach(([x, y], n) => {
    buat('circle', { class: 'titik', cx: x, cy: y, r: 12 }, svg);
    const el = document.createElement('article');
    el.style.left = `${x - 40}px`;
    el.style.top = `${y + 36}px`;
    el.innerHTML = `<h3>${tahap[n][0]}</h3><p>${tahap[n][1]}</p>`;
    wadah.append(el);
  });
}

function bangunAlur() {
  const wadah = $('#alur-diagram');
  const status = [
    ['Menunggu konfirmasi', 'penyewa mengirim booking'],
    ['Menunggu pembayaran', 'penyedia mengonfirmasi'],
    ['Siap diambil', 'penyewa mengunggah bukti transfer'],
    ['Sedang disewa', 'serah terima alat'],
    ['Sudah dikembalikan', 'penyedia menerima alat'],
    ['Selesai', 'jaminan dikembalikan'],
  ];
  const titik = [[110, 480], [374, 410], [638, 370], [902, 290], [1166, 240], [1430, 150]];
  const TINGGI = 760;
  // Syarat jaminan menempel di tengah perpindahan dari status ke-n ke status berikutnya.
  const syarat = [
    [0, 'Semua jaminan sudah dinyatakan valid'],
    [2, 'Dokumen asli dipegang penyedia'],
    [4, 'Dokumen asli kembali ke penyewa'],
  ].map(([n, teks]) => ({
    x: (titik[n][0] + titik[n + 1][0]) / 2,
    y: (titik[n][1] + titik[n + 1][1]) / 2,
    teks,
  }));

  const svg = buat('svg', {}, wadah);
  buat('path', { class: 'cabang', 'data-step': 2, d: 'M110 480 L110 680' }, svg);
  buat('path', { class: 'cabang', 'data-step': 2, d: 'M374 410 C420 510 480 570 480 680' }, svg);
  syarat.forEach(({ x, y }) => {
    buat('path', { class: 'cabang', 'data-step': 1, d: `M${x} ${y + 8} L${x} ${y + 76}` }, svg);
  });
  buat('path', { class: 'jejak', d: lengkung(titik) }, svg);
  titik.forEach(([x, y]) => buat('circle', { class: 'titik', cx: x, cy: y, r: 12 }, svg));

  const html = [
    ...titik.map(([x, y], n) => `<div class="st" style="left:${x - 115}px;bottom:${TINGGI - y + 30}px"><b>${status[n][0]}</b><span>${status[n][1]}</span></div>`),
    ...syarat.map(({ x, y, teks }) => `<div class="syarat" data-step="1" style="left:${x - 120}px;top:${y + 78}px">${teks}</div>`),
    '<div class="gagal" data-step="2" style="left:62px;top:690px">Ditolak</div>',
    '<div class="gagal" data-step="2" style="left:404px;top:690px">Dibatalkan</div>',
    '<i class="jalan"></i>',
  ];
  wadah.insertAdjacentHTML('beforeend', html.join(''));
}

/* ---------- adegan: animasi khusus tiap slide ---------- */

/** Tween angka dari `dari` ke `ke` yang ditulis ke `el`, dibulatkan dengan pemisah ribuan. */
function hitung(el, dari, ke, durasi, ease) {
  const nilai = { n: dari };
  return gsap.to(nilai, { n: ke, duration: d(durasi), ease, onUpdate: () => (el.textContent = Math.round(nilai.n).toLocaleString('id-ID')) });
}

/** Gambar `jalur` sambil menjalankan penanda `jalan` di ujung garisnya.
    `petakan` mengubah titik pada jalur menjadi posisi penanda. */
function telusuri(tl, jalur, jalan, durasi, kapan, petakan = (titik) => titik) {
  const panjang = jalur.getTotalLength();
  const maju = { t: 0 };
  const letak = () => {
    const { x, y } = petakan(jalur.getPointAtLength(panjang * maju.t));
    jalan.style.transform = `translate(${x}px, ${y}px)`;
  };
  letak();
  tl.from(jalur, { drawSVG: 0, duration: d(durasi), ease: 'power1.inOut' }, kapan)
    .to(maju, { t: 1, duration: d(durasi), ease: 'power1.inOut', onUpdate: letak }, kapan);
}

const BAGIAN_LOGO = ['.l-puncak', '.l-dasar', '.l-matahari'];

/** Huruf judul besar melompat bergiliran, berulang selama slide tampil. */
function ombak(huruf) {
  return gsap.timeline({ repeat: -1, repeatDelay: 3.5, delay: 2.4 })
    .to(huruf, { y: -24, color: '#ffb876', duration: 0.28, ease: 'power2.out', stagger: 0.07 })
    .to(huruf, { y: 0, color: '#f3eddf', duration: 0.6, ease: 'bounce.out', stagger: 0.07 }, 0.28);
}

/** Angka besar jatuh ke tempatnya sambil berputar. */
const JATUH = { autoAlpha: 0, scale: 2.4, rotation: -24, ease: 'back.out(2)' };

// Sikap tiap HP di kipas 3D: yang di tengah paling depan, yang di tepi menghadap ke tengah.
const SIKAP_HP = [
  { rotationY: 30, z: -90 },
  { rotationY: 15, z: -20 },
  { rotationY: 0, z: 80 },
  { rotationY: -15, z: -20 },
  { rotationY: -30, z: -90 },
];
const SIKAP_WEB = { rotationY: 11, rotationX: 2, z: 0 };
const SIKAP_ADMIN = { rotationY: -20, rotationX: 0, z: 30 };
// Semua perangkat di galeri, yang melayang naik turun selama slide tampil.
const PERANGKAT = '.galeri .hp, .galeri .browser';

/** Nilai awal dan akhir untuk memutar kartu masuk seperti daun pintu, dengan engsel di sisi `engsel`. */
const pintu = (sudut, engsel) => [
  { rotationY: sudut },
  { rotationY: 0, transformPerspective: 1200, transformOrigin: `${engsel} center`, duration: 0.95, ease: 'back.out(1.3)' },
];

/** Adegan untuk slide dengan dua papan: papan kiri terbuka saat masuk, papan kanan pada langkah 1. */
function adeganPintu(id, lanjutan) {
  return {
    masuk(tl) {
      if (!tenang) tl.fromTo(`#${id} .papan:not(.putus)`, ...pintu(-75, 'left'), 0.3);
      lanjutan?.(tl);
    },
    atur(langkah, seketika, sebelum) {
      if (seketika || tenang || langkah !== 1 || sebelum >= 1) return;
      gsap.fromTo(`#${id} .papan.putus`, ...pintu(75, 'right'));
    },
  };
}

/** Tiap adegan boleh punya: masuk(tl) saat slide tampil, atur(langkah, seketika, sebelum)
    untuk menyetel keadaan sebuah langkah (maju maupun mundur), dan keluar(). */
const adegan = {
  judul: {
    masuk(tl) {
      tl.from('.kontur path', { drawSVG: 0, duration: d(2.6), ease: 'power2.out', stagger: 0.09 }, 0);
      if (tenang) return;
      this.ombak = ombak(judulSlide[kini]);
      // Garis kontur terus berdenyut pelan dari tengah ke luar.
      this.denyut = gsap.to('.kontur path', { opacity: 0.75, duration: 1.4, ease: 'sine.inOut', stagger: { each: 0.16, repeat: -1, yoyo: true }, delay: 2.8 });
    },
    keluar() {
      this.ombak?.kill();
      this.denyut?.kill();
      gsap.set('.kontur path', { clearProps: 'opacity' });
    },
  },

  terima: {
    masuk(tl) {
      if (tenang) return;
      this.ombak = ombak(judulSlide[kini]);
      tl.call(() => { ledakkan({ x: 0.3, y: 0.5 }, 130); ledakkan({ x: 0.72, y: 0.45 }, 130); }, null, 0.9)
        .call(() => ledakkan({ x: 0.5, y: 0.35 }, 160), null, 1.7);
    },
    keluar() {
      this.ombak?.kill();
    },
  },

  rumusan: {
    masuk(tl) {
      tl.from('#rumusan li[data-in] .angka', { ...JATUH, duration: d(0.7) }, 0.55);
    },
    atur(langkah, seketika, sebelum) {
      if (seketika || tenang || langkah <= sebelum) return;
      gsap.from(`#rumusan li[data-step="${langkah}"] .angka`, { ...JATUH, duration: 0.7 });
    },
  },

  bisnis: {
    masuk(tl) {
      tl.from('.pihak > div', { autoAlpha: 0, y: geser(70), rotationY: (n) => geser([-50, 0, 50][n]), transformPerspective: 1100, duration: d(0.9), ease: 'back.out(1.4)', stagger: 0.16 }, 0.4);
    },
  },

  batasan: adeganPintu('batasan'),

  // Bendera di puncak baru saja muncul di kanan bawah layar.
  kesimpulan: adeganPintu('kesimpulan', (tl) => tl.call(() => ledakkan({ x: 0.89, y: 0.6 }, 70), null, 1.5)),

  aktor: {
    masuk(tl) {
      if (!tenang) tl.fromTo('.aktor > div[data-in]', ...pintu(-80, 'left'), 0.3);
    },
    atur(langkah, seketika, sebelum) {
      if (seketika || tenang || langkah <= sebelum) return;
      gsap.fromTo(`.aktor > div[data-step="${langkah}"]`, ...pintu(80, 'right'));
    },
  },

  logo: {
    masuk(tl) {
      tl.fromTo('.logo-kartu', { autoAlpha: 0, scale: 0.9, rotationY: geser(-70) }, { autoAlpha: 1, scale: 1, rotationY: 0, duration: d(1.1), ease: 'back.out(1.5)' }, 0.2)
        .from('.l-puncak path', { autoAlpha: 0, y: geser(70), duration: d(0.8), ease: 'power3.out', stagger: 0.12 }, 0.5)
        .from('.l-dasar', { scaleX: 0, transformOrigin: 'left center', duration: d(0.7), ease: 'power3.out' }, 0.7)
        .from('.l-matahari', { autoAlpha: 0, y: geser(120), duration: d(1), ease: 'back.out(1.6)' }, 1);
      if (tenang) return;
      this.ayun = gsap.fromTo('.logo-kartu', { rotationY: -9, rotationX: 3 }, { rotationY: 9, rotationX: -3, duration: 3.4, ease: 'sine.inOut', yoyo: true, repeat: -1, delay: 1.5, immediateRender: false });
    },
    keluar() {
      this.ayun?.kill();
    },
    // Langkah 0 sampai 2 menyorot satu bagian logo, langkah terakhir menyalakan semuanya.
    atur(langkah, seketika) {
      BAGIAN_LOGO.forEach((bagian, n) => {
        const sorot = langkah === n || langkah === BAGIAN_LOGO.length;
        gsap.to(bagian, { opacity: sorot ? 1 : 0.28, duration: d(seketika ? 0 : 0.45), ease: 'power2.out' });
      });
    },
  },

  data: {
    masuk(tl) {
      tl.from('.batang-tegak i', { scaleY: 0, duration: d(1.2), ease: 'back.out(1.5)', stagger: 0.16 }, 0.6)
        .from('.batang-tegak b', { ...JATUH, duration: d(0.6), stagger: 0.16 }, 1.2);
    },
    atur(langkah, seketika, sebelum) {
      if (seketika || tenang || langkah <= sebelum) return;
      if (langkah === 1) hitung($('#n-omzet'), 5, 8, 1.1, 'power2.out');
    },
  },

  latar: {
    masuk(tl) {
      tl.from('.chat > *', { autoAlpha: 0, y: geser(18), duration: d(0.5), ease: 'power3.out', stagger: 0.38 }, 0.7);
    },
    atur(langkah, seketika, sebelum) {
      $$('[data-ilus]').forEach((el) => {
        const urut = +el.dataset.ilus;
        const tampil = urut === langkah;
        // Kartu berganti dengan berputar: yang lama berpaling ke kiri, yang baru datang dari kanan.
        gsap.to(el, { autoAlpha: tampil ? 1 : 0, scale: tampil ? 1 : 0.97, rotationY: tampil ? 0 : geser(urut < langkah ? -90 : 90), transformPerspective: 1200, duration: d(seketika ? 0 : 0.65), ease: 'power3.out', overwrite: true });
      });
      if (langkah === 1 && !seketika && sebelum < 1) {
        gsap.from('.buku .cap', { autoAlpha: 0, scale: 1.5, duration: d(0.5), delay: d(0.6), ease: 'back.out(2)' });
      }
    },
  },

  metode: {
    masuk(tl) {
      tl.from('#tahap .jejak', { drawSVG: 0, duration: d(1.8), ease: 'power2.inOut' }, 0.4)
        .from('#tahap .titik', { autoAlpha: 0, scale: 0.9, transformOrigin: 'center', duration: d(0.4), stagger: 0.42 }, 0.5)
        .from('#tahap article', { autoAlpha: 0, y: geser(22), duration: d(0.7), ease: 'power3.out', stagger: 0.42 }, 0.55);
    },
  },

  alur: {
    masuk(tl) {
      telusuri(tl, $('#alur-diagram .jejak'), $('#alur-diagram .jalan'), 2.4, 0.4);
      tl.from('#alur-diagram .titik', { autoAlpha: 0, duration: d(0.3), stagger: 0.44 }, 0.4)
        .from('#alur-diagram .st', { autoAlpha: 0, y: geser(16), duration: d(0.6), ease: 'power3.out', stagger: 0.44 }, 0.45);
    },
  },

  algoritma: {
    atur(langkah, seketika, sebelum) {
      const maju = !seketika && !tenang && langkah > sebelum;
      const sapu = $('.sapu');
      const hantu = $('.hantu');
      const sel = $$('.slot-kisi .pakai');
      const baru = $$('.slot-kisi .tk.baru');
      // Setelah permintaan baru diterima (langkah 4), tiap hari bertambah satu unit terpakai.
      const terpakai = langkah >= 4 ? [2, 2, 1, 2, 2] : [1, 1, 0, 1, 1];
      const puncak = Math.max(...terpakai);

      gsap.killTweensOf([sapu, hantu, ...sel, ...baru]);
      sel.forEach((el, n) => {
        el.textContent = terpakai[n];
        el.classList.toggle('puncak', langkah >= 3 && terpakai[n] === puncak);
      });
      gsap.set(sapu, { autoAlpha: 0, x: 0 });
      gsap.set(sel, { autoAlpha: langkah >= 3 ? 1 : 0, scale: 1 });
      gsap.set(baru, { autoAlpha: langkah >= 4 ? 1 : 0, y: 0 });
      gsap.set(hantu, { autoAlpha: langkah >= 5 ? 1 : 0, x: 0 });
      if (!maju) return;

      if (langkah === 2) {
        gsap.fromTo('.tk.a, .tk.b', { scale: 1 }, { scale: 1.14, duration: 0.2, yoyo: true, repeat: 3, stagger: 0.05, ease: 'power2.out' });
      } else if (langkah === 3) {
        // Garis sapu berjalan melewati lima kolom hari (150px per kolom).
        gsap.set(sel, { autoAlpha: 0 });
        gsap.timeline()
          .set(sapu, { autoAlpha: 1 })
          .to(sapu, { x: 750, duration: 2.6, ease: 'none' })
          .to(sel, { autoAlpha: 1, duration: 0.25, stagger: 0.52 }, 0.26)
          .to(sapu, { autoAlpha: 0, duration: 0.3 });
      } else if (langkah === 4) {
        gsap.from(baru, { autoAlpha: 0, y: -70, duration: 0.55, ease: 'back.out(1.6)', stagger: 0.12 });
        gsap.from(sel, { scale: 1.6, duration: 0.45, ease: 'power3.out', stagger: 0.12 });
      } else if (langkah === 5) {
        gsap.fromTo(hantu, { x: -10 }, { x: 10, duration: 0.07, ease: 'none', yoyo: true, repeat: 7, onComplete: () => gsap.set(hantu, { x: 0 }) });
      }
    },
  },

  video: {
    masuk(tl) {
      const video = $('#promo');
      video.currentTime = 0;
      tl.call(() => video.play().catch(() => {}), null, 1.2);
      // Layar video datang dari kedalaman sambil berputar ke arah penonton.
      if (!tenang) tl.fromTo('.layar-video', { rotationY: -40, z: -600 }, { rotationY: 0, z: 0, duration: 1.2, ease: 'back.out(1.2)' }, 0.3);
    },
    keluar() {
      $('#promo').pause();
    },
  },

  pengujian: {
    masuk(tl) {
      tl.add(hitung($('#skor'), 0, 245, 1.6, 'power1.out'), 0.6)
        .from('.titik-uji i', { autoAlpha: 0, scale: 0.4, duration: d(0.35), ease: 'back.out(2)', stagger: 0.012 }, 0.6)
        .call(() => ledakkan($('#skor'), 110), null, 2.2)
        .fromTo('#skor', { scale: 1 }, { scale: 1.14, duration: d(0.22), ease: 'power2.out', yoyo: true, repeat: 1, transformOrigin: 'left bottom' }, 2.2);
    },
  },

  susunan: {
    masuk(tl) {
      // Lapisan jatuh dari depan layar mulai dari dasar, lalu tumpukannya berayun supaya kedalamannya terlihat.
      const lapis = $$('.strata li');
      const atas = lapis.length - 1;
      this.keluar();
      lapis.forEach((el, n) => {
        // Tingkat lapisan dihitung dari dasar tumpukan (0 = paling bawah).
        const tingkat = atas - n;
        tl.fromTo(el,
          { autoAlpha: 0, y: geser(-140), z: geser(520), rotationX: geser(-70) },
          { autoAlpha: 1, y: 0, z: geser(tingkat * 26), rotationX: 0, duration: d(0.8), ease: 'back.out(1.3)' }, 0.35 + tingkat * 0.14);
      });
      if (tenang) return;
      this.ayun = gsap.fromTo('.strata', { rotationY: -9, rotationX: 5 }, { rotationY: 9, rotationX: -2, duration: 3.6, ease: 'sine.inOut', yoyo: true, repeat: -1, delay: 1.7, immediateRender: false });
    },
    keluar() {
      this.ayun?.kill();
      gsap.set('.strata', { rotationY: 0, rotationX: 0 });
    },
  },

  implementasi: {
    // HP terbang dari kedalaman ke kipas 3D, lalu maju satu per satu, lalu melayang.
    masuk(tl) {
      const badan = $$('.hp-baris .rangka');
      const nama = $$('.hp-baris figcaption');
      this.keluar();
      if (tenang) return;
      badan.forEach((el, n) => {
        tl.fromTo(el,
          { autoAlpha: 0, z: -1400, rotationY: SIKAP_HP[n].rotationY + 110, y: 160 },
          { autoAlpha: 1, y: 0, ...SIKAP_HP[n], duration: 1.25, ease: 'back.out(1.25)' }, 0.35 + Math.abs(n - 2) * 0.16);
        const sorot = 2.1 + n * 0.6;
        tl.to(el, { rotationY: 0, z: 150, duration: 0.42, ease: 'power3.out' }, sorot)
          .to(nama[n], { color: '#ffb876', scale: 1.12, duration: 0.3, ease: 'power3.out' }, sorot)
          .to(el, { ...SIKAP_HP[n], duration: 0.5, ease: 'power2.inOut' }, sorot + 0.6)
          .to(nama[n], { color: '#f3eddf', scale: 1, duration: 0.4, ease: 'power2.out' }, sorot + 0.6);
      });
      tl.from(nama, { autoAlpha: 0, y: 20, duration: 0.5, ease: 'power3.out', stagger: 0.08 }, 1.1);
      this.apung = gsap.to(PERANGKAT, { y: -16, duration: 2.3, ease: 'sine.inOut', yoyo: true, repeat: -1, stagger: { each: 0.35, from: 'center' } });
    },
    atur(langkah, seketika, sebelum) {
      const layar = $('.web .browser .rangka');
      const admin = $('.web .hp .rangka');
      const badan = $$('.hp-baris .rangka');
      gsap.killTweensOf([layar, admin]);
      gsap.set(layar, { autoAlpha: 1, x: 0, ...SIKAP_WEB });
      gsap.set(admin, { autoAlpha: 1, x: 0, ...SIKAP_ADMIN });
      if (tenang) {
        gsap.set([layar, admin, ...badan], { rotationY: 0, rotationX: 0, z: 0 });
        return;
      }
      badan.forEach((el, n) => gsap.set(el, { autoAlpha: 1, y: 0, ...SIKAP_HP[n] }));
      if (seketika || langkah !== 1 || sebelum >= 1) return;
      gsap.from(layar, { autoAlpha: 0, x: -260, z: -700, rotationY: 62, duration: 1.1, ease: 'back.out(1.2)' });
      gsap.from(admin, { autoAlpha: 0, x: 320, z: -500, rotationY: -100, duration: 1.2, delay: 0.25, ease: 'back.out(1.5)' });
    },
    keluar() {
      this.apung?.kill();
      gsap.set(PERANGKAT, { y: 0 });
    },
  },

  kasus: {
    masuk(tl) {
      const kotak = $('.perjalanan');
      const jalur = $('.perjalanan .jejak');
      // Jalurnya direntangkan (preserveAspectRatio none), jadi titik dipetakan lewat matriks layar.
      const keKotak = (titik) => {
        const layar = titik.matrixTransform(jalur.getScreenCTM());
        const batas = kotak.getBoundingClientRect();
        const skalaPanggung = batas.width / kotak.offsetWidth;
        return { x: (layar.x - batas.left) / skalaPanggung, y: (layar.y - batas.top) / skalaPanggung };
      };
      telusuri(tl, jalur, $('.perjalanan .jalan'), 2, 0.7, keKotak);
      tl.from('.perjalanan .cap', { autoAlpha: 0, scale: 1.6, duration: d(0.45), ease: 'back.out(2)' }, 2.75);
    },
    atur(langkah, seketika, sebelum) {
      if (seketika || tenang || langkah <= sebelum) return;
      gsap.fromTo(`.kasus li[data-step="${langkah}"]`, ...pintu(-85, 'left'));
    },
  },
};

/* ---------- mesin slide ---------- */

const slides = $$('.slide');
let jumlahLangkah = [];
let judulSlide = [];
let aksenSlide = [];
let kini = -1;
let langkah = 0;
let masuk = null;

// Slide yang berbagi pos (mis. empat slide Perancangan) dikelompokkan jadi satu titik di jalur.
const pos = [];
slides.forEach((s, i) => {
  const akhir = pos[pos.length - 1];
  if (akhir && akhir.nama === s.dataset.pos) akhir.isi.push(i);
  else pos.push({ nama: s.dataset.pos, isi: [i] });
});
const Y_BAWAH = 930;
const Y_ATAS = 150;
const yPos = (n) => Y_BAWAH - ((Y_BAWAH - Y_ATAS) * n) / (pos.length - 1);

function ySlide(i) {
  const n = pos.findIndex((g) => g.isi.includes(i));
  const urut = pos[n].isi.indexOf(i) / pos[n].isi.length;
  return yPos(Math.min(pos.length - 1, n + urut));
}

function bangunRel() {
  const rel = $('.rail');
  const svg = buat('svg', { width: 250, height: 1080 }, rel);
  buat('path', { class: 'jalur', d: `M78 ${Y_BAWAH} L78 ${Y_ATAS}` }, svg);
  buat('path', { class: 'tempuh', d: `M78 ${Y_BAWAH} L78 ${Y_BAWAH}` }, svg);
  pos.forEach((g, n) => {
    const tombol = document.createElement('button');
    tombol.type = 'button';
    tombol.style.top = `${yPos(n)}px`;
    tombol.setAttribute('aria-label', `${g.nama}: ${slides[g.isi[0]].dataset.label}`);
    tombol.addEventListener('click', () => tampil(g.isi[0]));
    rel.append(tombol);
  });
  rel.insertAdjacentHTML('beforeend', '<div class="pendaki"><i></i><b></b><span></span></div>');
}

function perbaruiRel(i, seketika) {
  const y = ySlide(i);
  const s = slides[i];
  const pendaki = $('.pendaki');
  const durasi = d(seketika ? 0 : 1.1);
  gsap.to(pendaki, { y, duration: durasi, ease: 'power3.inOut' });
  gsap.to('.rail .tempuh', { attr: { d: `M78 ${Y_BAWAH} L78 ${y}` }, duration: durasi, ease: 'power3.inOut' });
  $('b', pendaki).textContent = s.dataset.pos;
  $('span', pendaki).textContent = s.dataset.label;
  $$('.rail button').forEach((tombol, n) => tombol.classList.toggle('lewat', pos[n].isi[0] <= i));
  $('.hitung').textContent = `${i + 1} / ${slides.length}`;
}

/** Elemen tampak bila langkahnya sudah tercapai dan batas `data-hide-at` belum terlewati. */
function tampakPada(el, ke) {
  const { step, hideAt } = el.dataset;
  return (!step || +step <= ke) && !(hideAt && ke >= +hideAt);
}

const garisIkon = (akar) => $$('svg.ikon:not(.pudar) *', akar);

/** Setel elemen berlangkah pada slide aktif ke keadaan `ke`. */
function aturLangkah(ke, seketika, sebelum) {
  const s = slides[kini];
  const durasi = d(seketika ? 0 : 0.6);
  const maju = !seketika && !tenang && ke > sebelum;
  let percikan = 0;
  $$('[data-step], [data-hide-at]', s).forEach((el) => {
    const tampak = tampakPada(el, ke);
    const baru = maju && +el.dataset.step === ke;
    // Skala hanya untuk elemen HTML; pada jalur SVG skala akan menggeser gambarnya.
    const kotak = el instanceof HTMLElement;
    const sasaran = { autoAlpha: tampak ? 1 : 0, y: tampak ? 0 : geser(30), duration: baru ? 0.75 : durasi, ease: baru ? 'back.out(1.6)' : 'power3.out', overwrite: true };
    if (kotak && !tenang) {
      sasaran.scale = tampak ? 1 : 0.94;
      // Wadah ruang 3D sudah punya perspektif sendiri, jadi tidak ikut direbahkan.
      if (!ruang3d.includes(el)) Object.assign(sasaran, { rotationX: tampak ? 0 : -18, transformPerspective: 900 });
    }
    gsap.to(el, sasaran);
    // Blok yang baru muncul: percikan, butir daftarnya masuk bergiliran, dan ikonnya tergambar.
    if (!baru) return;
    if (kotak && percikan++ < 3) percik(el);
    const butir = $$('li, tr', el);
    if (butir.length) gsap.fromTo(butir, { autoAlpha: 0, x: -18 }, { autoAlpha: 1, x: 0, duration: 0.5, ease: 'power3.out', stagger: 0.08, delay: 0.1, overwrite: true });
    const garis = garisIkon(el);
    if (garis.length) gsap.fromTo(garis, { drawSVG: '0%' }, { drawSVG: '100%', duration: 0.7, ease: 'power2.out', stagger: 0.04, delay: 0.15, overwrite: true });
  });
  adegan[s.id]?.atur?.(ke, seketika, sebelum);
}

function tampil(i, diAkhir = false) {
  if (i < 0 || i >= slides.length || i === kini) return;
  const lama = slides[kini];
  const s = slides[i];
  const awal = kini === -1;
  masuk?.progress(1);

  if (lama) {
    adegan[lama.id]?.keluar?.();
    gsap.killTweensOf(lama);
    // Mendaki: slide lama tertinggal ke bawah. Turun: sebaliknya.
    gsap.to(lama, { autoAlpha: 0, y: geser(i > kini ? 70 : -70), scale: tenang ? 1 : 0.95, duration: d(0.32), ease: 'power2.in', onComplete: () => lama.classList.remove('aktif') });
  }

  // Pindah pos: punggungan gelap menyapu layar searah pendakian.
  const gantiPos = !awal && !tenang && lama.dataset.pos !== s.dataset.pos;
  if (gantiPos) {
    const bawah = innerHeight * 1.01;
    const atas = -innerHeight * 1.51;
    const naik = i > kini;
    gsap.fromTo('.usap', { y: naik ? bawah : atas }, { y: naik ? atas : bawah, duration: 1.1, ease: 'power2.inOut', overwrite: true });
  }

  kini = i;
  langkah = diAkhir ? jumlahLangkah[i] : 0;
  s.classList.add('aktif');
  gsap.killTweensOf(s);
  gsap.set(s, { autoAlpha: 1, y: 0, scale: 1 });

  const masukan = $$('[data-in]', s);
  gsap.set(masukan, { autoAlpha: 0, y: geser(44), scale: tenang ? 1 : 0.94, rotationX: geser(-16), transformPerspective: 900, transformOrigin: '50% 100%' });
  aturLangkah(langkah, true, langkah);

  // Huruf judul besar berdiri dari posisi rebah.
  const jungkir = !tenang && $('.head', s).classList.contains('wordmark');
  masuk = gsap.timeline({ delay: awal ? 0.2 : d(gantiPos ? 0.62 : 0.4) });
  masuk
    .fromTo(judulSlide[i],
      { autoAlpha: 0, y: geser(46), clipPath: 'inset(-10% 0 100% 0)', ...jungkir && { rotationX: -95, transformPerspective: 700, transformOrigin: '50% 100%' } },
      { autoAlpha: 1, y: 0, clipPath: 'inset(-10% 0 -25% 0)', ...jungkir && { rotationX: 0 }, duration: d(0.95), ease: jungkir ? 'back.out(1.5)' : 'power4.out', stagger: judulSlide[i].length > 4 ? 0.045 : 0.1 }, 0)
    .to(masukan, { autoAlpha: 1, y: 0, scale: 1, rotationX: 0, duration: d(0.85), ease: 'back.out(1.5)', stagger: 0.09 }, 0.3);
  if (aksenSlide[i]) masuk.fromTo(aksenSlide[i], { scaleY: 0 }, { scaleY: 1, duration: d(0.8), ease: 'power4.out' }, 0.15);
  // Butir daftar di dalam blok awal ikut masuk bergiliran.
  const butirAwal = masukan.flatMap((el) => $$('li, tr', el));
  if (butirAwal.length && !tenang) masuk.fromTo(butirAwal, { autoAlpha: 0, x: -26 }, { autoAlpha: 1, x: 0, duration: 0.5, ease: 'power3.out', stagger: 0.06 }, 0.55);
  const ikonAwal = garisIkon(s).filter((el) => !el.closest('[data-step]'));
  if (ikonAwal.length && !tenang) masuk.fromTo(ikonAwal, { drawSVG: '0%' }, { drawSVG: '100%', duration: 0.8, ease: 'power2.out', stagger: 0.03 }, 0.5);
  adegan[s.id]?.masuk?.(masuk);

  const polos = s.id === 'judul' || s.id === 'terima';
  gsap.to(kamera, { p: i / (slides.length - 1), duration: d(awal ? 0 : 1.5), ease: 'power2.inOut', onUpdate: gambarDunia, overwrite: true });
  gsap.to(dunia.tirai, { opacity: polos ? 0 : 1, duration: d(0.8), ease: 'power1.out' });
  perbaruiRel(i, awal);
  history.replaceState(null, '', `#${i + 1}`);
}

function lanjut() {
  if (langkah < jumlahLangkah[kini]) {
    langkah++;
    aturLangkah(langkah, false, langkah - 1);
  } else {
    tampil(kini + 1);
  }
}

function mundur() {
  if (langkah > 0) {
    langkah--;
    aturLangkah(langkah, false, langkah + 1);
  } else {
    tampil(kini - 1, true);
  }
}

/* ---------- masukan pengguna ---------- */

function skala() {
  document.documentElement.style.setProperty('--s', Math.min(innerWidth / 1920, innerHeight / 1080));
  gambarBintang();
  ukurKanvas($('.kunang'));
  ukurKanvas(pesta.kanvas);
  dunia.gunung?.ukur();
  gambarDunia();
}

// Penunjuk menggeser titik pandang ruang 3D dan punggungan, supaya terasa berkedalaman.
const ruang3d = $$('.hp-baris, .web, .logo-wrap');
function terapkanTilik() {
  const asal = `${50 - tilik.x * 46}% ${42 - tilik.y * 34}%`;
  ruang3d.forEach((el) => (el.style.perspectiveOrigin = asal));
  gambarDunia();
}
if (!tenang && matchMedia('(hover: hover) and (pointer: fine)').matches) {
  addEventListener('pointermove', (e) => {
    gsap.to(tilik, { x: e.clientX / innerWidth - 0.5, y: e.clientY / innerHeight - 0.5, duration: 0.9, ease: 'power2.out', overwrite: true, onUpdate: terapkanTilik });
  });
}

addEventListener('keydown', (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const maju = ['ArrowRight', 'ArrowDown', 'PageDown', ' ', 'Enter'];
  const balik = ['ArrowLeft', 'ArrowUp', 'PageUp', 'Backspace'];
  if (maju.includes(e.key)) lanjut();
  else if (balik.includes(e.key)) mundur();
  else if (e.key === 'Home') tampil(0);
  else if (e.key === 'End') tampil(slides.length - 1);
  else if (e.key.toLowerCase() === 'f') {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen?.();
  } else return;
  e.preventDefault();
});

$('.stage').addEventListener('click', (e) => {
  if (!e.target.closest('button, video, a')) lanjut();
});

let sentuhX = null;
addEventListener('touchstart', (e) => (sentuhX = e.touches[0].clientX), { passive: true });
addEventListener('touchend', (e) => {
  if (sentuhX === null) return;
  const selisih = e.changedTouches[0].clientX - sentuhX;
  sentuhX = null;
  if (Math.abs(selisih) < 50) return;
  if (selisih < 0) lanjut();
  else mundur();
}, { passive: true });

addEventListener('resize', skala);

/* ---------- mulai ---------- */

function mulai() {
  $('#identitas').innerHTML = IDENTITAS.filter(([, isi]) => isi).map(([label, isi]) => `<dt>${label}</dt><dd>${isi}</dd>`).join('');
  bangunKontur();
  bangunTahap();
  bangunAlur();
  bangunRel();
  bangunKelip();
  bangunBurung();
  nyalakanKunang();
  $$('.titik-uji').forEach((el) => (el.innerHTML = '<i></i>'.repeat(+el.dataset.n)));

  jumlahLangkah = slides.map((s) => Math.max(0, ...$$('[data-step], [data-hide-at]', s).map((el) => +(el.dataset.step ?? el.dataset.hideAt))));
  // Judul besar dipecah per huruf, judul biasa per baris. Slide harus terukur saat dipecah.
  judulSlide = slides.map((s, n) => {
    s.classList.add('aktif');
    const kepala = $('.head', s);
    const besar = kepala.classList.contains('wordmark');
    const pecah = SplitText.create(kepala, { type: besar ? 'chars' : 'lines' });
    if (!besar) {
      const aksen = document.createElement('i');
      aksen.className = 'aksen';
      aksen.style.top = `${kepala.offsetTop + 10}px`;
      aksen.style.height = `${kepala.offsetHeight - 16}px`;
      s.append(aksen);
      aksenSlide[n] = aksen;
    }
    s.classList.remove('aktif');
    return pecah.chars.length ? pecah.chars : pecah.lines;
  });

  skala();
  const dariHash = parseInt(location.hash.slice(1), 10);
  tampil(Number.isFinite(dariHash) ? Math.min(slides.length, Math.max(1, dariHash)) - 1 : 0);
}

document.fonts.ready.then(mulai);
