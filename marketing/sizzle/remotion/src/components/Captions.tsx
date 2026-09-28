import React from 'react';
import {useCurrentFrame} from 'remotion';
import {beatPulse, fitSize, FONT, inkText, measure, rnd, springAt, useFontReady} from '../lib';
import {Caption, CAPTIONS, EARN_STARS_AT, f, FPS, PALETTE} from '../timeline';

export type CaptionGeom = {
  cx: number; // centre x
  tierY: number; // big word centre y
  bigSize: number;
  subSize: number;
  maxW: number;
  kineticY: number;
  kineticSize: number;
  stackY: number[]; // centre y for each stacked word
  stackSize: number;
  stackHugeSize: number;
};

const EXIT = 8 / FPS;

/** per-letter spring in, staggered spring out */
const BigWord: React.FC<{text: string; x: number; y: number; size: number; at: number; out: number; t: number; fill: string; seed: number}> = ({
  text,
  x,
  y,
  size,
  at,
  out,
  t,
  fill,
  seed,
}) => {
  const letters = text.split('');
  const widths = letters.map((c) => measure(c, size));
  const total = widths.reduce((a, b) => a + b, 0);
  let acc = 0;
  const pulse = t - at > 0.3 ? beatPulse(t, 0.1) * 0.04 : 0;
  return (
    <div style={{position: 'absolute', left: x - total / 2, top: y - size * 0.55, width: total, height: size * 1.1, transform: `scale(${1 + pulse})`}}>
      {letters.map((ch, i) => {
        const left = acc;
        acc += widths[i];
        const d = i * (1.6 / FPS);
        const s = springAt(t, at + d, {damping: 10, stiffness: 210, mass: 0.7});
        const r0 = (rnd(seed * 31 + i) - 0.5) * 50;
        // exit: letters pop up & shrink, staggered
        const eStart = out - EXIT - (letters.length - 1 - i) * 0 - i * (0.8 / FPS);
        const ep = Math.max(0, Math.min(1, (t - eStart) / (6 / FPS)));
        const ee = ep * ep;
        const sc = s * (1 - ee);
        if (sc <= 0.001) return null;
        return (
          <span
            key={i}
            style={{
              ...inkText(size, fill),
              position: 'absolute',
              left,
              top: 0,
              display: 'inline-block',
              transform: `translateY(${(1 - s) * size * 0.5 - ee * size * 0.6}px) rotate(${(1 - s) * r0 + ee * 18}deg) scale(${sc})`,
              transformOrigin: '50% 70%',
            }}
          >
            {ch}
          </span>
        );
      })}
    </div>
  );
};

const SubPill: React.FC<{text: string; x: number; y: number; size: number; at: number; out: number; t: number; tilt: number}> = ({text, x, y, size, at, out, t, tilt}) => {
  const s = springAt(t, at, {damping: 12, stiffness: 220, mass: 0.6});
  const ep = Math.max(0, Math.min(1, (t - (out - 6 / FPS)) / (6 / FPS)));
  if (s <= 0.001 || ep >= 1) return null;
  const w = measure(text, size) + size * 1.1;
  const h = size * 1.45;
  const textIn = springAt(t, at + 2 / FPS, {damping: 14, stiffness: 200});
  return (
    <div
      style={{
        position: 'absolute',
        left: x - w / 2,
        top: y - h / 2,
        width: w,
        height: h,
        borderRadius: h / 2,
        background: 'rgba(26,31,46,0.92)',
        border: `${size * 0.09}px solid ${PALETTE.white}`,
        boxShadow: `0 ${size * 0.14}px 0 rgba(26,31,46,0.85), 0 ${size * 0.25}px ${size * 0.5}px rgba(0,0,0,0.4)`,
        transform: `rotate(${-tilt * 0.6}deg) scale(${s * (1 - ep)}, ${Math.min(1.15, s) * (1 - ep * ep)})`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      <span style={{fontFamily: FONT, fontSize: size, lineHeight: 1, color: PALETTE.white, whiteSpace: 'nowrap', transform: `translateY(${(1 - textIn) * size}px)`, opacity: textIn}}>{text}</span>
    </div>
  );
};

const StarIcon: React.FC<{size: number}> = ({size}) => (
  <svg width={size} height={size} viewBox="-55 -55 110 110" style={{overflow: 'visible'}}>
    <path
      d="M0,-48 L13.5,-17 L46,-15 L21,6.5 L29,39 L0,21 L-29,39 L-21,6.5 L-46,-15 L-13.5,-17Z"
      fill={PALETTE.yellow}
      stroke={PALETTE.ink}
      strokeWidth={9}
      strokeLinejoin="round"
      paintOrder="stroke"
    />
    <path d="M0,-34 L9,-13 L-2,-10Z" fill="#FFF6C8" opacity={0.9} />
  </svg>
);

const Stars: React.FC<{x: number; y: number; size: number; t: number; out: number}> = ({x, y, size, t, out}) => {
  const ep = Math.max(0, Math.min(1, (t - (out - 6 / FPS)) / (6 / FPS)));
  return (
    <>
      {[0, 1, 2].map((i) => {
        const s = springAt(t, EARN_STARS_AT + i * 0.11, {damping: 8, stiffness: 200, mass: 0.6});
        if (s <= 0.001) return null;
        const sx = x + (i - 1) * size * 1.15;
        const lift = i === 1 ? -size * 0.18 : 0;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: sx - size / 2,
              top: y - size / 2 + lift,
              transform: `scale(${s * (1 - ep)}) rotate(${(1 - s) * -180 + (i - 1) * 10}deg)`,
              filter: 'drop-shadow(0 6px 0 rgba(26,31,46,0.8)) drop-shadow(0 0 18px rgba(255,209,64,0.7))',
            }}
          >
            <StarIcon size={size} />
          </div>
        );
      })}
    </>
  );
};

