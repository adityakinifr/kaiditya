#!/usr/bin/env python3
"""Finish the raw floor-tile renders from blender/tiles.py.

  tiles_post.py RAW_DIR SPRITES_DIR PREVIEWS_DIR MANIFEST_JSON [--hero HERO_PNG] [--only park,docks]

* Base / path tiles: crop the overscan, tile 3x3, Lanczos-downsample (premultiplied) and cut out
  the centre, so the 1x 233x133 tile is still seamless (no clamped-edge seam), then force opaque.
* Decals: premultiplied downsample (finish.downsample) and trim to the visible pixels.
* Writes SPRITES_DIR/tiles_<biome>.atlas/, PREVIEWS_DIR/tiles.png (contact sheet),
  PREVIEWS_DIR/tiles_check_<biome>.png (3x3 random mix of variants + path strip + hero, for seams)
  and the "tiles" section of the manifest.
"""
import colorsys, json, os, random, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import finish   # noqa: E402  (shared premultiplied Lanczos downsample)


def wrap_downsample(src, ov, ss, size):
    im = Image.open(src).convert("RGBA")
    W, H = size[0] * ss, size[1] * ss
    im = im.crop((ov, ov, ov + W, ov + H))
    big = Image.new("RGBA", (3 * W, 3 * H))
    for i in range(3):
        for j in range(3):
            big.paste(im, (i * W, j * H))
    small = big.convert("RGBa").resize((3 * size[0], 3 * size[1]), Image.LANCZOS).convert("RGBA")
    t = small.crop((size[0], size[1], 2 * size[0], 2 * size[1]))
    t.putalpha(255)
    return t


def trim(path):
    im = Image.open(path).convert("RGBA")
    b = im.getchannel("A").point(lambda a: 255 if a > 3 else 0).getbbox()
    if b:
        b = (max(0, b[0] - 1), max(0, b[1] - 1), min(im.width, b[2] + 1), min(im.height, b[3] + 1))
        im = im.crop(b)
    im.save(path, optimize=True)
    return im.size


def stats(im):
    """Mean HSV saturation / value of the opaque pixels (sampled)."""
    im = im.convert("RGBA")
    data = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
    px = [p for p in data if p[3] > 200][::7]
    s = v = 0.0
    lo, hi = 1.0, 0.0
    for r, g, b, _ in px:
        h_, s_, v_ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        s += s_; v += v_
        lo, hi = min(lo, v_), max(hi, v_)
    n = max(1, len(px))
    return s / n, v / n


