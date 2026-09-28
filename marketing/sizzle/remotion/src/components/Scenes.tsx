import React from 'react';
import {AbsoluteFill, Html5Audio, OffthreadVideo, Sequence, getStaticFiles, interpolate, staticFile, useCurrentFrame} from 'remotion';
import {beatPulse, FONT, inkText, measure, springAt, useFontReady} from '../lib';
import {db, DURATION_S, END_CARD, f, FPS, MUSIC, PALETTE, POWS, SFX, SFX_TRIM_DB, UNLOCK_SCREENS} from '../timeline';
import {FloatingProps, LightLeak, SparkleBurst, Sunburst} from './Fx';
import {Hero, Logo} from './Logo';
import {SRC_H, SRC_W} from './ShotVideo';

// ── Phone frame (CSS-drawn, generic modern phone) ───────────────────────────
export const PhoneFrame: React.FC<{screenW: number; screenH: number; children: React.ReactNode; glare?: number}> = ({screenW, screenH, children, glare = 0}) => {
  const b = screenW * 0.045;
  const R = screenW * 0.155;
  const W = screenW + b * 2;
  const H = screenH + b * 2;
  return (
    <div style={{position: 'relative', width: W, height: H}}>
      {/* side buttons */}
      <div style={{position: 'absolute', left: -b * 0.28, top: H * 0.2, width: b * 0.4, height: H * 0.06, borderRadius: b, background: '#2a2e38'}} />
      <div style={{position: 'absolute', left: -b * 0.28, top: H * 0.29, width: b * 0.4, height: H * 0.1, borderRadius: b, background: '#2a2e38'}} />
      <div style={{position: 'absolute', right: -b * 0.28, top: H * 0.27, width: b * 0.4, height: H * 0.14, borderRadius: b, background: '#2a2e38'}} />
      {/* body */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: R + b,
          background: 'linear-gradient(140deg, #5b6172 0%, #1b1e26 22%, #0d0f14 50%, #262a34 78%, #6a7082 100%)',
          boxShadow: `0 ${H * 0.04}px ${H * 0.08}px rgba(0,0,0,0.55), 0 ${H * 0.01}px ${H * 0.02}px rgba(0,0,0,0.5)`,
        }}
      />
      <div style={{position: 'absolute', inset: b * 0.22, borderRadius: R + b * 0.78, background: '#050608'}} />
      {/* screen */}
      <div style={{position: 'absolute', left: b, top: b, width: screenW, height: screenH, borderRadius: R, overflow: 'hidden', background: '#000', transform: 'translateZ(0)'}}>
        {children}
        {/* glass reflection */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: `linear-gradient(118deg, rgba(255,255,255,${0.1 + glare * 0.08}) 0%, rgba(255,255,255,0.03) 34%, rgba(255,255,255,0) 34.5%, rgba(255,255,255,0) 100%)`,
            pointerEvents: 'none',
          }}
        />
      </div>
      {/* dynamic island */}
      <div
        style={{
          position: 'absolute',
          left: W / 2 - screenW * 0.155,
          top: b + screenH * 0.013,
          width: screenW * 0.31,
          height: screenW * 0.088,
          borderRadius: screenW,
          background: '#000',
          boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.04)',
        }}
      >
        <div style={{position: 'absolute', right: screenW * 0.03, top: '30%', width: screenW * 0.035, height: screenW * 0.035, borderRadius: '50%', background: 'radial-gradient(circle at 35% 35%, #2b3a5c, #05070c 70%)'}} />
      </div>
      {/* rim light */}
      <div style={{position: 'absolute', inset: 0, borderRadius: R + b, boxShadow: 'inset 0 0 0 1.5px rgba(255,255,255,0.18), inset 0 2px 0 rgba(255,255,255,0.12)', pointerEvents: 'none'}} />
    </div>
  );
};