const TierCaption: React.FC<{c: Extract<Caption, {kind: 'tier'}>; g: CaptionGeom; t: number}> = ({c, g, t}) => {
  const size = fitSize(c.big, g.bigSize, g.maxW);
  const subSize = g.subSize;
  const tilt = c.tilt ?? 0;
  const subY = g.tierY + size * 0.62 + subSize * 0.95;
  return (
    <div style={{position: 'absolute', inset: 0, transform: `rotate(${tilt}deg)`, transformOrigin: `${g.cx}px ${g.tierY}px`}}>
      <BigWord text={c.big} x={g.cx} y={g.tierY} size={size} at={c.bigAt} out={c.out} t={t} fill={PALETTE.yellow} seed={c.id.length} />
      {(c.subs ?? []).map((s, i) => {
        const out = s.out ?? c.out;
        if (t < s.at - 0.01 || t > out + 0.01) return null;
        return <SubPill key={i} text={fitSize(s.text, subSize, g.maxW * 0.9) === subSize ? s.text : s.text} x={g.cx} y={subY} size={fitSize(s.text, subSize, g.maxW * 0.8)} at={s.at} out={out} t={t} tilt={tilt} />;
      })}
      {c.stars ? <Stars x={g.cx} y={subY + subSize * 0.3} size={subSize * 2.1} t={t} out={c.out} /> : null}
    </div>
  );
};

const KineticCaption: React.FC<{c: Extract<Caption, {kind: 'kinetic'}>; g: CaptionGeom; t: number}> = ({c, g, t}) => {
  const lineTexts = c.lines.map((l) => l.words.map((w) => w.text).join(''));
  const size = Math.min(...lineTexts.map((lt) => fitSize(lt, g.kineticSize, g.maxW)));
  const lh = size * 1.02;
  const y0 = g.kineticY - ((c.lines.length - 1) * lh) / 2;
  // exit: whole block punches forward & fades
  const ep = Math.max(0, Math.min(1, (t - (c.out - 6 / FPS)) / (6 / FPS)));
  let wordIdx = 0;
  return (
    <div style={{position: 'absolute', inset: 0, transform: `scale(${1 + ep * ep * 0.5})`, opacity: 1 - ep, transformOrigin: `${g.cx}px ${g.kineticY}px`}}>
      {c.lines.map((l, li) => {
        const widths = l.words.map((w) => measure(w.text, size));
        const total = widths.reduce((a, b) => a + b, 0);
        let x = g.cx - total / 2;
        return l.words.map((w, wi) => {
          const idx = wordIdx++;
          const left = x;
          x += widths[wi];
          const s = springAt(t, w.at, {damping: 11, stiffness: 260, mass: 0.7});
          if (s <= 0.001) return null;
          const rot = (idx % 2 ? 1 : -1) * 5;
          const from = 2.3;
          const sc = from - (from - 1) * s;
          const op = Math.min(1, (t - w.at) * FPS / 2.5);
          const pulse = beatPulse(t, 0.08) * 0.03;
          return (
            <span
              key={`${li}-${wi}`}
              style={{
                ...inkText(size, w.accent ? PALETTE.yellow : PALETTE.white),
                position: 'absolute',
                left,
                top: y0 + li * lh - size * 0.55,
                transform: `scale(${sc + pulse}) rotate(${rot * (0.4 + 0.6 * (1 - s))}deg)`,
                transformOrigin: '50% 60%',
                opacity: op,
              }}
            >
              {w.text}
            </span>
          );
        });
      })}
    </div>
  );
};

