// Records the demo: drives the local-mode web build through a full rental and saves one screenshot per beat,
// plus manifest.json with where each tap lands, for the Remotion composition to animate.
// usage: node capture/run.mjs   (web build served at http://127.0.0.1:8090, see README.md)
import { mkdirSync, rmSync, writeFileSync } from 'fs';
import { open, boot, dump, find } from './lib.mjs';

const ROOT = new URL('..', import.meta.url).pathname;
const OUT = `${ROOT}public/shots`;
const SPECIMEN = `${ROOT}capture/specimen`;
const PROFILE = process.env.PROFILE_DIR ?? '/tmp/rentgear-demo-profile';
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
rmSync(PROFILE, { recursive: true, force: true });

const manifest = [];
let page;
let device = 'phone';
let n = 0;

/** Screenshot of the current screen. `tap` marks where the next tap lands. */
async function shot(id, tap = null) {
  await page.waitForTimeout(350);
  const file = `${String(++n).padStart(3, '0')}-${id}.png`;
  await page.screenshot({ path: `${OUT}/${file}` });
  const { width, height } = page.viewportSize();
  // Boxes of the labelled elements on screen, so the video can highlight one by its text.
  const nodes = (await dump(page))
    .filter((d) => d.w * d.h < width * height * 0.6 && d.y + d.h > 0 && d.y < height)
    .map((d) => ({ label: d.label.slice(0, 400), x: d.x, y: d.y, w: d.w, h: d.h }));
  manifest.push({ id, file, device, width, height, tap, nodes });
  console.log(file, tap ? `tap ${Math.round(tap.x)},${Math.round(tap.y)}` : '');
}

/** Screenshot with the tap target marked, then tap it. */
async function tap(id, text, { nth = 0, wait = 1500, dx = 0, dy = 0 } = {}) {
  let p;
  try {
    p = await find(page, text, { nth });
  } catch (e) {
    await page.screenshot({ path: `${OUT}/_debug.png` });
    for (const d of await dump(page)) console.log(' ', d.role ?? '-', JSON.stringify(d.label).slice(0, 100), d.x, d.y, d.w, d.h);
    throw e;
  }
  const at = { x: p.x + dx, y: p.y + dy };
  await shot(id, at);
  await page.mouse.click(at.x, at.y);
  await page.mouse.move(2, 300);
  await page.waitForTimeout(wait);
}

/** Tap a fixed point (sliders, chips without labels). */
async function tapAt(id, x, y, wait = 900) {
  await shot(id, { x, y });
  await page.mouse.click(x, y);
  await page.mouse.move(2, 300);
  await page.waitForTimeout(wait);
}

async function type(text) {
  await page.keyboard.type(text, { delay: 25 });
  await page.waitForTimeout(500);
}

async function scroll(dy, x = 384, y = 600) {
  await page.mouse.move(x, y);
  // Flutter web moves a third of the wheel delta per event, so each 300 delta is 100 px of scroll.
  for (let done = 0; done < Math.abs(dy); done += 100) {
    await page.mouse.wheel(0, Math.sign(dy) * 300);
    await page.waitForTimeout(60);
  }
  await page.waitForTimeout(900);
}

/** The next file dialog gets this file. */
function nextFile(name) {
  page.once('filechooser', (fc) => fc.setFiles(`${SPECIMEN}/${name}`));
}

async function login(id, chip) {
  await tap(`${id}-login`, chip, { wait: 2800 });
}

/** Back out of pushed pages until the bottom navigation shows. */
async function home() {
  for (let i = 0; i < 6; i++) {
    const nodes = await dump(page);
    if (nodes.some((d) => d.role === 'tab' && d.label === 'Profil')) return;
    const back = nodes.find((d) => d.role === 'button' && d.label === 'Kembali');
    if (!back) return;
    await page.mouse.click(back.x + back.w / 2, back.y + back.h / 2);
    await page.waitForTimeout(1200);
  }
}

