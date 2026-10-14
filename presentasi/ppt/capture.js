// Screenshot every slide of the web deck at every step, 1920x1080.
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const [deck, out] = process.argv.slice(2);
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: ['--autoplay-policy=no-user-gesture-required', '--use-gl=angle'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1920, height: 1080 });
  // The promo video slide is left out of the PowerPoint copy, so the deck is served without it.
  const html = fs.readFileSync(`${deck}/index.html`, 'utf8').replace(/<section class="slide" id="video"[\s\S]*?<\/section>\s*/, '');
  await p.setRequestInterception(true);
  p.on('request', (r) => (r.url().split('#')[0].endsWith('/index.html') ? r.respond({ contentType: 'text/html', body: html }) : r.continue()));
  const total = (html.match(/<section class="slide[ "]/g) || []).length;
  const meta = [];
  const only = (process.env.N || '').split(',').filter(Boolean).map(Number);
  const prev = only.length ? JSON.parse(fs.readFileSync(`${out}/meta.json`)) : [];
  for (let n = 1; n <= total; n++) {
    if (only.length && !only.includes(n)) { meta.push(prev[n - 1]); continue; }
    await p.goto(`file://${deck}/index.html#${n}`, { waitUntil: 'load' });
    await p.reload({ waitUntil: 'load' });
    // The web-only start hint does not belong in the PowerPoint copy.
    await p.addStyleTag({ content: '.petunjuk{visibility:hidden!important}' });
    await wait(3500);
    const info = await p.evaluate(() => {
      const s = document.querySelector('section.slide.aktif');
      return {
        id: s.id, label: s.dataset.label, pos: s.dataset.pos,
        steps: jumlahLangkah[kini],
        text: s.innerText.replace(/\n{2,}/g, '\n').trim(),
      };
    });
    await wait(500);
    const files = [];
    for (let k = 0; k <= info.steps; k++) {
      if (k) { await p.keyboard.press('ArrowRight'); await wait(4000); }
      const f = `s${String(n).padStart(2, '0')}_${k}.png`;
      await p.screenshot({ path: `${out}/${f}` });
      files.push(f);
    }
    // Final state again after everything settles, used for notes text.
    info.text = await p.evaluate(() => document.querySelector('section.slide.aktif').innerText.replace(/\n{2,}/g, '\n').trim());
    meta.push({ n, ...info, files });
    console.log(n, info.id, info.steps);
  }
  fs.writeFileSync(`${out}/meta.json`, JSON.stringify(meta, null, 1));
  await b.close();
})();
