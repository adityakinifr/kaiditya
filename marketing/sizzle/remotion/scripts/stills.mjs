// Usage: node scripts/stills.mjs <CompId> <outDir> <t1> <t2> ...   (times in seconds; frame = round(t*60))
import {bundle} from '@remotion/bundler';
import {renderStill, selectComposition} from '@remotion/renderer';
import path from 'node:path';
import fs from 'node:fs';

const [, , compId, outDir, ...times] = process.argv;
fs.mkdirSync(outDir, {recursive: true});
const serveUrl = await bundle({entryPoint: path.resolve('src/index.ts'), publicDir: path.resolve('public')});
const composition = await selectComposition({serveUrl, id: compId});
for (const t of times) {
  const frame = Math.min(composition.durationInFrames - 1, Math.round(parseFloat(t) * 60));
  const output = path.join(outDir, `${compId}_${String(frame).padStart(4, '0')}.png`);
  await renderStill({serveUrl, composition, frame, output, imageFormat: 'png', scale: 1});
  console.log(output);
}
