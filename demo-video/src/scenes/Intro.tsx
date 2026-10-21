import React from 'react';
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { Background } from '../components/Background';
import { Caption, Rise } from '../components/Panel';
import { Phone } from '../components/Screen';
import type { ScenePlan } from '../plan';
import { BODY, C, DISPLAY } from '../theme';
import { Voice } from './AppScene';

const POINTS = ['Penyedia terverifikasi admin', 'Jaminan dokumen tercatat', 'Stok dicek per tanggal', 'Diskon sewa lama dari toko'];
const FAN = [
  { file: '012-sewa-katalog.png', x: 1080, y: 150, r: -14, z: 0, delay: 18 },
  { file: '015-sewa-detail-diskon.png', x: 1330, y: 110, r: -4, z: 2, delay: 28 },
  { file: '027-sewa-ringkasan.png', x: 1560, y: 170, r: 8, z: 1, delay: 38 },
];

export const Intro: React.FC<{ scene: ScenePlan }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - 4, fps, config: { damping: 12, stiffness: 120 } });
  const word = 'RentGear';
  return (
    <AbsoluteFill>
      <Background seed="intro" />
      {FAN.map((p) => {
        const s = spring({ frame: frame - p.delay, fps, config: { damping: 16, stiffness: 70 } });
        const bob = Math.sin((frame + p.delay * 3) / 40) * 6;
        return (
          <div key={p.file} style={{
            position: 'absolute', left: p.x - 150, top: p.y, zIndex: p.z,
            transform: `perspective(1600px) translateX(${(1 - s) * 500}px) translateY(${bob}px) rotateY(${-22 + (1 - s) * -30}deg) rotateZ(${p.r * s}deg) scale(0.72)`,
            transformOrigin: 'center', opacity: interpolate(s, [0, 0.25], [0, 1], { extrapolateRight: 'clamp' }),
          }}>
            <Phone width={400}><Img src={staticFile(`shots/${p.file}`)} style={{ width: 400, display: 'block' }} /></Phone>
          </div>
        );
      })}
      <div style={{ position: 'absolute', left: 140, top: 190, width: 900, zIndex: 5 }}>
        <Img src={staticFile('brand/icon.png')} style={{
          width: 132, height: 132, borderRadius: 32, boxShadow: '0 20px 50px rgba(0,0,0,0.45)',
          transform: `scale(${pop}) rotate(${(1 - pop) * -20}deg)`,
        }} />
        <h1 style={{ margin: '30px 0 0', fontFamily: DISPLAY, fontWeight: 800, fontSize: 230, lineHeight: 0.9, color: C.sand, display: 'flex' }}>
          {word.split('').map((ch, i) => {
            const s = spring({ frame: frame - 10 - i * 2.5, fps, config: { damping: 14, stiffness: 110 } });
            return (
              <span key={i} style={{ display: 'inline-block', transform: `translateY(${(1 - s) * 120}px) rotateX(${(1 - s) * 80}deg)`, opacity: s, color: i >= 4 ? C.moss : C.sand }}>{ch}</span>
            );
          })}
        </h1>
        <Rise delay={34}>
          <p style={{ margin: '24px 0 0', fontFamily: BODY, fontSize: 40, lineHeight: 1.3, color: C.mist, maxWidth: 820 }}>
            Sewa alat hiking &amp; camping dari banyak toko, dalam satu aplikasi.
          </p>
        </Rise>
        <div style={{ marginTop: 44, display: 'flex', flexWrap: 'wrap', gap: 14, maxWidth: 860 }}>
          {POINTS.map((t, i) => (
            <Rise key={t} delay={70 + i * 9} distance={20}>
              <span style={{ display: 'inline-block', padding: '12px 22px', borderRadius: 999, border: `1.5px solid ${C.line}`, background: 'rgba(46,107,79,0.22)', fontFamily: BODY, fontSize: 26, color: C.sand }}>
                {t}
              </span>
            </Rise>
          ))}
        </div>
      </div>
      <div style={{ position: 'absolute', left: 140, top: 880, zIndex: 5 }}>
        <Caption lines={scene.lines} width={860} size={32} />
      </div>
      <Voice scene={scene} />
    </AbsoluteFill>
  );
};
