// Helpers to drive the Flutter web build through its accessibility tree in Chrome.
import { chromium } from 'playwright-core';

export const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
export const URL = 'http://127.0.0.1:8090/';

export async function open({ width = 390, height = 844, scale = 3, userDataDir } = {}) {
  const ctx = await chromium.launchPersistentContext(userDataDir, {
    executablePath: CHROME, headless: true,
    viewport: { width, height }, deviceScaleFactor: scale, locale: 'id-ID', timezoneId: 'Asia/Jakarta',
  });
  const page = ctx.pages()[0] ?? (await ctx.newPage());
  page.on('pageerror', (e) => console.log('PAGEERROR', String(e)));
  return { ctx, page };
}

export async function boot(page) {
  await page.goto(URL);
  await page.waitForSelector('flt-semantics-placeholder, flt-glass-pane', { timeout: 30000 });
  await page.waitForTimeout(2500);
  await enableSemantics(page);
}

export async function enableSemantics(page) {
  await page.evaluate(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.click();
  });
  await page.waitForTimeout(800);
}

/** All semantics nodes with a label/text, with their boxes. */
export async function dump(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics, input, textarea')].map((e) => {
    const r = e.getBoundingClientRect();
    const label = (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.innerText || '').trim().replace(/\s+/g, ' ');
    return { role: e.getAttribute('role'), label, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
  }).filter((n) => n.label && n.w > 0));
}

/** Center of the first node whose label contains `text` (exact match preferred). */
export async function find(page, text, { nth = 0, role } = {}) {
  const nodes = (await dump(page)).filter((n) => (!role || n.role === role));
  const exact = nodes.filter((n) => n.label === text);
  // Parents repeat their children's text, so the smallest matching box is the actual control.
  const loose = nodes.filter((n) => n.label.includes(text)).sort((a, b) => a.w * a.h - b.w * b.h);
  const list = exact.length ? exact : loose;
  if (!list[nth]) throw new Error(`not found: ${text}`);
  const n = list[nth];
  return { x: n.x + n.w / 2, y: n.y + n.h / 2, node: n };
}

export async function tap(page, text, opts) {
  const p = await find(page, text, opts);
  await page.mouse.click(p.x, p.y);
  await page.waitForTimeout(opts?.wait ?? 1200);
  return p;
}
