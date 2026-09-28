// Checks every cut / section boundary / caption / SFX cue sits on the 128 BPM grid (1/2-beat resolution)
// and reports its frame (round(t*60)). Run: node scripts/verify-grid.mjs
import {buildSync} from 'esbuild';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const out = path.join(os.tmpdir(), `timeline-${process.pid}.mjs`);
buildSync({entryPoints: ['src/timeline.ts'], bundle: true, format: 'esm', platform: 'node', outfile: out, logLevel: 'error'});
const T = await import(pathToFileURL(out).href);
const half = T.BEAT / 2;
const onGrid = (t) => Math.abs(t / half - Math.round(t / half)) < 1e-9;
let bad = 0;
const row = (label, t, mustGrid = true) => {
  const ok = !mustGrid || onGrid(t);
  if (!ok) bad++;
  console.log(`${ok ? 'OK ' : 'OFF'}  ${label.padEnd(34)} t=${t.toFixed(5).padStart(9)}  frame=${String(T.f(t)).padStart(4)}  beat=${(t / T.BEAT).toFixed(3)}`);
};
console.log('── sections');
for (const s of T.SECTIONS) row(`section ${s.name}`, s.start);
console.log('── shots (cut-in points; cold-open flashes end off-grid by design)');
for (const s of T.SHOTS) row(`shot ${s.id} ${s.clip}@${s.src}`, s.start);
console.log('── contiguity');
for (let i = 1; i < T.SHOTS.length; i++) {
  const a = T.SHOTS[i - 1], b = T.SHOTS[i];
  if (T.f(a.end) > T.f(b.start)) { console.log(`OVERLAP ${a.id} → ${b.id}`); bad++; }
}
console.log('── key hits');
for (const t of T.IMPACTS) row('impact', t);
row('button', T.BUTTON_HIT);
row('silence gap start', T.SILENCE_GAP[0]);
console.log(`total frames ${T.DURATION_FRAMES} (${T.DURATION_S}s @ ${T.FPS})`);
console.log(bad ? `\n${bad} problem(s)` : '\nall cuts on grid ✔');
process.exit(bad ? 1 : 0);
