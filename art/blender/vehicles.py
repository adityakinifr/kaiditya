"""Top-down toon vehicle sprites (mirrors CharacterFactory.makeCar / makeTruck / makeBoat).
Each vehicle points "up" (+Y world = top of image), camera straight down, transparent bg.
Canvas follows the model footprint at the shared PX_PER_UNIT density (raw = C.SS x final).
Run: Blender -b -P vehicles.py -- [--out DIR] [--only car_hero,boat_hero,...]"""
import os, sys, math, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, common as C
importlib.reload(C)
from mathutils import Vector

PT = 1.0 / 29.0            # game points -> world units
MARGIN = 0.25              # canvas margin around the footprint (units)
KEY_TOPDOWN = Vector((-0.55, 0.40, 0.75)).normalized()   # key from image upper-left


def parse():
    a = C.script_args()
    o = {"out": None, "only": None}
    i = 0
    while i < len(a):
        if a[i] == "--out": o["out"] = a[i + 1]; i += 1
        elif a[i] == "--only": o["only"] = a[i + 1].split(","); i += 1
        i += 1
    return o


# ----------------------------------------------------------------------------- shape helpers
def rrect(w, h, r, cx=0.0, cy=0.0, n=6):
    """Rounded-rectangle outline (CCW) centred on (cx, cy)."""
    r = min(r, w / 2 - 1e-4, h / 2 - 1e-4)
    pts = []
    for qx, qy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        ox, oy = cx + qx * (w / 2 - r), cy + qy * (h / 2 - r)
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((ox + r * math.cos(a), oy + r * math.sin(a)))
    return pts


def scale_pts(pts, k, cx=0.0, cy=0.0, ky=None):
    ky = k if ky is None else ky
    return [(cx + (x - cx) * k, cy + (y - cy) * ky) for x, y in pts]


def loft(name, bot, top, z0, z1, mat, bevel=0.06, seg=3, cap_bottom=True):
    """Solid between two outlines with the same vertex count (bottom at z0, top at z1),
    bevelled edges so the toon bands + ink read as a rounded volume."""
    n = len(bot)
    verts = [(x, y, z0) for x, y in bot] + [(x, y, z1) for x, y in top]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(range(n, 2 * n)))
    if cap_bottom:
        faces.append(tuple(reversed(range(n))))
    o = C.mesh_obj(name, verts, faces, mat, smooth=True)
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = seg
        m.limit_method = "ANGLE"; m.angle_limit = math.radians(35)
        try:
            m.harden_normals = True
        except Exception:
            pass
    return o


def slab(name, pts, z0, z1, mat, bevel=0.02, seg=2):
    return loft(name, pts, pts, z0, z1, mat, bevel=bevel, seg=seg)


def quad_bezier(p0, c, p1, n=10):
    out = []
    for k in range(n):
        t = k / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]))
    return out


def bolt_pts(scale, cx=0.0, cy=0.0):
    """Characters.boltPath (points) -> world units, CCW."""
    p = [(2, 12), (-6, 2), (0, 2), (-2, -12), (7, 0), (1, 0)]
    return [(cx + x * scale * PT, cy + y * scale * PT) for x, y in p]


def bolt(name, scale, cx, cy, z, mat, ink=None, h=0.05):
    """Lightning bolt emblem with a dark backing so it pops on dark purple."""
    pts = bolt_pts(scale, cx, cy)
    if ink is not None:
        # dark drop-shadow copy offset to the lower right (away from the key light)
        d = 0.035 * scale
        bolt(name + "_back", scale, cx + d, cy - d, z, ink, None, h * 0.5)
        z += h * 0.5
    # fan triangulation isn't safe for a concave bolt -> split into two quads + ngon
    verts = [(x, y, z) for x, y in pts] + [(x, y, z + h) for x, y in pts]
    n = len(pts)
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces += [(n + 0, n + 1, n + 2, n + 5), (n + 5, n + 2, n + 3, n + 4)]
    faces += [(5, 2, 1, 0), (4, 3, 2, 5)]
    o = C.mesh_obj(name, verts, faces, mat, smooth=False)
    m = o.modifiers.new("bevel", "BEVEL"); m.width = 0.012; m.segments = 1
    return o


