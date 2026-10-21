// Turns the script, the recorded voice lengths and the screenshot manifest into frame timings.
import manifestJson from '../public/shots/manifest.json';
import script from './script.json';
import timing from './timing.json';

export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;
/** Frames two neighbouring scenes overlap during the transition. */
export const TRANSITION = 18;

const LEAD = 0.55; // silence before the first sentence of a scene
const GAP = 0.4; // silence between sentences
const TAIL = 0.9; // silence after the last sentence
const MIN_BEAT = 1.35; // shortest time one screenshot stays on screen

type Tap = { x: number; y: number };
export type Shot = { id: string; file: string; device: 'phone' | 'desktop'; width: number; height: number; tap: Tap | null };
/** Area to highlight, in the screenshot's own CSS pixels: x, y, width, height. */
export type Focus = { box: [number, number, number, number] };
export type Beat = { shot: Shot; from: number; duration: number; focus?: Focus };
export type Line = { text: string; from: number; duration: number; file: string; step?: number };
export type ScenePlan = {
  id: string;
  kind: 'intro' | 'phone' | 'desktop' | 'outro';
  chapter?: string;
  title?: string;
  steps: string[];
  duration: number;
  lines: Line[];
  beats: Beat[];
};

const manifest = manifestJson as Shot[];
const shotById = new Map(manifest.map((s) => [s.id, s]));
const sec = (s: number) => Math.round(s * FPS);

type SceneJson = {
  id: string;
  kind: ScenePlan['kind'];
  chapter?: string;
  title?: string;
  steps?: string[];
  shots?: string[];
  /** `at` names the screenshot that is on screen when the sentence starts. */
  sentences: { text: string; step?: number; at?: string }[];
  focus?: Record<string, Focus>;
};

const LEAD_IN = 0.2; // the screen changes this long before the sentence about it starts

function planScene(scene: SceneJson): ScenePlan {
  const voice = (timing as Record<string, { file: string; seconds: number }[]>)[scene.id];
  const shots = (scene.shots ?? []).map((entry) => {
    const [id, weight] = entry.split(':');
    const shot = shotById.get(id);
    if (!shot) throw new Error(`No screenshot "${id}" in manifest.json`);
    return { shot, weight: Number(weight ?? 1) };
  });

  // Each sentence owns the screenshots from its `at` up to the next sentence's. A sentence whose screenshots need
  // more time than its words gets a longer pause after it, so no screen flashes by.
  const firstShot = scene.sentences.map((s, i) => (i === 0 ? 0 : s.at ? shots.findIndex((x) => x.shot.id === s.at) : -1));
  const weightOf = (i: number) => {
    if (!shots.length || firstShot[i] < 0) return 0;
    const next = firstShot.slice(i + 1).find((v) => v >= 0) ?? shots.length;
    return shots.slice(firstShot[i], next).reduce((sum, x) => sum + x.weight, 0);
  };
  const starts: number[] = []; // seconds each sentence starts
  const segStart: number[] = []; // seconds each sentence's screenshots start
  let t = LEAD;
  scene.sentences.forEach((_, i) => {
    if (i > 0) {
      const prevSeg = segStart[i - 1];
      t = Math.max(t, prevSeg + weightOf(i - 1) * MIN_BEAT + LEAD_IN);
    }
    starts.push(t);
    segStart.push(i === 0 ? 0 : t - LEAD_IN);
    t += voice[i].seconds + GAP;
  });
  const last = scene.sentences.length - 1;
  const extra = scene.kind === 'outro' ? 3.2 : scene.kind === 'intro' ? 1.2 : 0;
  const spoken = Math.max(t - GAP + TAIL + extra, segStart[last] + weightOf(last) * MIN_BEAT + TAIL);
  const duration = sec(spoken);

  const lines = scene.sentences.map((s, i) => ({
    text: s.text, step: s.step, file: voice[i].file, from: sec(starts[i]), duration: sec(voice[i].seconds),
  }));

  // Within a sentence, its screenshots share the time by weight. The last one also covers the outgoing transition.
  const beats: Beat[] = [];
  scene.sentences.forEach((_, i) => {
    if (firstShot[i] < 0 || !shots.length) return;
    const next = firstShot.slice(i + 1).find((v) => v >= 0) ?? shots.length;
    const nextSentence = firstShot.findIndex((v, j) => j > i && v >= 0);
    const from = sec(segStart[i]);
    const to = nextSentence < 0 ? duration : sec(segStart[nextSentence]);
    const group = shots.slice(firstShot[i], next);
    const total = group.reduce((sum, x) => sum + x.weight, 0);
    const usable = (nextSentence < 0 ? to - TRANSITION : to) - from;
    let at = from;
    group.forEach(({ shot, weight }, j) => {
      const end = j === group.length - 1 ? to : Math.round(at + (usable * weight) / total);
      beats.push({ shot, from: at, duration: end - at, focus: scene.focus?.[shot.id] });
      at = end;
    });
  });

  return {
    id: scene.id, kind: scene.kind, chapter: scene.chapter, title: scene.title,
    steps: scene.steps ?? [], duration, lines, beats,
  };
}

export const scenes: ScenePlan[] = (script.scenes as SceneJson[]).map(planScene);
export const totalFrames = scenes.reduce((sum, s) => sum + s.duration, 0) - TRANSITION * (scenes.length - 1);

/** Start frame of each scene in the whole video, for the progress bar. */
export const sceneStarts = scenes.reduce<number[]>((acc, s, i) => {
  acc.push(i === 0 ? 0 : acc[i - 1] + scenes[i - 1].duration - TRANSITION);
  return acc;
}, []);
