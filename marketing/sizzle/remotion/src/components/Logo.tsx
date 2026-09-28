import React from 'react';
import {Img, staticFile, useCurrentFrame} from 'remotion';
import {beatPulse, FONT, measure, springAt, useFontReady} from '../lib';
import {BAR, BEAT, FPS, PALETTE} from '../timeline';

const WORD = 'KAIDITYA';
const SPACING = 0.03;

/**
 * Code-built KAIDITYA logo: yellow gradient face, ink outline, deep extrusion,
 * specular shine sweep, spring slam with squash & stretch, beat pulse.
 * (x, y) is the centre of the word; `size` is font size in px.
 */
export const Logo: React.FC<{x: number; y: number; size: number; at: number; exitAt?: number}> = ({x, y, size, at, exitAt}) => {
  useFontReady();
  const frame = useCurrentFrame();
  const t = frame / FPS - at;
  if (t < 0) return null;

  const W = size * 0.085; // outline half-width
  const E = size * 0.085; // extrusion depth
  const widths = WORD.split('').map((c) => measure(c, size));
  const total = widths.reduce((a, b) => a + b, 0) + SPACING * size * (WORD.length - 1);
  const lefts: number[] = [];
  let acc = 0;
  for (const w of widths) {
    lefts.push(acc);
    acc += w + SPACING * size;
  }

  // slam: from huge → 1 with a stiff spring, then squash & stretch wobble
  const slam = springAt(t, 0, {damping: 18, stiffness: 320, mass: 0.7});
  const base = 2.8 - 1.8 * slam;
  const land = 0.075;
  const sq = t > land ? Math.exp(-(t - land) / 0.16) * Math.sin(((t - land) / 0.26) * Math.PI * 2 + Math.PI / 2) : 0;
  const pulse = t > 0.5 ? beatPulse(t + at, 0.1) * 0.025 : 0;
  let sx = base * (1 + 0.16 * sq + pulse);
  let sy = base * (1 - 0.2 * sq + pulse);
  let opacity = Math.min(1, t * FPS / 3);

  // zoom-through exit
  if (exitAt !== undefined) {
    const e = frame / FPS - exitAt;
    if (e > 0) {
      const p = Math.min(1, e / (7 / FPS));
      sx *= 1 + p * p * 2.5;
      sy *= 1 + p * p * 2.5;
      opacity *= 1 - p;
    }
  }

  // shine sweep every 2 bars, starting 0.35 s after slam
  const shineT = t - 0.35;
  const shinePeriod = BAR * 2;
  const shineP = shineT < 0 ? -1 : (shineT % shinePeriod) / 0.55;
  const bandX = shineP >= 0 && shineP <= 1 ? -0.3 * total + shineP * 1.6 * total : -99999;

  const pad = size * 0.25; // background-clip:text only paints inside the box — pad so overhanging glyph parts get filled
  const fontBase: React.CSSProperties = {fontFamily: FONT, fontSize: size, lineHeight: 1, position: 'absolute', left: -pad, top: 0, padding: `0 ${pad}px`, whiteSpace: 'pre'};

  return (
    <div
      style={{
        position: 'absolute',
        left: x - total / 2,
        top: y - size * 0.55,
        width: total,
        height: size * 1.1,
        transform: `scale(${sx}, ${sy})`,
        transformOrigin: '50% 60%',
        opacity,
        filter: `drop-shadow(0 ${size * 0.09}px 0 rgba(8,10,24,0.55)) drop-shadow(0 ${size * 0.1}px ${size * 0.12}px rgba(0,0,0,0.45))`,
      }}
    >
      {WORD.split('').map((ch, i) => {
        // per-letter jiggle wave after the slam
        const lt = t - 0.06 - i * 0.028;
        const wob = lt > 0 ? Math.exp(-lt / 0.2) * Math.sin(lt * 26) : 0;
        const ly = -wob * size * 0.12 + Math.sin((t + at) * Math.PI * 2 / (BEAT * 4) + i * 0.7) * size * 0.012;
        const lr = (i % 2 ? 1 : -1) * 2.5 + wob * 6 * (i % 2 ? 1 : -1);
        const inkCopies = [];
        for (let d = 0; d <= E; d += Math.max(2, E / 6)) inkCopies.push(d);
        inkCopies.push(E);
        const fillCopies = [];
        for (let d = 1; d <= E; d += Math.max(1.5, E / 10)) fillCopies.push(d);
        const shineLeft = bandX - lefts[i] + pad;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: lefts[i],
              top: size * 0.05,
              width: widths[i],
              height: size,
              transform: `translateY(${ly}px) rotate(${lr}deg)`,
              transformOrigin: '50% 80%',
            }}
          >
            {/* ink silhouette (outline around face + extrusion) */}
            {inkCopies.map((d, k) => (
              <span key={`i${k}`} style={{...fontBase, top: d, color: PALETTE.ink, WebkitTextStroke: `${W * 2}px ${PALETTE.ink}`, strokeLinejoin: 'round'} as React.CSSProperties}>
                {ch}
              </span>
            ))}
            {/* extrusion */}
            {fillCopies.map((d, k) => (
              <span key={`e${k}`} style={{...fontBase, top: d, color: k === fillCopies.length - 1 ? '#A8620A' : PALETTE.yellowDeep}}>
                {ch}
              </span>
            ))}
            {/* face */}
            <span
              style={{
                ...fontBase,
                color: 'transparent',
                backgroundImage: 'linear-gradient(180deg, #FFF4B8 0%, #FFE066 28%, #FFD140 55%, #FFB21A 100%)',
                WebkitBackgroundClip: 'text',
                backgroundClip: 'text',
              }}
            >
              {ch}
            </span>
            {/* inner top highlight */}
            <span
              style={{
                ...fontBase,
                color: 'transparent',
                backgroundImage: 'linear-gradient(180deg, rgba(255,255,255,0.75) 0%, rgba(255,255,255,0) 30%)',
                WebkitBackgroundClip: 'text',
                backgroundClip: 'text',
                mixBlendMode: 'screen',
              }}
            >
              {ch}
            </span>
            {/* specular shine sweep */}
            {bandX > -9999 ? (
              <span
                style={{
                  ...fontBase,
                  color: 'transparent',
                  backgroundImage: `linear-gradient(105deg, rgba(255,255,255,0) ${shineLeft - size * 0.5}px, rgba(255,255,255,0.95) ${shineLeft}px, rgba(255,255,255,0) ${shineLeft + size * 0.35}px)`,
                  WebkitBackgroundClip: 'text',
                  backgroundClip: 'text',
                }}
              >
                {ch}
              </span>
            ) : null}
          </div>
        );
      })}
    </div>
  );
};

