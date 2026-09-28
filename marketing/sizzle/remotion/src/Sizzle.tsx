import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {Captions, CaptionGeom} from './components/Captions';
import {FlashOverlay, FloatingProps, Grain, LightLeak, Sunburst, Vignette} from './components/Fx';
import {Gameplay} from './components/Gameplay';
import {AudioLayer, EndCard, EndCardLayout, FadeOut, LogoScene, PhoneFrame, PowBursts, UnlocksScene} from './components/Scenes';
import {SRC_H, SRC_W} from './components/ShotVideo';
import {beatPulse, FontReadyContext, noise, shakeAt, springAt, springKeys, useFontsReadyState} from './lib';
import {bar, COLD_OPEN_GAP, END_CARD, FPS, PALETTE, sectionAt, SECTIONS, SHOTS, UNLOCK_SCREENS} from './timeline';

const sec = (n: string) => SECTIONS.find((s) => s.name === n)!;

const coldOpenLeak = (t: number) => (t < bar(3) ? 0.12 : 0);

// ════════════════════════════════════════════════════════════════════════════
// VERTICAL 1080×1920
// ════════════════════════════════════════════════════════════════════════════
const V_CAPTIONS: CaptionGeom = {
  cx: 540,
  tierY: 370,
  bigSize: 230,
  subSize: 62,
  maxW: 860,
  kineticY: 900,
  kineticSize: 215,
  stackY: [1090, 1230, 1510],
  stackSize: 130,
  stackHugeSize: 215,
};

const V_END: EndCardLayout = {
  logo: {x: 540, y: 560, size: 196},
  hero: {x: 540, y: 1085, size: 430},
  tagline: {x: 540, y: 1170, size: 60},
  badges: [
    {x: 540, y: 1300},
    {x: 540, y: 1402},
    {x: 540, y: 1504},
  ],
  badgeSize: 46,
  cta: {x: 540, y: 1650, size: 58},
  sunburst: {cx: 0.5, cy: 0.3},
};

export const SizzleVertical: React.FC = () => {
  const ready = useFontsReadyState();
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const sh = shakeAt(t);
  const overscan = 1 + (Math.min(sh.amp, 40) * 2.4) / 1080;
  const inUnlocks = t >= UNLOCK_SCREENS.start && t < UNLOCK_SCREENS.end;
  return (
    <FontReadyContext.Provider value={ready}>
      <AbsoluteFill style={{backgroundColor: '#06070b'}}>
        <AbsoluteFill style={{transform: `translate(${sh.x}px, ${sh.y}px) rotate(${sh.r}deg) scale(${overscan})`}}>
          <Gameplay W={1080} H={1920} layout="vertical" />
          {inUnlocks ? (
            <AbsoluteFill>
              <Sunburst cx={0.5} cy={0.62} rays={20} c1="#18244F" c2="#20337A" speed={10} glow="rgba(77,235,217,0.35)" glowSize={0.55} />
              <FloatingProps count={10} seed={5} opacity={0.7} sizeScale={0.8} />
              <UnlocksScene cx={540} cy={1210} screenW={330} />
            </AbsoluteFill>
          ) : null}
          <LogoScene W={1080} H={1920} logoY={820} logoSize={200} heroY={1360} heroSize={440} start={sec('logo').start} end={sec('logo').end} />
          <EndCard W={1080} H={1920} L={V_END} withBackground />
        </AbsoluteFill>
        <Captions g={V_CAPTIONS} />
        <PowBursts rect={{x: 0, y: 0, w: 1080, h: 1920}} scale={1} />
        <LightLeak intensity={coldOpenLeak(t)} seed={7} />
        <Vignette strength={0.55} />
        <FlashOverlay />
        <Grain opacity={t < bar(3) ? 0.12 : 0.07} />
        <FadeOut />
        <AudioLayer />
      </AbsoluteFill>
    </FontReadyContext.Provider>
  );
};

// ════════════════════════════════════════════════════════════════════════════
// LANDSCAPE 1920×1080
// ════════════════════════════════════════════════════════════════════════════
const L_CAPTIONS: CaptionGeom = {
  cx: 1310,
  tierY: 430,
  bigSize: 250,
  subSize: 62,
  maxW: 780,
  kineticY: 520,
  kineticSize: 205,
  stackY: [230, 370, 690],
  stackSize: 135,
  stackHugeSize: 230,
};