def tyre(x, y, r, w, mat, hub):
    C.cylinder((x, y, r), r, w, mat, rot=(0, math.pi / 2, 0), verts=24, bevel=0.04)
    C.cylinder((x + math.copysign(w / 2, x), y, r), r * 0.5, 0.03, hub, rot=(0, math.pi / 2, 0),
               verts=16)


def mats():
    return {
        "tyre": C.toon("tyre", C.P["tyre"], rim=0.25, hi=0.2),
        "metal": C.toon("metal", C.P["metal"], hi=0.35),
        "glass": C.toon("glass", C.P["glass"], hi=0.45, rim=0.3),
        "glassD": C.toon("glassD", C.scale_col(C.P["glass"], 0.62), hi=0.3, rim=0.3),
        "energy": C.toon("energy", C.P["energy"], hi=0.3),
        "energyF": C.toon("energyF", C.P["energy"], flat=True),
        "red": C.toon("red", C.P["heroRed"], hi=0.25),
        "redF": C.toon("redF", C.P["heroRed"], flat=True),
        "white": C.toon("white", C.P["white"], hi=0.0),
        "lamp": C.toon("lamp", C.rgb(1.0, 0.97, 0.80), flat=True),
        "ink": C.toon("inkM", C.INK_LIN, flat=True),
        "dark": C.toon("darkM", C.rgb(0.20, 0.21, 0.26), hi=0.2),
    }


# ----------------------------------------------------------------------------- cars
def build_car(col, hero):
    M = mats()
    BODY = C.toon("body", col, hi=0.18)
    TR = 0.25
    for sx in (1, -1):
        for sy in (0.88, -0.88):
            tyre(sx * 0.73, sy, TR, 0.28, M["tyre"], M["metal"])
    # chunky lower body: slightly tucked-in bottom, heavy rounded edges
    body_top = 0.60
    loft("body", rrect(1.40, 2.62, 0.34), rrect(1.52, 2.74, 0.42), 0.14, body_top, BODY,
         bevel=0.14, seg=4)
    # bumpers
    for sy in (1, -1):
        C.box((0, sy * 1.37, 0.30), (1.18, 0.16, 0.20), M["dark"], bevel=0.07, seg=3)
    # cabin: glass greenhouse with a body-coloured roof on top
    cy = -0.12
    loft("cabin", rrect(1.28, 1.56, 0.30, cy=cy), rrect(1.02, 0.98, 0.24, cy=cy - 0.06),
         body_top - 0.02, 0.98, M["glass"], bevel=0.05, seg=2)
    loft("roof", rrect(1.08, 1.04, 0.26, cy=cy - 0.06), rrect(1.02, 0.96, 0.24, cy=cy - 0.06),
         0.97, 1.06, BODY, bevel=0.04, seg=3)
    # headlights (front, on the hood nose) and tail lights
    for sx in (1, -1):
        C.sphere((sx * 0.46, 1.30, 0.52), (0.19, 0.10, 0.10), M["energyF"] if hero else M["lamp"])
        C.sphere((sx * 0.50, -1.33, 0.52), (0.15, 0.07, 0.08), M["redF"])
    if hero:
        S = 0.30
        slab("stripe_hood", rrect(S, 0.62, 0.05, cy=1.00), body_top - 0.01, body_top + 0.025, M["energy"])
        slab("stripe_roof", rrect(S, 0.96, 0.05, cy=cy - 0.06), 1.055, 1.085, M["energy"])
        slab("stripe_boot", rrect(S, 0.34, 0.05, cy=-1.10), body_top - 0.01, body_top + 0.025, M["energy"])
        # red K on the roof stripe
        k = C.text("K", (0, cy - 0.06, 1.09), 0.62, M["red"], extrude=0.02)
        k.data.body = "K"
        k.data.font = bpy_font_bold()
        # cape-red spoiler on two posts
        for sx in (1, -1):
            C.box((sx * 0.46, -1.22, 0.72), (0.08, 0.08, 0.24), M["dark"], bevel=0.02)
        C.box((0, -1.25, 0.86), (1.46, 0.26, 0.07), M["red"], bevel=0.035, seg=2)
    return 1.66, 2.90


