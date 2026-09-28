// ─────────────────────────────────────────────────────────────────────────────
// Kaiditya sizzle — single source of truth for BOTH compositions.
// Every time here is in SECONDS on the 128 BPM grid; frames = round(t × FPS).
// ─────────────────────────────────────────────────────────────────────────────

export const FPS = 60;
export const BPM = 128;
export const BEAT = 60 / BPM; // 0.46875 s
export const BAR = BEAT * 4; // 1.875 s
export const DURATION_S = 47.5;
export const DURATION_FRAMES = Math.round(DURATION_S * FPS); // 2850

/** seconds → frame on the 60 fps grid */
export const f = (t: number) => Math.round(t * FPS);
/** start of bar N (1-indexed) in seconds */
export const bar = (n: number) => (n - 1) * BAR;
/** beat k (0-indexed, within bar N) */
export const beatOf = (n: number, k: number) => bar(n) + k * BEAT;

export const PALETTE = {
  heroBlue: '#3373F2',
  heroRed: '#F0474D',
  yellow: '#FFD140',
  yellowDeep: '#E09A12',
  teal: '#4DEBD9',
  purple: '#52387A',
  indigo: '#262B4A',
  navy: '#1E2440',
  ink: '#1A1F2E',
  magenta: '#FF3D7F',
  white: '#FFFFFF',
};

// ── Sections ────────────────────────────────────────────────────────────────
export type SectionName =
  | 'coldOpen'
  | 'logo'
  | 'tagline'
  | 'sneak'
  | 'rescue'
  | 'chase'
  | 'traps'
  | 'build'
  | 'drop'
  | 'heroCity'
  | 'unlocks'
  | 'endCard';

export const SECTIONS: {name: SectionName; start: number; end: number}[] = [
  {name: 'coldOpen', start: bar(1), end: bar(3)},
  {name: 'logo', start: bar(3), end: bar(4)},
  {name: 'tagline', start: bar(4), end: bar(6)},
  {name: 'sneak', start: bar(6), end: bar(8)},
  {name: 'rescue', start: bar(8), end: bar(10)},
  {name: 'chase', start: bar(10), end: bar(12)},
  {name: 'traps', start: bar(12), end: bar(14)},
  {name: 'build', start: bar(14), end: bar(16)},
  {name: 'drop', start: bar(16), end: bar(20)},
  {name: 'heroCity', start: bar(20), end: bar(21)},
  {name: 'unlocks', start: bar(21), end: bar(22)},
  {name: 'endCard', start: bar(22), end: DURATION_S},
];

export const sectionAt = (t: number): SectionName => {
  for (const s of SECTIONS) if (t >= s.start && t < s.end) return s.name;
  return 'endCard';
};

// Key musical moments (already contain big hits in the music itself).
export const IMPACTS = [bar(3), bar(16), bar(22)]; // 3.75, 28.125, 39.375
export const BUTTON_HIT = bar(24); // 43.125
export const SILENCE_GAP: [number, number] = [beatOf(15, 3), bar(16)]; // 27.656–28.125
export const COLD_OPEN_GAP: [number, number] = [3.515625, bar(3)];

// ── Shots ───────────────────────────────────────────────────────────────────
// Clip frame coords: cx/cy are 0–1 fractions of the 1320×2868 source where the
// hero is; the renderer centres the punch-in there (clamped to stay in frame).
// `track` lets the centre follow the hero over source time: [srcT, cx, cy].
export type ShotFx = {
  punchIn?: boolean; // zoom-punch on entry
  rgbIn?: number; // RGB-split strength on entry (px @1080w)
  glitchOut?: boolean; // cold-open glitch + snap to black
  suckOut?: boolean; // shrink/spin into black
  whipOut?: boolean; // whip-pan out (horizontal blur slide)
  whipIn?: boolean;
  grade?: 'normal' | 'dim' | 'build' | 'bright';
};

export type Shot = {
  id: string;
  clip: string; // basename in public/clips
  start: number; // timeline seconds (on grid)
  end: number;
  src: number; // source in-point seconds
  punch: number; // start zoom relative to cover-fit
  push?: number; // end zoom (Ken Burns); default punch*1.08
  cx?: number;
  cy?: number;
  track?: [number, number, number][];
  fx?: ShotFx;
};

const drop2 = (i: number) => bar(16) + i * 2 * BEAT; // 2-beat grid in bars 16–17
const drop1 = (i: number) => bar(18) + i * BEAT; // 1-beat grid in bars 18–19