const L_END: EndCardLayout = {
  logo: {x: 1200, y: 250, size: 190},
  hero: {x: 520, y: 930, size: 600},
  tagline: {x: 1200, y: 420, size: 54},
  badges: [
    {x: 1200, y: 540},
    {x: 1200, y: 628},
    {x: 1200, y: 716},
  ],
  badgeSize: 42,
  cta: {x: 1200, y: 860, size: 50},
  sunburst: {cx: 0.5, cy: 0.4},
};

const SCREEN_H = 880;
const SCREEN_W = (SCREEN_H * SRC_W) / SRC_H;
const PHONE_B = SCREEN_W * 0.045;
const PHONE_W = SCREEN_W + PHONE_B * 2;
const PHONE_H = SCREEN_H + PHONE_B * 2;

const LandscapeBackground: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const s = sectionAt(t);
  const pulse = s === 'drop' || s === 'heroCity' ? beatPulse(t, 0.12) : beatPulse(t, 0.2) * 0.4;
  const blobs = [
    {c: PALETTE.heroBlue, x: 0.2 + 0.1 * Math.sin(t * 0.3), y: 0.3 + 0.1 * Math.cos(t * 0.4), r: 900},
    {c: PALETTE.purple, x: 0.85 + 0.08 * Math.cos(t * 0.35), y: 0.75 + 0.1 * Math.sin(t * 0.25), r: 1000},
    {c: PALETTE.teal, x: 0.6 + 0.15 * Math.sin(t * 0.22 + 2), y: 0.1 + 0.08 * Math.sin(t * 0.5), r: 700},
  ];
  const buildA = s === 'build' ? 0.35 + 0.3 * beatPulse(t, 0.15) + 0.2 * ((t - sec('build').start) / 3.75) : 0;
  return (
    <AbsoluteFill style={{background: `radial-gradient(ellipse at 35% 50%, #2F3775 0%, ${PALETTE.indigo} 45%, #12152B 100%)`}}>
      <Sunburst cx={0.323} cy={0.5} rays={28} c1="rgba(30,36,64,0)" c2="rgba(70,84,170,0.22)" speed={5} glow={`rgba(120,160,255,${0.18 + pulse * 0.2})`} glowSize={0.5} />
      <AbsoluteFill style={{mixBlendMode: 'screen', opacity: 0.4}}>
        {blobs.map((b, i) => (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: b.x * 1920 - b.r / 2,
              top: b.y * 1080 - b.r / 2,
              width: b.r,
              height: b.r,
              borderRadius: '50%',
              background: `radial-gradient(circle, ${b.c} 0%, rgba(0,0,0,0) 65%)`,
            }}
          />
        ))}
      </AbsoluteFill>
      <FloatingProps count={18} seed={3} opacity={0.9} sizeScale={0.85} />
      {buildA > 0 ? <AbsoluteFill style={{background: `radial-gradient(ellipse at 35% 50%, rgba(160,30,90,${buildA * 0.5}) 0%, rgba(60,5,40,${buildA + 0.2}) 100%)`, mixBlendMode: 'multiply'}} /> : null}
      {s === 'drop' ? (
        <>
          <Sunburst cx={0.5} cy={0.5} rays={18} c1="rgba(0,0,0,0)" c2={`rgba(255,209,64,${0.1 + pulse * 0.22})`} speed={-22} glow={`rgba(255,61,127,${0.15 + pulse * 0.25})`} glowSize={0.45} />
          {SHOTS.filter((sh) => sh.id.startsWith('d')).map((sh, i) => {
            const lt = t - sh.start;
            if (lt < 0 || lt > 0.6) return null;
            const p = lt / 0.6;
            const r = 300 + (1 - Math.pow(1 - p, 3)) * 900;
            return (
              <div
                key={sh.id}
                style={{
                  position: 'absolute',
                  left: 960 - r,
                  top: 540 - r,
                  width: r * 2,
                  height: r * 2,
                  borderRadius: '50%',
                  border: `${(1 - p) * 26 + 2}px solid ${i % 2 ? PALETTE.yellow : PALETTE.magenta}`,
                  opacity: (1 - p) * 0.6,
                }}
              />
            );
          })}
        </>
      ) : null}
      {t < bar(3) ? <AbsoluteFill style={{backgroundColor: '#04050a', opacity: 0.9}} /> : null}
    </AbsoluteFill>
  );
};

