#!/bin/sh
# Copies the latest music/SFX from ../audio into public/audio (Remotion only serves public/).
# Missing files are fine: the compositions check getStaticFiles() and skip absent audio.
set -e
cd "$(dirname "$0")/.."
mkdir -p public/audio
for f in ../audio/*.wav ../audio/cues.json; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in *nomaster*) continue;; esac
  cp -p "$f" public/audio/
done
ls public/audio
