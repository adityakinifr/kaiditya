"""Seamless biome floor tiles + scatter decals for the 55deg camera (graphics plan P3).

One tile = 2 x TY world units of ground, framed by the characters' 55deg orthographic camera:
233 x 133 px at 1x (70 x 40 pt at worldScale 0.3).  Renders at 2x (466 x 266) plus an
overscan border; tools/tiles_post.py crops the border and wrap-downsamples (3x3 tile, Lanczos,
crop the centre) so the 1x tile stays seamless.

Seamless across VARIANTS (SKTileMapNode mixes them randomly):
  * everything is built in one period and wrapped (copies at +-TX / +-TY),
  * the layout (plank rows, slab joints, seams) is shared by all variants of a biome,
  * any piece or scatter item that CROSSES the tile edge takes its colour / details from the
    shared seed; only interior pieces and items use the variant seed.

Outputs (raw dir):  <biome>_0..3.png, <biome>_path_0..1.png, <biome>_decal_<i>.png (transparent)
Run: Blender -b -P tiles.py -- --out RAW_DIR [--only park,docks]
"""
import os, sys, math, json, random, time
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import bpy
import common as C
import envkit as E
importlib.reload(C); importlib.reload(E)

TILE_PX = (233, 133)                     # final 1x size
RAW_PX = (TILE_PX[0] * C.SS, TILE_PX[1] * C.SS)
OV = 16                                  # raw overscan px on each side (cropped in post)
TX = 2.0                                 # tile width, world units
COS = math.cos(math.radians(C.CAM_TILT))
TY = TX * RAW_PX[1] / RAW_PX[0] / COS    # ground depth that projects to exactly 266 raw px (~1.99)
HX, HY = TX / 2, TY / 2
DECAL_W = 1.2                            # decal canvas: 1.2 units wide -> 140 x 80 px at 1x
DECAL_PX = (140 * C.SS, 80 * C.SS)
EPS = 1e-4


def hexs(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def shade(h, k):
    """sRGB hex -> value-scaled linear colour."""
    return C.rgb(*[min(1.0, c * k) for c in hexs(h)])


# ----------------------------------------------------------------------------- geometry builder
class B:
    """Accumulates many small primitives into one mesh (one object per material)."""
    def __init__(self):
        self.v, self.f = [], []

    def _add(self, verts, faces):
        o = len(self.v)
        self.v += verts
        self.f += [tuple(i + o for i in f) for f in faces]

    def box(self, cx, cy, cz, sx, sy, sz, rot=0.0):
        c, s = math.cos(rot), math.sin(rot)
        vs = []
        for i in range(8):
            x = (sx / 2) * (1 if i & 1 else -1); y = (sy / 2) * (1 if i & 2 else -1); z = (sz / 2) * (1 if i & 4 else -1)
            vs.append((cx + x * c - y * s, cy + x * s + y * c, cz + z))
        self._add(vs, [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)])

    def disc(self, cx, cy, z, rx, ry, n=10, jit=0.0, rnd=None, rot=0.0):
        c, s = math.cos(rot), math.sin(rot)
        vs = [(cx, cy, z)]
        for k in range(n):
            a = 2 * math.pi * k / n
            j = 1 + (jit * (rnd.random() - 0.5) * 2 if rnd else 0)
            x, y = rx * j * math.cos(a), ry * j * math.sin(a)
            vs.append((cx + x * c - y * s, cy + x * s + y * c, z))
        self._add(vs, [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)])

    def blob(self, cx, cy, cz, rx, ry, rz, seg=6, rings=4):
        vs = [(cx, cy, cz - rz)]
        for r in range(1, rings):
            ph = math.pi * r / rings - math.pi / 2
            for k in range(seg):
                a = 2 * math.pi * k / seg
                vs.append((cx + rx * math.cos(ph) * math.cos(a), cy + ry * math.cos(ph) * math.sin(a), cz + rz * math.sin(ph)))
        vs.append((cx, cy, cz + rz))
        fs = []
        top = len(vs) - 1
        for k in range(seg):
            fs.append((0, 1 + (k + 1) % seg, 1 + k))
        for r in range(rings - 2):
            b0 = 1 + r * seg; b1 = b0 + seg
            for k in range(seg):
                k2 = (k + 1) % seg
                fs.append((b0 + k, b0 + k2, b1 + k2, b1 + k))
        last = 1 + (rings - 2) * seg
        for k in range(seg):
            fs.append((top, last + k, last + (k + 1) % seg))
        self._add(vs, fs)

    def cone(self, cx, cy, r, h, lean=(0, 0), n=4, z0=0.0, rot=0.0):
        vs = [(cx + r * math.cos(rot + 2 * math.pi * k / n), cy + r * math.sin(rot + 2 * math.pi * k / n), z0) for k in range(n)]
        vs.append((cx + lean[0], cy + lean[1], z0 + h))
        self._add(vs, [(k, (k + 1) % n, n) for k in range(n)])

    def strip(self, pts, w, z):
        """Flat ribbon along a polyline (cracks, seams)."""
        vs = []
        for i, (x, y) in enumerate(pts):
            x0, y0 = pts[max(0, i - 1)]; x1, y1 = pts[min(len(pts) - 1, i + 1)]
            dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) or 1
            nx, ny = -dy / L, dx / L
            ww = w * (0.35 if i in (0, len(pts) - 1) else 1.0)
            vs += [(x + nx * ww / 2, y + ny * ww / 2, z), (x - nx * ww / 2, y - ny * ww / 2, z)]
        self._add(vs, [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(pts) - 1)])

    def obj(self, name, mat, bevel=0.0, smooth=False):
        if not self.v:
            return None
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f); me.update()
        o = bpy.data.objects.new(name, me)
        o.data.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = smooth
        if bevel:
            m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 1
            m.limit_method = "ANGLE"; m.angle_limit = math.radians(40)
        return o