/** A menu-screen clip that fills a phone screen exactly (same aspect). */
const ScreenClip: React.FC<{clip: string; src: number; w: number; h: number; startFrame: number}> = ({clip, src, w, h, startFrame}) => (
  <Sequence from={startFrame} layout="none">
    <OffthreadVideo
      src={staticFile(`clips/${clip}.mp4`)}
      trimBefore={Math.round(src * FPS)}
      muted
      style={{position: 'absolute', left: 0, top: 0, width: w, height: h, filter: 'saturate(1.12) contrast(1.04)'}}
    />
  </Sequence>
);

// ── Unlocks: floating phones (shop + map, complete card pops on EARN) ───────
export const UnlocksScene: React.FC<{cx: number; cy: number; screenW: number}> = ({cx, cy, screenW}) => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const {start, end, shop, map, complete} = UNLOCK_SCREENS;
  if (t < start || t >= end) return null;
  const lt = t - start;
  const screenH = (screenW * SRC_H) / SRC_W;
  const phoneW = screenW * 1.09;
  const phoneH = screenH + screenW * 0.09;
  const inL = springAt(lt, 0, {damping: 14, stiffness: 140});
  const inR = springAt(lt, 0.06, {damping: 14, stiffness: 140});
  const inC = springAt(t, complete.at, {damping: 11, stiffness: 190});
  const floatY = (k: number) => Math.sin((t + k) * 2.2) * screenW * 0.025;
  const sf = f(start);
  const phone = (key: string, x: number, y: number, rot: number, rotY: number, scale: number, node: React.ReactNode, z: number) => (
    <div
      key={key}
      style={{
        position: 'absolute',
        left: x - phoneW / 2,
        top: y - phoneH / 2,
        transform: `perspective(1800px) rotateY(${rotY}deg) rotate(${rot}deg) scale(${scale})`,
        zIndex: z,
      }}
    >
      <PhoneFrame screenW={screenW} screenH={screenH}>
        {node}
      </PhoneFrame>
    </div>
  );
  const dim = inC * 0.35;
  return (
    <AbsoluteFill>
      {phone(
        'shop',
        cx - screenW * 0.62 - (1 - inL) * screenW * 2.2,
        cy + floatY(0) + screenW * 0.05,
        -9 + (1 - inL) * -20,
        14,
        0.94 - dim * 0.1,
        <>
          <ScreenClip clip={shop.clip} src={shop.src} w={screenW} h={screenH} startFrame={sf} />
          <div style={{position: 'absolute', inset: 0, background: `rgba(0,0,0,${dim})`}} />
        </>,
        1,
      )}
      {phone(
        'map',
        cx + screenW * 0.62 + (1 - inR) * screenW * 2.2,
        cy + floatY(1.3) - screenW * 0.05,
        8 + (1 - inR) * 20,
        -14,
        0.94 - dim * 0.1,
        <>
          <ScreenClip clip={map.clip} src={map.src} w={screenW} h={screenH} startFrame={sf} />
          <div style={{position: 'absolute', inset: 0, background: `rgba(0,0,0,${dim})`}} />
        </>,
        2,
      )}
      {inC > 0.001
        ? phone(
            'complete',
            cx,
            cy + (1 - inC) * screenW * 2.6 + floatY(2.1) * 0.5,
            (1 - inC) * 12 - 1.5,
            0,
            1.02 * (0.6 + 0.4 * inC),
            <ScreenClip clip={complete.clip} src={complete.src} w={screenW} h={screenH} startFrame={f(complete.at)} />,
            3,
          )
        : null}
    </AbsoluteFill>
  );
};

// ── Comic POW bursts ───────────────────────────────────────────────────────
const burstPath = (n: number, r1: number, r2: number, seed: number) => {
  const pts: string[] = [];
  for (let i = 0; i < n * 2; i++) {
    const a = (i / (n * 2)) * Math.PI * 2;
    const jitter = 1 + 0.18 * Math.sin(i * 7.3 + seed);
    const r = (i % 2 ? r2 : r1 * jitter);
    pts.push(`${Math.cos(a) * r},${Math.sin(a) * r}`);
  }
  return `M${pts.join('L')}Z`;
};

