// Speaks every sentence of src/script.json with the macOS Indonesian voice and writes the timing the video uses.
// usage: node capture/voice.mjs
import { execFileSync } from 'child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'fs';

const ROOT = new URL('..', import.meta.url).pathname;
const script = JSON.parse(readFileSync(`${ROOT}src/script.json`, 'utf8'));
const OUT = `${ROOT}public/voice`;
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const timing = {};
for (const scene of script.scenes) {
  timing[scene.id] = scene.sentences.map((s, i) => {
    const base = `${scene.id}-${i}`;
    execFileSync('say', ['-v', script.voice.name, '-r', String(script.voice.rate), '-o', `${OUT}/${base}.aiff`, s.speak ?? s.text]);
    // Trim the silence `say` leaves at both ends, normalise loudness, and store as 48 kHz WAV.
    execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-i', `${OUT}/${base}.aiff`, '-af',
      'silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=11',
      '-ar', '48000', `${OUT}/${base}.wav`]);
    rmSync(`${OUT}/${base}.aiff`);
    const seconds = Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', `${OUT}/${base}.wav`]).toString());
    console.log(base, seconds.toFixed(2));
    return { file: `voice/${base}.wav`, seconds };
  });
}
writeFileSync(`${ROOT}src/timing.json`, JSON.stringify(timing, null, 1));