# ----------------------------------------------------------------------------- tile context
class Ctx:
    def __init__(self, biome, kind, variant, mats, decal=False):
        self.biome, self.kind, self.variant, self.mats = biome, kind, variant, mats
        self.decal = decal
        self.bs = {}

    def b(self, key):
        return self.bs.setdefault(key, B())

    def rnd(self, key, shared):
        return random.Random(f"{self.biome}|{self.kind}|{key}|{'S' if shared else self.variant}")

    def put(self, key, fn, x, y, r):
        """Add a primitive at (x, y) plus its periodic copies that can reach the frame."""
        if self.decal:
            fn(self.b(key), x, y); return
        m = r + 0.35
        for dx in (-TX, 0, TX):
            for dy in (-TY, 0, TY):
                X, Y = x + dx, y + dy
                if abs(X) < HX + m and abs(Y) < HY + m:
                    fn(self.b(key), X, Y)

    def near_edge(self, x, y, m):
        return abs(x) > HX - m or abs(y) > HY - m

    def scatter(self, name, count, margin, place, shared_count=None):
        """Uniform scatter over one period.  Items within `margin` of an edge come from the shared
        seed (identical in every variant); interior items come from the variant seed."""
        rs, rv = self.rnd(name, True), self.rnd(name, False)
        for _ in range(count if shared_count is None else shared_count):
            x, y = rs.uniform(-HX, HX), rs.uniform(-HY, HY)
            r2 = random.Random(rs.random())
            if self.near_edge(x, y, margin):
                place(r2, x, y, True)
        for _ in range(count):
            x, y = rv.uniform(-HX, HX), rv.uniform(-HY, HY)
            r2 = random.Random(rv.random())
            if not self.near_edge(x, y, margin):
                place(r2, x, y, False)

    def build(self):
        noink = bpy.data.collections.new("noink"); bpy.context.scene.collection.children.link(noink)
        ink = bpy.data.collections.new("ink"); bpy.context.scene.collection.children.link(ink)
        for key, b in self.bs.items():
            spec = self.mats[key]
            col, mode = spec[0], spec[1]
            opts = spec[2] if len(spec) > 2 else {}
            if mode == "flat":
                mat = C.toon(f"{self.biome}_{key}", col, flat=True)
            else:
                mat = C.toon(f"{self.biome}_{key}", col, rim=0.0, hi=opts.get("hi", 0.0))
                if opts.get("ao", 0.16):
                    E.add_ao_band(mat, strength=opts.get("ao", 0.16), dist=0.12, threshold=0.8)
            o = b.obj(f"{key}", mat, bevel=opts.get("bevel", 0.0), smooth=opts.get("smooth", False))
            if o is None:
                continue
            (ink if opts.get("ink", False) else noink).objects.link(o)


# ----------------------------------------------------------------------------- layouts
def rows_layout(ctx, n_rows, joints_for_row, piece_fn, split=(0.0, 0.6), axis="x", row_sizes=None):
    """Rows of pieces (planks, bricks, slabs) along `axis`, rows stacked across the other axis.
    joints_for_row(r) -> sorted joint positions in [-P/2, P/2) (shared layout).  Pieces that cross
    the tile edge use the shared seed; interior pieces use the variant seed and may be split."""
    P, Q = (TX, TY) if axis == "x" else (TY, TX)
    sizes = row_sizes or [Q / n_rows] * n_rows
    v = -Q / 2
    for r, sz in enumerate(sizes):
        v0, v1 = v, v + sz; v = v1
        js = joints_for_row(r)
        pieces = []
        for i, a in enumerate(js):
            b = js[i + 1] if i + 1 < len(js) else js[0] + P
            pieces.append((a, b))
        out = []
        for k, (a, b) in enumerate(pieces):
            crossing = b > P / 2 + EPS
            if crossing:
                out.append((a, b, True, f"r{r}p{k}"))
                continue
            rv = ctx.rnd(f"split{r}_{k}", False)
            if b - a > split[1] * 2 and rv.random() < split[0]:
                m = a + (b - a) * rv.uniform(0.3, 0.7)
                out += [(a, m, False, f"r{r}p{k}a"), (m, b, False, f"r{r}p{k}b")]
            else:
                out.append((a, b, False, f"r{r}p{k}"))
        for a, b, shared, key in out:
            rnd = ctx.rnd(key, shared)
            piece_fn(ctx, rnd, a, b, v0, v1, shared, axis)


def uv(axis, u, v):
    return (u, v) if axis == "x" else (v, u)


def slab(ctx, key, a, b, v0, v1, axis, gap, h=0.06, lift=0.0):
    u0, u1 = a + gap / 2, b - gap / 2
    w0, w1 = v0 + gap / 2, v1 - gap / 2
    cx, cy = uv(axis, (u0 + u1) / 2, (w0 + w1) / 2)
    sx, sy = uv(axis, u1 - u0, w1 - w0)
    ctx.put(key, lambda bb, x, y: bb.box(x, y, lift - h / 2, sx, sy, h), cx, cy, max(sx, sy) / 2)


def crack(ctx, key, rnd, x, y, length, w=0.018, z=0.002, ang=None):
    ang = rnd.uniform(0, math.pi) if ang is None else ang
    pts = []
    px, py = x - math.cos(ang) * length / 2, y - math.sin(ang) * length / 2
    n = 5
    for i in range(n + 1):
        pts.append((px, py))
        a = ang + rnd.uniform(-0.6, 0.6)
        px += math.cos(a) * length / n; py += math.sin(a) * length / n
    ctx.put(key, lambda bb, X, Y: bb.strip([(X + p[0] - x, Y + p[1] - y) for p in pts], w, z), x, y, length)


def base_plane(ctx, key, z=0.0):
    ctx.b(key).box(0, 0, z - 0.05, 12, 12, 0.1)


# ============================================================================= biomes
# Colours are sRGB hex; floors stay low-saturation and inside a ~25-60% value band (lab is the
# deliberate light exception).  Reserved hues (red, warm yellow, cyan, gold) are not used.
BIOMES = {}


def biome(name):
    def deco(cls):
        BIOMES[name] = cls()
        return cls
    return deco


