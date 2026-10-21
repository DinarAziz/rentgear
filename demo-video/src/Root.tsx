import React from 'react';
import { Composition } from 'remotion';
import { Demo, totalFrames } from './Demo';
import { FPS, HEIGHT, WIDTH } from './plan';
import './theme';

export const RemotionRoot: React.FC = () => (
  <Composition id="RentGearDemo" component={Demo} durationInFrames={totalFrames} fps={FPS} width={WIDTH} height={HEIGHT} />
);