_font = None
def bpy_font_bold():
    """Heavy font for the K if the system has one; Blender's built-in otherwise."""
    import bpy
    for p in ("/System/Library/Fonts/Supplemental/Arial Black.ttf",
              "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
              "/Library/Fonts/Arial Bold.ttf"):
        if os.path.exists(p):
            try:
                return bpy.data.fonts.load(p, check_existing=True)
            except Exception:
                pass
    return bpy.data.fonts[0] if len(bpy.data.fonts) else None


# ----------------------------------------------------------------------------- truck
def build_truck():
    M = mats()
    V = C.P["villain"]
    CAB = C.toon("cab", C.scale_col(V, 1.15), hi=0.2)
    BED = C.toon("bed", C.scale_col(V, 0.62), hi=0.15)
    BEDW = C.toon("bedw", C.scale_col(V, 0.85), hi=0.15)
    TR, TW = 0.33, 0.30
    for sx in (1, -1):
        for y in (1.30, -0.55, -1.40):
            tyre(sx * 1.0, y, TR, TW, M["tyre"], M["metal"])
    # cab + hood
    loft("cab", rrect(1.86, 1.62, 0.30, cy=1.20), rrect(2.0, 1.72, 0.38, cy=1.20), 0.20, 0.85, CAB,
         bevel=0.14, seg=4)
    loft("cabin", rrect(1.84, 0.95, 0.22, cy=0.82), rrect(1.56, 0.58, 0.18, cy=0.72),
         0.83, 1.28, M["glassD"], bevel=0.05, seg=2)
    loft("roof", rrect(1.62, 0.64, 0.2, cy=0.72), rrect(1.56, 0.58, 0.18, cy=0.72), 1.27, 1.36, CAB,
         bevel=0.04, seg=3)
    # angry brows over red headlights
    for sx in (1, -1):
        C.sphere((sx * 0.60, 1.98, 0.78), (0.24, 0.13, 0.12), M["redF"])
        C.box((sx * 0.60, 1.88, 0.86), (0.52, 0.12, 0.06), M["ink"], rot=(0, 0, math.radians(-sx * 16)),
              bevel=0.02)
    # hood vents
    for x in (-0.25, 0, 0.25):
        C.box((x, 1.55, 0.85), (0.1, 0.42, 0.04), C.toon("cabD", C.scale_col(V, 0.7)), bevel=0.02)
    # spiked bull bar
    C.box((0, 2.10, 0.42), (1.8, 0.14, 0.18), M["metal"], bevel=0.06, seg=2)
    for x in (-0.66, -0.22, 0.22, 0.66):
        C.cone_dir((x, 2.16, 0.42), (0, 1, 0), 0.07, 0.20, M["metal"], verts=12)
    # exhaust stacks behind the cab
    for sx in (1, -1):
        C.cylinder((sx * 0.86, 0.30, 0.95), 0.09, 1.2, M["metal"], verts=16)
        C.cylinder((sx * 0.86, 0.30, 1.56), 0.06, 0.02, M["ink"], verts=16)
    # cargo bed: dark floor with raised side walls, big yellow bolt
    by, bl, bw = -0.92, 2.34, 1.96
    slab("bedfloor", rrect(bw, bl, 0.16, cy=by), 0.20, 0.55, BED, bevel=0.06)
    t = 0.14
    for sx in (1, -1):
        C.box((sx * (bw / 2 - t / 2), by, 0.72), (t, bl, 0.36), BEDW, bevel=0.05)
    for sy in (1, -1):
        C.box((0, by + sy * (bl / 2 - t / 2), 0.72), (bw, t, 0.36), BEDW, bevel=0.05)
    bolt("bolt", 2.5, 0.0, by, 0.55, M["energy"], ink=M["ink"], h=0.06)
    return 2.40, 4.30


