// Speaks every sentence of src/script.json and writes the timing the video uses.
//
//   node capture/voice.mjs                 all sentences, with the engine in script.json ("elevenlabs" or "mac")
//   node capture/voice.mjs voices          ElevenLabs: list Indonesian female voices from the Voice Library
//   node capture/voice.mjs samples a,b,c   ElevenLabs: add those library voices and speak one sample with each
//
// ElevenLabs needs an API key in demo-video/elevenlabs.key (one line, ignored by git). The key is never printed.
import { execFileSync } from 'child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'fs';

const ROOT = new URL('..', import.meta.url).pathname;
const script = JSON.parse(readFileSync(`${ROOT}src/script.json`, 'utf8'));
const OUT = `${ROOT}public/voice`;
const API = 'https://api.elevenlabs.io';

function key() {
  const file = `${ROOT}elevenlabs.key`;
  if (!existsSync(file)) throw new Error('Put the ElevenLabs API key in demo-video/elevenlabs.key first.');
  return readFileSync(file, 'utf8').trim();
}

async function eleven(path, init = {}) {
  const res = await fetch(`${API}${path}`, { ...init, headers: { 'xi-api-key': key(), 'Content-Type': 'application/json', ...init.headers } });
  if (!res.ok) throw new Error(`ElevenLabs ${res.status} on ${path.split('?')[0]}: ${(await res.text()).slice(0, 300)}`);
  return res;
}

async function speakEleven(text, voiceId, file, context = {}, model = script.voice.model) {
  const res = await eleven(`/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`, {
    method: 'POST',
    body: JSON.stringify({
      text,
      model_id: model,
      voice_settings: { stability: 0.55, similarity_boost: 0.8, style: 0.1, use_speaker_boost: true, speed: 1.0 },
      // Neighbouring sentences keep the intonation flowing as one narration.
      previous_text: context.previous, next_text: context.next,
    }),
  });
  writeFileSync(file, Buffer.from(await res.arrayBuffer()));
}

function speakMac(text, file) {
  execFileSync('say', ['-v', script.voice.mac.name, '-r', String(script.voice.mac.rate), '-o', file, text]);
}

/** Trim silence at both ends, even out loudness, store as 48 kHz WAV, and return the length in seconds. */
function finish(input, output) {
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-i', input, '-af',
    'silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=11',
    '-ar', '48000', output]);
  rmSync(input);
  return Number(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', output]).toString());
}

const [command, arg] = process.argv.slice(2);

if (command === 'voices') {
  const res = await eleven('/v1/shared-voices?page_size=40&language=id&gender=female&sort=usage_character_count_1y');
  const { voices } = await res.json();
  for (const v of voices.filter((v) => v.free_users_allowed !== false)) {
    console.log([v.public_owner_id, v.voice_id, v.name, v.age, v.accent, v.use_case, (v.descriptive ?? ''), `${Math.round((v.usage_character_count_1y ?? 0) / 1e6)}M`].join(' | '));
    if (v.description) console.log('   ', v.description.replace(/\s+/g, ' ').slice(0, 160));
  }
} else if (command === 'samples') {
  // arg: comma-separated voices. "owner:voice" is a library voice, added to the account first; a bare id is a voice
  // already on the account. "@model" after either picks another model for that sample.
  const sample = `${script.scenes[1].sentences[2].text} ${script.scenes[1].sentences[3].text}`;
  const dir = `${ROOT}out/samples`;
  mkdirSync(dir, { recursive: true });
  const parts = [];
  for (const [i, pair] of arg.split(',').entries()) {
    const [ids, model] = pair.split('@');
    const [owner, voice] = ids.includes(':') ? ids.split(':') : [null, ids];
    const voiceId = owner
      ? (await (await eleven(`/v1/voices/add/${owner}/${voice}`, { method: 'POST', body: JSON.stringify({ new_name: `RentGear ${i + 1}` }) })).json()).voice_id
      : voice;
    const mp3 = `${dir}/sample-${i + 1}.mp3`;
    await speakEleven(sample, voiceId, mp3, {}, model ?? script.voice.model);
    console.log(`sample-${i + 1}: ${voiceId} ${model ?? script.voice.model}`);
    parts.push(mp3);
  }
  // One file with every sample in a row, a short pause between them.
  const list = parts.flatMap((p) => ['-i', p]);
  const filter = parts.map((_, i) => `[${i}:a]aresample=44100,apad=pad_dur=0.8[a${i}]`).join(';') + ';' + parts.map((_, i) => `[a${i}]`).join('') + `concat=n=${parts.length}:v=0:a=1`;
  execFileSync('ffmpeg', ['-loglevel', 'error', '-y', ...list, '-filter_complex', filter, `${dir}/semua-contoh.mp3`]);
  console.log(`${dir}/semua-contoh.mp3`);
} else {
  const engine = script.voice.engine;
  if (engine === 'elevenlabs' && !script.voice.voiceId) throw new Error('Set voice.voiceId in src/script.json first.');
  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });
  const timing = {};
  for (const scene of script.scenes) {
    const texts = scene.sentences.map((s) => s.speak ?? s.text);
    timing[scene.id] = [];
    for (const [i, text] of texts.entries()) {
      const base = `${scene.id}-${i}`;
      const raw = `${OUT}/${base}.${engine === 'mac' ? 'aiff' : 'mp3'}`;
      if (engine === 'mac') speakMac(text, raw);
      else await speakEleven(text, script.voice.voiceId, raw, { previous: texts[i - 1], next: texts[i + 1] });
      const seconds = finish(raw, `${OUT}/${base}.wav`);
      console.log(base, seconds.toFixed(2));
      timing[scene.id].push({ file: `voice/${base}.wav`, seconds });
    }
  }
  writeFileSync(`${ROOT}src/timing.json`, JSON.stringify(timing, null, 1));
}
