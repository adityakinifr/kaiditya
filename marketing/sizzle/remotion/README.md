# Kaiditya sizzle reel (Remotion)

Two compositions, one timeline:

| id | size | fps | length |
|---|---|---|---|
| `SizzleVertical` | 1080×1920 | 60 | 2850 frames (47.5 s) |
| `SizzleLandscape` | 1920×1080 | 60 | 2850 frames (47.5 s) |

Everything (shots, punch-in centres, captions, flashes, camera shakes, POW bursts, SFX cues) lives in
`src/timeline.ts`, on the 128 BPM grid (beat 0.46875 s; frame = round(t × 60)).

## Setup

```sh
cd ~/artwork/sizzle/remotion
npm install
# clips are hard-linked into public/clips (Remotion only serves public/). Re-link if clips change:
for f in ../clips/*.mp4; do ln -f "$f" public/clips/; done
# copy the latest music + SFX into public/audio (skips *_nomaster*). Missing files => silent render.
./scripts/sync-audio.sh
```

## Preview / check

```sh
npx remotion studio                         # interactive preview
node scripts/verify-grid.mjs                # asserts every cut sits on the beat grid, prints frames
node scripts/stills.mjs SizzleVertical out/ 3.8 28.2 43.5   # spot-check stills at given seconds
```

## Final renders (H.264 CRF 17, yuv420p BT.709 limited range, AAC 320k)

```sh
./scripts/sync-audio.sh
npx remotion render SizzleVertical ../Kaiditya_Sizzle_Vertical_1080x1920.mp4 \
  --codec=h264 --crf=17 --pixel-format=yuv420p --color-space=bt709 --audio-codec=aac --audio-bitrate=320k --concurrency=6
npx remotion render SizzleLandscape ../Kaiditya_Sizzle_Landscape_1920x1080.mp4 \
  --codec=h264 --crf=17 --pixel-format=yuv420p --color-space=bt709 --audio-codec=aac --audio-bitrate=320k --concurrency=6

# posters (end card) + loudness check
npx remotion still SizzleVertical ../poster_vertical.png --frame=2760
npx remotion still SizzleLandscape ../poster_landscape.png --frame=2760
ffmpeg -i ../Kaiditya_Sizzle_Vertical_1080x1920.mp4 -af ebur128=peak=true -f null - 2>&1 | tail -12
```

Contact sheets (3×4, 12 frames evenly sampled):

```sh
for v in Vertical:1080x1920:contact_vertical Landscape:1920x1080:contact_landscape; do
  IFS=: read n s o <<< "$v"
  ffmpeg -y -i ../Kaiditya_Sizzle_${n}_${s}.mp4 -vf "select='not(mod(n\,237))',scale=iw/3:-1,tile=3x4" -frames:v 1 -fps_mode vfr ../$o.png
done
```

## Wiring audio

* Music: `audio/sizzle_music.wav` (already contains the big impacts at 3.75 / 28.125 / 39.375).
* SFX cues: `SFX` array in `src/timeline.ts` — `{t, file, db, note}`; `t` is the start time (whooshes are pre-rolled
  to peak on the cut). Levels are −9…−14 dB under the music. Nothing is placed inside the silence gap (27.656–28.125).
* Music is trimmed −0.4 dB (`MUSIC.volume`) and SFX get a further `SFX_TRIM_DB = −2`: the music alone peaks at −1.3 dBTP,
  so this keeps the master ≈ −14.3 LUFS integrated / ≈ −1.2 dBTP after AAC.
* `AudioLayer` checks `getStaticFiles()` and simply skips any file that isn't in `public/audio`.

## Layout

* `src/timeline.ts` — the edit (single source of truth)
* `src/Sizzle.tsx` — the two compositions (layout geometry for captions / end card / phone stage)
* `src/components/ShotVideo.tsx` — punch-in + Ken Burns + grade + RGB split / glitch / whip / suck-in per shot
* `src/components/Gameplay.tsx` — all shots on the grid + speed lines + build vignette
* `src/components/Captions.tsx` — two-tier captions, kinetic tagline, build-up stack, EARN stars
* `src/components/Logo.tsx` — code-built KAIDITYA logo, dancing hero sprite
* `src/components/Scenes.tsx` — phone frame, unlocks scene, POW bursts, logo scene, end card, audio
* `src/components/Fx.tsx` — grain, vignette, light leaks, flashes, sunburst, sparkles, floating coins/crystals