# ----------------------------------------------------------------------------- boats
def boat_hull_pts(s):
    """Characters.makeBoat hull path (points * s) -> world units, CCW, ~evenly sampled."""
    P = lambda x, y: (x * s * PT, y * s * PT)
    pts = []
    pts += quad_bezier(P(0, 52), P(-30, 30), P(-26, -10), 12)
    pts += [P(-26, -10), P(-25, -27)]
    pts += [P(-22, -44), P(-8, -45), P(8, -45)]
    pts += [P(22, -44), P(25, -27)]
    pts += quad_bezier(P(26, -10), P(30, 30), P(0, 52), 12)
    return pts


def build_boat(col, s, hero):
    M = mats()
    HULL = C.toon("hull", col, hi=0.2)
    DECK = C.toon("deck", C.scale_col(col, 0.62), hi=0.15)
    u = s * PT
    top = boat_hull_pts(s)
    cy = 4 * u
    bot = scale_pts(top, 0.80, 0, cy, ky=0.92)
    loft("hull", bot, top, 0.0, 0.50, HULL, bevel=0.10, seg=4)
    # white gunwale band -> inset foredeck + sunken dark cockpit
    loft("foredeck", scale_pts(top, 0.86, 0, cy), scale_pts(top, 0.84, 0, cy), 0.48, 0.53,
         C.toon("deckL", C.mix_col(col, C.P["white"], 0.55) if hero else C.scale_col(col, 1.25), hi=0.1),
         bevel=0.02)
    ck = rrect(28 * u, 34 * u, 8 * u, cy=-8 * u)
    slab("cockpit", ck, 0.50, 0.56, DECK, bevel=0.025)
    # seats
    SEAT = C.toon("seat", C.mix_col(col, C.P["white"], 0.45) if hero else C.rgb(0.22, 0.2, 0.28), hi=0.1)
    for sx in (1, -1):
        C.box((sx * 6.5 * u, -9 * u, 0.62), (9 * u, 12 * u, 0.12), SEAT, bevel=0.04, seg=2)
    # curved windshield in front of the cockpit
    wy = 10 * u
    loft("windshield", rrect(26 * u, 7 * u, 3.4 * u, cy=wy), rrect(22 * u, 3 * u, 1.4 * u, cy=wy - 3 * u),
         0.54, 0.80, M["glass"], bevel=0.02, seg=2)
    # outboard engine(s)
    engines = (0,) if hero else (-9 * u, 9 * u)
    for ex in engines:
        C.box((ex, -47 * u, 0.50), (9 * u, 8 * u, 0.36), M["dark"], bevel=0.06, seg=3)
        C.box((ex, -48 * u, 0.70), (7 * u, 5 * u, 0.08), M["metal"], bevel=0.03)
    if hero:
        # yellow racing stripe up the bow + white K on the stern deck
        slab("stripe", rrect(6 * u, 26 * u, 2 * u, cy=28 * u), 0.52, 0.555, M["energy"])
        C.box((0, -34 * u, 0.56), (12 * u, 11 * u, 0.04), M["red"], bevel=0.02)
        k = C.text("K", (0, -34 * u, 0.58), 0.40, M["white"], extrude=0.02)
        k.data.font = bpy_font_bold()
    else:
        bolt("bolt", 1.25 * s, 0.0, 29 * u, 0.53, M["energy"], ink=M["ink"], h=0.04)
        C.box((0, -34 * u, 0.56), (20 * u, 4 * u, 0.04), M["energy"], bevel=0.015)
    w = 60 * s * PT
    return w, (52 + 52) * s * PT


