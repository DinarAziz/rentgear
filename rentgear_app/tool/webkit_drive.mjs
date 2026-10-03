// Drives the web build in Playwright WebKit (Safari's engine), like adb_drive.sh does for the phone.
// usage: SHOT_DIR=/tmp node tool/webkit_drive.mjs <profile> <WxH> <url> <shot> [click x y | type s | key k | wait ms | wheel x y dy | file path]...
import { createRequire } from 'module';
const require = createRequire('/Users/ds/Kuliah/Semester-1/PTI/project_sewa_hiking/promo/');
const { webkit } = require('playwright');

const [profile, size, url, shot, ...steps] = process.argv.slice(2);
const [width, height] = size.split('x').map(Number);
const dir = (process.env.SHOT_DIR ?? '/tmp') + '/';
const ctx = await webkit.launchPersistentContext(`${dir}wk-${profile}`, { viewport: { width, height } });
const page = ctx.pages()[0] ?? (await ctx.newPage());
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
await page.goto(url);
await page.waitForTimeout(5000);
let pendingFile = null;
page.on('filechooser', async (fc) => pendingFile && fc.setFiles(pendingFile));
for (let i = 0; i < steps.length; ) {
  const s = steps[i];
  if (s === 'click') { await page.mouse.click(+steps[i + 1], +steps[i + 2]); i += 3; }
  else if (s === 'type') { await page.keyboard.type(steps[i + 1], { delay: 30 }); i += 2; }
  else if (s === 'key') { await page.keyboard.press(steps[i + 1]); i += 2; }
  else if (s === 'wait') { await page.waitForTimeout(+steps[i + 1]); i += 2; continue; }
  else if (s === 'wheel') { await page.mouse.move(+steps[i + 1], +steps[i + 2]); await page.mouse.wheel(0, +steps[i + 3]); i += 4; }
  else if (s === 'file') { pendingFile = steps[i + 1]; i += 2; continue; }
  else if (s === 'shot') { await page.screenshot({ path: `${dir}${steps[i + 1]}.png` }); i += 2; continue; }
  else throw new Error(`unknown step ${s}`);
  await page.waitForTimeout(900);
}
await page.waitForTimeout(1200);
await page.screenshot({ path: `${dir}${shot}.png` });
if (errors.length) console.log('ERRORS:\n' + errors.join('\n'));
console.log('saved', await page.evaluate(() => navigator.userAgent));
await ctx.close();