const StackCaption: React.FC<{c: Extract<Caption, {kind: 'stack'}>; g: CaptionGeom; t: number}> = ({c, g, t}) => {
  const out: React.ReactNode[] = [];
  c.words.forEach((w, i) => {
    const s = springAt(t, w.at, {damping: w.huge ? 9 : 12, stiffness: 300, mass: 0.7});
    if (s <= 0.001) return;
    const sc = 2 - s;
    const lt = t - w.at;
    if (!w.huge) {
      const size = fitSize(w.text, g.stackSize, g.maxW);
      const tw = measure(w.text, size);
      out.push(
        <span
          key={i}
          style={{
            ...inkText(size, PALETTE.white),
            position: 'absolute',
            left: g.cx - tw / 2,
            top: g.stackY[i] - size * 0.55,
            transform: `scale(${sc}) rotate(${(i % 2 ? 4 : -4) + (1 - s) * 8}deg)`,
            transformOrigin: '50% 55%',
          }}
        >
          {w.text}
        </span>,
      );
      return;
    }
    // HUGE word: split on the hyphen into two stacked lines if it would otherwise shrink
    let lines = [w.text];
    let size = fitSize(w.text, g.stackHugeSize, g.maxW);
    if (size < g.stackHugeSize * 0.85 && w.text.includes('-')) {
      const k = w.text.indexOf('-') + 1;
      lines = [w.text.slice(0, k), w.text.slice(k)];
      size = Math.min(...lines.map((l) => fitSize(l, g.stackHugeSize, g.maxW)));
    }
    const lh = size * 0.95;
    const jit = Math.min(1, lt / 1.4) * size * 0.025;
    lines.forEach((line, li) => {
      const tw = measure(line, size);
      const y = g.stackY[i] + (li - (lines.length - 1) / 2) * lh;
      const ls = springAt(t, w.at + li * (2 / FPS), {damping: 9, stiffness: 300, mass: 0.7});
      const jx = jit * Math.sin(t * 90 + li * 2);
      const jy = jit * Math.cos(t * 77 + li);
      const common: React.CSSProperties = {
        position: 'absolute',
        left: g.cx - tw / 2 + jx,
        top: y - size * 0.55 + jy,
        transform: `scale(${2 - ls}) rotate(${-3 + li * 2 + (1 - ls) * 8}deg)`,
        transformOrigin: '50% 55%',
      };
      out.push(
        <span key={`${i}-${li}-s`} style={{...inkText(size, PALETTE.ink, {stroke: size * 0.08}), ...common}}>
          {line}
        </span>,
        <span
          key={`${i}-${li}-f`}
          style={{
            fontFamily: inkText(size, '#fff').fontFamily,
            fontSize: size,
            lineHeight: 1,
            whiteSpace: 'nowrap',
            color: 'transparent',
            backgroundImage: 'linear-gradient(180deg, #FF8FB6 0%, #FF3D7F 45%, #D0184A 100%)',
            WebkitBackgroundClip: 'text',
            backgroundClip: 'text',
            padding: `0 ${size * 0.2}px`,
            marginLeft: -size * 0.2,
            filter: `drop-shadow(0 0 ${size * 0.2}px rgba(255,40,100,${0.35 + 0.35 * beatPulse(t, 0.12)}))`,
            ...common,
          }}
        >
          {line}
        </span>,
      );
    });
  });
  return <>{out}</>;
};

export const Captions: React.FC<{g: CaptionGeom}> = ({g}) => {
  useFontReady();
  const frame = useCurrentFrame();
  const t = frame / FPS;
  return (
    <>
      {CAPTIONS.map((c) => {
        const start = c.kind === 'tier' ? c.bigAt : c.kind === 'kinetic' ? c.lines[0].words[0].at : c.words[0].at;
        if (frame < f(start) || frame >= f(c.out)) return null;
        if (c.kind === 'tier') return <TierCaption key={c.id} c={c} g={g} t={t} />;
        if (c.kind === 'kinetic') return <KineticCaption key={c.id} c={c} g={g} t={t} />;
        return <StackCaption key={c.id} c={c} g={g} t={t} />;
      })}
    </>
  );
};
