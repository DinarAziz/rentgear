import React from 'react';
import { Easing, interpolate, useCurrentFrame } from 'remotion';
import type { Line } from '../plan';
import { BODY, C, DISPLAY } from '../theme';

const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;
const out = Easing.out(Easing.cubic);

/** Fades and slides a block up, `delay` frames after the scene starts. */
export const Rise: React.FC<{ delay?: number; distance?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ delay = 0, distance = 40, children, style }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame - delay, [0, 22], [0, 1], { ...clamp, easing: out });
  return <div style={{ ...style, opacity: p, transform: `translateY(${(1 - p) * distance}px)` }}>{children}</div>;
};

export const Chapter: React.FC<{ text: string; size?: number }> = ({ text, size = 26 }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 16, fontFamily: BODY, fontWeight: 600, fontSize: size, letterSpacing: size * 0.24, textTransform: 'uppercase', color: C.summit }}>
    <span style={{ width: 46, height: 3, background: C.summit, borderRadius: 2 }} />
    {text}
  </div>
);

export const Title: React.FC<{ text: string; size?: number }> = ({ text, size = 108 }) => (
  <h1 style={{ margin: 0, fontFamily: DISPLAY, fontWeight: 800, fontSize: size, lineHeight: 0.95, color: C.sand, letterSpacing: 0.5 }}>{text}</h1>
);

/** Which step the narration is on: the last sentence that has started and names a step. */
export function activeStep(lines: Line[], frame: number) {
  let step = lines.find((l) => l.step !== undefined)?.step ?? 0;
  for (const l of lines) if (frame >= l.from && l.step !== undefined) step = l.step;
  return step;
}

export const Steps: React.FC<{ steps: string[]; active: number; size?: number; delay?: number }> = ({ steps, active, size = 32, delay = 10 }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: size * 0.62 }}>
      {steps.map((s, i) => {
        const p = interpolate(frame - delay - i * 5, [0, 18], [0, 1], { ...clamp, easing: out });
        const done = i < active;
        const now = i === active;
        const circle = size * 1.3;
        return (
          <div key={s} style={{ display: 'flex', alignItems: 'center', gap: size * 0.6, opacity: p, transform: `translateX(${(1 - p) * 30}px)` }}>
            <div style={{
              width: circle, height: circle, flex: 'none', borderRadius: '50%', display: 'grid', placeItems: 'center',
              fontFamily: BODY, fontWeight: 700, fontSize: size * 0.62,
              background: now ? C.summit : done ? C.forest : 'transparent',
              border: now || done ? 'none' : `2px solid ${C.line}`,
              color: now ? C.night : done ? C.sand : C.mist,
              boxShadow: now ? '0 0 0 8px rgba(240,138,60,0.18)' : 'none',
            }}>
              {done ? (
                <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 20 20"><path d="M4 10.5l4 4 8-9" stroke={C.sand} strokeWidth="2.6" fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
              ) : i + 1}
            </div>
            <span style={{ fontFamily: BODY, fontSize: size, fontWeight: now ? 600 : 400, color: now ? C.sand : done ? C.mist : 'rgba(183,201,189,0.55)' }}>{s}</span>
          </div>
        );
      })}
    </div>
  );
};

/** Subtitle of the sentence being spoken; it stays until the next sentence starts. */
export const Caption: React.FC<{ lines: Line[]; size?: number; width: number }> = ({ lines, size = 33, width }) => {
  const frame = useCurrentFrame();
  const idx = lines.reduce((acc, l, i) => (frame >= l.from - 4 ? i : acc), -1);
  if (idx < 0) return null;
  const line = lines[idx];
  const p = interpolate(frame - (line.from - 4), [0, 10], [0, 1], clamp);
  return (
    <div style={{ width, display: 'flex', gap: 22, opacity: p, transform: `translateY(${(1 - p) * 12}px)` }}>
      <span style={{ width: 5, flex: 'none', borderRadius: 3, background: C.moss }} />
      <p style={{ margin: 0, fontFamily: BODY, fontSize: size, lineHeight: 1.38, color: C.sand }}>{line.text}</p>
    </div>
  );
};
