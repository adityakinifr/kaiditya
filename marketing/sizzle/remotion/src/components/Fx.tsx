import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {flashAt, rnd} from '../lib';
import {FPS, PALETTE} from '../timeline';

export const Grain: React.FC<{opacity?: number}> = ({opacity = 0.07}) => {
  const frame = useCurrentFrame();
  const g = Math.floor(frame / 2); // ~30 fps grain, reads more filmic
  const tile = g % 8;
  const ox = Math.floor(rnd(g) * 512);
  const oy = Math.floor(rnd(g + 0.5) * 512);
  return (
    <AbsoluteFill
      style={{
        backgroundImage: `url(${staticFile(`noise/n${tile}.png`)})`,
        backgroundPosition: `${ox}px ${oy}px`,
        backgroundSize: '384px 384px',
        mixBlendMode: 'overlay',
        opacity,
        pointerEvents: 'none',
      }}
    />
  );
};

export const Vignette: React.FC<{strength?: number}> = ({strength = 0.5}) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse 75% 70% at 50% 50%, rgba(0,0,0,0) 55%, rgba(5,6,14,${strength * 0.55}) 80%, rgba(5,6,14,${strength}) 100%)`,
      pointerEvents: 'none',
    }}
  />
);

/** Drifting warm light leaks (screen blend). */
export const LightLeak: React.FC<{intensity: number; seed?: number}> = ({intensity, seed = 0}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  if (intensity <= 0.001) return null;
  const t = frame / FPS;
  const blobs = [
    {c: '255,150,60', x: 0.1 + 0.25 * Math.sin(t * 0.7 + seed), y: 0.15 + 0.1 * Math.cos(t * 0.5 + seed), r: 0.75},
    {c: '255,61,127', x: 0.95 - 0.2 * Math.sin(t * 0.55 + seed * 2), y: 0.8 + 0.1 * Math.sin(t * 0.8), r: 0.7},
    {c: '255,209,64', x: 0.6 + 0.3 * Math.sin(t * 0.35 + 1 + seed), y: 0.05, r: 0.55},
  ];
  const m = Math.max(width, height);
  return (
    <AbsoluteFill style={{mixBlendMode: 'screen', opacity: intensity, pointerEvents: 'none'}}>
      {blobs.map((b, i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: b.x * width - (b.r * m) / 2,
            top: b.y * height - (b.r * m) / 2,
            width: b.r * m,
            height: b.r * m,
            borderRadius: '50%',
            background: `radial-gradient(circle, rgba(${b.c},0.55) 0%, rgba(${b.c},0.18) 35%, rgba(${b.c},0) 70%)`,
          }}
        />
      ))}
    </AbsoluteFill>
  );
};

export const FlashOverlay: React.FC = () => {
  const frame = useCurrentFrame();
  const {opacity, color} = flashAt(frame / FPS);
  if (opacity <= 0.001) return null;
  return <AbsoluteFill style={{backgroundColor: color, opacity, pointerEvents: 'none'}} />;
};

/** Rotating sunburst rays with a warm core glow. */
export const Sunburst: React.FC<{
  cx?: number;
  cy?: number;
  rays?: number;
  c1?: string;
  c2?: string;
  speed?: number; // deg / s
  glow?: string;
  glowSize?: number;
  opacity?: number;
}> = ({cx = 0.5, cy = 0.5, rays = 20, c1 = PALETTE.navy, c2 = '#2B3170', speed = 9, glow = 'rgba(255,209,64,0.55)', glowSize = 0.5, opacity = 1}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const rot = (frame / FPS) * speed;
  const seg = 360 / rays;
  const m = Math.hypot(width, height) * 1.1;
  return (
    <AbsoluteFill style={{overflow: 'hidden', opacity}}>
      <div
        style={{
          position: 'absolute',
          left: cx * width - m / 2,
          top: cy * height - m / 2,
          width: m,
          height: m,
          background: `repeating-conic-gradient(from ${rot}deg at 50% 50%, ${c1} 0deg ${seg * 0.5 - 0.4}deg, ${c2} ${seg * 0.5 + 0.4}deg ${seg - 0.4}deg, ${c1} ${seg}deg)`,
        }}
      />
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle at ${cx * 100}% ${cy * 100}%, ${glow} 0%, rgba(0,0,0,0) ${glowSize * 100}%)`,
          mixBlendMode: 'screen',
        }}
      />
      <AbsoluteFill style={{background: `radial-gradient(ellipse at ${cx * 100}% ${cy * 100}%, rgba(0,0,0,0) 30%, rgba(10,12,30,0.75) 100%)`}} />
    </AbsoluteFill>
  );
};

const Star4: React.FC<{size: number; color: string}> = ({size, color}) => (
  <svg width={size} height={size} viewBox="-50 -50 100 100" style={{overflow: 'visible'}}>
    <path d="M0,-50 C6,-10 10,-6 50,0 C10,6 6,10 0,50 C-6,10 -10,6 -50,0 C-10,-6 -6,-10 0,-50Z" fill={color} />
  </svg>
);