export const SHOTS: Shot[] = [
  // COLD OPEN — four flash cuts on the stabs, each ~1 beat, glitch → black
  {id: 'co1', clip: 'chase', start: 0, end: 0.45, src: 9.0, punch: 1.55, push: 1.75, cx: 0.5, cy: 0.64, fx: {glitchOut: true}},
  {id: 'co2', clip: 'tower', start: beatOf(1, 2), end: beatOf(1, 2) + 0.45, src: 9.0, punch: 1.8, push: 2.0, cx: 0.5, cy: 0.48, fx: {glitchOut: true}},
  {id: 'co3', clip: 'harbor', start: bar(2), end: bar(2) + 0.45, src: 12.0, punch: 1.5, push: 1.7, cx: 0.5, cy: 0.66, fx: {glitchOut: true}},
  {id: 'co4', clip: 'boss', start: beatOf(2, 2), end: COLD_OPEN_GAP[0], src: 18.0, punch: 1.7, push: 1.9, cx: 0.5, cy: 0.36, fx: {suckOut: true}},

  // TAGLINE — Town Square, dimmed & softened behind type
  {id: 'tag', clip: 'park', start: bar(4), end: bar(6), src: 0.85, punch: 1.3, push: 1.5, cx: 0.5, cy: 0.48, fx: {grade: 'dim'}},

  // SNEAK
  {id: 'sn1', clip: 'docks', start: bar(6), end: bar(7), src: 3.0, punch: 1.6, push: 1.75, cx: 0.5, cy: 0.49, fx: {punchIn: true}},
  {id: 'sn2', clip: 'lab', start: bar(7), end: bar(8), src: 7.5, punch: 1.5, push: 1.65, cx: 0.5, cy: 0.46, fx: {punchIn: true}},
  // RESCUE
  {id: 'rs1', clip: 'docks', start: bar(8), end: bar(9), src: 13.8, punch: 1.7, push: 1.85, cx: 0.5, cy: 0.48, fx: {punchIn: true}},
  {id: 'rs2', clip: 'tower', start: bar(9), end: bar(10), src: 2.4, punch: 1.7, push: 1.85, cx: 0.5, cy: 0.48, fx: {punchIn: true}},
  // CHASE
  {id: 'ch1', clip: 'chase', start: bar(10), end: bar(11), src: 3.0, punch: 1.25, push: 1.35, cx: 0.5, cy: 0.58, fx: {punchIn: true}},
  {id: 'ch2', clip: 'harbor', start: bar(11), end: bar(12), src: 5.0, punch: 1.25, push: 1.35, cx: 0.5, cy: 0.6, fx: {punchIn: true}},
  // TRAPS
  {id: 'tr1', clip: 'gauntlet', start: bar(12), end: bar(13), src: 9.0, punch: 1.5, push: 1.65, cx: 0.5, cy: 0.48, fx: {punchIn: true}},
  {id: 'tr2', clip: 'rooftops', start: bar(13), end: bar(14), src: 3.0, punch: 1.6, push: 1.75, cx: 0.5, cy: 0.49, fx: {punchIn: true, whipOut: true}},

  // BUILD — approach the fortress, Lord Chow-Chow appears
  {
    id: 'bld', clip: 'boss', start: bar(14), end: SILENCE_GAP[0], src: 13.5, punch: 1.35, push: 1.85,
    track: [[13.5, 0.47, 0.5], [14.6, 0.5, 0.48], [15.4, 0.5, 0.32], [17.3, 0.5, 0.3]],
    fx: {whipIn: true, grade: 'build'},
  },

  // BOSS DROP — 2-beat cuts in bars 16–17, 1-beat cuts in bars 18–19
  {id: 'd01', clip: 'boss', start: drop2(0), end: drop2(1), src: 18.0, punch: 1.6, push: 1.75, cx: 0.5, cy: 0.36, fx: {punchIn: true, rgbIn: 36}},
  {id: 'd02', clip: 'chase', start: drop2(1), end: drop2(2), src: 12.0, punch: 1.3, push: 1.42, cx: 0.5, cy: 0.62, fx: {punchIn: true, rgbIn: 28}},
  {id: 'd03', clip: 'boss', start: drop2(2), end: drop2(3), src: 19.9, punch: 1.6, push: 1.75, cx: 0.5, cy: 0.36, fx: {punchIn: true, rgbIn: 36}},
  {id: 'd04', clip: 'harbor', start: drop2(3), end: drop2(4), src: 18.0, punch: 1.3, push: 1.42, cx: 0.5, cy: 0.62, fx: {punchIn: true, rgbIn: 28}},
  {id: 'd05', clip: 'boss', start: drop1(0), end: drop1(1), src: 22.0, punch: 1.6, push: 1.7, cx: 0.5, cy: 0.36, fx: {punchIn: true, rgbIn: 30}},
  {id: 'd06', clip: 'lab', start: drop1(1), end: drop1(2), src: 9.0, punch: 1.55, push: 1.65, cx: 0.5, cy: 0.47, fx: {punchIn: true, rgbIn: 24}},
  {id: 'd07', clip: 'boss', start: drop1(2), end: drop1(3), src: 24.0, punch: 1.6, push: 1.7, cx: 0.5, cy: 0.36, fx: {punchIn: true, rgbIn: 30}},
  {id: 'd08', clip: 'sewers', start: drop1(3), end: drop1(4), src: 21.0, punch: 1.55, push: 1.65, cx: 0.5, cy: 0.5, fx: {punchIn: true, rgbIn: 24}},
  {id: 'd09', clip: 'power', start: drop1(4), end: drop1(5), src: 12.0, punch: 1.55, push: 1.65, cx: 0.5, cy: 0.5, fx: {punchIn: true, rgbIn: 24}},
  {id: 'd10', clip: 'rooftops', start: drop1(5), end: drop1(6), src: 9.0, punch: 1.55, push: 1.65, cx: 0.5, cy: 0.48, fx: {punchIn: true, rgbIn: 24}},
  {id: 'd11', clip: 'park', start: drop1(6), end: drop1(7), src: 9.0, punch: 1.5, push: 1.6, cx: 0.5, cy: 0.5, fx: {punchIn: true, rgbIn: 24}},
  {id: 'd12', clip: 'boss', start: drop1(7), end: drop1(8), src: 25.3, punch: 1.6, push: 1.72, cx: 0.5, cy: 0.36, fx: {punchIn: true, rgbIn: 36}},

  // HERO CITY
  {id: 'hub', clip: 'hub', start: bar(20), end: bar(21), src: 2.0, punch: 1.25, push: 1.4, cx: 0.5, cy: 0.5, fx: {punchIn: true, grade: 'bright'}},

  // (bar 21 UNLOCKS is a motion-graphics scene with shop/map/complete phones — see UNLOCK_SCREENS)

  // END CARD lead-in: "YOU SAVED THE WORLD!" card for one beat on the impact
  {id: 'win', clip: 'boss', start: bar(22), end: beatOf(22, 1), src: 28.4, punch: 1.12, push: 1.22, cx: 0.5, cy: 0.5, fx: {punchIn: true, rgbIn: 20}},
];

