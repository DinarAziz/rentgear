import React from 'react';
import { Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import type { Beat } from '../plan';
import { C } from '../theme';

const XFADE = 9; // frames a new screenshot fades in over the previous one
const TAP = 16; // frames the finger shows before the tap lands

const ease = Easing.inOut(Easing.cubic);

const ZOOM = 1.07;

/** How strongly the beat's highlight shows (0 to 1); it fades out before a tap so the finger is seen clearly. */
function highlight(beat: Beat, frame: number) {
  if (!beat.focus || beat.duration < 45) return 0;
  const outEnd = beat.shot.tap ? beat.duration - TAP - 2 : beat.duration - 2;
  return interpolate(frame, [XFADE, XFADE + 20], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease })
    * (1 - interpolate(frame, [outEnd - 16, outEnd], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: ease }));
}

/** A slight push-in toward the highlighted area, never showing past the screenshot's edges. */
function camera(beat: Beat, p: number, k: number, w: number, h: number) {
  if (!beat.focus || p === 0) return { scale: 1, x: 0, y: 0 };
  const [bx, by, bw, bh] = beat.focus.box;
  const scale = 1 + (ZOOM - 1) * p;
  const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
  const x = clamp(w / 2 - scale * (bx + bw / 2) * k, w - scale * w, 0);
  const y = clamp(h / 2 - scale * (by + bh / 2) * k, h - scale * h, 0);
  return { scale, x, y };
}

/** Dims everything except the focus box and outlines it. */
const Spotlight: React.FC<{ box: [number, number, number, number]; k: number; p: number }> = ({ box, k, p }) => {
  const pad = 6;
  const [x, y, w, h] = box;
  return (
    <div style={{
      position: 'absolute', left: (x - pad) * k, top: (y - pad) * k, width: (w + pad * 2) * k, height: (h + pad * 2) * k,
      borderRadius: 16 * k, border: `${2.5 * k}px solid rgba(240,138,60,${0.95 * p})`,
      boxShadow: `0 0 0 4000px rgba(8,19,15,${0.5 * p}), 0 0 ${24 * k}px rgba(240,138,60,${0.35 * p})`,
    }} />
  );
};