def build_barge():
    M = mats()
    HULL = C.toon("bhull", C.rgb(0.50, 0.36, 0.26), hi=0.15)
    DECK = C.toon("bdeck", C.rgb(0.52, 0.53, 0.56), hi=0.1)
    RIM = C.toon("brim", C.rgb(0.34, 0.26, 0.21), hi=0.15)
    W, L = 1.80, 4.00
    loft("hull", rrect(W * 0.88, L * 0.93, 0.35), rrect(W, L, 0.45), 0.0, 0.42, HULL, bevel=0.10, seg=3)
    slab("deck", rrect(W - 0.22, L - 0.22, 0.34), 0.40, 0.44, DECK, bevel=0.01)
    # raised rim (gunwale) all round
    t = 0.10
    for sx in (1, -1):
        C.box((sx * (W / 2 - t / 2 - 0.01), 0, 0.52), (t, L - 0.7, 0.18), RIM, bevel=0.04)
    # tyre fenders hanging off the sides
    for sx in (1, -1):
        for y in (-1.2, 0.0, 1.2):
            C.torus((sx * (W / 2 + 0.02), y, 0.36), 0.10, 0.045, M["tyre"], rot=(0, math.pi / 2, 0),
                    minor_seg=8, major_seg=20)
    # containers
    for (cy, c) in ((0.95, C.rgb(0.80, 0.34, 0.30)), (-0.25, C.rgb(0.30, 0.58, 0.55))):
        mc = C.toon("cont%.2f" % cy, c, hi=0.2)
        C.box((0, cy, 0.78), (1.24, 1.08, 0.66), mc, bevel=0.05, seg=2)
        for k in range(5):
            C.box((-0.45 + k * 0.225, cy, 1.115), (0.07, 1.02, 0.03), C.toon("contD%.2f" % cy, C.scale_col(c, 0.72)),
                  bevel=0.01)
    # wooden crates near the bow
    WOOD = C.toon("crate", C.P["wood"], hi=0.2)
    WOODD = C.toon("crateD", C.scale_col(C.P["wood"], 0.65))
    for (x, y, sz) in ((-0.38, 1.72, 0.40), (0.25, 1.70, 0.36)):
        C.box((x, y, 0.44 + sz / 2), (sz, sz, sz), WOOD, bevel=0.03, rot=(0, 0, math.radians(8 * x)))
        C.box((x, y, 0.44 + sz + 0.005), (sz * 0.8, 0.05, 0.02), WOODD, rot=(0, 0, math.radians(8 * x + 45)),
              bevel=0.005)
    # small wheelhouse at the stern
    C.box((0, -1.45, 0.72), (0.90, 0.62, 0.56), M["white"], bevel=0.06, seg=3)
    loft("whglass", rrect(0.86, 0.10, 0.03, cy=-1.10), rrect(0.8, 0.06, 0.02, cy=-1.12), 0.72, 0.98,
         M["glassD"], bevel=0.01)
    C.box((0, -1.45, 1.03), (1.0, 0.74, 0.08), C.toon("whroof", C.rgb(0.80, 0.34, 0.30), hi=0.2),
          bevel=0.03)
    C.cylinder((0.30, -1.58, 1.15), 0.06, 0.25, M["dark"], verts=12)
    return W + 0.12, L


VEHICLES = {
    "car_hero": lambda: build_car(C.P["heroBlue"], True),
    "car_traffic_red": lambda: build_car(C.rgb(0.9, 0.4, 0.4), False),
    "car_traffic_blue": lambda: build_car(C.rgb(0.4, 0.6, 0.85), False),
    "car_traffic_yellow": lambda: build_car(C.rgb(0.95, 0.8, 0.35), False),
    "car_traffic_white": lambda: build_car(C.rgb(0.85, 0.85, 0.85), False),
    "truck_villain": build_truck,
    "boat_hero": lambda: build_boat(C.P["heroBlue"], 1.0, True),
    "boat_villain": lambda: build_boat(C.P["villain"], 1.3, False),
    "barge": build_barge,
}


def main():
    opts = parse()
    out = opts["out"] or C.default_raw_dir("vehicles")
    names = opts["only"] or list(VEHICLES)
    t0 = time.time()
    for name in names:
        t1 = time.time()
        C.reset()
        C._mats.clear()                 # materials died with the old scene
        w, h = VEHICLES[name]()
        key = C.add_key_light()
        key.rotation_quaternion = C.look_quat(KEY_TOPDOWN)
        cam, (wpx, hpx) = C.topdown_camera(w + 2 * MARGIN, h + 2 * MARGIN)
        C.outline(px=2.6, inner_px=1.4)
        C.render_to(os.path.join(out, f"{name}.png"))
        print(f"[vehicles] {name}: {wpx}x{hpx} final ({wpx * C.SS}x{hpx * C.SS} raw) "
              f"in {time.time() - t1:.1f}s")
    print(f"[vehicles] {len(names)} vehicles in {time.time() - t0:.1f}s -> {out}")


main()