# ----------------------------------------------------------------------------- park
@biome("park")
class Park:
    base = "#6c9660"
    ink = "#3f5a3c"

    def mats(self):
        g = self.base
        return {
            "ground": (shade(g, 1.0), "flat"),
            "patchD": (shade("#658d5a", 1.0), "flat"), "patchL": (shade("#76a068", 1.0), "flat"),
            "tuft": (shade("#5c874f", 1.0), "toon", {"ao": 0}), "tuftL": (shade("#7eaa6c", 1.0), "toon", {"ao": 0}),
            "flowerW": (shade("#e6e0cf", 1.0), "toon", {"ao": 0, "smooth": True}),
            "flowerP": (shade("#d49fb2", 1.0), "toon", {"ao": 0, "smooth": True}),
            "flowerL": (shade("#ada0d2", 1.0), "toon", {"ao": 0, "smooth": True}),
            "stone": (shade("#9d978a", 1.0), "toon", {"smooth": True, "ink": True}),
            "dirt": (shade("#a8966f", 1.0), "flat"), "dirtD": (shade("#998865", 1.0), "flat"),
            "cobble": (shade("#b1a88f", 1.0), "toon", {"bevel": 0.02, "ink": True}),
            "cobbleD": (shade("#a1987f", 1.0), "toon", {"bevel": 0.02, "ink": True}),
            "grassEdge": (shade("#62905a", 1.0), "toon", {"ao": 0}),
            "leaf": (shade("#8c9a4e", 1.0), "toon", {"ao": 0, "ink": True}),
            "leafB": (shade("#9a7a4a", 1.0), "toon", {"ao": 0, "ink": True}),
            "mud": (shade("#7a6a50", 1.0), "flat"), "mudD": (shade("#6c5d47", 1.0), "flat"),
            "clover": (shade("#5a9258", 1.0), "toon", {"ao": 0, "ink": True}),
            "rockL": (shade("#a8a296", 1.0), "toon", {"smooth": True, "ink": True}),
            "mushroom": (shade("#d8cfc0", 1.0), "toon", {"smooth": True, "ink": True}),
            "mushCap": (shade("#9a7466", 1.0), "toon", {"smooth": True, "ink": True}),
        }

    def patches(self, ctx):
        def pl(r, x, y, sh):
            key = "patchD" if r.random() < 0.5 else "patchL"
            rx, ry, rot = r.uniform(0.12, 0.3), r.uniform(0.08, 0.2), r.uniform(0, 3)
            ctx.put(key, lambda b, X, Y: b.disc(X, Y, 0.001, rx, ry, 12, 0.25, random.Random(1), rot), x, y, rx)
        ctx.scatter("patch", 14, 0.35, pl)

    def tufts(self, ctx, count):
        def pl(r, x, y, sh):
            key = "tuft" if r.random() < 0.6 else "tuftL"
            blades = [(r.uniform(-0.03, 0.03), r.uniform(-0.02, 0.02), r.uniform(0.05, 0.09), r.uniform(-0.03, 0.03)) for _ in range(3)]
            def f(b, X, Y):
                for dx, dy, h, ln in blades:
                    b.cone(X + dx, Y + dy, 0.012, h, lean=(ln, -0.01), n=3)
            ctx.put(key, f, x, y, 0.06)
        ctx.scatter("tuft", count, 0.12, pl)

    def base_tile(self, ctx):
        base_plane(ctx, "ground")
        self.patches(ctx)
        self.tufts(ctx, 70)
        n_fl = [3, 0, 5, 2][ctx.variant]
        def fl(r, x, y, sh):
            key = r.choice(["flowerW", "flowerW", "flowerP", "flowerL"])
            pts = [(r.uniform(-0.05, 0.05), r.uniform(-0.04, 0.04)) for _ in range(r.randint(2, 4))]
            def f(b, X, Y):
                for dx, dy in pts:
                    b.cone(X + dx, Y + dy, 0.008, 0.06, n=3)
                    b.blob(X + dx, Y + dy, 0.065, 0.034, 0.034, 0.016, seg=7, rings=3)
            ctx.put(key, f, x, y, 0.08)
        ctx.scatter("flower", n_fl, 0.2, fl, shared_count=0)
        if ctx.variant == 3:
            r = ctx.rnd("stone", False)
            ctx.put("stone", lambda b, X, Y: b.blob(X, Y, 0.01, 0.07, 0.05, 0.035), r.uniform(-0.5, 0.5), r.uniform(-0.4, 0.4), 0.1)

    def path_tile(self, ctx):
        base_plane(ctx, "dirt")
        def dp(r, x, y, sh):
            rx, ry = r.uniform(0.1, 0.25), r.uniform(0.06, 0.16)
            ctx.put("dirtD", lambda b, X, Y: b.disc(X, Y, 0.001, rx, ry, 10, 0.25, random.Random(2)), x, y, rx)
        ctx.scatter("dpatch", 10, 0.3, dp)
        # flat stepping cobbles on a loose hex-ish grid (shared layout, variant colours inside)
        k = 0
        for j in range(4):
            for i in range(5):
                x = -HX + (i + 0.5 + (0.5 if j % 2 else 0)) * TX / 5
                y = -HY + (j + 0.5) * TY / 4
                x = (x + HX) % TX - HX
                edge = ctx.near_edge(x, y, 0.28)
                r = ctx.rnd(f"cob{j}_{i}", edge)
                if not edge and r.random() < 0.12:
                    continue
                key = "cobble" if r.random() < 0.6 else "cobbleD"
                rx, ry, rot = r.uniform(0.13, 0.17), r.uniform(0.1, 0.13), r.uniform(-0.4, 0.4)
                ox, oy = r.uniform(-0.03, 0.03), r.uniform(-0.03, 0.03)
                ctx.put(key, lambda b, X, Y, rx=rx, ry=ry, rot=rot, s=r.random():
                        _pebble(b, X, Y, rx, ry, rot, 0.025, s), x + ox, y + oy, rx)
                k += 1

    def decals(self):
        def flowers(ctx):
            r = random.Random(4)
            for _ in range(7):
                x, y = r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25)
                key = r.choice(["flowerW", "flowerP", "flowerL"])
                ctx.b("tuft").cone(x, y, 0.01, 0.07, n=3)
                ctx.b(key).blob(x, y, 0.075, 0.03, 0.03, 0.016, seg=7, rings=3)
            for _ in range(10):
                ctx.b("tuftL").cone(r.uniform(-0.35, 0.35), r.uniform(-0.3, 0.3), 0.014, 0.08, lean=(0.02, 0), n=3)
        def leaves(ctx):
            r = random.Random(5)
            for _ in range(7):
                _leaf(ctx.b(r.choice(["leaf", "leafB"])), r.uniform(-0.4, 0.4), r.uniform(-0.35, 0.35), r.uniform(0, 6.3), 0.07)
        def rocks(ctx):
            r = random.Random(6)
            for (x, y, s) in ((0, 0, 0.1), (0.14, -0.06, 0.06), (-0.12, 0.05, 0.05), (0.05, 0.11, 0.035)):
                ctx.b("rockL").blob(x, y, s * 0.3, s, s * 0.8, s * 0.6, seg=7, rings=4)
            for _ in range(6):
                ctx.b("tuft").cone(r.uniform(-0.2, 0.2), r.uniform(-0.16, 0.16), 0.012, 0.07, n=3)
        def mud(ctx):
            ctx.b("mud").disc(0, 0, 0.001, 0.38, 0.26, 16, 0.25, random.Random(7))
            ctx.b("mudD").disc(0.1, -0.05, 0.002, 0.14, 0.08, 10, 0.3, random.Random(8))
        def clover(ctx):
            r = random.Random(9)
            for _ in range(9):
                x, y = r.uniform(-0.28, 0.28), r.uniform(-0.22, 0.22)
                for k in range(3):
                    a = k * 2.1 + r.random()
                    ctx.b("clover").disc(x + 0.025 * math.cos(a), y + 0.025 * math.sin(a), 0.01, 0.026, 0.022, 8)
            ctx.b("mushCap").blob(0.2, 0.1, 0.06, 0.05, 0.05, 0.03, seg=10, rings=5)
            ctx.b("mushroom").box(0.2, 0.1, 0.03, 0.025, 0.025, 0.06)
        return [flowers, leaves, rocks, mud, clover]