export const UNLOCK_SCREENS = {
  start: bar(21),
  end: bar(22),
  shop: {clip: 'shop', src: 0.5},
  map: {clip: 'map', src: 0.5},
  complete: {clip: 'complete', src: 0.8, at: beatOf(21, 2)}, // pops on the EARN beat
};

export const END_CARD = {
  start: beatOf(22, 1), // after the one-beat win card
  logoAt: beatOf(22, 1),
  taglineAt: beatOf(22, 2),
  tagline: 'Pint-Sized Hero, Big-Time Save',
  badges: [
    {text: 'No ads', at: bar(23)},
    {text: 'No in-app purchases', at: beatOf(23, 1)},
    {text: 'Plays offline', at: beatOf(23, 2)},
  ],
  ctaAt: BUTTON_HIT,
  cta: 'Coming soon on iPhone',
  fadeStart: DURATION_S - 0.5,
};

// ── Captions ────────────────────────────────────────────────────────────────
// kind 'tier': BIG word (per-letter springs) + small subline pill.
// kind 'kinetic': words that pop one by one on the given beats (tagline).
// kind 'stack': build-up words stacked, last one huge & red.
export type Caption =
  | {
      kind: 'tier';
      id: string;
      big: string;
      bigAt: number;
      out: number;
      subs?: {text: string; at: number; out?: number}[];
      stars?: boolean;
      tilt?: number;
    }
  | {kind: 'kinetic'; id: string; lines: {words: {text: string; at: number; accent?: boolean}[]}[]; out: number}
  | {kind: 'stack'; id: string; words: {text: string; at: number; huge?: boolean}[]; out: number};