const PhoneStage: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const inCold = t < COLD_OPEN_GAP[0];
  const inMain = t >= bar(4) && t < UNLOCK_SCREENS.start;
  const inWin = t >= bar(22) && t < END_CARD.start;
  if (!inCold && !inMain && !inWin) return null;
  const sh = shakeAt(t);
  // during the boss drop the phone springs to centre stage (no captions there)
  const toCentre = springAt(t, bar(16), {damping: 16, stiffness: 200}) - springAt(t, bar(20), {damping: 16, stiffness: 200});
  const cx = inMain ? 620 + 340 * toCentre : 960;
  let ty = 0;
  let rz = 0;
  let scale = 1;
  let rotY = 0;
  if (inCold) {
    scale = interpolate(t, [0, COLD_OPEN_GAP[0]], [0.94, 1.04]);
    rotY = interpolate(t, [0, COLD_OPEN_GAP[0]], [8, -6]);
  }
  if (inMain) {
    const enter = springAt(t, bar(4), {damping: 14, stiffness: 170, mass: 0.8});
    ty = (1 - enter) * 1150;
    rz = (1 - enter) * 14;
    rotY = springKeys(t, [
      {t: 0, v: -12},
      {t: bar(6), v: -7},
      {t: bar(8), v: -15},
      {t: bar(10), v: -5},
      {t: bar(12), v: -13},
      {t: bar(14), v: -3},
      {t: bar(16), v: -10},
      {t: bar(20), v: -14},
    ]);
    rz += springKeys(t, [
      {t: 0, v: -2},
      {t: bar(6), v: -3},
      {t: bar(8), v: 1.5},
      {t: bar(10), v: -3.5},
      {t: bar(12), v: 2},
      {t: bar(14), v: 0},
      {t: bar(16), v: -1.5},
      {t: bar(20), v: -2.5},
    ]);
    // build: slow push-in; drop: punch on cuts
    if (t >= bar(14) && t < bar(16)) scale *= interpolate(t, [bar(14), bar(16)], [1, 1.07]);
    // drop: alternate tilt kick on every cut
    if (t >= bar(16) && t < bar(20)) {
      const cuts = SHOTS.filter((s) => s.id.startsWith('d'));
      let kick = 0;
      cuts.forEach((c, i) => {
        if (t >= c.start) kick = (i % 2 ? 1 : -1) * 4 * Math.exp(-(t - c.start) / 0.12) + kick * 0;
      });
      rz += kick;
      scale *= 1 + 0.05 * Math.max(...cuts.map((c) => (t >= c.start ? Math.exp(-(t - c.start) / 0.08) : 0)));
    }
    ty += Math.sin(t * 1.6) * 9;
    rz += noise(5, t * 0.6) * 0.8;
  }
  if (inWin) scale = 0.9 + 0.1 * springAt(t, bar(22), {damping: 12, stiffness: 220});
  return (
    <div
      style={{
        position: 'absolute',
        left: cx - PHONE_W / 2 + sh.x * 0.7,
        top: 540 - PHONE_H / 2 + ty + sh.y * 0.7,
        transform: `perspective(2200px) rotateY(${rotY}deg) rotate(${rz + sh.r}deg) scale(${scale})`,
        filter: 'drop-shadow(0 50px 60px rgba(0,0,0,0.45))',
      }}
    >
      <PhoneFrame screenW={SCREEN_W} screenH={SCREEN_H} glare={Math.abs(rotY) / 15}>
        <Gameplay W={SCREEN_W} H={SCREEN_H} layout="landscape" />
      </PhoneFrame>
    </div>
  );
};

export const SizzleLandscape: React.FC = () => {
  const ready = useFontsReadyState();
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const inLogoOrEnd = (t >= sec('logo').start && t < sec('logo').end) || t >= END_CARD.start;
  return (
    <FontReadyContext.Provider value={ready}>
      <AbsoluteFill style={{backgroundColor: '#06070b'}}>
        {!inLogoOrEnd ? <LandscapeBackground /> : null}
        <PhoneStage />
        <UnlocksScene cx={585} cy={565} screenW={272} />
        <LogoScene W={1920} H={1080} logoY={400} logoSize={230} heroY={960} heroSize={400} start={sec('logo').start} end={sec('logo').end} />
        <EndCard W={1920} H={1080} L={L_END} withBackground />
        <Captions g={L_CAPTIONS} />
        <PowBursts rect={{x: 960 - SCREEN_W / 2, y: 540 - SCREEN_H / 2, w: SCREEN_W, h: SCREEN_H}} scale={0.85} />
        <LightLeak intensity={coldOpenLeak(t)} seed={7} />
        <Vignette strength={0.45} />
        <FlashOverlay />
        <Grain opacity={t < bar(3) ? 0.12 : 0.07} />
        <FadeOut />
        <AudioLayer />
      </AbsoluteFill>
    </FontReadyContext.Provider>
  );
};
