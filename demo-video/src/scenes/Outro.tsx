import React from 'react';
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { Background } from '../components/Background';
import { Caption, Rise } from '../components/Panel';
import type { ScenePlan } from '../plan';
import { BODY, C, DISPLAY } from '../theme';
import { Voice } from './AppScene';

const stroke = { fill: 'none', stroke: C.sand, strokeWidth: 3, strokeLinecap: 'round', strokeLinejoin: 'round' } as const;
const ICONS: Record<string, React.ReactNode> = {
  Pesan: <><rect x="10" y="14" width="44" height="40" rx="6" {...stroke} /><path d="M10 26h44M22 8v10M42 8v10M22 38h8M22 46h16" {...stroke} /></>,
  Jaminan: <><rect x="8" y="14" width="48" height="36" rx="6" {...stroke} /><circle cx="24" cy="30" r="6" {...stroke} /><path d="M15 44c2-5 5-7 9-7s7 2 9 7M38 28h10M38 36h10" {...stroke} /></>,
  Bayar: <><rect x="8" y="18" width="48" height="30" rx="5" {...stroke} /><circle cx="32" cy="33" r="7" {...stroke} /><path d="M16 26v14M48 26v14" {...stroke} /></>,
  'Serah terima': <><path d="M12 24l20-10 20 10v20L32 54 12 44z" {...stroke} /><path d="M12 24l20 10 20-10M32 34v20" {...stroke} /></>,
  Kembali: <><path d="M20 22H42a12 12 0 0 1 0 24H18" {...stroke} /><path d="M26 14l-8 8 8 8" {...stroke} /></>,
  Ulasan: <path d="M32 10l6.5 13.5 14.5 2-10.5 10 2.5 14.5L32 43l-13 7 2.5-14.5L11 25.5l14.5-2z" {...stroke} />,
};

export const Outro: React.FC<{ scene: ScenePlan }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const names = Object.keys(ICONS);
  const first = scene.lines[0];
  // Each step lights up while the narration lists it.
  const at = (i: number) => first.from + 30 + (i * (first.duration - 30)) / names.length;
  const line = interpolate(frame, [at(0), at(names.length - 1)], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const second = scene.lines[1];
  const end = spring({ frame: frame - second.from + 6, fps, config: { damping: 16, stiffness: 90 } });

  return (
    <AbsoluteFill>
      <Background seed="outro" />
      <div style={{ position: 'absolute', top: 120, width: '100%', textAlign: 'center' }}>
        <Rise delay={4}>
          <h1 style={{ margin: 0, fontFamily: DISPLAY, fontWeight: 800, fontSize: 120, color: C.sand }}>Alur lengkap RentGear</h1>
        </Rise>
      </div>
      <div style={{ position: 'absolute', left: 180, top: 360, width: 1560, height: 200 }}>
        <div style={{ position: 'absolute', left: 80, right: 80, top: 58, height: 4, background: C.line, borderRadius: 2 }} />
        <div style={{ position: 'absolute', left: 80, top: 58, height: 4, width: `${line * (1560 - 160)}px`, background: C.summit, borderRadius: 2 }} />
        {names.map((n, i) => {
          const s = spring({ frame: frame - at(i), fps, config: { damping: 11, stiffness: 140 } });
          return (
            <div key={n} style={{ position: 'absolute', left: 80 + (i * (1560 - 160)) / (names.length - 1) - 80, width: 160, textAlign: 'center' }}>
              <div style={{
                margin: '0 auto', width: 120, height: 120, borderRadius: '50%', display: 'grid', placeItems: 'center',
                background: s > 0.5 ? C.forest : C.pine, border: `3px solid ${s > 0.5 ? C.moss : C.line}`,
                transform: `translateY(-2px) scale(${0.7 + 0.3 * s})`, boxShadow: s > 0.5 ? '0 0 0 12px rgba(46,107,79,0.25)' : 'none',
              }}>
                <svg width="64" height="64" viewBox="0 0 64 64" style={{ opacity: 0.35 + 0.65 * s }}>{ICONS[n]}</svg>
              </div>
              <div style={{ marginTop: 22, fontFamily: BODY, fontWeight: 600, fontSize: 30, color: s > 0.5 ? C.sand : C.mist, opacity: 0.4 + 0.6 * s }}>{n}</div>
            </div>
          );
        })}
      </div>
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 640, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 56,
        opacity: end, transform: `translateY(${(1 - end) * 40}px)`,
      }}>
        <Img src={staticFile('brand/qr.svg')} style={{ width: 210, height: 210, borderRadius: 18, background: C.sand, padding: 12 }} />
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
            <Img src={staticFile('brand/icon.png')} style={{ width: 72, height: 72, borderRadius: 18 }} />
            <span style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 88, color: C.sand }}>RentGear</span>
          </div>
          <div style={{ marginTop: 10, fontFamily: BODY, fontWeight: 600, fontSize: 52, color: C.ember }}>rentgear.serverbaik.my.id</div>
          <div style={{ marginTop: 8, fontFamily: BODY, fontSize: 28, color: C.mist }}>Pindai kode QR untuk membuka situsnya</div>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 140, top: 936 }}>
        <Caption lines={scene.lines} width={1640} size={32} />
      </div>
      <Voice scene={scene} />
    </AbsoluteFill>
  );
};