export const CAPTIONS: Caption[] = [
  {
    kind: 'kinetic', id: 'tag1', out: bar(5),
    lines: [{words: [{text: 'PINT-', at: beatOf(4, 0)}, {text: 'SIZED', at: beatOf(4, 1)}]}, {words: [{text: 'HERO.', at: beatOf(4, 2), accent: true}]}],
  },
  {
    kind: 'kinetic', id: 'tag2', out: bar(6),
    lines: [{words: [{text: 'BIG-', at: beatOf(5, 0)}, {text: 'TIME', at: beatOf(5, 1)}]}, {words: [{text: 'SAVE.', at: beatOf(5, 2), accent: true}]}],
  },
  {
    kind: 'tier', id: 'sneak', big: 'SNEAK', bigAt: bar(6), out: bar(8), tilt: -4,
    subs: [{text: 'past the minions', at: beatOf(6, 1), out: bar(7)}, {text: '…and their lasers', at: bar(7)}],
  },
  {kind: 'tier', id: 'rescue', big: 'RESCUE', bigAt: bar(8), out: bar(10), tilt: 3, subs: [{text: 'the citizens', at: beatOf(8, 1)}]},
  {kind: 'tier', id: 'chase', big: 'CHASE', bigAt: bar(10), out: bar(12), tilt: -3, subs: [{text: 'the getaway', at: beatOf(10, 1)}]},
  {kind: 'tier', id: 'dodge', big: 'DODGE', bigAt: bar(12), out: beatOf(13, 3) + BEAT / 2, tilt: 4, subs: [{text: 'the traps', at: beatOf(12, 1)}]},
  {
    kind: 'stack', id: 'build', out: SILENCE_GAP[0],
    words: [{text: 'FACE', at: bar(14)}, {text: 'LORD', at: beatOf(14, 2)}, {text: 'CHOW-CHOW', at: bar(15), huge: true}],
  },
  {kind: 'tier', id: 'explore', big: 'EXPLORE', bigAt: bar(20), out: bar(21), tilt: -3, subs: [{text: 'Hero City', at: beatOf(20, 1)}]},
  {kind: 'tier', id: 'unlock', big: 'UNLOCK', bigAt: bar(21), out: beatOf(21, 2), tilt: 3, subs: [{text: 'gadgets & costumes', at: beatOf(21, 1)}]},
  {kind: 'tier', id: 'earn', big: 'EARN', bigAt: beatOf(21, 2), out: bar(22), tilt: -3, stars: true},
];

export const EARN_STARS_AT = beatOf(21, 2) + 0.1;

// ── Camera hits (shake), flashes, comic bursts ─────────────────────────────
export type Hit = {t: number; amp: number; decay?: number};
export const SHAKES: Hit[] = [
  {t: bar(3), amp: 26, decay: 0.07}, // logo slam — ~3 frames of shake
  ...SHOTS.filter((s) => s.id.startsWith('d')).map((s) => ({t: s.start, amp: 9, decay: 0.09})),
  ...[bar(16), bar(17), bar(18), bar(19)].map((t) => ({t, amp: 30, decay: 0.16})), // drop downbeats
  {t: bar(22), amp: 22, decay: 0.12},
  {t: END_CARD.logoAt, amp: 20, decay: 0.1},
  {t: BUTTON_HIT, amp: 16, decay: 0.1},
];

export type Flash = {t: number; frames: number; opacity: number; color?: string};
export const FLASHES: Flash[] = [
  ...[0, beatOf(1, 2), bar(2), beatOf(2, 2)].map((t) => ({t, frames: 3, opacity: 0.85})),
  {t: bar(3), frames: 5, opacity: 1},
  {t: bar(4), frames: 3, opacity: 0.6},
  ...[bar(6), bar(8), bar(10), bar(12), bar(20)].map((t) => ({t, frames: 3, opacity: 0.55})),
  {t: bar(16) - 2 / FPS, frames: 6, opacity: 1}, // white flash frame out of the silence into the drop
  ...SHOTS.filter((s) => s.id.startsWith('d') && s.id !== 'd01').map((s, i) => ({t: s.start, frames: 2, opacity: i % 2 ? 0.7 : 0.45})),
  {t: bar(21), frames: 3, opacity: 0.5},
  {t: bar(22), frames: 5, opacity: 1},
  {t: END_CARD.logoAt, frames: 4, opacity: 0.9},
  {t: BUTTON_HIT, frames: 6, opacity: 0.9, color: '#FFF3C4'},
];

