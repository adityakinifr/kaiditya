import React from 'react';
import {Composition, staticFile} from 'remotion';
import {loadFont} from '@remotion/fonts';
import {SizzleLandscape, SizzleVertical} from './Sizzle';
import {DURATION_FRAMES, FPS} from './timeline';

loadFont({family: 'Lilita One', url: staticFile('fonts/LilitaOne-Regular.ttf'), weight: '400'});

export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="SizzleVertical" component={SizzleVertical} durationInFrames={DURATION_FRAMES} fps={FPS} width={1080} height={1920} />
    <Composition id="SizzleLandscape" component={SizzleLandscape} durationInFrames={DURATION_FRAMES} fps={FPS} width={1920} height={1080} />
  </>
);