const Finger: React.FC<{ x: number; y: number; t: number; k: number }> = ({ x, y, t, k }) => {
  // t: frames until the tap lands (positive) or since it landed (negative).
  const size = 46 * k;
  const appear = interpolate(t, [TAP - 6, TAP], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const press = t <= 3 && t >= -2 ? 0.82 : 1;
  const leave = interpolate(t, [-8, 0], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const ring = interpolate(t, [-12, 2], [2.6, 0.6], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const ringOpacity = interpolate(t, [-12, 2], [0, 0.7], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  return (
    <>
      {t <= 2 && (
        <div style={{
          position: 'absolute', left: x - size / 2, top: y - size / 2, width: size, height: size, borderRadius: '50%',
          border: `${3 * k}px solid ${C.summit}`, transform: `scale(${ring})`, opacity: ringOpacity,
        }} />
      )}
      <div style={{
        position: 'absolute', left: x - size / 2, top: y - size / 2, width: size, height: size, borderRadius: '50%',
        background: 'rgba(255,255,255,0.55)', border: `${2.5 * k}px solid rgba(240,138,60,0.95)`,
        boxShadow: '0 6px 18px rgba(0,0,0,0.35)', opacity: appear * leave,
        transform: `scale(${(0.6 + 0.4 * appear) * press})`,
      }} />
    </>
  );
};

/** Screenshots of one scene, cross-faded, with zoom and taps. `width` is the on-screen width in pixels. */
export const ScreenStack: React.FC<{ beats: Beat[]; width: number }> = ({ beats, width }) => {
  const frame = useCurrentFrame();
  const i = Math.max(0, beats.findIndex((b) => frame >= b.from && frame < b.from + b.duration));
  const beat = beats[i];
  const prev = i > 0 ? beats[i - 1] : null;
  const k = width / beat.shot.width;
  const height = beat.shot.height * k;
  const local = frame - beat.from;
  const lit = highlight(beat, local);
  const cam = camera(beat, lit, k, width, height);
  const fadeIn = prev ? interpolate(local, [0, XFADE], [0, 1], { extrapolateRight: 'clamp', easing: Easing.out(Easing.quad) }) : 1;
  const tap = beat.shot.tap;
  const prevTap = prev?.shot.tap;

  return (
    <div style={{ position: 'relative', width, height, overflow: 'hidden', background: '#f5f1e8' }}>
      {prev && fadeIn < 1 && (
        <Img src={staticFile(`shots/${prev.shot.file}`)} style={{ position: 'absolute', inset: 0, width, height }} />
      )}
      <div style={{
        position: 'absolute', inset: 0, opacity: fadeIn, transformOrigin: '0 0',
        transform: `translate(${cam.x}px, ${cam.y}px) scale(${cam.scale * (1.012 - 0.012 * fadeIn)})`,
      }}>
        <Img src={staticFile(`shots/${beat.shot.file}`)} style={{ width, height, display: 'block' }} />
        {beat.focus && lit > 0 && <Spotlight box={beat.focus.box} k={k} p={lit} />}
        {tap && <Finger x={tap.x * k} y={tap.y * k} t={beat.duration - local} k={k} />}
      </div>
      {/* The ring of the previous tap keeps spreading over the new screen. */}
      {prevTap && local < 12 && <Finger x={prevTap.x * k} y={prevTap.y * k} t={-local} k={k} />}
    </div>
  );
};

/** A phone frame around the screen. */
export const Phone: React.FC<{ width: number; children: React.ReactNode }> = ({ width, children }) => {
  const bezel = 15;
  return (
    <div style={{
      position: 'relative', padding: bezel, borderRadius: 64, background: 'linear-gradient(145deg, #2b3a33, #0b1511 55%, #1d2a24)',
      boxShadow: '0 50px 90px rgba(0,0,0,0.55), 0 0 0 2px rgba(183,201,189,0.18), inset 0 0 0 2px rgba(255,255,255,0.06)',
    }}>
      <div style={{ position: 'absolute', right: -5, top: 190, width: 5, height: 90, borderRadius: 3, background: '#24322b' }} />
      <div style={{ position: 'absolute', left: -5, top: 160, width: 5, height: 60, borderRadius: 3, background: '#24322b' }} />
      <div style={{ position: 'absolute', left: -5, top: 236, width: 5, height: 60, borderRadius: 3, background: '#24322b' }} />
      <div style={{ width, borderRadius: 50, overflow: 'hidden', position: 'relative' }}>
        {children}
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(115deg, rgba(255,255,255,0.08), transparent 32%)', pointerEvents: 'none' }} />
      </div>
    </div>
  );
};

/** A desktop browser window around the screen. */
export const Browser: React.FC<{ width: number; url: string; children: React.ReactNode }> = ({ width, url, children }) => (
  <div style={{ width, borderRadius: 18, overflow: 'hidden', background: '#e9e4d8', boxShadow: '0 50px 90px rgba(0,0,0,0.55), 0 0 0 1.5px rgba(183,201,189,0.25)' }}>
    <div style={{ height: 46, display: 'flex', alignItems: 'center', gap: 9, padding: '0 18px', background: '#dcd6c8' }}>
      {['#e46b5d', '#e8b04b', '#5fb36a'].map((c) => <i key={c} style={{ width: 13, height: 13, borderRadius: '50%', background: c }} />)}
      <div style={{ marginLeft: 22, flex: 1, height: 28, borderRadius: 8, background: '#f5f1e8', display: 'flex', alignItems: 'center', padding: '0 14px', fontFamily: 'Outfit, sans-serif', fontSize: 16, color: '#4a5a52' }}>
        <svg width="14" height="16" viewBox="0 0 14 16" style={{ marginRight: 10 }}>
          <rect x="1" y="7" width="12" height="8" rx="2" fill="#4a5a52" />
          <path d="M4 7V5a3 3 0 0 1 6 0v2" stroke="#4a5a52" strokeWidth="1.8" fill="none" />
        </svg>
        {url}
      </div>
    </div>
    {children}
  </div>
);

/** Rises from below with a little tilt when a scene starts. */
export function useEntrance(delay = 0) {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping: 18, stiffness: 90, mass: 0.9 } });
}
