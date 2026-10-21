import React from 'react';
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { TransitionSeries, linearTiming } from '@remotion/transitions';
import { fade } from '@remotion/transitions/fade';
import { DesktopScene, PhoneScene } from './scenes/AppScene';
import { Intro } from './scenes/Intro';
import { Outro } from './scenes/Outro';
import { TRANSITION, sceneStarts, scenes, totalFrames } from './plan';
import { BODY, C, DISPLAY } from './theme';

const SceneView: React.FC<{ index: number }> = ({ index }) => {
  const scene = scenes[index];
  if (scene.kind === 'intro') return <Intro scene={scene} />;
  if (scene.kind === 'outro') return <Outro scene={scene} />;
  if (scene.kind === 'desktop') return <DesktopScene scene={scene} />;
  return <PhoneScene scene={scene} />;
};

/** Brand mark and a chapter progress bar, shown between the intro and the outro. */
const Chrome: React.FC = () => {
  const frame = useCurrentFrame();
  const appStart = sceneStarts[1];
  const appEnd = sceneStarts[scenes.length - 1] + TRANSITION;
  const show = interpolate(frame, [appStart, appStart + 20, appEnd - 20, appEnd], [0, 1, 1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const progress = Math.min(1, Math.max(0, (frame - appStart) / (appEnd - appStart)));
  const chapters = scenes.slice(1, -1);
  return (
    <AbsoluteFill style={{ opacity: show, pointerEvents: 'none' }}>
      <div style={{ position: 'absolute', left: 46, top: 34, display: 'flex', alignItems: 'center', gap: 14 }}>
        <Img src={staticFile('brand/icon.png')} style={{ width: 44, height: 44, borderRadius: 11 }} />
        <span style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 36, color: C.sand }}>RentGear</span>
        <span style={{ marginLeft: 8, fontFamily: BODY, fontSize: 20, color: C.mist }}>Cara pakai</span>
      </div>
      <div style={{ position: 'absolute', left: 46, right: 46, bottom: 26, height: 5, borderRadius: 3, background: 'rgba(183,201,189,0.16)' }}>
        <div style={{ height: '100%', width: `${progress * 100}%`, borderRadius: 3, background: `linear-gradient(90deg, ${C.forest}, ${C.summit})` }} />
        {chapters.map((s, i) => (
          <i key={s.id} style={{
            position: 'absolute', top: -3, width: 2, height: 11, background: 'rgba(243,237,223,0.35)',
            left: `${((sceneStarts[i + 1] - appStart) / (appEnd - appStart)) * 100}%`,
          }} />
        ))}
      </div>
    </AbsoluteFill>
  );
};

export const Demo: React.FC = () => (
  <AbsoluteFill style={{ background: C.night }}>
    <TransitionSeries>
      {scenes.flatMap((s, i) => [
        ...(i > 0 ? [<TransitionSeries.Transition key={`t-${s.id}`} presentation={fade()} timing={linearTiming({ durationInFrames: TRANSITION })} />] : []),
        <TransitionSeries.Sequence key={s.id} durationInFrames={s.duration}>
          <SceneView index={i} />
        </TransitionSeries.Sequence>,
      ])}
    </TransitionSeries>
    <Chrome />
  </AbsoluteFill>
);

export { totalFrames };