/** Burst of 4-point sparkles from (x,y) at time `at` (seconds, local frame basis), plus lingering twinkles. */
export const SparkleBurst: React.FC<{x: number; y: number; at: number; spread: number; count?: number; seed?: number; twinkle?: boolean; scale?: number}> = ({
  x,
  y,
  at,
  spread,
  count = 22,
  seed = 1,
  twinkle = true,
  scale = 1,
}) => {
  const frame = useCurrentFrame();
  const t = frame / FPS - at;
  if (t < 0) return null;
  const colors = ['#FFFFFF', PALETTE.yellow, '#FFF3C4', PALETTE.teal];
  const items: React.ReactNode[] = [];
  for (let i = 0; i < count; i++) {
    const a = rnd(seed * 100 + i) * Math.PI * 2;
    const d = spread * (0.35 + rnd(seed * 200 + i) * 0.75);
    const life = 0.55 + rnd(seed * 300 + i) * 0.5;
    if (t > life) continue;
    const p = t / life;
    const e = 1 - Math.pow(1 - p, 3);
    const s = (18 + rnd(seed * 400 + i) * 34) * scale * Math.sin(Math.min(1, p * 1.0) * Math.PI) ;
    items.push(
      <div
        key={`b${i}`}
        style={{
          position: 'absolute',
          left: x + Math.cos(a) * d * e - s / 2,
          top: y + Math.sin(a) * d * e * 0.8 - s / 2 + p * p * 40 * scale,
          transform: `rotate(${p * 120 * (i % 2 ? 1 : -1)}deg)`,
          filter: 'drop-shadow(0 0 8px rgba(255,240,180,0.9))',
        }}
      >
        <Star4 size={s} color={colors[i % colors.length]} />
      </div>,
    );
  }
  if (twinkle) {
    for (let i = 0; i < 10; i++) {
      const px = x + (rnd(seed * 500 + i) - 0.5) * spread * 1.9;
      const py = y + (rnd(seed * 600 + i) - 0.5) * spread * 0.9;
      const period = 0.9 + rnd(seed * 700 + i) * 0.8;
      const ph = ((t + rnd(seed * 800 + i) * period) % period) / period;
      const s = 26 * scale * Math.max(0, Math.sin(ph * Math.PI)) ** 2;
      if (s < 1 || t < 0.3) continue;
      items.push(
        <div key={`t${i}`} style={{position: 'absolute', left: px - s / 2, top: py - s / 2, filter: 'drop-shadow(0 0 6px rgba(255,255,255,0.9))'}}>
          <Star4 size={s} color="#FFFFFF" />
        </div>,
      );
    }
  }
  return <AbsoluteFill style={{pointerEvents: 'none'}}>{items}</AbsoluteFill>;
};

/** Floating coins & crystals (spinning sprite frames), parallax drift. */
export const FloatingProps: React.FC<{count?: number; seed?: number; opacity?: number; sizeScale?: number; avoid?: {x: number; y: number; r: number}}> = ({
  count = 16,
  seed = 3,
  opacity = 1,
  sizeScale = 1,
}) => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const t = frame / FPS;
  const items = Array.from({length: count}, (_, i) => {
    const depth = 0.35 + rnd(seed * 10 + i) * 0.65; // 1 = near
    const isCoin = i % 3 !== 2;
    const size = (isCoin ? 70 : 80) * (0.5 + depth) * sizeScale * (Math.min(width, height) / 1080);
    const speed = 30 + depth * 70; // px/s upward drift
    const baseX = rnd(seed * 20 + i) * width;
    const span = height + size * 2;
    const y = height + size - (((rnd(seed * 30 + i) * span) + t * speed) % span);
    const x = baseX + Math.sin(t * (0.6 + depth) + i) * 30 * depth;
    const fr = isCoin ? Math.floor(t * 10 + i) % 6 : Math.floor(t * 8 + i) % 8;
    const src = isCoin ? `sprites/coin_${fr}.png` : `sprites/crystal_${fr}.png`;
    const blur = depth < 0.55 ? (0.55 - depth) * 10 : 0;
    return {depth, el: (
      <Img
        key={i}
        src={staticFile(src)}
        style={{
          position: 'absolute',
          left: x - size / 2,
          top: y - size / 2,
          width: size,
          height: size,
          objectFit: 'contain',
          opacity: (0.45 + depth * 0.55) * opacity,
          filter: `blur(${blur}px) drop-shadow(0 6px 10px rgba(0,0,0,0.35))`,
          transform: `rotate(${Math.sin(t + i) * 12}deg)`,
        }}
      />
    )};
  }).sort((a, b) => a.depth - b.depth);
  return <AbsoluteFill style={{pointerEvents: 'none'}}>{items.map((it) => it.el)}</AbsoluteFill>;
};
