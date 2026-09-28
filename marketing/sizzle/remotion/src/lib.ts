import React, {createContext, useContext, useEffect, useState} from 'react';
import {continueRender, delayRender, spring, SpringConfig} from 'remotion';
import {BEAT, FLASHES, FPS, PALETTE, SHAKES} from './timeline';

export const FONT = 'Lilita One';

// ── Font readiness + text measurement ───────────────────────────────────────
export const FontReadyContext = createContext(false);

export const useFontsReadyState = () => {
  const [ready, setReady] = useState(false);
  const [handle] = useState(() => delayRender('Lilita One'));
  useEffect(() => {
    document.fonts
      .load(`100px "${FONT}"`)
      .then(() => document.fonts.ready)
      .then(() => {
        setReady(true);
        continueRender(handle);
      })
      .catch(() => {
        setReady(true);
        continueRender(handle);
      });
  }, [handle]);
  return ready;
};

let ctx2d: CanvasRenderingContext2D | null = null;
const cache = new Map<string, number>();
export const measure = (text: string, size: number, spacingEm = 0): number => {
  const key = `${text}|${size}|${spacingEm}`;
  const hit = cache.get(key);
  if (hit !== undefined) return hit;
  if (!ctx2d) ctx2d = document.createElement('canvas').getContext('2d');
  if (!ctx2d) return text.length * size * 0.55;
  ctx2d.font = `${size}px "${FONT}"`;
  const w = ctx2d.measureText(text).width + spacingEm * size * Math.max(0, text.length - 1);
  cache.set(key, w);
  return w;
};

export const useFontReady = () => useContext(FontReadyContext);

/** largest font size ≤ base such that text fits maxW */
export const fitSize = (text: string, base: number, maxW: number, spacingEm = 0) => {
  const w = measure(text, base, spacingEm);
  return w > maxW ? (base * maxW) / w : base;
};

// ── Styles ──────────────────────────────────────────────────────────────────
/** Chunky game-UI text: fill + thick ink outline (stroke painted under the fill) + hard drop. */
export const inkText = (size: number, fill: string, opts: {stroke?: number; drop?: number; soft?: boolean} = {}): React.CSSProperties => {
  const w = opts.stroke ?? size * 0.075;
  const d = opts.drop ?? size * 0.06;
  return {
    fontFamily: FONT,
    fontSize: size,
    lineHeight: 1,
    color: fill,
    WebkitTextStroke: `${w * 2}px ${PALETTE.ink}`,
    paintOrder: 'stroke fill',
    textShadow: `0 ${d}px 0 ${PALETTE.ink}${opts.soft === false ? '' : `, 0 ${d * 1.6}px ${d * 2.2}px rgba(0,0,0,0.45)`}`,
    whiteSpace: 'nowrap',
  } as React.CSSProperties;
};

// ── Math / motion helpers ──────────────────────────────────────────────────
export const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/** smooth-ish deterministic noise in [-1,1] */
export const noise = (seed: number, t: number) =>
  (Math.sin(t * 1.7 + seed * 12.9898) * 0.5 + Math.sin(t * 3.1 + seed * 78.233) * 0.3 + Math.sin(t * 5.3 + seed * 37.719) * 0.2);

/** spring value at time t (s) since start; returns 0 before start */
export const springAt = (t: number, start: number, config: Partial<SpringConfig> = {}, durationInFrames?: number) => {
  const fr = (t - start) * FPS;
  if (fr < 0) return 0;
  return spring({frame: fr, fps: FPS, config: {damping: 12, stiffness: 180, mass: 0.8, ...config}, durationInFrames});
};

/** decaying hit envelope, 0 before t0 */
export const hitEnv = (t: number, t0: number, decay: number) => (t < t0 ? 0 : Math.exp(-(t - t0) / decay));

/** beat pulse: 1 on every beat, decaying */
export const beatPulse = (t: number, decay = 0.09, offset = 0) => {
  const ph = (((t - offset) % BEAT) + BEAT) % BEAT;
  return Math.exp(-ph / decay);
};

export const shakeAt = (t: number) => {
  let amp = 0;
  for (const h of SHAKES) amp += h.amp * hitEnv(t, h.t, h.decay ?? 0.1);
  // fast jitter
  const tt = t * 38;
  return {x: amp * noise(1, tt), y: amp * noise(2, tt * 1.1), r: amp * 0.05 * noise(3, tt * 0.9), amp};
};

export const flashAt = (t: number): {opacity: number; color: string} => {
  let best = 0;
  let color = '#FFFFFF';
  for (const fl of FLASHES) {
    const fr = (t - fl.t) * FPS;
    if (fr < 0 || fr >= fl.frames + 1) continue;
    const o = fl.opacity * Math.pow(1 - fr / (fl.frames + 1), 1.4);
    if (o > best) {
      best = o;
      color = fl.color ?? '#FFFFFF';
    }
  }
  return {opacity: best, color};
};

/** springs between successive keyframe values */
export const springKeys = (t: number, keys: {t: number; v: number}[], config: Partial<SpringConfig> = {damping: 14, stiffness: 120}) => {
  if (keys.length === 0) return 0;
  let v = keys[0].v;
  for (let i = 1; i < keys.length; i++) {
    const s = springAt(t, keys[i].t, config);
    v += (keys[i].v - keys[i - 1].v) * s;
  }
  return v;
};

/** pseudo-random from integer seed */
export const rnd = (seed: number) => {
  const x = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};