def _pebble(b, x, y, rx, ry, rot, h, s=0.5):
    """Flat rounded stone: a squashed low-poly disc prism."""
    n = 9
    c, sn = math.cos(rot), math.sin(rot)
    r = random.Random(s)
    ring = []
    for k in range(n):
        a = 2 * math.pi * k / n
        j = 1 + 0.12 * (r.random() - 0.5)
        px, py = rx * j * math.cos(a), ry * j * math.sin(a)
        ring.append((x + px * c - py * sn, y + px * sn + py * c))
    vs = [(px, py, -0.02) for px, py in ring] + [(px, py, h) for px, py in ring] + [(x, y, h)]
    fs = [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)] + [(2 * n, n + k, n + (k + 1) % n) for k in range(n)]
    b._add(vs, fs)


def _leaf(b, x, y, rot, s):
    c, sn = math.cos(rot), math.sin(rot)
    pts = [(-s, 0), (-s * 0.3, s * 0.45), (s * 0.5, s * 0.35), (s, 0), (s * 0.5, -s * 0.35), (-s * 0.3, -s * 0.45)]
    vs = [(x, y, 0.006)] + [(x + px * c - py * sn, y + px * sn + py * c, 0.004 + 0.004 * (i % 2)) for i, (px, py) in enumerate(pts)]
    b._add(vs, [(0, 1 + k, 1 + (k + 1) % 6) for k in range(6)])


