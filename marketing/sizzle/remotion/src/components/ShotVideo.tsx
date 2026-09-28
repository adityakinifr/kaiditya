import React from 'react';
import {AbsoluteFill, Easing, interpolate, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import {clamp, rnd, springAt} from '../lib';
import {FPS, Shot} from '../timeline';

export const SRC_W = 1320;
export const SRC_H = 2868;

export type Layout = 'vertical' | 'landscape';

const centreAt = (shot: Shot, srcT: number): [number, number] => {
  if (!shot.track) return [shot.cx ?? 0.5, shot.cy ?? 0.5];
  const tr = shot.track;
  if (srcT <= tr[0][0]) return [tr[0][1], tr[0][2]];
  for (let i = 1; i < tr.length; i++) {
    if (srcT <= tr[i][0]) {
      const k = (srcT - tr[i - 1][0]) / (tr[i][0] - tr[i - 1][0]);
      const e = Easing.inOut(Easing.sin)(k);
      return [tr[i - 1][1] + (tr[i][1] - tr[i - 1][1]) * e, tr[i - 1][2] + (tr[i][2] - tr[i - 1][2]) * e];
    }
  }
  const l = tr[tr.length - 1];
  return [l[1], l[2]];
};

/** One gameplay shot, rendered into a W×H box. Must be inside a <Sequence from={shot.start}>. */
export const ShotVideo: React.FC<{shot: Shot; W: number; H: number; layout: Layout; mediaOnly?: boolean}> = ({shot, W, H, layout}) => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const dur = shot.end - shot.start;
  const fx = shot.fx ?? {};
  const k = W / 1080; // scale factor for px-based effects

  // Ken Burns push
  const push = shot.push ?? shot.punch * 1.08;
  let zoom = interpolate(t, [0, dur], [shot.punch, push], {easing: Easing.inOut(Easing.quad), extrapolateRight: 'clamp'});
  // zoom-punch on entry
  if (fx.punchIn) zoom *= 1 + 0.16 * (1 - springAt(t, 0, {damping: 15, stiffness: 260, mass: 0.6}));

  // suck-out (cold open end): shrink + spin into black
  let suck = 0;
  if (fx.suckOut) suck = interpolate(t, [dur - 0.24, dur], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic)});

  const cover = Math.max(W / SRC_W, H / SRC_H);
  const vw = SRC_W * cover * zoom;
  const vh = SRC_H * cover * zoom;
  const [cx, cy] = centreAt(shot, shot.src + t);
  const left = clamp(W / 2 - cx * vw, W - vw, 0);
  const top = clamp(H / 2 - cy * vh, H - vh, 0);

  // whip pans
  let whipX = 0;
  let blurX = 0;
  const WHIP = 8 / FPS;
  if (fx.whipOut && t > dur - WHIP) {
    const p = Easing.in(Easing.cubic)((t - (dur - WHIP)) / WHIP);
    whipX = -W * 1.1 * p;
    blurX = 70 * k * Math.sin(Math.min(1, p * 1.3) * Math.PI * 0.5);
  }
  if (fx.whipIn && t < WHIP) {
    const p = Easing.out(Easing.cubic)(t / WHIP);
    whipX = W * 1.1 * (1 - p);
    blurX = 70 * k * (1 - p);
  }

  // RGB split + glitch
  let rgb = 0;
  let disp = 0;
  let flicker = 1;
  if (fx.rgbIn) rgb = fx.rgbIn * k * Math.exp(-t / 0.075);
  if (fx.glitchOut) {
    const g = interpolate(t, [dur - 0.14, dur], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
    const r = rnd(frame + shot.start * 100);
    rgb = Math.max(rgb, (8 + 40 * g) * k * (0.6 + r));
    disp = g * 90 * k * (r > 0.3 ? 1 : 0.2);
    flicker = g > 0 ? (r > 0.25 ? 1 : 0.35) * (1 - g * 0.5) : 1;
    // entry glitch too (first 3 frames)
    if (frame < 3) {
      rgb = Math.max(rgb, (30 - frame * 9) * k);
      disp = Math.max(disp, (3 - frame) * 16 * k);
    }
  }
  if (suck > 0) rgb = Math.max(rgb, suck * 40 * k);

  // grade
  const grade = fx.grade ?? 'normal';
  let filter = 'contrast(1.08) saturate(1.18) brightness(1.03)';
  if (grade === 'dim') filter = layout === 'vertical' ? 'contrast(1.05) saturate(1.0) brightness(0.5) blur(3px)' : 'contrast(1.06) saturate(1.1) brightness(0.92)';
  if (grade === 'build') filter = `contrast(1.14) saturate(${interpolate(t, [0, dur], [0.8, 0.6])}) brightness(${interpolate(t, [0, dur], [1.05, 0.92])})`;
  if (grade === 'bright') filter = 'contrast(1.06) saturate(1.28) brightness(1.06)';
  if (suck > 0) filter += ` brightness(${1 + suck * 0.8})`;

  const filterId = `f-${layout}-${shot.id}`;
  const needsSvg = rgb > 0.3 || disp > 0.3 || blurX > 0.3;
  const seed = frame % 97;

  const scale = suck > 0 ? 1 - suck * 0.96 : 1;
  const rot = suck * 28;

  return (
    <AbsoluteFill style={{overflow: 'hidden', backgroundColor: '#07080d'}}>
      {needsSvg ? (
        <svg width={0} height={0} style={{position: 'absolute'}}>
          <defs>
            <filter id={filterId} x="-20%" y="-5%" width="140%" height="110%" colorInterpolationFilters="sRGB">
              <feTurbulence type="fractalNoise" baseFrequency={`0.00001 ${0.012 / k}`} numOctaves={1} seed={seed} result="noise" />
              <feComponentTransfer in="noise" result="bands">
                <feFuncR type="discrete" tableValues="0.5 0.5 0.1 0.5 0.9 0.5 0.5 0.3 0.5" />
                <feFuncG type="linear" slope={0} intercept={0.5} />
              </feComponentTransfer>
              <feDisplacementMap in="SourceGraphic" in2="bands" scale={disp} xChannelSelector="R" yChannelSelector="G" result="disp" />
              <feGaussianBlur in="disp" stdDeviation={`${blurX} 0`} result="blur" />
              <feColorMatrix in="blur" type="matrix" values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="r" />
              <feOffset in="r" dx={-rgb} dy={0} result="ro" />
              <feColorMatrix in="blur" type="matrix" values="0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0" result="g" />
              <feColorMatrix in="blur" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0" result="b" />
              <feOffset in="b" dx={rgb} dy={rgb * 0.25} result="bo" />
              <feBlend in="ro" in2="g" mode="screen" result="rg" />
              <feBlend in="rg" in2="bo" mode="screen" />
            </filter>
          </defs>
        </svg>
      ) : null}
      <AbsoluteFill
        style={{
          filter: needsSvg ? `url(#${filterId}) ${filter}` : filter,
          opacity: flicker,
          transform: `translateX(${whipX}px) scale(${scale}) rotate(${rot}deg)`,
        }}
      >
        <OffthreadVideo
          src={staticFile(`clips/${shot.clip}.mp4`)}
          trimBefore={Math.round(shot.src * FPS)}
          muted
          style={{position: 'absolute', left, top, width: vw, height: vh, maxWidth: 'none'}}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
