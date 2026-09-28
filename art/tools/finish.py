#!/usr/bin/env python3
"""Post-process raw 2x Blender renders -> final sprites + contact sheets.

  finish.py ASSET RAW_DIR OUT_DIR SHEET_PNG [--factor 2]
  finish.py --montage OUT.png IMG... (quick ad-hoc review grid)

Downsamples every PNG in RAW_DIR by --factor with Lanczos (premultiplied, so edges stay clean)
into OUT_DIR, then writes a labelled contact sheet: one row per direction (n, ne, e, se, s, sw, w,
nw), columns = idle, walk 0..3.  Assets with a single image (vehicles) get a one-cell sheet.
Requires Pillow (python3 -m pip install pillow). Without Pillow it falls back to macOS `sips`
for the resize and skips the sheet."""
import os, re, sys, shutil, subprocess

ORDER = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
BG = (58, 66, 84, 255)
CELL_BG = (86, 132, 84, 255)   # grass-ish, similar to the in-game ground

try:
    from PIL import Image, ImageDraw
    HAVE_PIL = True
except Exception:
    HAVE_PIL = False


def downsample(src, dst, factor):
    if HAVE_PIL:
        im = Image.open(src).convert("RGBA")
        w, h = im.size
        # premultiply to avoid dark fringes on transparent edges
        pm = im.convert("RGBa").resize((w // factor, h // factor), Image.LANCZOS)
        pm.convert("RGBA").save(dst, optimize=True)
    else:
        shutil.copy(src, dst)
        w = int(subprocess.check_output(["sips", "-g", "pixelWidth", dst]).split()[-1])
        subprocess.run(["sips", "-Z", str(w // factor), dst], check=True, capture_output=True)


def cell(img, size):
    c = Image.new("RGBA", size, CELL_BG)
    c.alpha_composite(img, ((size[0] - img.width) // 2, (size[1] - img.height) // 2))
    return c


def sheet(asset, files, out_png):
    imgs = {os.path.basename(f): Image.open(f).convert("RGBA") for f in files}
    pad, label_w = 6, 34
    rows = []
    for d in ORDER:
        row = [n for n in (f"{asset}_idle_{d}.png",) if n in imgs]
        row += sorted(n for n in imgs if re.fullmatch(rf"{asset}_walk_{d}_\d+\.png", n))
        if row:
            rows.append((d, row))
    if not rows:   # vehicles / singles
        rows = [("", sorted(imgs))]
    cw = max(i.width for i in imgs.values()); ch = max(i.height for i in imgs.values())
    ncol = max(len(r) for _, r in rows)
    W = label_w + ncol * (cw + pad) + pad
    H = 24 + len(rows) * (ch + pad) + pad
    S = Image.new("RGBA", (W, H), BG)
    dr = ImageDraw.Draw(S)
    head = "cols: idle, walk 0-3" if rows[0][0] else "  ".join(n[:-4] for n in rows[0][1])
    dr.text((pad, 6), f"{asset}   {head}   (max {cw}x{ch})", fill=(235, 235, 240, 255))
    for r, (d, names) in enumerate(rows):
        y = 24 + r * (ch + pad)
        dr.text((6, y + ch // 2 - 6), d, fill=(235, 235, 240, 255))
        for c, n in enumerate(names):
            S.alpha_composite(cell(imgs[n], (cw, ch)), (label_w + c * (cw + pad), y))
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    S.convert("RGB").save(out_png, optimize=True)


def montage(out, files, scale=1):
    ims = [Image.open(f).convert("RGBA") for f in files]
    cw = max(i.width for i in ims); ch = max(i.height for i in ims)
    ncol = min(len(ims), 5)
    nrow = (len(ims) + ncol - 1) // ncol
    S = Image.new("RGBA", (ncol * cw, nrow * ch), BG)
    for k, im in enumerate(ims):
        S.alpha_composite(cell(im, (cw, ch)), ((k % ncol) * cw, (k // ncol) * ch))
    if scale != 1:
        S = S.resize((int(S.width * scale), int(S.height * scale)), Image.LANCZOS)
    S.convert("RGB").save(out)


def main(argv):
    if argv and argv[0] == "--montage":
        scale = 1.0
        if "--scale" in argv:
            i = argv.index("--scale"); scale = float(argv[i + 1]); del argv[i:i + 2]
        montage(argv[1], argv[2:], scale); return
    factor = 2
    if "--factor" in argv:
        i = argv.index("--factor"); factor = int(argv[i + 1]); del argv[i:i + 2]
    asset, raw, out, sheet_png = argv[:4]
    os.makedirs(out, exist_ok=True)
    files = []
    for n in sorted(os.listdir(raw)):
        if n.endswith(".png"):
            dst = os.path.join(out, n)
            downsample(os.path.join(raw, n), dst, factor)
            files.append(dst)
    if HAVE_PIL:
        sheet(asset, files, sheet_png)
        print(f"[finish] {asset}: {len(files)} sprites -> {out}; sheet {sheet_png}")
    else:
        print(f"[finish] {asset}: {len(files)} sprites -> {out}; (no Pillow: sheet skipped)")


if __name__ == "__main__":
    main(sys.argv[1:])