export const PowBursts: React.FC<{rect: {x: number; y: number; w: number; h: number}; scale: number}> = ({rect, scale}) => {
  useFontReady();
  const frame = useCurrentFrame();
  const t = frame / FPS;
  return (
    <>
      {POWS.map((p, i) => {
        const lt = t - p.t;
        if (lt < 0 || lt > 0.46) return null;
        const s = springAt(lt, 0, {damping: 8, stiffness: 320, mass: 0.5});
        const out = Math.max(0, (lt - 0.36) / 0.1);
        const sc = s * (1 - out * out) * scale;
        const size = 420;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: rect.x + p.x * rect.w - size / 2,
              top: rect.y + p.y * rect.h - size / 2,
              width: size,
              height: size,
              transform: `scale(${sc}) rotate(${p.rot + lt * 20}deg)`,
            }}
          >
            <svg width={size} height={size} viewBox="-210 -210 420 420" style={{position: 'absolute', overflow: 'visible'}}>
              <path d={burstPath(14, 200, 120, i)} fill={PALETTE.ink} transform="translate(0,14)" />
              <path d={burstPath(14, 200, 120, i)} fill={PALETTE.yellow} stroke={PALETTE.ink} strokeWidth={12} strokeLinejoin="round" />
              <path d={burstPath(12, 140, 92, i + 3)} fill={PALETTE.heroRed} />
            </svg>
            <div style={{position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
              <span style={{...inkText(118, PALETTE.white, {stroke: 10}), transform: 'rotate(-6deg)'}}>{p.text}</span>
            </div>
          </div>
        );
      })}
    </>
  );
};

// ── Logo slam scene (bar 3) ────────────────────────────────────────────────
export const LogoScene: React.FC<{W: number; H: number; logoY: number; logoSize: number; heroY: number; heroSize: number; start: number; end: number}> = ({
  W,
  H,
  logoY,
  logoSize,
  heroY,
  heroSize,
  start,
  end,
}) => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  if (t < start || t >= end) return null;
  const lt = t - start;
  const burstScale = springAt(lt, 0, {damping: 20, stiffness: 200});
  return (
    <AbsoluteFill>
      <div style={{position: 'absolute', inset: 0, transform: `scale(${1.3 - 0.3 * burstScale})`}}>
        <Sunburst cx={0.5} cy={logoY / H} rays={22} c1={PALETTE.navy} c2="#303A86" speed={14} glow="rgba(255,209,64,0.5)" glowSize={0.55} />
      </div>
      <LightLeak intensity={0.55} seed={1} />
      <Hero x={W / 2} y={heroY} size={heroSize} at={start + 0.16} />
      <Logo x={W / 2} y={logoY} size={logoSize} at={start} exitAt={end - 7 / FPS} />
      <SparkleBurst x={W / 2} y={logoY} at={start + 0.04} spread={Math.min(W, H) * 0.55} count={26} seed={2} scale={Math.min(W, H) / 1080} />
    </AbsoluteFill>
  );
};

// ── End card ───────────────────────────────────────────────────────────────
export type EndCardLayout = {
  logo: {x: number; y: number; size: number};
  hero: {x: number; y: number; size: number};
  tagline: {x: number; y: number; size: number};
  badges: {x: number; y: number}[];
  badgeSize: number;
  cta: {x: number; y: number; size: number};
  sunburst: {cx: number; cy: number};
};