async function logout(id, profileTab = 'Profil') {
  await home();
  await tap(`${id}-profil`, profileTab, { wait: 1500 });
  await scroll(1500);
  await tap(`${id}-keluar`, 'Keluar', { wait: 1800 });
  const confirm = (await dump(page)).find((d) => d.role === 'button' && d.label === 'Keluar');
  if (confirm) {
    await page.mouse.click(confirm.x + confirm.w / 2, confirm.y + confirm.h / 2);
    await page.waitForTimeout(2000);
  }
}

const today = new Date();
const dayLabel = (offset) => {
  const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset);
  return `${d.getDate()}, `;
};

const s = await open({ userDataDir: PROFILE });
page = s.page;
await boot(page);
writeFileSync(`${OUT}/manifest.json`, '[]');

try {
  // 1. Toko mengatur diskon.
  await login('toko1', 'Penyedia · Arjuna');
  await shot('toko1-pesanan');
  await tap('toko1-profil', 'Profil');
  await tap('toko1-menu-diskon', 'Diskon sewa');
  await tapAt('toko1-diskon7', 167, 368);
  await tapAt('toko1-diskon3', 112, 281);
  await tap('toko1-simpan', 'Simpan diskon', { wait: 1800 });
  await shot('toko1-tersimpan');
  await logout('toko1-out');

  // 2. Penyewa mencari alat dan memesan.
  await login('sewa', 'Penyewa · Budi');
  await tap('sewa-katalog', 'Arjuna Outdoor Malang', { wait: 2200 });
  await tap('sewa-toko', 'Tenda Dome 4 Orang Eiger', { wait: 2200 });
  await scroll(520);
  await shot('sewa-detail-harga');
  await scroll(420);
  await shot('sewa-detail-diskon');
  await tap('sewa-detail', 'Sewa Sekarang', { wait: 2000 });
  await tap('sewa-form', 'Pilih tanggal', { wait: 1500 });
  await tap('sewa-tgl-mulai', dayLabel(0), { wait: 700 });
  await tap('sewa-tgl-akhir', dayLabel(2), { wait: 700 });
  await tap('sewa-tgl-pilih', 'Pilih', { wait: 1800 });
  await tap('sewa-jenis', 'Jenis dokumen', { wait: 1000 });
  await tap('sewa-ktp', 'KTP — Kartu Tanda Penduduk', { wait: 1000 });
  await tap('sewa-nomor', 'Nomor dokumen', { wait: 600 });
  await type('3573011204020001');
  await page.keyboard.press('Tab');
  await scroll(260);
  nextFile('ktp.jpg');
  await tap('sewa-foto', 'Foto dokumen', { wait: 1200 });
  await tap('sewa-galeri', 'Pilih dari galeri', { wait: 2500 });
  await shot('sewa-foto-ok');
  await scroll(420);
  await shot('sewa-ringkasan');
  await scroll(600);
  await tap('sewa-setuju', 'Saya setuju dengan ketentuan sewa', { wait: 800 });
  await tap('sewa-kirim', 'Kirim Booking', { wait: 2800 });
  await shot('sewa-terkirim');
  await logout('sewa-out');

  // 3. Toko memeriksa jaminan dan mengonfirmasi.
  await login('toko2', 'Penyedia · Arjuna');
  await tap('toko2-pesanan', '21–23 Okt', { wait: 2200 });
  await tap('toko2-valid', 'Valid', { wait: 1500 });
  await tap('toko2-konfirmasi', 'Konfirmasi booking', { wait: 2200 });
  await shot('toko2-dikonfirmasi');
  await logout('toko2-out');

  // 4. Penyewa membayar dengan transfer dan mengunggah bukti.
  await login('bayar', 'Penyewa · Budi');
  await tap('bayar-tab', 'Sewa Saya', { wait: 1800 });
  await tap('bayar-list', '21–23 Okt', { wait: 2200 });
  await scroll(300);
  nextFile('transfer.jpg');
  await tap('bayar-upload', 'Upload bukti transfer', { wait: 1200 });
  await tap('bayar-galeri', 'Pilih dari galeri', { wait: 2500 });
  await tap('bayar-kirim', 'Kirim', { wait: 2200 });
  await shot('bayar-terkirim');
  await logout('bayar-out');

  // 5. Toko menerima pembayaran dan menyerahkan alat.
  await login('toko3', 'Penyedia · Arjuna');
  await tap('toko3-pesanan', '21–23 Okt', { wait: 2200 });
  await scroll(400);
  await tap('toko3-terima-bayar', 'Terima pembayaran', { wait: 1200 });
  await tap('toko3-sudah-masuk', 'Sudah masuk', { wait: 2200 });
  await tap('toko3-serahkan', 'Terima jaminan & serahkan alat', { wait: 1200 });
  await tap('toko3-sudah-diterima', 'Sudah diterima', { wait: 2200 });
  await shot('toko3-disewa');
  nextFile('kondisi.jpg');
  await tap('toko3-foto-kondisi', 'Tambah', { wait: 1200 });
  await tap('toko3-galeri', 'Pilih dari galeri', { wait: 2500 });
  await shot('toko3-kondisi-ok');

  // 6. Alat kembali: toko memeriksa kondisi, mengembalikan jaminan, transaksi selesai.
  await tap('toko3-kembali', 'Terima pengembalian alat', { wait: 1500 });
  await tap('toko3-baik', 'Baik', { wait: 700 });
  await tap('toko3-terima-alat', 'Terima alat', { wait: 2200 });
  await shot('toko3-dikembalikan');
  await tap('toko3-selesai', 'Kembalikan jaminan & selesaikan', { wait: 1500 });
  await tap('toko3-dialog-selesai', 'Selesaikan', { wait: 2200 });
  await shot('toko3-selesai-ok');
  await logout('toko3-out');

  // 7. Penyewa memberi ulasan.
  await login('ulas', 'Penyewa · Budi');
  await tap('ulas-tab', 'Sewa Saya', { wait: 1800 });
  await tap('ulas-list', 'INV-20261021', { wait: 2200 });
  await scroll(300);
  await tap('ulas-beri', 'Beri ulasan', { wait: 1500 });
  await tap('ulas-bintang', '5 bintang', { wait: 700 });
  await tapAt('ulas-teks', 195, 470, 600);
  await type('Tenda bersih, diskon 3 hari lumayan. Serah terima cepat.');
  await tap('ulas-kirim', 'Kirim ulasan', { wait: 2200 });
  await shot('ulas-ok');
  await logout('ulas-out');

  // 8. Admin di layar lebar.
  device = 'desktop';
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(1500);
  await login('admin', 'Admin');
  await tap('admin-dashboard', '1 penyedia menunggu verifikasi', { wait: 2000 });
  await tap('admin-penyedia', 'Verifikasi', { wait: 1500 });
  await tap('admin-verifikasi-yakin', 'Verifikasi', { wait: 2000 });
  await shot('admin-terverifikasi');
  await tap('admin-transaksi-tab', 'Transaksi Tab 4 dari 5', { wait: 2000 });
  await tap('admin-transaksi', 'INV-20261021', { wait: 2200 });
  await shot('admin-transaksi-detail');
  await page.keyboard.press('Escape');
  await home();
  await page.waitForTimeout(800);
  const dash = await find(page, 'Dashboard Tab 1 dari 5');
  await page.mouse.click(dash.x, dash.y);
  await page.waitForTimeout(1800);
  await tap('admin-audit-buka', 'Jejak audit', { wait: 2200 });
  await shot('admin-audit');
} finally {
  writeFileSync(`${OUT}/manifest.json`, JSON.stringify(manifest, null, 1));
  await s.ctx.close();
}
