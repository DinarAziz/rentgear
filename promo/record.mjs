// Frame-accurate capture: instead of Playwright's built-in video recorder
// (VP8 at a low, fixed bitrate -> blocky/blurry on fine UI text), pause every
// CSS animation and scrub `currentTime` frame by frame, taking a lossless PNG
// screenshot at each step. Assembled into H.264 afterwards at high quality.
import { chromium } from "playwright";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const here = path.dirname(fileURLToPath(import.meta.url));
const framesDir = path.join(here, "frames");
fs.rmSync(framesDir, { recursive: true, force: true });
fs.mkdirSync(framesDir, { recursive: true });

const FPS = 25;
// 5 steps of 4.0s to reach the last scene's start, + .4s fade-in + 3.6s hold
// (stop before its own fade-out, which has nothing to crossfade into).
const TOTAL_MS = 5 * 4000 + 400 + 3600;
const FRAME_COUNT = Math.round((TOTAL_MS / 1000) * FPS);

const browser = await chromium.launch({ channel: "chrome" });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
await page.goto("file://" + path.join(here, "web", "index.html"));

// Freeze every CSS animation so we control time explicitly.
await page.evaluate(() => document.getAnimations().forEach((a) => a.pause()));

for (let i = 0; i < FRAME_COUNT; i++) {
  const t = (i * 1000) / FPS;
  await page.evaluate((ms) => {
    document.getAnimations().forEach((a) => {
      a.currentTime = ms;
    });
  }, t);
  const name = String(i).padStart(5, "0") + ".png";
  await page.screenshot({ path: path.join(framesDir, name) });
  if (i % 50 === 0) console.log(`frame ${i}/${FRAME_COUNT}`);
}

await browser.close();
console.log(`captured ${FRAME_COUNT} frames at ${FPS}fps`);

execSync(
  `ffmpeg -y -framerate ${FPS} -i "${framesDir}/%05d.png" ` +
    `-c:v libx264 -pix_fmt yuv420p -crf 16 -preset slow -movflags +faststart ` +
    `"${path.join(here, "promo.mp4")}" -loglevel error`,
  { stdio: "inherit" }
);
console.log("wrote promo.mp4");