const Badge: React.FC<{text: string; x: number; y: number; size: number; at: number; t: number; i: number}> = ({text, x, y, size, at, t, i}) => {
  const s = springAt(t, at, {damping: 9, stiffness: 240, mass: 0.6});
  if (s <= 0.001) return null;
  const iconS = size * 1.05;
  const w = measure(text, size) + size * 1.2 + iconS + size * 0.4;
  const h = size * 1.7;
  const icons = [PALETTE.heroRed, PALETTE.heroBlue, PALETTE.teal];
  const bob = Math.sin((t - at) * 3 + i) * size * 0.06;
  return (
    <div
      style={{
        position: 'absolute',
        left: x - w / 2,
        top: y - h / 2 + bob,
        width: w,
        height: h,
        borderRadius: h / 2,
        background: 'linear-gradient(180deg, #FFFFFF 0%, #EEF1FA 100%)',
        border: `${size * 0.12}px solid ${PALETTE.ink}`,
        boxShadow: `0 ${size * 0.16}px 0 ${PALETTE.ink}, 0 ${size * 0.3}px ${size * 0.5}px rgba(0,0,0,0.35)`,
        transform: `scale(${s}) rotate(${(1 - s) * (i % 2 ? 14 : -14) + (i - 1) * 1.5}deg)`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: size * 0.35,
        boxSizing: 'border-box',
      }}
    >
      <svg width={iconS} height={iconS} viewBox="0 0 100 100">
        <circle cx={50} cy={50} r={46} fill={icons[i % 3]} stroke={PALETTE.ink} strokeWidth={8} />
        <path d="M28 52 L44 67 L73 36" fill="none" stroke="#fff" strokeWidth={13} strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span style={{fontFamily: FONT, fontSize: size, lineHeight: 1, color: PALETTE.ink, whiteSpace: 'nowrap', transform: `translateY(${size * 0.03}px)`}}>{text}</span>
    </div>
  );
};