def check_image(atlas, info, hero, size):
    """3x3 random variant mix, a path strip across the middle row, a few decals and the hero."""
    tw, th = size
    rnd = random.Random(1)
    cols, rows = 5, 5
    S = Image.new("RGBA", (cols * tw, rows * th))
    for j in range(rows):
        for i in range(cols):
            name = rnd.choice(info["path"]) if j == 2 else rnd.choice(info["base"])
            S.paste(Image.open(os.path.join(atlas, name + ".png")), (i * tw, j * th))
    for k, d in enumerate(info["decals"]):
        im = Image.open(os.path.join(atlas, d + ".png")).convert("RGBA")
        x = 30 + (k * 197) % (cols * tw - im.width - 30)
        y = (k % 2) * 3 * th + 30 + (k * 37) % 60
        S.alpha_composite(im, (x, y))
    if hero and os.path.exists(hero):
        h = Image.open(hero).convert("RGBA")
        S.alpha_composite(h, (cols * tw // 2 - h.width // 2, 2 * th + th // 2 - int(h.height * 0.82)))
    return S


def main(argv):
    raw, sprites, previews, manifest = argv[:4]
    hero = argv[argv.index("--hero") + 1] if "--hero" in argv else None
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
    meta = json.load(open(os.path.join(raw, "_meta.json")))
    size, ov, ss = tuple(meta["tile_px"]), meta["overscan_raw_px"], meta["ss"]
    man = json.load(open(manifest)) if os.path.exists(manifest) else {}
    tiles = man.get("tiles", {})
    sheet_rows = []
    for biome, info in meta["biomes"].items():
        if only and biome not in only:
            continue
        atlas = os.path.join(sprites, f"tiles_{biome}.atlas")
        os.makedirs(atlas, exist_ok=True)
        for n in os.listdir(atlas):   # stale sprites from older builds
            if n.endswith(".png") and n[:-4] not in info["base"] + info["path"] + info["decals"]:
                os.remove(os.path.join(atlas, n))
        for n in info["base"] + info["path"]:
            wrap_downsample(os.path.join(raw, n + ".png"), ov, ss, size).save(os.path.join(atlas, n + ".png"), optimize=True)
        dsz = {}
        for n in info["decals"]:
            dst = os.path.join(atlas, n + ".png")
            finish.downsample(os.path.join(raw, n + ".png"), dst, ss)
            dsz[n] = list(trim(dst))
        s_, v_ = stats(Image.open(os.path.join(atlas, info["base"][0] + ".png")))
        tiles[biome] = {
            "atlas": f"tiles_{biome}",
            "tile_size_px": list(size),
            "tile_size_pt": [round(size[0] * 0.3, 1), round(size[1] * 0.3, 1)],
            "base": info["base"],
            "path": info["path"],
            "decals": info["decals"],
            "decal_size_px": dsz,
            "mean_saturation": round(s_, 3),
            "mean_value": round(v_, 3),
        }
        chk = check_image(atlas, info, hero, size)
        chk.convert("RGB").save(os.path.join(previews, f"tiles_check_{biome}.png"), optimize=True)
        sheet_rows.append((biome, atlas, info))
        print(f"[tiles_post] {biome}: sat {s_:.2f} val {v_:.2f}")
    man["tiles"] = dict(sorted(tiles.items()))
    man["tiles_note"] = ("SKTileMapNode tileSize 70x40 pt (233x133 px * 0.3). All <biome>_0..3 variants "
                         "are seamless against each other; <biome>_path_* are seamless against each other "
                         "(walkway strip). Decals: anchor (0.5, 0.5), scatter with a seeded RNG; "
                         "stains/cracks can use blendMode .multiply or alpha 0.6-0.9.")
    json.dump(man, open(manifest, "w"), indent=2)
    sheet(sheet_rows, os.path.join(previews, "tiles.png"), size)


def sheet(rows, out, size):
    tw, th = size
    pad, lab = 6, 70
    maxd = max(len(i["decals"]) for _, _, i in rows) if rows else 0
    ncol = 6 + maxd
    W = lab + ncol * (tw + pad)
    H = 20 + len(rows) * (th + pad + 14)
    S = Image.new("RGBA", (W, H), (58, 66, 84, 255))
    d = ImageDraw.Draw(S)
    d.text((6, 4), "base 0-3 | path 0-1 | decals (on base_0)", fill=(235, 235, 240, 255))
    for r, (biome, atlas, info) in enumerate(rows):
        y = 20 + r * (th + pad + 14)
        d.text((6, y + th // 2), biome, fill=(235, 235, 240, 255))
        bg = Image.open(os.path.join(atlas, info["base"][0] + ".png")).convert("RGBA")
        for c, n in enumerate(info["base"] + info["path"] + info["decals"]):
            im = Image.open(os.path.join(atlas, n + ".png")).convert("RGBA")
            x = lab + c * (tw + pad)
            if n in info["decals"]:
                cellim = bg.copy()
                cellim.alpha_composite(im, ((tw - im.width) // 2, (th - im.height) // 2))
                im = cellim
            S.alpha_composite(im, (x, y))
            d.text((x, y + th + 1), n.replace(biome + "_", ""), fill=(200, 200, 210, 255))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    S.convert("RGB").save(out, optimize=True)


if __name__ == "__main__":
    main(sys.argv[1:])
