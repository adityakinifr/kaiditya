# Kaiditya sizzle reel

47.5 s trailer, 60 fps, 128 BPM beat-synced, -14 LUFS.

- `Kaiditya_Sizzle_Vertical_1080x1920.mp4` — Reels / Shorts / TikTok / App Store preview
- `Kaiditya_Sizzle_Landscape_1920x1080.mp4` — YouTube / web
- `poster_*.png` — thumbnails
- `EDL.md` — shot list by bar

These are share encodes (CRF 23). The CRF 17 masters (>100 MB), the raw simulator clips
(`remotion/public/`) and the WAV stems live in Google Drive: `My Drive/Kaiditya/sizzle/`.

## Rebuilding

- Music + SFX: `audio/build_music.py` (cue sheet in `audio/cues.json`).
- Video: `remotion/` (Remotion 4). `public/` holds the clips, audio, fonts and sprites and is
  not committed (copy it from `My Drive/Kaiditya/sizzle/remotion/public/`); see `remotion/README.md` for how to repopulate it and render.
- Clips are captured from the simulator with the `KAIDITYA_CLEAN=1 KAIDITYA_SILENT=1` debug hooks.
