import React, { useMemo } from 'react';
import { AbsoluteFill, random, useCurrentFrame } from 'remotion';
import { C } from '../theme';

/** Contour lines like a topographic map, drifting slowly over a dark pine gradient. */
export const Background: React.FC<{ seed?: string }> = ({ seed = 'topo' }) => {
  const frame = useCurrentFrame();
  const paths = useMemo(() => {
    const lines: string[] = [];
    for (let i = 0; i < 14; i++) {
      const y0 = 60 + i * 74;
      const amp = 18 + random(`${seed}-a${i}`) * 34;
      const phase = random(`${seed}-p${i}`) * Math.PI * 2;
      const pts: string[] = [];
      for (let x = -40; x <= 1960; x += 40) {
        const y = y0 + Math.sin(x / 260 + phase) * amp + Math.sin(x / 97 + phase * 2) * amp * 0.25;
        pts.push(`${x},${y.toFixed(1)}`);
      }
      lines.push(`M${pts.join(' L')}`);
    }
    return lines;
  }, [seed]);

  return (
    <AbsoluteFill style={{ background: `radial-gradient(120% 90% at 78% 18%, ${C.pine} 0%, ${C.night} 62%)` }}>
      <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0, transform: `translateX(${-(frame * 0.35) % 80}px)` }}>
        {paths.map((d, i) => (
          <path key={i} d={d} fill="none" stroke={i % 4 === 0 ? 'rgba(143,195,162,0.13)' : 'rgba(183,201,189,0.06)'} strokeWidth={i % 4 === 0 ? 1.6 : 1.1} />
        ))}
      </svg>
      <AbsoluteFill style={{ background: 'radial-gradient(40% 50% at 22% 55%, rgba(46,107,79,0.32), transparent 70%)' }} />
    </AbsoluteFill>
  );
};
