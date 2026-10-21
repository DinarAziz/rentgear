// Renders specimen images (fake data, marked SPESIMEN) for the upload steps in the demo.
import { chromium } from 'playwright-core';
import { CHROME } from '../lib.mjs';
const out = new URL('.', import.meta.url).pathname;
const card = (w, h, body) => `<html><body style="margin:0;width:${w}px;height:${h}px;font-family:Helvetica,Arial,sans-serif">${body}</body></html>`;
const stamp = `<div style="position:absolute;inset:0;display:grid;place-items:center;pointer-events:none"><div style="transform:rotate(-18deg);border:8px solid rgba(200,30,30,.75);color:rgba(200,30,30,.75);font-size:96px;font-weight:900;letter-spacing:12px;padding:6px 28px">SPESIMEN</div></div>`;
const ktp = card(1012, 638, `<div style="position:relative;width:1012px;height:638px;background:linear-gradient(135deg,#bfe3f5,#e8f4fb 55%,#c9e7d9);border-radius:28px;overflow:hidden;color:#123">
  <div style="text-align:center;font-weight:800;font-size:34px;padding-top:26px">PROVINSI JAWA TIMUR<br><span style="font-size:30px">KOTA MALANG</span></div>
  <div style="position:absolute;left:44px;top:150px;font-size:27px;line-height:1.55">
    <div><b>NIK</b> &nbsp;: 3573011204020001</div><div>Nama : BUDI SANTOSO</div><div>Tempat/Tgl Lahir : MALANG, 12-04-2002</div>
    <div>Alamat : JL. CONTOH NO. 1</div><div>Agama : -</div><div>Pekerjaan : MAHASISWA</div><div>Berlaku Hingga : SEUMUR HIDUP</div></div>
  <div style="position:absolute;right:56px;top:170px;width:220px;height:280px;background:#9fb3c2;border-radius:10px;display:grid;place-items:center;color:#fff;font-size:22px">FOTO</div>
  ${stamp}</div>`);
const transfer = card(720, 1080, `<div style="position:relative;width:720px;height:1080px;background:#f4f6f8;color:#123">
  <div style="background:#0b5ea8;color:#fff;padding:48px 40px;font-size:40px;font-weight:800">m-Banking</div>
  <div style="margin:40px;background:#fff;border-radius:24px;padding:40px;font-size:30px;line-height:1.8">
    <div style="color:#1a9b55;font-size:44px;font-weight:800;text-align:center">Transfer Berhasil</div>
    <div style="text-align:center;font-size:56px;font-weight:900;margin:18px 0">Rp221.500</div>
    <div>Ke: Arjuna Outdoor</div><div>Rekening: BCA 1234567890</div><div>Berita: INV booking tenda</div><div>Tanggal: 21 Okt 2026</div></div>
  ${stamp}</div>`);
const b = await chromium.launch({ executablePath: CHROME });
const p = await b.newPage();
for (const [name, html, w, h] of [['ktp', ktp, 1012, 638], ['transfer', transfer, 720, 1080]]) {
  await p.setViewportSize({ width: w, height: h });
  await p.setContent(html);
  await p.screenshot({ path: `${out}${name}.jpg`, type: 'jpeg', quality: 90 });
}
await b.close();
console.log('ok');