/** Hero sprite that pops in with a bounce and then dances on the beat. */
export const Hero: React.FC<{x: number; y: number; size: number; at: number; flip?: boolean}> = ({x, y, size, at}) => {
  const frame = useCurrentFrame();
  const gt = frame / FPS;
  const t = gt - at;
  if (t < 0) return null;
  const pop = springAt(t, 0, {damping: 9, stiffness: 170, mass: 0.7});
  // dance: step frames on half-beats, hop + squash on beats
  const half = Math.floor(gt / (BEAT / 2));
  const frames = ['hero_walk_s_1', 'hero_idle_s', 'hero_walk_s_3', 'hero_idle_s'];
  const sprite = t < 0.35 ? 'hero_idle_s' : frames[half % 4];
  const ph = ((gt % BEAT) + BEAT) % BEAT / BEAT;
  const hop = t > 0.35 ? Math.sin(ph * Math.PI) * size * 0.05 : 0;
  const squash = t > 0.35 ? Math.exp(-ph / 0.12) * 0.08 : 0;
  const lean = t > 0.35 ? Math.sin(gt * Math.PI * 2 / (BEAT * 2)) * 5 : 0;
  // blink-ish sparkle is handled by Sparkle twinkles; here a subtle breathing
  const s = pop;
  return (
    <div style={{position: 'absolute', left: x - size / 2, top: y - size, width: size, height: size}}>
      {/* contact shadow */}
      <div
        style={{
          position: 'absolute',
          left: size * 0.28,
          top: size * 0.86,
          width: size * 0.44,
          height: size * 0.09,
          borderRadius: '50%',
          background: 'rgba(5,6,20,0.45)',
          filter: `blur(${size * 0.02}px)`,
          transform: `scale(${s * (1 - hop / size)})`,
        }}
      />
      <Img
        src={staticFile(`sprites/${sprite}.png`)}
        style={{
          position: 'absolute',
          width: size,
          height: size,
          transform: `translateY(${-hop + (1 - s) * size * 0.3}px) scale(${s * (1 + squash)}, ${s * (1 - squash)}) rotate(${lean}deg)`,
          transformOrigin: '50% 88%',
          filter: `drop-shadow(0 0 ${size * 0.02}px rgba(26,31,46,0.9)) drop-shadow(0 ${size * 0.03}px 0 rgba(26,31,46,0.35))`,
          imageRendering: 'auto',
        }}
      />
    </div>
  );
};