export const POWS: {t: number; text: string; x: number; y: number; rot: number}[] = [
  {t: drop2(2) + 0.04, text: 'POW!', x: 0.7, y: 0.36, rot: -12},
  {t: drop1(7) + 0.18, text: 'POW!', x: 0.3, y: 0.34, rot: 10},
];

// ── Audio ───────────────────────────────────────────────────────────────────
// Music file carries the big impacts (3.75 / 28.125 / 39.375) — SFX stay ~-8…-12 dB under it.
// music peaks at -1.3 dBTP on its own; trim 0.4 dB so SFX + AAC never cross -1 dBTP (master stays ≈ -14 LUFS)
export const MUSIC = {file: 'audio/sizzle_music.wav', volume: Math.pow(10, -0.4 / 20)};
/** global SFX trim (dB) applied on top of each cue's level */
export const SFX_TRIM_DB = -2;

export const db = (d: number) => Math.pow(10, d / 20);

export type SfxCue = {t: number; file: string; db: number; note?: string};
// `t` is when the sound should START (whooshes are pre-rolled so they peak on the cut).
const W_SHORT = 0.16;
const W_LONG = 0.42;
export const SFX: SfxCue[] = [
  // section transitions
  {t: bar(4) - W_SHORT, file: 'whoosh_short.wav', db: -11, note: 'into tagline'},
  {t: bar(6) - W_SHORT, file: 'whoosh_short.wav', db: -11, note: 'into sneak'},
  {t: bar(8) - W_SHORT, file: 'whoosh_short.wav', db: -12, note: 'into rescue'},
  {t: bar(10) - W_SHORT, file: 'whoosh_short.wav', db: -11, note: 'into chase'},
  {t: bar(12) - W_SHORT, file: 'whoosh_short.wav', db: -12, note: 'into traps'},
  {t: bar(14) - W_LONG, file: 'whoosh_long.wav', db: -9, note: 'whip-pan into build'},
  {t: bar(20) - W_SHORT, file: 'whoosh_short.wav', db: -11, note: 'into hero city'},
  {t: bar(21) - W_SHORT, file: 'whoosh_short.wav', db: -12, note: 'into unlocks'},
  {t: END_CARD.logoAt - W_SHORT, file: 'whoosh_short.wav', db: -12, note: 'into end card logo'},
  // caption words
  ...CAPTIONS.flatMap((c): SfxCue[] => {
    if (c.kind === 'tier') {
      return [
        {t: c.bigAt, file: 'swoosh_up.wav', db: -13, note: c.big},
        ...(c.subs ?? []).map((s) => ({t: s.at, file: 'pop.wav', db: -11, note: s.text})),
      ];
    }
    if (c.kind === 'kinetic') return c.lines.flatMap((l) => l.words.map((w) => ({t: w.at, file: 'pop.wav', db: -10, note: w.text})));
    return c.words.map((w) => ({t: w.at, file: w.huge ? 'impact_small.wav' : 'pop.wav', db: w.huge ? -10 : -11, note: w.text}));
  }),
  // drop cuts (the downbeat at 28.125 is already a big hit in the music)
  ...SHOTS.filter((s) => s.id.startsWith('d') && s.id !== 'd01').map((s) => ({t: s.start, file: 'impact_small.wav', db: -14, note: `drop cut ${s.id}`})),
  // sparkles
  {t: bar(3) + 0.05, file: 'sparkle.wav', db: -10, note: 'logo'},
  {t: END_CARD.logoAt + 0.05, file: 'sparkle.wav', db: -10, note: 'end logo'},
  ...END_CARD.badges.map((b) => ({t: b.at, file: 'sparkle.wav', db: -12, note: b.text})),
  {t: END_CARD.ctaAt, file: 'pop.wav', db: -9, note: 'CTA'},
  // coin on EARN ★★★ (each star)
  ...[0, 1, 2].map((i) => ({t: EARN_STARS_AT + i * 0.11, file: 'coin.wav', db: -11 - i, note: 'star'})),
  // POW bursts
  ...POWS.map((p) => ({t: p.t, file: 'impact_small.wav', db: -12, note: 'pow'})),
];