# ----------------------------------------------------------------------------- docks
@biome("docks")
class Docks:
    base = "#5d7174"
    ink = "#3b4a50"
    SH = ["#5f7477", "#5a6e72", "#63777a", "#586b70"]

    def mats(self):
        m = {"gap": (shade("#46565b", 1.0), "flat"),
             "nail": (shade("#4a585e", 1.0), "flat"),
             "grain": (shade("#55686c", 1.0), "flat"),
             "grainL": (shade("#687c7e", 1.0), "flat"),
             "puddle": (shade("#4f6874", 1.0), "flat"), "puddleL": (shade("#7890a0", 1.0), "flat"),
             "stain": (shade("#465357", 1.0), "flat"),
             "plate": (shade("#6a7278", 1.0), "toon", {"bevel": 0.01, "ink": True}),
             "bolt": (shade("#555c64", 1.0), "toon", {"smooth": True}),
             "rope": (shade("#9a8a6a", 1.0), "toon", {"smooth": True, "ink": True}),
             "weed": (shade("#5f7e66", 1.0), "flat"),
             "crackD": (shade("#3f4d52", 1.0), "flat")}
        for i, h in enumerate(self.SH):
            m[f"plank{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.012, "ink": True})
        for i, h in enumerate(["#6b7e7e", "#667a7b", "#708383", "#637677"]):
            m[f"walk{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.012, "ink": True})
        return m

    def plank(self, prefix, gap=0.03):
        def fn(ctx, rnd, a, b, v0, v1, shared, axis):
            key = f"{prefix}{rnd.randrange(4)}"
            slab(ctx, key, a, b, v0, v1, axis, gap, lift=rnd.uniform(0, 0.006))
            # faint grain line + end nails (low contrast)
            L = b - a
            if L > 0.5 and rnd.random() < 0.7:
                u = rnd.uniform(a + 0.15, b - 0.15 - 0.3 * min(L, 1))
                vv = rnd.uniform(v0 + 0.1, v1 - 0.1)
                pts = [uv(axis, u + t * 0.3 * min(L, 1), vv + 0.01 * math.sin(t * 6)) for t in (0, 0.33, 0.66, 1)]
                cx, cy = pts[0]
                ctx.put(rnd.choice(["grain", "grainL"]), lambda bb, X, Y, pts=pts, cx=cx, cy=cy:
                        bb.strip([(X + p[0] - cx, Y + p[1] - cy) for p in pts], 0.012, 0.009), cx, cy, 0.4)
            for ue in (a + 0.07, b - 0.07):
                for vv in (v0 + (v1 - v0) * 0.3, v0 + (v1 - v0) * 0.7):
                    x, y = uv(axis, ue, vv)
                    ctx.put("nail", lambda bb, X, Y: bb.disc(X, Y, 0.0095, 0.012, 0.012, 6), x, y, 0.02)
        return fn

    def base_tile(self, ctx):
        base_plane(ctx, "gap", z=-0.06)
        rows_layout(ctx, 5, lambda r: [-1.0] if r % 2 == 0 else [-0.35], self.plank("plank"), split=(0.3, 0.5))
        if ctx.variant in (1, 3):
            r = ctx.rnd("crack", False)
            crack(ctx, "crackD", r, r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5), 0.3, w=0.012, z=0.01, ang=r.uniform(-0.2, 0.2))

    def path_tile(self, ctx):
        base_plane(ctx, "gap", z=-0.06)
        # boardwalk: planks run along y, slightly lighter
        rows_layout(ctx, 5, lambda r: [-TY / 2] if r % 2 == 0 else [-0.2], self.plank("walk"), split=(0.3, 0.45), axis="y")

    def decals(self):
        def puddle(ctx):
            ctx.b("puddle").disc(0, 0, 0.012, 0.36, 0.24, 18, 0.2, random.Random(1))
            ctx.b("puddleL").disc(-0.08, 0.05, 0.013, 0.12, 0.04, 10, 0.2, random.Random(2), rot=0.2)
        def stain(ctx):
            ctx.b("stain").disc(0, 0, 0.012, 0.3, 0.2, 16, 0.35, random.Random(3))
            ctx.b("stain").disc(0.3, -0.12, 0.012, 0.07, 0.05, 8, 0.3, random.Random(4))
        def plate(ctx):
            ctx.b("plate").box(0, 0, 0.012, 0.34, 0.24, 0.02)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    ctx.b("bolt").blob(sx * 0.13, sy * 0.08, 0.024, 0.018, 0.018, 0.01, seg=8, rings=4)
        def rope(ctx):
            for k in range(3):
                r = 0.16 - k * 0.045
                n = 24
                pts = [(r * math.cos(2 * math.pi * i / n), r * 0.95 * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]
                for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
                    ctx.b("rope").blob((x0 + x1) / 2, (y0 + y1) / 2, 0.03 + k * 0.012, 0.032, 0.032, 0.022, seg=6, rings=3)
        def weed(ctx):
            r = random.Random(8)
            for _ in range(5):
                ctx.b("weed").disc(r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), 0.012, r.uniform(0.05, 0.12), r.uniform(0.03, 0.07), 9, 0.4, r)
            crack(ctx, "crackD", r, 0, 0, 0.5, w=0.014, z=0.013, ang=0.1)
        return [puddle, stain, plate, rope, weed]


# ----------------------------------------------------------------------------- tower
@biome("tower")
class Tower:
    base = "#3f4151"
    ink = "#25262f"
    SH = ["#40424f", "#3c3e4b", "#444653", "#3a3c49"]

    def mats(self):
        m = {"gap": (shade("#2c2d38", 1.0), "flat"),
             "rivet": (shade("#555866", 1.0), "toon", {"smooth": True, "ao": 0}),
             "tread": (shade("#4a4c5a", 1.0), "toon", {"ao": 0}),
             "oil": (shade("#30313c", 1.0), "flat"), "oilL": (shade("#4d4a60", 1.0), "flat"),
             "scorch": (shade("#2e2d36", 1.0), "flat"),
             "vent": (shade("#353743", 1.0), "toon", {"bevel": 0.01, "ink": True}),
             "ventSlot": (shade("#22232b", 1.0), "flat"),
             "bolt": (shade("#6e7282", 1.0), "toon", {"smooth": True, "ink": True}),
             "crackD": (shade("#2a2b33", 1.0), "flat"),
             "grate": (shade("#4a4d5b", 1.0), "toon", {"ink": True, "ao": 0}),
             "grateHole": (shade("#23242c", 1.0), "flat"),
             "rail": (shade("#50535f", 1.0), "toon", {"bevel": 0.01, "ink": True})}
        for i, h in enumerate(self.SH):
            m[f"plate{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.02, "ink": True})
        return m

    def plate(self, ctx, rnd, a, b, v0, v1, shared, axis):
        slab(ctx, f"plate{rnd.randrange(4)}", a, b, v0, v1, axis, 0.035, h=0.05)
        for u in (a + 0.07, b - 0.07):
            for v in (v0 + 0.07, v1 - 0.07):
                ctx.put("rivet", lambda bb, X, Y: bb.blob(X, Y, 0.0, 0.016, 0.016, 0.012, seg=6, rings=3), u, v, 0.02)
        if rnd.random() < 0.45:   # diamond tread plate
            for i in range(4):
                for j in range(3):
                    u = a + (b - a) * (i + 1) / 5; v = v0 + (v1 - v0) * (j + 1) / 4
                    rot = 0.6 if (i + j) % 2 else -0.6
                    ctx.put("tread", lambda bb, X, Y, rot=rot: bb.box(X, Y, 0.004, 0.07, 0.016, 0.008, rot), u, v, 0.05)

    def base_tile(self, ctx):
        base_plane(ctx, "gap", z=-0.05)
        rows_layout(ctx, 2, lambda r: [-1.0, 0.0], self.plate)
        if ctx.variant == 2:
            r = ctx.rnd("oil", False)
            ctx.put("oil", lambda b, X, Y: b.disc(X, Y, 0.006, 0.2, 0.13, 14, 0.3, random.Random(3)), r.uniform(-0.4, 0.4), r.uniform(-0.3, 0.3), 0.2)

    def path_tile(self, ctx):
        base_plane(ctx, "grateHole", z=-0.05)
        # catwalk grating: bars along y every 0.1, cross bars every 0.4, framed
        for i in range(20):
            x = -HX + (i + 0.5) * TX / 20
            ctx.put("grate", lambda b, X, Y: b.box(X, Y, -0.015, 0.035, TY + 0.001, 0.03), x, 0, TY / 2)
        for j in range(5):
            y = -HY + (j + 0.5) * TY / 5
            ctx.put("rail", lambda b, X, Y: b.box(X, Y, -0.008, TX + 0.001, 0.05, 0.03), 0, y, TX / 2)

    def decals(self):
        def oil(ctx):
            ctx.b("oil").disc(0, 0, 0.004, 0.34, 0.22, 16, 0.3, random.Random(1))
            ctx.b("oilL").disc(-0.1, 0.04, 0.005, 0.1, 0.035, 10, 0.2, random.Random(2), rot=0.3)
        def bolts(ctx):
            r = random.Random(3)
            for _ in range(5):
                ctx.b("bolt").box(r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25), 0.012, 0.04, 0.04, 0.024, r.uniform(0, 1))
        def scorch(ctx):
            ctx.b("scorch").disc(0, 0, 0.004, 0.32, 0.22, 18, 0.45, random.Random(4))
        def vent(ctx):
            ctx.b("vent").box(0, 0, 0.012, 0.44, 0.3, 0.024)
            for k in range(5):
                ctx.b("ventSlot").box(0, -0.1 + k * 0.05, 0.025, 0.34, 0.022, 0.002)
        def crack_(ctx):
            r = random.Random(5)
            crack(ctx, "crackD", r, 0, 0, 0.6, w=0.016, z=0.004)
            crack(ctx, "crackD", r, 0.1, 0.05, 0.25, w=0.01, z=0.004)
        return [oil, bolts, scorch, vent, crack_]


# ----------------------------------------------------------------------------- rooftops
@biome("rooftops")
class Rooftops:
    base = "#4b4b56"
    ink = "#2c2c35"

    def mats(self):
        return {"tar": (shade(self.base, 1.0), "flat"),
                "tarD": (shade("#42424c", 1.0), "flat"), "tarL": (shade("#54545e", 1.0), "flat"),
                "seam": (shade("#3a3a44", 1.0), "toon", {"ao": 0}),
                "gravelA": (shade("#5d5c66", 1.0), "toon", {"ao": 0, "smooth": True}),
                "gravelB": (shade("#686670", 1.0), "toon", {"ao": 0, "smooth": True}),
                "gravelC": (shade("#55545c", 1.0), "toon", {"ao": 0, "smooth": True}),
                "paver0": (shade("#66666f", 1.0), "toon", {"bevel": 0.015, "ink": True}),
                "paver1": (shade("#6d6c75", 1.0), "toon", {"bevel": 0.015, "ink": True}),
                "paver2": (shade("#62626b", 1.0), "toon", {"bevel": 0.015, "ink": True}),
                "paver3": (shade("#6a6972", 1.0), "toon", {"bevel": 0.015, "ink": True}),
                "puddle": (shade("#454a5c", 1.0), "flat"), "puddleL": (shade("#6d7590", 1.0), "flat"),
                "crackD": (shade("#34343d", 1.0), "flat"),
                "leaf": (shade("#7a7250", 1.0), "toon", {"ao": 0, "ink": True}),
                "leafB": (shade("#8a6a4c", 1.0), "toon", {"ao": 0, "ink": True}),
                "patch": (shade("#3e3e48", 1.0), "toon", {"bevel": 0.01, "ink": True}),
                "drain": (shade("#5a5d68", 1.0), "toon", {"ink": True, "smooth": True}),
                "drainHole": (shade("#26262e", 1.0), "flat")}

    def gravel(self, ctx, count):
        def pl(r, x, y, sh):
            key = r.choice(["gravelA", "gravelB", "gravelC"])
            s = r.uniform(0.012, 0.022)
            ctx.put(key, lambda b, X, Y: b.blob(X, Y, 0.0, s, s * 0.9, s * 0.6, seg=5, rings=3), x, y, s)
        ctx.scatter("gravel", count, 0.05, pl)

    def base_tile(self, ctx):
        base_plane(ctx, "tar")
        def tp(r, x, y, sh):
            key = "tarD" if r.random() < 0.5 else "tarL"
            rx, ry = r.uniform(0.12, 0.3), r.uniform(0.08, 0.18)
            ctx.put(key, lambda b, X, Y: b.disc(X, Y, 0.001, rx, ry, 12, 0.3, random.Random(5)), x, y, rx)
        ctx.scatter("tarp", 10, 0.35, tp)
        # membrane seam across the tile (shared)
        ctx.put("seam", lambda b, X, Y: b.box(X, Y, 0.002, TX + 0.001, 0.035, 0.006), 0, HY * 0.35, TX / 2)
        self.gravel(ctx, 260)

    def path_tile(self, ctx):
        base_plane(ctx, "tarD", z=-0.04)
        rows_layout(ctx, 3, lambda r: [-1.0, -0.5, 0.0, 0.5],
                    lambda c, rnd, a, b, v0, v1, sh, ax: slab(c, f"paver{rnd.randrange(4)}", a, b, v0, v1, ax, 0.05, h=0.04))

    def decals(self):
        def puddle(ctx):
            ctx.b("puddle").disc(0, 0, 0.004, 0.38, 0.24, 18, 0.25, random.Random(1))
            ctx.b("puddleL").disc(0.08, 0.06, 0.005, 0.14, 0.04, 10, 0.2, random.Random(2), rot=-0.2)
        def patch(ctx):
            ctx.b("patch").box(0, 0, 0.006, 0.42, 0.3, 0.012, 0.15)
        def cracks(ctx):
            r = random.Random(3)
            crack(ctx, "crackD", r, 0, 0, 0.6, w=0.016, z=0.003)
            crack(ctx, "crackD", r, -0.12, 0.08, 0.3, w=0.012, z=0.003)
        def leaves(ctx):
            r = random.Random(4)
            for _ in range(6):
                _leaf(ctx.b(r.choice(["leaf", "leafB"])), r.uniform(-0.4, 0.4), r.uniform(-0.3, 0.3), r.uniform(0, 6.3), 0.065)
        def drain(ctx):
            ctx.b("drain").disc(0, 0, 0.012, 0.16, 0.16, 20)
            ctx.b("drain").box(0, 0, 0.006, 0.34, 0.34, 0.012)
            for k in range(-2, 3):
                ctx.b("drainHole").box(k * 0.05, 0, 0.0135, 0.022, 0.2, 0.001)
        return [puddle, patch, cracks, leaves, drain]


# ----------------------------------------------------------------------------- lab
@biome("lab")
class Lab:
    base = "#b9c2c9"
    ink = "#7c8a96"
    SH = ["#bcc5cc", "#b6c0c7", "#c1c9cf", "#b3bcc4"]

    def mats(self):
        m = {"grout": (shade("#9aa6b0", 1.0), "flat"),
             "scuff": (shade("#a9b3bb", 1.0), "flat"),
             "mat0": (shade("#8995a1", 1.0), "toon", {"bevel": 0.015, "ink": True}),
             "mat1": (shade("#86929e", 1.0), "toon", {"bevel": 0.015, "ink": True}),
             "mat2": (shade("#8c98a4", 1.0), "toon", {"bevel": 0.015, "ink": True}),
             "mat3": (shade("#83909c", 1.0), "toon", {"bevel": 0.015, "ink": True}),
             "matLine": (shade("#9ba7b2", 1.0), "flat"),
             "spill": (shade("#9fb3bd", 1.0), "flat"), "spillL": (shade("#cfdbe2", 1.0), "flat"),
             "crackD": (shade("#8995a0", 1.0), "flat"),
             "drain": (shade("#9aa4ae", 1.0), "toon", {"ink": True}),
             "drainHole": (shade("#6d7883", 1.0), "flat"),
             "stain": (shade("#a8aeb6", 1.0), "flat"),
             "bolt": (shade("#8e98a3", 1.0), "toon", {"smooth": True, "ink": True})}
        for i, h in enumerate(self.SH):
            m[f"tile{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.012, "ink": False, "ao": 0.1})
        return m

    def tile(self, ctx, rnd, a, b, v0, v1, shared, axis):
        slab(ctx, f"tile{rnd.randrange(4)}", a, b, v0, v1, axis, 0.022, h=0.03)
        if not shared and rnd.random() < 0.12:
            crack(ctx, "crackD", rnd, (a + b) / 2, (v0 + v1) / 2, 0.2, w=0.008, z=0.002)

    def base_tile(self, ctx):
        base_plane(ctx, "grout", z=-0.03)
        rows_layout(ctx, 4, lambda r: [-1.0, -0.5, 0.0, 0.5], self.tile)
        if ctx.variant == 1:
            r = ctx.rnd("scuff", False)
            for _ in range(3):
                crack(ctx, "scuff", r, r.uniform(-0.6, 0.6), r.uniform(-0.5, 0.5), 0.18, w=0.02, z=0.002)

    def path_tile(self, ctx):
        base_plane(ctx, "grout", z=-0.03)
        rows_layout(ctx, 2, lambda r: [-1.0, 0.0],
                    lambda c, rnd, a, b, v0, v1, sh, ax: slab(c, f"mat{rnd.randrange(4)}", a, b, v0, v1, ax, 0.03, h=0.03))
        for x in (-HX + 0.12, HX - 0.12):   # guide lines (low-sat, not the reserved cyan)
            ctx.put("matLine", lambda b, X, Y: b.box(X, Y, 0.001, 0.03, TY + 0.001, 0.002), x, 0, TY / 2)

    def decals(self):
        def spill(ctx):
            ctx.b("spill").disc(0, 0, 0.003, 0.34, 0.22, 18, 0.3, random.Random(1))
            ctx.b("spillL").disc(-0.06, 0.04, 0.004, 0.12, 0.04, 10, 0.2, random.Random(2))
        def cracks(ctx):
            r = random.Random(3)
            crack(ctx, "crackD", r, 0, 0, 0.5, w=0.012, z=0.002)
        def drain(ctx):
            ctx.b("drain").box(0, 0, 0.004, 0.3, 0.3, 0.008)
            for k in range(-3, 4):
                ctx.b("drainHole").box(k * 0.035, 0, 0.0085, 0.015, 0.22, 0.001)
        def stain(ctx):
            ctx.b("stain").disc(0, 0, 0.002, 0.28, 0.18, 16, 0.35, random.Random(4))
        def bolts(ctx):
            for sx in (-1, 1):
                for sy in (-1, 1):
                    ctx.b("bolt").blob(sx * 0.12, sy * 0.08, 0.008, 0.02, 0.02, 0.01, seg=8, rings=4)
            ctx.b("scuff").box(0, 0, 0.002, 0.3, 0.2, 0.002)
        return [spill, cracks, drain, stain, bolts]


# ----------------------------------------------------------------------------- sewers
@biome("sewers")
class Sewers:
    base = "#58604f"
    ink = "#353a30"
    SH = ["#5a6252", "#555d4e", "#5f6656", "#525a4b"]

    def mats(self):
        m = {"mortar": (shade("#434a3e", 1.0), "flat"),
             "moss": (shade("#5b6e45", 1.0), "flat"), "mossL": (shade("#667a4c", 1.0), "flat"),
             "crackD": (shade("#3f463a", 1.0), "flat"),
             "puddle": (shade("#47574f", 1.0), "flat"), "puddleL": (shade("#6f8478", 1.0), "flat"),
             "slime": (shade("#5f6c46", 1.0), "flat"),
             "grate": (shade("#4d5249", 1.0), "toon", {"ink": True}),
             "grateHole": (shade("#2b3029", 1.0), "flat"),
             "mossClump": (shade("#627848", 1.0), "toon", {"smooth": True, "ao": 0}),
             "pebble": (shade("#6a6f60", 1.0), "toon", {"smooth": True, "ink": True})}
        for i, h in enumerate(self.SH):
            m[f"brick{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.02, "ink": True})
        for i, h in enumerate(["#646b5d", "#60675a", "#686f61", "#5c6356"]):
            m[f"flag{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.025, "ink": True})
        return m

    def brick(self, prefix, gap=0.035):
        def fn(ctx, rnd, a, b, v0, v1, shared, axis):
            slab(ctx, f"{prefix}{rnd.randrange(4)}", a, b, v0, v1, axis, gap, h=0.05, lift=rnd.uniform(0, 0.01))
            if rnd.random() < 0.35:
                u, v = rnd.uniform(a + 0.06, b - 0.06), rnd.uniform(v0 + 0.05, v1 - 0.05)
                rx, ry = rnd.uniform(0.04, 0.1), rnd.uniform(0.03, 0.06)
                x, y = uv(axis, u, v)
                ctx.put(rnd.choice(["moss", "mossL"]), lambda bb, X, Y: bb.disc(X, Y, 0.0125, rx, ry, 9, 0.35, random.Random(3)), x, y, rx)
            if not shared and rnd.random() < 0.1:
                crack(ctx, "crackD", rnd, (a + b) / 2, (v0 + v1) / 2, 0.15, w=0.01, z=0.012)
        return fn

    def base_tile(self, ctx):
        base_plane(ctx, "mortar", z=-0.05)
        rows_layout(ctx, 6, lambda r: [-1.0, -0.5, 0.0, 0.5] if r % 2 == 0 else [-0.75, -0.25, 0.25, 0.75],
                    self.brick("brick"))

    def path_tile(self, ctx):
        base_plane(ctx, "mortar", z=-0.05)
        rows_layout(ctx, 3, lambda r: [-1.0, -0.33, 0.33] if r % 2 == 0 else [-0.66, 0.0, 0.66],
                    self.brick("flag", gap=0.04), split=(0.25, 0.3))

    def decals(self):
        def puddle(ctx):
            ctx.b("puddle").disc(0, 0, 0.003, 0.38, 0.25, 18, 0.25, random.Random(1))
            ctx.b("puddleL").disc(0.06, 0.05, 0.004, 0.13, 0.04, 10, 0.2, random.Random(2))
        def moss(ctx):
            r = random.Random(3)
            for _ in range(8):
                ctx.b("mossClump").blob(r.uniform(-0.22, 0.22), r.uniform(-0.15, 0.15), 0.0, 0.07, 0.06, 0.035, seg=7, rings=4)
        def cracks(ctx):
            r = random.Random(4)
            crack(ctx, "crackD", r, 0, 0, 0.55, w=0.016, z=0.003)
        def slime(ctx):
            ctx.b("slime").disc(0, 0, 0.002, 0.3, 0.2, 18, 0.45, random.Random(5))
        def grate(ctx):
            ctx.b("grate").box(0, 0, 0.006, 0.4, 0.3, 0.012)
            for k in range(-3, 4):
                ctx.b("grateHole").box(k * 0.05, 0, 0.0125, 0.024, 0.22, 0.001)
        def pebbles(ctx):
            r = random.Random(6)
            for _ in range(7):
                s = r.uniform(0.02, 0.045)
                ctx.b("pebble").blob(r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), s * 0.3, s, s * 0.8, s * 0.6, seg=7, rings=4)
        return [puddle, moss, cracks, slime, grate, pebbles]


# ----------------------------------------------------------------------------- fortress
@biome("fortress")
class Fortress:
    base = "#5a4153"
    ink = "#34242f"
    SH = ["#5c4355", "#573f51", "#60475a", "#543c4d"]

    def mats(self):
        m = {"mortar": (shade("#432f3d", 1.0), "flat"),
             "crackD": (shade("#3e2b38", 1.0), "flat"),
             "rubble": (shade("#6a5264", 1.0), "toon", {"smooth": True, "ink": True}),
             "stain": (shade("#4b3545", 1.0), "flat"),
             "stud": (shade("#6b6470", 1.0), "toon", {"smooth": True, "ink": True}),
             "rune": (shade("#7a4d6c", 1.0), "flat"),
             "puddle": (shade("#4e3f55", 1.0), "flat"), "puddleL": (shade("#7a6a86", 1.0), "flat"),
             "border": (shade("#6d5268", 1.0), "toon", {"bevel": 0.02, "ink": True})}
        for i, h in enumerate(self.SH):
            m[f"slab{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.025, "ink": True})
        for i, h in enumerate(["#684d60", "#634a5c", "#6d5265", "#5f4658"]):
            m[f"run{i}"] = (shade(h, 1.0), "toon", {"bevel": 0.02, "ink": True})
        return m

    JOINTS = [[-1.0, -0.2, 0.45], [-0.62, 0.12, 0.7], [-1.0, -0.45, 0.25]]

    def slab_fn(self, prefix, gap=0.04):
        def fn(ctx, rnd, a, b, v0, v1, shared, axis):
            slab(ctx, f"{prefix}{rnd.randrange(4)}", a, b, v0, v1, axis, gap, h=0.06, lift=rnd.uniform(0, 0.012))
            if not shared and rnd.random() < 0.12:
                crack(ctx, "crackD", rnd, (a + b) / 2, (v0 + v1) / 2, min(b - a, 0.4) * 0.8, w=0.012, z=0.014)
        return fn

    def base_tile(self, ctx):
        base_plane(ctx, "mortar", z=-0.06)
        rows_layout(ctx, 3, lambda r: self.JOINTS[r], self.slab_fn("slab"), split=(0.35, 0.3),
                    row_sizes=[TY * 0.36, TY * 0.30, TY * 0.34])

    def path_tile(self, ctx):
        base_plane(ctx, "mortar", z=-0.06)
        rows_layout(ctx, 4, lambda r: [-1.0, 0.0] if r % 2 == 0 else [-0.5, 0.5], self.slab_fn("run", 0.035))

    def decals(self):
        def cracks(ctx):
            r = random.Random(1)
            crack(ctx, "crackD", r, 0, 0, 0.6, w=0.018, z=0.003)
            crack(ctx, "crackD", r, 0.1, -0.05, 0.28, w=0.012, z=0.003)
        def rubble(ctx):
            r = random.Random(2)
            for _ in range(7):
                s = r.uniform(0.02, 0.06)
                ctx.b("rubble").blob(r.uniform(-0.28, 0.28), r.uniform(-0.18, 0.18), s * 0.3, s, s * 0.8, s * 0.6, seg=6, rings=3)
        def stain(ctx):
            ctx.b("stain").disc(0, 0, 0.002, 0.32, 0.2, 18, 0.35, random.Random(3))
        def studs(ctx):
            for k in range(4):
                ctx.b("stud").blob(-0.24 + k * 0.16, 0, 0.015, 0.03, 0.03, 0.02, seg=10, rings=5)
        def rune(ctx):
            n = 32
            pts = [(0.28 * math.cos(2 * math.pi * i / n), 0.28 * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]
            ctx.b("rune").strip(pts, 0.025, 0.002)
            # villain sigil: inner diamond + paw-ish dots (no occult symbols; it's a kids' game)
            d = [(0.0, 0.17), (0.17, 0.0), (0.0, -0.17), (-0.17, 0.0), (0.0, 0.17)]
            ctx.b("rune").strip(d, 0.02, 0.002)
            for a in (0.8, 2.35, 3.9, 5.5):
                ctx.b("rune").disc(0.22 * math.cos(a), 0.22 * math.sin(a), 0.002, 0.025, 0.025, 8)
        def puddle(ctx):
            ctx.b("puddle").disc(0, 0, 0.003, 0.34, 0.22, 18, 0.25, random.Random(4))
            ctx.b("puddleL").disc(-0.06, 0.04, 0.004, 0.12, 0.035, 10, 0.2, random.Random(5))
        return [cracks, rubble, stain, studs, rune, puddle]


# ============================================================================= render
def tile_outline(ink_hex, base_hex):
    """Floor ink: 60% ink over the base colour, 1.3 px outer / 1.0 px inner, only the 'ink' collection."""
    sc = bpy.context.scene
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    vl = sc.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(120)
    while len(fs.linesets):
        fs.linesets.remove(fs.linesets[0])
    col = C.mix_col(C.hexc(base_hex), C.hexc(ink_hex), 0.6)
    inked = bpy.data.collections.get("ink")
    for name, px, sel in (("outer", 1.3, dict(select_external_contour=True, select_silhouette=True)),
                          ("inner", 1.0, dict(select_border=True, select_crease=False))):
        ls = fs.linesets.new(name)
        ls.select_by_visibility = True; ls.visibility = "VISIBLE"
        ls.select_by_edge_types = True
        for k in ("select_silhouette", "select_border", "select_crease", "select_contour",
                  "select_external_contour", "select_material_boundary", "select_edge_mark"):
            setattr(ls, k, sel.get(k, False))
        ls.select_by_collection = True; ls.collection = inked; ls.collection_negation = "INCLUSIVE"
        st = bpy.data.linestyles.new(name)
        st.color = col; st.thickness = px * C.SS; st.thickness_position = "CENTER"; st.caps = "ROUND"
        ls.linestyle = st


def camera(width_units, px, ov):
    sc = bpy.context.scene
    tilt = math.radians(C.CAM_TILT)
    from mathutils import Vector
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"
    cd.ortho_scale = width_units * (px[0] + 2 * ov) / px[0]
    cd.sensor_fit = "HORIZONTAL"
    cd.clip_start = 0.1; cd.clip_end = 100
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam)
    fwd = Vector((0, math.sin(tilt), -math.cos(tilt)))
    cam.location = -fwd * 20; cam.rotation_euler = (tilt, 0, 0)
    sc.camera = cam
    sc.render.resolution_x = px[0] + 2 * ov
    sc.render.resolution_y = px[1] + 2 * ov
    sc.render.pixel_aspect_x = sc.render.pixel_aspect_y = 1


def render_one(bname, B_, kind, variant, path, decal_fn=None):
    C.reset()
    sc = bpy.context.scene
    sc.eevee.taa_render_samples = 32
    ctx = Ctx(bname, kind, variant, B_.mats(), decal=decal_fn is not None)
    if decal_fn is not None:
        decal_fn(ctx)
    elif kind == "base":
        B_.base_tile(ctx)
    else:
        B_.path_tile(ctx)
    ctx.build()
    C.add_key_light()
    tile_outline(B_.ink, B_.base)
    if decal_fn is not None:
        sc.render.film_transparent = True
        camera(DECAL_W, DECAL_PX, 0)
    else:
        camera(TX, RAW_PX, OV)
    C.render_to(path)


def main():
    a = C.script_args()
    out = a[a.index("--out") + 1] if "--out" in a else C.default_raw_dir("tiles")
    only = a[a.index("--only") + 1].split(",") if "--only" in a else None
    os.makedirs(out, exist_ok=True)
    t0 = time.time(); n = 0
    meta = {"tile_px": list(TILE_PX), "overscan_raw_px": OV, "ss": C.SS, "tile_ground_units": [TX, round(TY, 4)],
            "biomes": {}}
    for bname, B_ in BIOMES.items():
        if only and bname not in only:
            continue
        info = {"base": [], "path": [], "decals": []}
        for v in range(4):
            nm = f"{bname}_{v}"; render_one(bname, B_, "base", v, os.path.join(out, nm + ".png")); info["base"].append(nm); n += 1
        for v in range(2):
            nm = f"{bname}_path_{v}"; render_one(bname, B_, "path", v, os.path.join(out, nm + ".png")); info["path"].append(nm); n += 1
        for i, fn in enumerate(B_.decals()):
            nm = f"{bname}_decal_{i}"; render_one(bname, B_, "decal", i, os.path.join(out, nm + ".png"), decal_fn=fn)
            info["decals"].append(nm); n += 1
        meta["biomes"][bname] = info
        print(f"[sprites] tiles: {bname} done ({time.time() - t0:.0f}s)")
    mp = os.path.join(out, "_meta.json")
    if only and os.path.exists(mp):
        old = json.load(open(mp)); old["biomes"].update(meta["biomes"]); meta = old
    json.dump(meta, open(mp, "w"), indent=1)
    print(f"[sprites] tiles: {n} images in {time.time() - t0:.1f}s -> {out}")


main()
