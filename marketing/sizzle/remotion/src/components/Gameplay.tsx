import React from 'react';
import {AbsoluteFill, Sequence, useCurrentFrame} from 'remotion';
import {beatPulse, rnd} from '../lib';
import {f, FPS, SECTIONS, SHOTS} from '../timeline';
import {Layout, ShotVideo} from './ShotVideo';

const sec = (name: string) => SECTIONS.find((s) => s.name === name)!;

const SpeedLines: React.FC<{W: number; H: number; t0: number}> = ({W, H}) => {
  const frame = useCurrentFrame();
  const lines = Array.from({length: 26}, (_, i) => {
    const x = rnd(i * 3.1) * W;
    const len = (0.18 + rnd(i * 7.7) * 0.3) * H;
    const speed = (1.6 + rnd(i * 1.3) * 1.8) * H; // px / s
    const y = ((rnd(i * 5.2) * (H + len) + (frame / FPS) * speed) % (H + len)) - len;
    const w = (1.5 + rnd(i * 9.1) * 3) * (W / 1080);
    return (
      <div
        key={i}
        style={{
          position: 'absolute',
          left: x,
          top: y,
          width: w,
          height: len,
          borderRadius: w,
          background: 'linear-gradient(180deg, rgba(255,255,255,0), rgba(255,255,255,0.55), rgba(255,255,255,0))',
          opacity: 0.5,
        }}
      />
    );
  });
  return <AbsoluteFill style={{mixBlendMode: 'screen'}}>{lines}</AbsoluteFill>;
};

const BuildVignette: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const dur = sec('build').end - sec('build').start;
  const ramp = Math.min(1, t / dur);
  const p = beatPulse(t, 0.14);
  const a = 0.35 + 0.35 * ramp + 0.25 * p;
  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse 70% 60% at 50% 45%, rgba(0,0,0,0) 35%, rgba(120,20,90,${a * 0.6}) 70%, rgba(60,0,40,${a}) 100%)`,
        mixBlendMode: 'multiply',
      }}
    >
      <AbsoluteFill style={{background: `radial-gradient(ellipse 80% 70% at 50% 45%, rgba(0,0,0,0) 45%, rgba(240,50,90,${0.18 + 0.22 * p * ramp}) 100%)`, mixBlendMode: 'screen'}} />
    </AbsoluteFill>
  );
};

/** All gameplay shots, cut on the grid, rendered into a W×H box. */
export const Gameplay: React.FC<{W: number; H: number; layout: Layout}> = ({W, H, layout}) => {
  const chase = sec('chase');
  const build = sec('build');
  return (
    <AbsoluteFill style={{width: W, height: H, overflow: 'hidden', backgroundColor: '#06070b'}}>
      {SHOTS.map((s) => (
        <Sequence key={s.id} from={f(s.start)} durationInFrames={f(s.end) - f(s.start)} name={`${s.id} ${s.clip}@${s.src}`}>
          <ShotVideo shot={s} W={W} H={H} layout={layout} />
        </Sequence>
      ))}
      <Sequence from={f(chase.start)} durationInFrames={f(chase.end) - f(chase.start)} name="speed lines">
        <SpeedLines W={W} H={H} t0={chase.start} />
      </Sequence>
      <Sequence from={f(build.start)} durationInFrames={f(build.end) - f(build.start)} name="build vignette">
        <BuildVignette />
      </Sequence>
    </AbsoluteFill>
  );
};