export const EndCard: React.FC<{W: number; H: number; L: EndCardLayout; withBackground: boolean}> = ({W, H, L, withBackground}) => {
  useFontReady();
  const frame = useCurrentFrame();
  const t = frame / FPS;
  if (t < END_CARD.start) return null;
  const lt = t - END_CARD.start;
  const burstIn = springAt(lt, 0, {damping: 20, stiffness: 160});
  const ctaPulse = t > END_CARD.ctaAt ? beatPulse(t, 0.12) : 0;

  // tagline typed on per character with a tiny pop
  const tagChars = END_CARD.tagline.split('');
  const tagWidths = tagChars.map((c) => measure(c, L.tagline.size));
  const tagTotal = tagWidths.reduce((a, b) => a + b, 0);
  const charStep = 1.1 / FPS;
  let tx = L.tagline.x - tagTotal / 2;

  // CTA
  const ctaS = springAt(t, END_CARD.ctaAt, {damping: 8, stiffness: 260, mass: 0.7});
  const ctaW = measure(END_CARD.cta, L.cta.size) + L.cta.size * 1.6;
  const ctaH = L.cta.size * 1.9;
  const shineP = t > END_CARD.ctaAt + 0.3 ? (((t - END_CARD.ctaAt - 0.3) % 1.875) / 0.6) : -1;

  return (
    <AbsoluteFill>
      {withBackground ? (
        <>
          <div style={{position: 'absolute', inset: 0, transform: `scale(${1.25 - 0.25 * burstIn})`}}>
            <Sunburst cx={L.sunburst.cx} cy={L.sunburst.cy} rays={24} c1={PALETTE.navy} c2="#2E3780" speed={7} glow="rgba(255,209,64,0.42)" glowSize={0.6} />
          </div>
          <FloatingProps count={12} seed={9} opacity={0.8} sizeScale={0.9} />
        </>
      ) : null}
      <LightLeak intensity={0.45} seed={4} />
      <Hero x={L.hero.x} y={L.hero.y} size={L.hero.size} at={END_CARD.logoAt + 0.12} />
      <Logo x={L.logo.x} y={L.logo.y} size={L.logo.size} at={END_CARD.logoAt} />
      <SparkleBurst x={L.logo.x} y={L.logo.y} at={END_CARD.logoAt + 0.03} spread={Math.min(W, H) * 0.55} count={24} seed={7} scale={Math.min(W, H) / 1080} />
      {/* tagline */}
      {tagChars.map((ch, i) => {
        const left = tx;
        tx += tagWidths[i];
        const at = END_CARD.taglineAt + i * charStep;
        const s = springAt(t, at, {damping: 10, stiffness: 300, mass: 0.5});
        if (s <= 0.001) return null;
        return (
          <span
            key={i}
            style={{
              ...inkText(L.tagline.size, PALETTE.white, {stroke: L.tagline.size * 0.09, drop: L.tagline.size * 0.08}),
              position: 'absolute',
              left,
              top: L.tagline.y - L.tagline.size * 0.55,
              transform: `translateY(${(1 - s) * L.tagline.size * 0.4}px) scale(${s})`,
              transformOrigin: '50% 80%',
              display: 'inline-block',
            }}
          >
            {ch === ' ' ? ' ' : ch}
          </span>
        );
      })}
      {END_CARD.badges.map((b, i) => (
        <Badge key={b.text} text={b.text} x={L.badges[i].x} y={L.badges[i].y} size={L.badgeSize} at={b.at} t={t} i={i} />
      ))}
      {ctaS > 0.001 ? (
        <div
          style={{
            position: 'absolute',
            left: L.cta.x - ctaW / 2,
            top: L.cta.y - ctaH / 2,
            width: ctaW,
            height: ctaH,
            transform: `scale(${ctaS * (1 + ctaPulse * 0.035)})`,
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: ctaH / 2,
              background: 'linear-gradient(180deg, #FFE98A 0%, #FFD140 45%, #FFB21A 100%)',
              border: `${L.cta.size * 0.12}px solid ${PALETTE.ink}`,
              boxShadow: `0 ${L.cta.size * 0.2}px 0 ${PALETTE.ink}, 0 ${L.cta.size * 0.35}px ${L.cta.size * 0.8}px rgba(0,0,0,0.45), 0 0 ${L.cta.size * (0.6 + ctaPulse)}px rgba(255,209,64,0.55)`,
              overflow: 'hidden',
              boxSizing: 'border-box',
            }}
          >
            <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: '45%', background: 'linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0))', borderRadius: `${ctaH / 2}px ${ctaH / 2}px 0 0`}} />
            {shineP >= 0 && shineP <= 1 ? (
              <div
                style={{
                  position: 'absolute',
                  top: -ctaH,
                  left: -ctaW * 0.3 + shineP * ctaW * 1.6,
                  width: ctaH * 0.6,
                  height: ctaH * 3,
                  background: 'linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.85), rgba(255,255,255,0))',
                  transform: 'rotate(22deg)',
                }}
              />
            ) : null}
          </div>
          <div style={{position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
            <span style={{fontFamily: FONT, fontSize: L.cta.size, lineHeight: 1, color: PALETTE.ink, whiteSpace: 'nowrap', transform: `translateY(${L.cta.size * 0.02}px)`}}>
              {END_CARD.cta}
            </span>
          </div>
        </div>
      ) : null}
      <SparkleBurst x={L.cta.x} y={L.cta.y} at={END_CARD.ctaAt} spread={ctaW * 0.6} count={18} seed={11} twinkle={false} scale={Math.min(W, H) / 1080} />
    </AbsoluteFill>
  );
};

export const FadeOut: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const o = interpolate(t, [END_CARD.fadeStart, DURATION_S - 1 / FPS], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  if (o <= 0) return null;
  return <AbsoluteFill style={{backgroundColor: '#000', opacity: o}} />;
};

// ── Audio (optional: renders silently when files are absent) ───────────────
export const AudioLayer: React.FC = () => {
  const files = new Set(getStaticFiles().map((s) => s.name));
  const has = (p: string) => files.has(p);
  return (
    <>
      {has(MUSIC.file) ? (
        <Html5Audio
          src={staticFile(MUSIC.file)}
          volume={(fr) => MUSIC.volume * interpolate(fr / FPS, [END_CARD.fadeStart, DURATION_S], [1, 0.0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}
        />
      ) : null}
      {SFX.map((c, i) => {
        const p = `audio/${c.file}`;
        if (!has(p)) return null;
        return (
          <Sequence key={i} from={Math.max(0, f(c.t))} name={`sfx ${c.file} ${c.note ?? ''}`} layout="none">
            <Html5Audio src={staticFile(p)} volume={db(c.db + SFX_TRIM_DB)} />
          </Sequence>
        );
      })}
    </>
  );
};
