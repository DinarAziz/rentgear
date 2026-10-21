import React from 'react';
import { AbsoluteFill, Audio, Sequence, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { Background } from '../components/Background';
import { Caption, Chapter, Rise, Steps, Title, activeStep } from '../components/Panel';
import { Browser, Phone, ScreenStack, useEntrance } from '../components/Screen';
import type { ScenePlan } from '../plan';

/** The narration of a scene, plus a soft click on every tap. */
export const Voice: React.FC<{ scene: ScenePlan }> = ({ scene }) => (
  <>
    {scene.lines.map((l) => (
      <Sequence key={l.file} from={l.from} durationInFrames={l.duration + 6} layout="none">
        <Audio src={staticFile(l.file)} />
      </Sequence>
    ))}
    {scene.beats.filter((b) => b.shot.tap).map((b) => (
      <Sequence key={b.shot.id} from={b.from + b.duration - 1} durationInFrames={6} layout="none">
        <Audio src={staticFile('sfx/tap.wav')} volume={0.55} />
      </Sequence>
    ))}
  </>
);

const PHONE_WIDTH = 430;

export const PhoneScene: React.FC<{ scene: ScenePlan }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const enter = useEntrance(2);
  const drift = Math.sin(frame / 55) * 4;
  return (
    <AbsoluteFill>
      <Background seed={scene.id} />
      <div style={{
        position: 'absolute', left: 345, top: 64,
        transform: `perspective(1800px) translateY(${(1 - enter) * 120 + drift}px) rotateY(${(1 - enter) * -16 + 4}deg) rotateX(${(1 - enter) * 8}deg)`,
        opacity: interpolate(enter, [0, 0.3], [0, 1], { extrapolateRight: 'clamp' }),
      }}>
        <Phone width={PHONE_WIDTH}>
          <ScreenStack beats={scene.beats} width={PHONE_WIDTH} />
        </Phone>
      </div>
      <div style={{ position: 'absolute', left: 930, top: 150, width: 900 }}>
        <Rise delay={4}><Chapter text={scene.chapter ?? ''} /></Rise>
        <Rise delay={9} style={{ marginTop: 22 }}><Title text={scene.title ?? ''} /></Rise>
        <div style={{ marginTop: 56 }}>
          <Steps steps={scene.steps} active={activeStep(scene.lines, frame)} delay={16} />
        </div>
      </div>
      <div style={{ position: 'absolute', left: 930, top: 852 }}>
        <Caption lines={scene.lines} width={880} />
      </div>
      <Voice scene={scene} />
    </AbsoluteFill>
  );
};

const BROWSER_WIDTH = 1240;

export const DesktopScene: React.FC<{ scene: ScenePlan }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const enter = useEntrance(2);
  return (
    <AbsoluteFill>
      <Background seed={scene.id} />
      <div style={{
        position: 'absolute', left: 70, top: 130,
        transform: `perspective(2400px) translateY(${(1 - enter) * 90}px) rotateY(${(1 - enter) * 10 + 2}deg)`,
        transformOrigin: 'left center',
        opacity: interpolate(enter, [0, 0.3], [0, 1], { extrapolateRight: 'clamp' }),
      }}>
        <Browser width={BROWSER_WIDTH} url="rentgear.serverbaik.my.id">
          <ScreenStack beats={scene.beats} width={BROWSER_WIDTH} />
        </Browser>
      </div>
      <div style={{ position: 'absolute', left: 1370, top: 150, width: 490 }}>
        <Rise delay={4}><Chapter text={scene.chapter ?? ''} size={22} /></Rise>
        <Rise delay={9} style={{ marginTop: 20 }}><Title text={scene.title ?? ''} size={82} /></Rise>
        <div style={{ marginTop: 46 }}>
          <Steps steps={scene.steps} active={activeStep(scene.lines, frame)} size={27} delay={16} />
        </div>
      </div>
      <div style={{ position: 'absolute', left: 1370, top: 790 }}>
        <Caption lines={scene.lines} width={480} size={28} />
      </div>
      <Voice scene={scene} />
    </AbsoluteFill>
  );
};
