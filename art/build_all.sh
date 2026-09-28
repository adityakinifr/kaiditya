#!/usr/bin/env bash
# Render every sprite asset headlessly with Blender, then downsample into Resources/Sprites and
# write review contact sheets to art/previews.
#
#   art/build_all.sh                 # everything
#   art/build_all.sh hero minion     # just these assets
#   QUICK=1 art/build_all.sh hero    # idle frames for 4 directions only (fast look-dev)
#   BLENDER=/path/to/Blender art/build_all.sh
#
# Assets: hero minion drone chowchow npc_mayor npc_gran npc_tommy vehicles props tiles buildings
#   props -> Resources/Sprites/props.atlas + art/props_manifest.json + art/previews/props.png
#   tiles -> Resources/Sprites/tiles_<biome>.atlas + manifest "tiles" + art/previews/tiles*.png
#   buildings -> Resources/Sprites/buildings.atlas + art/buildings_manifest.json + art/previews/buildings.png
set -euo pipefail

ART="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$ART/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT_ROOT="$ROOT/Resources/Sprites"
RAW_ROOT="$ART/.cache/raw"
PREVIEWS="$ART/previews"
ALL=(hero minion drone chowchow npc_mayor npc_gran npc_tommy vehicles props tiles buildings)
ASSETS=("$@"); [ ${#ASSETS[@]} -eq 0 ] && ASSETS=("${ALL[@]}")

# A python3 that has Pillow (for Lanczos downsampling + contact sheets).
PY=""
for p in python3 /usr/bin/python3 /opt/homebrew/bin/python3; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c "import PIL" 2>/dev/null; then PY="$p"; break; fi
done
if [ -z "$PY" ]; then
  echo "warning: no python3 with Pillow found; using sips for resizing, contact sheets skipped" >&2
  PY="python3"
fi

EXTRA=(); [ "${QUICK:-0}" = "1" ] && EXTRA+=(--quick)
export PYTHONDONTWRITEBYTECODE=1
MANIFEST="$ART/props_manifest.json"
HERO_REF="$OUT_ROOT/hero.atlas/hero_idle_se.png"
mkdir -p "$OUT_ROOT" "$RAW_ROOT" "$PREVIEWS"
T0=$(date +%s)

for asset in "${ASSETS[@]}"; do
  case "$asset" in
    npc_*) script="npc.py"; args=(--npc "${asset#npc_}") ;;
    *)     script="$asset.py"; args=() ;;
  esac
  raw="$RAW_ROOT/$asset"
  mkdir -p "$raw"
  # props/tiles: drop stale raw renders so removed sprites don't linger in the atlases
  case "$asset" in props|tiles|buildings) find "$raw" -maxdepth 1 -name '*.png' -delete ;; esac
  t=$(date +%s)
  echo "==> $asset ($script)"
  "$BLENDER" -b --factory-startup -P "$ART/blender/$script" -- --out "$raw" ${args[@]+"${args[@]}"} ${EXTRA[@]+"${EXTRA[@]}"} \
    > "$RAW_ROOT/$asset.log" 2>&1 || { echo "Blender failed for $asset; see $RAW_ROOT/$asset.log" >&2; exit 1; }
  grep -h "\[sprites\]" "$RAW_ROOT/$asset.log" || true
  # Each asset becomes a SpriteKit texture atlas folder: Xcode compiles *.atlas automatically.
  case "$asset" in
    props)
      # downsample like the characters, then crop + anchors + manifest + contact sheet
      find "$OUT_ROOT/props.atlas" -maxdepth 1 -name '*.png' -delete 2>/dev/null || true
      "$PY" "$ART/tools/finish.py" props "$raw" "$OUT_ROOT/props.atlas" "$RAW_ROOT/props_finish_sheet.png"
      "$PY" "$ART/tools/props_post.py" "$raw" "$OUT_ROOT/props.atlas" "$MANIFEST" "$PREVIEWS/props.png" --hero "$HERO_REF"
      ;;
    buildings)
      # 2x -> 1x Lanczos (finish.downsample), crop + anchors + sign/door offsets + manifest + contact sheet
      find "$OUT_ROOT/buildings.atlas" -maxdepth 1 -name '*.png' -delete 2>/dev/null || true
      "$PY" "$ART/tools/buildings_post.py" "$raw" "$OUT_ROOT/buildings.atlas" "$ART/buildings_manifest.json" "$PREVIEWS/buildings.png" --hero "$HERO_REF"
      ;;
    tiles)
      # seamless wrap-downsample -> one atlas per biome, check sheets, manifest "tiles" section
      "$PY" "$ART/tools/tiles_post.py" "$raw" "$OUT_ROOT" "$PREVIEWS" "$MANIFEST" --hero "$HERO_REF"
      ;;
    *)
      "$PY" "$ART/tools/finish.py" "$asset" "$raw" "$OUT_ROOT/$asset.atlas" "$PREVIEWS/${asset}_sheet.png"
      ;;
  esac
  echo "    $(( $(date +%s) - t ))s"
done

echo "Done in $(( $(date +%s) - T0 ))s -> $OUT_ROOT"
