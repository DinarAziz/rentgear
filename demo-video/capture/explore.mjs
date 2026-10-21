// usage: node capture/explore.mjs <shot> [tap "text" | key K | type S | wait ms | wheel dy]...
import { open, boot, dump, tap } from './lib.mjs';
const S = process.env.SHOT_DIR;
const [shot, ...steps] = process.argv.slice(2);
import { rmSync } from "fs";
rmSync(`${S}/explore-profile`, { recursive: true, force: true });
const { ctx, page } = await open({ userDataDir: `${S}/explore-profile` });
await boot(page);
for (let i = 0; i < steps.length; i += 2) {
  const [s, v] = [steps[i], steps[i + 1]];
  if (s === 'tap') await tap(page, v);
  else if (s === 'key') await page.keyboard.press(v);
  else if (s === 'type') await page.keyboard.type(v, { delay: 20 });
  else if (s === 'wait') await page.waitForTimeout(+v);
  else if (s === 'wheel') { await page.mouse.move(195, 500); await page.mouse.wheel(0, +v); await page.waitForTimeout(900); }
  await page.waitForTimeout(500);
}
await page.screenshot({ path: `${S}/${shot}.png`, scale: 'css' });
for (const n of await dump(page)) console.log(n.role ?? '-', JSON.stringify(n.label).slice(0, 90), n.x, n.y, n.w, n.h);
await ctx.close();
