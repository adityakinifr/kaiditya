"""Toon 3/4 buildings for the 55deg character camera (graphics plan P7).

Each building is rendered WHOLE (not kit-bashed) from the characters' camera (tilt 55deg,
PX_PER_UNIT ~116), exactly like the props:
  <name>.png         EEVEE colour pass: toon bands + stepped violet AO band + Freestyle ink
  <name>_shadow.png  Cycles shadow-catcher pass: alpha-only cast + contact shadow, falls down-right

Buildings are axis-aligned boxes seen from the front (-Y), so only the front face and the roof
show; the side faces are edge-on in the orthographic view.

Footprint convention (same as props_manifest footprint_pt): a building spec of W x H points
(top-down rect, H = depth on screen) is modelled with a ground rect of
  W / (0.3 * PX_PER_UNIT) units wide  x  H / (0.3 * PX_PER_UNIT * cos55) units deep,
so the ground rect projects to exactly W x H points on screen at worldScale 0.3.
The canonical footprint is 200 x 150 pt (5.73 x 7.49 units); the fortress is 400 x 220 pt.

Every builder places a blank sign plate (Swift overlays the label) and a door; their positions
are written to _meta.json in points relative to the anchor (ground-footprint centre), and
tools/buildings_post.py turns that into art/buildings_manifest.json.

The raw canvas is sized per building from the projected geometry + its cast shadow; the world
origin's pixel is recorded in _meta.json.

Run: Blender -b -P buildings.py -- --out RAW_DIR [--only bld_shop,bld_lab]
"""
import os, sys, math, json, time, random, shutil
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import bpy
import common as C
import envkit as E
importlib.reload(C); importlib.reload(E)
from mathutils import Vector

PPU = C.PX_PER_UNIT
WS = 0.3
TILT = math.radians(C.CAM_TILT)
COS, SIN = math.cos(TILT), math.sin(TILT)
INK = (2.0, 1.2)            # static props line weights (graphics plan)


def pt2u(pt):
    return pt / (PPU * WS)


def footprint_units(w_pt, h_pt):
    return pt2u(w_pt), pt2u(h_pt) / COS


def to_pt(p):
    """World point -> screen offset in points from the anchor (x right, y up) at scale 0.3."""
    x, y, z = p
    return [round(x * PPU * WS, 1), round((y * COS + z * SIN) * PPU * WS, 1)]


# ----------------------------------------------------------------------------- palette (sRGB)
COL = {
    "cream":     C.rgb(0.96, 0.89, 0.74),
    "creamDark": C.rgb(0.86, 0.77, 0.62),
    "trim":      C.rgb(0.95, 0.95, 0.92),
    "wood":      C.P["wood"],
    "woodDark":  C.scale_col(C.P["wood"], 0.62),
    "stone":     C.rgb(0.66, 0.64, 0.70),
    "stoneDark": C.rgb(0.48, 0.46, 0.55),
    "brass":     C.rgb(0.84, 0.70, 0.38),
    "glass":     C.rgb(0.62, 0.80, 0.92),
    "glassDark": C.rgb(0.36, 0.52, 0.70),
    "plate":     C.rgb(0.97, 0.94, 0.84),     # sign plates: light, Swift draws dark ink text
    "iron":      C.rgb(0.22, 0.23, 0.30),
    "gunmetal":  C.rgb(0.34, 0.36, 0.44),
    "steel":     C.rgb(0.62, 0.65, 0.72),
    "concrete":  C.rgb(0.64, 0.65, 0.68),
    "leaf":      C.rgb(0.30, 0.58, 0.32),
    "leafLite":  C.rgb(0.42, 0.68, 0.38),
    "moss":      C.rgb(0.40, 0.56, 0.30),
    "mossDark":  C.rgb(0.28, 0.44, 0.24),
    "brick":     C.rgb(0.64, 0.38, 0.31),
    "brickDark": C.rgb(0.50, 0.28, 0.24),
}
ROOFS = {
    "blue":   C.rgb(0.30, 0.50, 0.86),
    "red":    C.rgb(0.84, 0.34, 0.32),
    "green":  C.rgb(0.36, 0.66, 0.40),
    "orange": C.rgb(0.94, 0.58, 0.26),
    "purple": C.rgb(0.58, 0.40, 0.80),
}


def M(name, col=None, rim=0.25, hi=0.10, ao=0.30, **kw):
    return E.tmat(name, col if col is not None else COL[name], rim=rim, hi=hi, ao=ao, **kw)


def G(name, col):
    return E.glow(name, col)


# ----------------------------------------------------------------------------- registry
REGISTRY = []   # (name, fn, cfg)


def building(name, footprint_pt=(200, 150), variants=None, note=""):
    def deco(fn):
        REGISTRY.append((name, fn, dict(footprint_pt=footprint_pt, variants=variants, note=note)))
        return fn
    return deco


class Feat:
    """Collects the sign plate / door placements a builder makes."""
    def __init__(self):
        self.sign = None
        self.door = None

    def set_sign(self, center, w, h, tilt=0.0):
        self.sign = dict(center=tuple(center), w=w, h=h, tilt=tilt)

    def set_door(self, x, y, w, h):
        self.door = dict(x=x, y=y, w=w, h=h)


# ----------------------------------------------------------------------------- geometry helpers
def slab(x0, x1, y0, y1, z0, z1, mat, bevel=0.03, seg=2):
    return C.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mat,
                 bevel=bevel, seg=seg, smooth=False)


def front(x, z, w, h, yf, depth, mat, bevel=0.02, proud=0.0):
    """Box on the front face (y = yf, facing -Y); (x, z) is its centre, depth sticks out."""
    return C.box((x, yf - depth / 2 + proud, z), (w, depth, h), mat, bevel=bevel, seg=2, smooth=False)


def mesh(name, verts, faces, mat, smooth=False, solid=0.0, offset=-1.0):
    """mesh_obj with faces re-oriented so that their normals point up / towards the camera."""
    fixed = []
    for f in faces:
        a, b, c = (Vector(verts[i]) for i in f[:3])
        n = (b - a).cross(c - a)
        # up-facing surfaces: +z; vertical surfaces: -y (towards camera)
        if (abs(n.z) > 1e-6 and n.z < 0) or (abs(n.z) <= 1e-6 and n.y > 0):
            f = tuple(reversed(f))
        fixed.append(tuple(f))
    o = C.mesh_obj(name, verts, fixed, mat, smooth=smooth)
    if solid:
        m = o.modifiers.new("solid", "SOLIDIFY"); m.thickness = solid; m.offset = offset
        m.use_even_offset = True
    return o


def rot_box(center, size, mat, rot, bevel=0.0):
    b = C.box(center, size, mat, bevel=bevel, seg=1, smooth=False)
    b.rotation_euler = rot
    return b


def star_mesh(name, r_out, r_in, t, mat, points=5):
    """Chunky star in the XZ plane (facing -Y)."""
    ring = []
    for k in range(points * 2):
        a = math.pi / 2 + k * math.pi / points
        r = r_out if k % 2 == 0 else r_in
        ring.append((r * math.cos(a), r * math.sin(a)))
    n = len(ring)
    vs = [(x, -t, z) for x, z in ring] + [(x, t, z) for x, z in ring] + [(0, -t * 1.6, 0), (0, t * 1.6, 0)]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i)[::-1])
        fs.append((2 * n, j, i)[::-1])
        fs.append((2 * n + 1, n + i, n + j)[::-1])
    return C.mesh_obj(name, vs, fs, mat, smooth=False)


def tube(name, pts, radius, mat, res=4):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"
    cu.bevel_depth = radius; cu.bevel_resolution = res; cu.use_fill_caps = True
    sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
    for p, (x, y, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1)
    o = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def gable_y(W, D, H, r, mat, ov=0.3, ovf=0.3, thick=0.14, y0=None, y1=None, x0=0.0):
    """Roof with the ridge along Y (gable end facing the camera). Returns slope angle."""
    a = math.atan2(r, W / 2)
    e = W / 2 + ov
    ze = H - ov * math.tan(a)
    y0 = -D / 2 - ovf if y0 is None else y0
    y1 = D / 2 + ovf if y1 is None else y1
    vs = [(x0 - e, y0, ze), (x0, y0, H + r), (x0 + e, y0, ze),
          (x0 - e, y1, ze), (x0, y1, H + r), (x0 + e, y1, ze)]
    mesh("roof", vs, [(0, 1, 4, 3), (1, 2, 5, 4)], mat, solid=thick)
    return a


def gable_x(W, D, H, r, mat, ov=0.3, ovs=0.3, thick=0.14):
    """Roof with the ridge along X (eave facing the camera). Returns slope angle."""
    a = math.atan2(r, D / 2)
    e = D / 2 + ov
    ze = H - ov * math.tan(a)
    x0, x1 = -W / 2 - ovs, W / 2 + ovs
    vs = [(x0, -e, ze), (x0, 0, H + r), (x0, e, ze), (x1, -e, ze), (x1, 0, H + r), (x1, e, ze)]
    mesh("roof", vs, [(0, 1, 4, 3), (1, 2, 5, 4)], mat, solid=thick)
    return a


def pediment(W, H, r, yf, mat, depth=0.2, x0=0.0):
    vs = [(x0 - W / 2, yf, H), (x0 + W / 2, yf, H), (x0, yf, H + r)]
    o = mesh("pediment", vs, [(0, 1, 2)], mat, solid=depth, offset=-1)
    return o


def slope_rows_y(W, H, r, ov, y0, y1, mat, n=6, t=0.035, x0=0.0, roof_t=0.0):
    """Tile rows parallel to the ridge on both slopes of a gable_y roof."""
    a = math.atan2(r, W / 2)
    L = (W / 2 + ov) / math.cos(a)
    for side in (-1, 1):
        d = Vector((side * math.cos(a), 0, -math.sin(a)))
        nrm = Vector((side * math.sin(a), 0, math.cos(a)))
        for k in range(1, n + 1):
            s = L * k / (n + 0.4)
            c = Vector((x0, (y0 + y1) / 2, H + r)) + d * s + nrm * (t / 2 + roof_t)
            rot_box(c, (0.07, y1 - y0, t), mat, (0, side * a, 0))


def slope_cross_y(W, H, r, ov, y0, y1, mat, pitch=0.6, t=0.03, x0=0.0):
    """Tile-course lines across both slopes of a gable_y roof (perpendicular to the ridge)."""
    a = math.atan2(r, W / 2)
    L = (W / 2 + ov) / math.cos(a)
    n = int((y1 - y0) / pitch)
    for side in (-1, 1):
        d = Vector((side * math.cos(a), 0, -math.sin(a)))
        nrm = Vector((side * math.sin(a), 0, math.cos(a)))
        for k in range(1, n):
            y = y0 + (y1 - y0) * k / n
            c = Vector((x0, y, H + r)) + d * (L / 2 + 0.06) + nrm * (t / 2)
            rot_box(c, (L - 0.12, 0.05, t), mat, (0, side * a, 0))


def roof_seams(W, D, z, mat, pitch=1.1, inset=0.35):
    """Membrane seams on a flat roof: thin strips at constant y (read as screen-horizontal lines)."""
    n = int((D - 2 * inset) / pitch)
    for k in range(1, n):
        y = -D / 2 + inset + (D - 2 * inset) * k / n
        C.box((0, y, z + 0.005), (W - 2 * inset, 0.05, 0.012), mat, bevel=0.0, smooth=False)
    for x in (-W / 6, W / 6):
        C.box((x, 0, z + 0.004), (0.05, D - 2 * inset, 0.01), mat, bevel=0.0, smooth=False)


def window(x, zc, w, h, yf, frame, glass, bars=True, sill=None, shine=None):
    front(x, zc, w + 0.16, h + 0.16, yf, 0.08, frame, bevel=0.02)
    front(x, zc, w, h, yf, 0.10, glass, bevel=0.0)
    if shine is not None:
        s = rot_box((x - w * 0.18, yf - 0.105, zc + h * 0.12), (w * 0.14, 0.01, h * 0.7), shine,
                    (0, math.radians(-30), 0))
    if bars:
        front(x, zc, 0.06, h, yf, 0.13, frame, bevel=0.0)
        front(x, zc, w, 0.06, yf, 0.13, frame, bevel=0.0)
    if sill is not None:
        front(x, zc - h / 2 - 0.1, w + 0.34, 0.09, yf, 0.2, sill, bevel=0.02)


def sign_plate(feat, x, zc, w, h, yf, plate, frame, proud=0.14, tilt_deg=0.0, bolts=None):
    """Blank sign plate facing the camera. Records the plate face centre for the manifest."""
    t = math.radians(tilt_deg)
    y = yf - proud
    fr = rot_box((x, y + 0.03, zc), (w + 0.16, 0.08, h + 0.16), frame, (-t, 0, 0), bevel=0.03)
    pl = rot_box((x, y - 0.02, zc), (w, 0.06, h), plate, (-t, 0, 0), bevel=0.01)
    if bolts is not None:
        for sx in (-1, 1):
            C.sphere((x + sx * (w / 2 - 0.08), y - 0.06, zc + h / 2 - 0.08), 0.035, bolts, seg=8, rings=4)
    feat.set_sign((x, y - 0.05, zc), w, h, tilt_deg)


def door(feat, x, w, h, yf, mat, frame, knob=None, panels=None, glass=None, double=False):
    front(x, h / 2 + 0.04, w + 0.2, h + 0.12, yf, 0.08, frame, bevel=0.02)
    front(x, h / 2, w, h, yf, 0.11, mat, bevel=0.015)
    if double:
        front(x, h / 2, 0.04, h, yf, 0.13, frame, bevel=0.0)
    if glass is not None:
        for sx in ((-1, 1) if double else (0,)):
            gx = x + sx * w / 4
            front(gx, h * 0.62, (w / 2 if double else w) * 0.6, h * 0.45, yf, 0.12, glass, bevel=0.0)
    if panels is not None:
        for sx in (-1, 1):
            front(x + sx * w * 0.22, h * 0.28, w * 0.32, h * 0.3, yf, 0.125, panels, bevel=0.01)
            if glass is None:
                front(x + sx * w * 0.22, h * 0.7, w * 0.32, h * 0.35, yf, 0.125, panels, bevel=0.01)
    if knob is not None:
        C.sphere((x + w * 0.35, yf - 0.15, h * 0.48), 0.055, knob, seg=10, rings=6)
    feat.set_door(x, yf, w, h)


def step(x, w, yf, mat, d=0.4, hgt=0.1):
    slab(x - w / 2, x + w / 2, yf - d, yf, 0, hgt, mat, bevel=0.02)


def flowers(x, z, w, yf, rnd, box_mat):
    front(x, z, w, 0.22, yf, 0.26, box_mat, bevel=0.03)
    leaf = M("leaf", ao=0)
    cols = [M("flowerPink", C.rgb(0.95, 0.55, 0.70), ao=0), M("flowerWhite", C.rgb(0.98, 0.96, 0.92), ao=0)]
    for k in range(7):
        fx = x - w / 2 + 0.1 + (w - 0.2) * k / 6
        C.sphere((fx, yf - 0.14, z + 0.15), (0.09, 0.08, 0.08), leaf, seg=10, rings=6)
        if k % 2 == 0:
            C.sphere((fx + 0.03, yf - 0.2, z + 0.22), 0.055, cols[(k // 2) % 2], seg=8, rings=5)


def crenels(x0, x1, y0, y1, z, mat, size=0.4, gap=0.4, h=0.35, sides=(0, 1, 2, 3)):
    """Merlons along the rectangle's edges (0 front, 1 right, 2 back, 3 left)."""
    def run(ax, a0, a1, fixed, horiz):
        L = a1 - a0
        n = max(1, int((L + gap) / (size + gap)))
        sp = (L - n * size) / max(n - 1, 1) if n > 1 else 0
        for k in range(n):
            c = a0 + size / 2 + k * (size + sp) if n > 1 else (a0 + a1) / 2
            if horiz:
                C.box((c, fixed, z + h / 2), (size, size, h), mat, bevel=0.03, seg=1, smooth=False)
            else:
                C.box((fixed, c, z + h / 2), (size, size, h), mat, bevel=0.03, seg=1, smooth=False)
    if 0 in sides: run("x", x0, x1, y0 + size / 2, True)
    if 2 in sides: run("x", x0, x1, y1 - size / 2, True)
    if 1 in sides: run("y", y0 + size, y1 - size, x1 - size / 2, False)
    if 3 in sides: run("y", y0 + size, y1 - size, x0 + size / 2, False)


def parapet(W, D, H, h, t, mat, bevel=0.03):
    slab(-W / 2, W / 2, -D / 2, -D / 2 + t, H, H + h, mat, bevel)
    slab(-W / 2, W / 2, D / 2 - t, D / 2, H, H + h, mat, bevel)
    slab(-W / 2, -W / 2 + t, -D / 2, D / 2, H, H + h, mat, bevel)
    slab(W / 2 - t, W / 2, -D / 2, D / 2, H, H + h, mat, bevel)


def ribs_x(x0, x1, yf, z0, z1, mat, pitch=0.22, w=0.07, depth=0.05):
    """Vertical corrugation ribs on a front face."""
    n = int((x1 - x0) / pitch)
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n
        front(x, (z0 + z1) / 2, w, z1 - z0, yf, depth, mat, bevel=0.0)


def vent(x, y, z, mat, cap, r=0.18, h=0.45):
    C.cylinder((x, y, z + h / 2), r * 0.6, h, mat, verts=14)
    C.cylinder((x, y, z + h + 0.05), r, 0.08, cap, verts=16)
    C.sphere((x, y, z + h + 0.1), (r, r, r * 0.5), cap, seg=14, rings=6)


# ============================================================================= 1. house
@building("bld_house", variants=list(ROOFS), note="town house; roof colour variants share one body")
def _house(feat, W, D, variant="blue"):
    rnd = random.Random(7)
    H, r = 2.2, 2.0
    yf = -D / 2
    roofc = ROOFS[variant]
    wall, trim, roof = M("cream"), M("trim", hi=0.2), M("roof_" + variant, roofc, hi=0.14)
    roofD = M("roofD_" + variant, C.scale_col(roofc, 0.72))
    stone = M("stone")
    slab(-W / 2 - 0.08, W / 2 + 0.08, -D / 2 - 0.08, D / 2 + 0.08, 0, 0.22, M("stoneDark"))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.2, H, wall, bevel=0.02)
    pediment(W, H - 0.01, r, yf + 0.005, wall, depth=0.25)
    ovf = 0.28
    gable_y(W, D, H, r, roof, ov=0.32, ovf=ovf)
    slope_rows_y(W, H, r, 0.32, -D / 2 - ovf, D / 2 + ovf, roofD, n=7, roof_t=0.0)
    slope_cross_y(W, H, r, 0.32, -D / 2 - ovf, D / 2 + ovf, roofD, pitch=0.62)
    # ridge cap + barge boards along the front gable edges
    C.cylinder((0, 0, H + r + 0.06), 0.11, D + 2 * ovf + 0.04, roofD, rot=(math.pi / 2, 0, 0), verts=12)
    a = math.atan2(r, W / 2)
    Lb = (W / 2 + 0.32) / math.cos(a)
    for s in (-1, 1):
        c = Vector((s * (W / 2 + 0.32) / 2, -D / 2 - ovf - 0.04, H + r - (r + 0.32 * math.tan(a)) / 2 + 0.06))
        rot_box(c, (Lb, 0.1, 0.16), trim, (0, s * a, 0), bevel=0.02)
    # corner boards + wall base trim
    for s in (-1, 1):
        front(s * (W / 2 - 0.08), (H + 0.2) / 2, 0.18, H - 0.2, yf, 0.06, trim, bevel=0.01)
    front(0, H - 0.05, W, 0.12, yf, 0.07, trim, bevel=0.01)
    # chimney on the right slope
    slab(1.1, 1.65, 1.2, 1.75, H, H + r + 0.6, M("brick"), bevel=0.03)
    slab(1.02, 1.73, 1.12, 1.83, H + r + 0.55, H + r + 0.72, M("brickDark"), bevel=0.02)
    # door with porch canopy + step
    door(feat, 0, 1.0, 1.55, yf, M("doorWood", COL["wood"]), trim, knob=M("brass", hi=0.4, ao=0),
         panels=M("woodDark"))
    step(0, 1.5, yf, stone, d=0.45)
    canopy = C.box((0, yf - 0.28, 1.86), (1.55, 0.6, 0.1), roof, bevel=0.02, smooth=False)
    canopy.rotation_euler = (math.radians(-16), 0, 0)
    for s in (-1, 1):
        C.box((s * 0.66, yf - 0.36, 1.78), (0.07, 0.07, 0.14), trim, bevel=0.01)
    # windows with shutters + flower boxes
    for s in (-1, 1):
        x = s * 1.78
        window(x, 1.2, 0.95, 0.9, yf, trim, M("glass", hi=0.2, ao=0), shine=G("shine", C.rgb(0.9, 0.97, 1.0)))
        for k in (-1, 1):
            front(x + k * 0.68, 1.2, 0.3, 1.02, yf, 0.07, roofD, bevel=0.01)
        flowers(x, 0.62, 1.1, yf, rnd, M("woodDark"))
    # sign in the gable
    sign_plate(feat, 0, H + 0.62, 2.1, 0.58, yf, M("plate", hi=0.15, ao=0), M("woodDark"),
               bolts=M("brass", hi=0.4, ao=0))
    # a small round attic vent above the sign
    C.cylinder((0, yf - 0.05, H + 1.42), 0.18, 0.1, trim, rot=(math.pi / 2, 0, 0), verts=20)
    C.cylinder((0, yf - 0.09, H + 1.42), 0.12, 0.06, M("glassDark", hi=0.1, ao=0), rot=(math.pi / 2, 0, 0), verts=20)


# ============================================================================= 2. shop
@building("bld_shop")
def _shop(feat, W, D, variant=None):
    H = 2.4
    yf = -D / 2
    wall, trim = M("shopWall", C.rgb(0.95, 0.80, 0.66)), M("trim", hi=0.2)
    roofm = M("shopRoof", C.rgb(0.56, 0.50, 0.52), rim=0.1)
    brown = M("woodDark")
    slab(-W / 2 - 0.06, W / 2 + 0.06, -D / 2 - 0.06, D / 2 + 0.06, 0, 0.18, M("stoneDark"))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.16, H, wall, bevel=0.02)
    slab(-W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, H + 0.08, roofm, bevel=0.0)
    roof_seams(W, D, H + 0.08, M("shopRoofD", C.rgb(0.48, 0.42, 0.46)))
    parapet(W, D, H, 0.3, 0.22, M("shopTrim", C.rgb(0.72, 0.44, 0.34)))
    # stepped false front carrying the sign
    slab(-W / 2 * 0.72, W / 2 * 0.72, -D / 2, -D / 2 + 0.3, H, H + 0.95, wall, bevel=0.03)
    slab(-W / 2 * 0.72 - 0.06, W / 2 * 0.72 + 0.06, -D / 2 - 0.04, -D / 2 + 0.34, H + 0.92, H + 1.04,
         M("shopTrim", C.rgb(0.72, 0.44, 0.34)), bevel=0.02)
    # roof clutter: vents + skylight
    vent(-1.6, 1.8, H, M("gunmetal"), M("steel", hi=0.3))
    slab(0.6, 1.9, 0.6, 2.2, H, H + 0.25, M("steel"), bevel=0.03)
    slab(0.7, 1.8, 0.7, 2.1, H + 0.25, H + 0.3, M("glass", hi=0.2, ao=0), bevel=0.0)
    for k in range(3):
        slab(-2.2 + k * 0.5, -1.8 + k * 0.5, -1.4, -1.0, H, H + 0.4, M("crateWood", COL["wood"]), bevel=0.03)
    # display windows with goods
    glass = M("glass", hi=0.2, ao=0)
    goods = [M("goodA", C.rgb(0.90, 0.46, 0.52)), M("goodB", C.rgb(0.46, 0.66, 0.90)),
             M("goodC", C.rgb(0.60, 0.80, 0.46))]
    for s in (-1, 1):
        x = s * 1.72
        window(x, 1.02, 1.6, 1.15, yf, M("shopTrim", C.rgb(0.72, 0.44, 0.34)), glass, bars=False,
               sill=trim, shine=G("shine", C.rgb(0.9, 0.97, 1.0)))
        for k in range(3):
            C.sphere((x - 0.5 + k * 0.5, yf - 0.1, 0.62), (0.16, 0.08, 0.16), goods[k], seg=12, rings=6)
    door(feat, 0, 1.0, 1.6, yf, M("shopDoor", C.rgb(0.72, 0.44, 0.34)), trim,
         knob=M("brass", hi=0.4, ao=0), glass=glass)
    step(0, 1.4, yf, M("stone"), d=0.4)
    # striped awning (warm yellow / cream), sloping out from the wall with a scalloped edge
    yel, crm = M("awningY", C.rgb(0.96, 0.76, 0.28), hi=0.14), M("awningW", C.rgb(0.98, 0.95, 0.86), hi=0.14)
    n = 12
    aw_w = W - 0.3
    drop, out = 0.5, 0.95
    ang = math.atan2(drop, out)
    L = math.hypot(drop, out)
    for k in range(n):
        x = -aw_w / 2 + aw_w * (k + 0.5) / n
        m = yel if k % 2 == 0 else crm
        rot_box((x, yf - out / 2, 2.1 - drop / 2), (aw_w / n + 0.005, L, 0.06), m, (ang, 0, 0))
        C.cylinder((x, yf - out, 2.1 - drop - 0.02), aw_w / n / 2, 0.06, m, rot=(math.pi / 2, 0, 0), verts=16)
    front(0, 2.12, aw_w + 0.1, 0.12, yf, 0.1, brown, bevel=0.02)
    sign_plate(feat, 0, H + 0.48, 3.0, 0.62, yf, M("plate", hi=0.15, ao=0), brown, proud=0.08)


# ============================================================================= 3. arcade
@building("bld_arcade")
def _arcade(feat, W, D, variant=None):
    H = 2.5
    yf = -D / 2
    wall = M("arcadeWall", C.rgb(0.26, 0.22, 0.42), rim=0.3)
    wallD = M("arcadeWallD", C.rgb(0.18, 0.16, 0.30))
    red = M("arcadeRed", C.rgb(0.90, 0.24, 0.30), hi=0.2)
    roofm = M("arcadeRoof", C.rgb(0.36, 0.34, 0.46), rim=0.1)
    pink, cyanN = G("neonPink", C.rgb(1.0, 0.45, 0.85)), G("neonBlue", C.rgb(0.45, 0.75, 1.0))
    bulb = G("bulb", C.rgb(1.0, 0.95, 0.82))
    slab(-W / 2 - 0.06, W / 2 + 0.06, -D / 2 - 0.06, D / 2 + 0.06, 0, 0.16, wallD)
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.14, H, wall, bevel=0.02)
    slab(-W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, H + 0.08, roofm, bevel=0.0)
    roof_seams(W, D, H + 0.08, M("arcadeRoofD", C.rgb(0.30, 0.28, 0.40)))
    parapet(W, D, H, 0.3, 0.22, red)
    # marquee block rising above the front
    slab(-2.1, 2.1, -D / 2 - 0.15, -D / 2 + 0.45, H, H + 1.25, wall, bevel=0.05)
    front(0, H + 1.28, 4.3, 0.12, yf - 0.15, 0.1, red, bevel=0.02)
    sign_plate(feat, 0, H + 0.62, 3.3, 0.72, yf - 0.15, M("plate", C.rgb(0.98, 0.96, 0.92), hi=0.15, ao=0),
               red, proud=0.08)
    for k in range(14):      # chase lights around the plate
        x = -1.75 + 3.5 * k / 13
        for z in (H + 0.14, H + 1.1):
            C.sphere((x, yf - 0.32, z), 0.055, bulb, seg=8, rings=5)
    for z in (H + 0.38, H + 0.62, H + 0.86):
        for s in (-1, 1):
            C.sphere((s * 1.82, yf - 0.32, z), 0.055, bulb, seg=8, rings=5)
    # neon stripes + stars on the facade
    front(0, H - 0.25, W - 0.2, 0.07, yf, 0.06, pink, bevel=0.0)
    front(0, 0.4, W - 0.2, 0.07, yf, 0.06, cyanN, bevel=0.0)
    for s in (-1, 1):
        st = star_mesh("star", 0.34, 0.15, 0.04, G("neonYellow", C.rgb(1.0, 0.72, 0.40)))
        st.location = (s * 2.3, yf - 0.06, H + 0.55)
        st.rotation_euler = (0, s * 0.25, 0)
    # porthole screens (game screens)
    for s in (-1, 1):
        for k, x in enumerate((1.25, 2.15)):
            cx = s * x
            C.cylinder((cx, yf - 0.03, 1.35), 0.4, 0.1, red, rot=(math.pi / 2, 0, 0), verts=28)
            C.cylinder((cx, yf - 0.07, 1.35), 0.31, 0.06, G("screen" + str(k), [C.rgb(0.45, 0.85, 1.0), C.rgb(1.0, 0.55, 0.85)][k]),
                       rot=(math.pi / 2, 0, 0), verts=28)
            C.box((cx - 0.08, yf - 0.1, 1.38), (0.12, 0.02, 0.12), wallD, bevel=0.0)
            C.box((cx + 0.1, yf - 0.1, 1.3), (0.08, 0.02, 0.08), wallD, bevel=0.0)
    door(feat, 0, 1.3, 1.65, yf, M("arcadeDoor", C.rgb(0.20, 0.18, 0.28)), red,
         glass=G("doorGlow", C.rgb(0.62, 0.52, 0.95)), double=True)
    # red carpet step
    slab(-0.8, 0.8, yf - 0.55, yf, 0, 0.06, red, bevel=0.01)
    # giant joystick on the roof
    slab(-0.9, 0.9, 1.0, 2.4, H, H + 0.45, M("gunmetal"), bevel=0.06)
    C.cylinder((0, 1.7, H + 0.95), 0.1, 1.0, M("steel", hi=0.3), verts=12)
    C.sphere((0, 1.7, H + 1.55), 0.42, red, seg=24, rings=12)
    C.sphere((-0.12, 1.55, H + 1.72), (0.1, 0.06, 0.08), G("shine", C.rgb(1.0, 0.9, 0.9)), seg=10, rings=6)
    for k, (x, m) in enumerate(((0.55, cyanN), (0.3, pink))):
        C.cylinder((x, 1.2, H + 0.5), 0.13, 0.1, m, verts=16)


# ============================================================================= 4. HQ
@building("bld_hq")
def _hq(feat, W, D, variant=None):
    H = 2.6
    yf = -D / 2
    blue = M("hqBlue", C.rgb(0.32, 0.52, 0.88), hi=0.14)
    blueD = M("hqBlueD", C.rgb(0.20, 0.34, 0.66))
    trim = M("trim", hi=0.2)
    glass = M("hqGlass", C.rgb(0.62, 0.84, 0.98), hi=0.25, ao=0)
    gold = M("hqGold", C.rgb(1.0, 0.82, 0.26), hi=0.35, ao=0)
    roofm = M("hqRoof", C.rgb(0.62, 0.66, 0.74), rim=0.1)
    slab(-W / 2 - 0.08, W / 2 + 0.08, -D / 2 - 0.08, D / 2 + 0.08, 0, 0.22, M("stone"))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.2, H, blue, bevel=0.02)
    slab(-W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, H + 0.08, roofm, bevel=0.0)
    roof_seams(W, D, H + 0.08, M("hqRoofD", C.rgb(0.52, 0.56, 0.66)))
    parapet(W, D, H, 0.28, 0.22, trim)
    front(0, 0.95, W, 0.1, yf, 0.06, trim, bevel=0.0)
    # window bands
    for s in (-1, 1):
        for k in range(2):
            x = s * (1.3 + k * 0.95)
            window(x, 1.7, 0.72, 0.9, yf, trim, glass, bars=False, shine=G("shine", C.rgb(0.9, 0.97, 1.0)))
            window(x, 0.58, 0.72, 0.5, yf, trim, glass, bars=False)
    # central entrance bay rising above the parapet, with the emblem
    slab(-1.05, 1.05, -D / 2 - 0.25, -D / 2 + 0.6, 0.2, H + 1.55, blueD, bevel=0.05)
    slab(-1.12, 1.12, -D / 2 - 0.3, -D / 2 + 0.66, H + 1.5, H + 1.65, trim, bevel=0.03)
    C.cylinder((0, yf - 0.3, H + 0.9), 0.5, 0.12, trim, rot=(math.pi / 2, 0, 0), verts=32)
    C.cylinder((0, yf - 0.36, H + 0.9), 0.42, 0.06, M("hqBadge", C.rgb(0.94, 0.30, 0.32), hi=0.2, ao=0),
               rot=(math.pi / 2, 0, 0), verts=32)
    st = star_mesh("emblem", 0.34, 0.15, 0.04, gold)
    st.location = (0, yf - 0.42, H + 0.88)
    door(feat, 0, 1.3, 1.6, yf - 0.25, glass, trim, double=True)
    front(0, 1.6 + 0.3, 1.9, 0.12, yf - 0.25, 0.3, trim, bevel=0.02)
    step(0, 2.2, yf - 0.25, M("stone"), d=0.5, hgt=0.12)
    sign_plate(feat, 0, H + 0.1, 1.75, 0.5, yf - 0.25, M("plate", C.rgb(0.98, 0.98, 0.96), hi=0.15, ao=0),
               trim, proud=0.06)
    # rooftop: comms tower block + antenna + dish
    slab(-1.3, 1.3, 0.6, 2.9, H, H + 1.1, blue, bevel=0.04)
    parapet_like = slab(-1.36, 1.36, 0.54, 2.96, H + 1.05, H + 1.18, trim, bevel=0.03)
    for k in range(3):
        front(-0.8 + k * 0.8, H + 0.6, 0.5, 0.4, 0.6, 0.06, glass, bevel=0.0)
    C.cylinder((0.7, 2.2, H + 1.9), 0.05, 1.5, M("steel", hi=0.3), verts=10)
    C.sphere((0.7, 2.2, H + 2.7), 0.1, G("beacon", C.rgb(1.0, 0.4, 0.4)), seg=10, rings=6)
    dish = C.sphere((-0.55, 1.8, H + 1.55), (0.45, 0.45, 0.16), M("steel", hi=0.3), seg=20, rings=10)
    dish.rotation_euler = (math.radians(-35), math.radians(-20), 0)
    C.cylinder((-0.55, 1.8, H + 1.3), 0.06, 0.3, M("gunmetal"), verts=10)
    # flags either side of the bay
    for s in (-1, 1):
        C.cylinder((s * 1.6, yf - 0.2, H + 0.75), 0.03, 1.5, M("steel", hi=0.3), verts=8)
        rot_box((s * 1.6 + s * 0.28, yf - 0.2, H + 1.28), (0.5, 0.03, 0.34), gold if s < 0 else M("hqRedFlag", C.rgb(0.94, 0.30, 0.32)),
                (0, 0, 0))


# ============================================================================= 5. warehouse
@building("bld_warehouse")
def _warehouse(feat, W, D, variant=None):
    H, r = 2.5, 1.1
    yf = -D / 2
    teal = M("teal", C.rgb(0.30, 0.56, 0.58), hi=0.12)
    tealD = M("tealD", C.rgb(0.22, 0.42, 0.46))
    grey = M("whRoof", C.rgb(0.58, 0.60, 0.66), hi=0.12, rim=0.15)
    greyD = M("whRoofD", C.rgb(0.42, 0.44, 0.52))
    slab(-W / 2 - 0.06, W / 2 + 0.06, -D / 2 - 0.06, D / 2 + 0.06, 0, 0.2, M("concrete"))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.18, H, teal, bevel=0.02)
    pediment(W, H - 0.01, r, yf + 0.005, teal, depth=0.25)
    ovf = 0.2
    a = gable_y(W, D, H, r, grey, ov=0.25, ovf=ovf)
    # corrugation on the roof: ribs running down the slopes
    L = (W / 2 + 0.25) / math.cos(a)
    for side in (-1, 1):
        d = Vector((side * math.cos(a), 0, -math.sin(a)))
        nrm = Vector((side * math.sin(a), 0, math.cos(a)))
        n = 22
        for k in range(n + 1):
            y = -D / 2 - ovf + 0.1 + (D + 2 * ovf - 0.2) * k / n
            c = Vector((0, y, H + r)) + d * (L / 2) + nrm * 0.025
            rot_box(c, (L, 0.06, 0.05), greyD, (0, side * a, 0))
    C.cylinder((0, 0, H + r + 0.04), 0.1, D + 2 * ovf, greyD, rot=(math.pi / 2, 0, 0), verts=10)
    # skylights
    for yy in (-1.2, 1.4):
        for side in (-1, 1):
            c = Vector((side * 1.3 * math.cos(a), yy, H + r - 1.3 * math.sin(a))) + Vector((side * math.sin(a), 0, math.cos(a))) * 0.06
            rot_box(c, (0.9, 1.0, 0.04), M("glass", hi=0.2, ao=0), (0, side * a, 0))
    # wall corrugation + corner posts + base band
    ribs_x(-W / 2 + 0.2, W / 2 - 0.2, yf, 0.3, H - 0.05, tealD, pitch=0.26)
    for s in (-1, 1):
        front(s * (W / 2 - 0.08), H / 2 + 0.1, 0.2, H - 0.1, yf, 0.1, greyD, bevel=0.01)
    front(0, 0.26, W, 0.14, yf, 0.1, greyD, bevel=0.01)
    front(0, H - 0.02, W, 0.12, yf, 0.1, greyD, bevel=0.01)
    # roll-up door
    dw, dh = 2.4, 1.9
    frame = M("gunmetal")
    slat = M("rollDoor", C.rgb(0.72, 0.74, 0.78), hi=0.15)
    front(0, dh / 2 + 0.08, dw + 0.3, dh + 0.2, yf, 0.14, frame, bevel=0.02)
    front(0, dh / 2 + 0.02, dw, dh, yf, 0.16, slat, bevel=0.0)
    for k in range(9):
        front(0, 0.12 + k * dh / 9, dw, 0.035, yf, 0.18, M("rollLine", C.rgb(0.50, 0.52, 0.58)), bevel=0.0)
    front(0, dh + 0.2, dw + 0.4, 0.26, yf, 0.3, frame, bevel=0.03)          # roller housing
    front(0, 0.12, 0.4, 0.07, yf, 0.2, M("iron"), bevel=0.0)                 # handle
    feat.set_door(0, yf, dw, dh)
    # hazard kick plates either side of the door (muted amber / ink)
    amb = M("amber", C.rgb(0.86, 0.66, 0.30))
    for s in (-1, 1):
        front(s * (dw / 2 + 0.28), 0.5, 0.18, 0.8, yf, 0.2, amb, bevel=0.02)
    # small windows high up
    for s in (-1, 1):
        window(s * 2.15, 1.75, 0.7, 0.5, yf, greyD, M("glassDark", hi=0.15, ao=0), bars=True)
    # sodium lamp over the door + sign in the gable
    C.box((0, yf - 0.2, H + 0.95), (0.3, 0.3, 0.1), frame, bevel=0.02)
    C.sphere((0, yf - 0.24, H + 0.86), (0.12, 0.12, 0.07), G("sodium", C.rgb(1.0, 0.70, 0.36)), seg=12, rings=6)
    sign_plate(feat, 0, H + 0.35, 2.6, 0.55, yf, M("plate", hi=0.15, ao=0), greyD, bolts=M("steel", ao=0))
    # a couple of barrels/pallets by the wall
    for x in (-2.35, -1.85):
        C.cylinder((x, yf - 0.4, 0.4), 0.24, 0.8, M("barrel", C.rgb(0.40, 0.52, 0.66)), verts=18)
        C.torus((x, yf - 0.4, 0.62), 0.25, 0.02, M("iron"), minor_seg=6)
    slab(1.75, 2.55, yf - 0.8, yf - 0.1, 0, 0.14, M("wood"), bevel=0.02)
    slab(1.85, 2.45, yf - 0.72, yf - 0.18, 0.14, 0.62, M("crateW", C.rgb(0.70, 0.52, 0.34)), bevel=0.03)


# ============================================================================= 6. lab
@building("bld_lab")
def _lab(feat, W, D, variant=None):
    H = 2.5
    yf = -D / 2
    white = M("labWhite", C.rgb(0.93, 0.95, 0.97), hi=0.1)
    grey = M("labGrey", C.rgb(0.72, 0.76, 0.82))
    cyan = M("labCyan", C.rgb(0.32, 0.78, 0.86), hi=0.2)
    glass = M("labGlass", C.rgb(0.62, 0.86, 0.95), hi=0.25, ao=0)
    slab(-W / 2 - 0.06, W / 2 + 0.06, -D / 2 - 0.06, D / 2 + 0.06, 0, 0.18, grey)
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.16, H, white, bevel=0.06, seg=3)
    slab(-W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, H + 0.08, M("labRoof", C.rgb(0.80, 0.83, 0.88), rim=0.1), bevel=0.0)
    roof_seams(W, D, H + 0.08, M("labRoofD", C.rgb(0.72, 0.75, 0.82)), pitch=1.4)
    parapet(W, D, H, 0.22, 0.2, white, bevel=0.06)
    front(0, H - 0.3, W + 0.02, 0.16, yf, 0.06, cyan, bevel=0.01)
    front(0, 0.3, W + 0.02, 0.1, yf, 0.06, cyan, bevel=0.0)
    # long window strips
    for s in (-1, 1):
        x = s * 1.85
        front(x, 1.3, 1.7, 0.95, yf, 0.08, grey, bevel=0.03)
        front(x, 1.3, 1.56, 0.82, yf, 0.1, glass, bevel=0.02)
        for k in (-1, 1):
            front(x + k * 0.39, 1.3, 0.05, 0.82, yf, 0.12, grey, bevel=0.0)
        rot_box((x - 0.4, yf - 0.11, 1.35), (0.12, 0.01, 0.6), G("shine", C.rgb(0.9, 0.97, 1.0)), (0, math.radians(-30), 0))
    # entrance bay with sliding glass doors + canopy
    slab(-1.0, 1.0, -D / 2 - 0.3, -D / 2 + 0.3, 0.16, H + 0.95, white, bevel=0.06, seg=3)
    door(feat, 0, 1.3, 1.6, yf - 0.3, glass, cyan, double=True)
    slab(-1.15, 1.15, -D / 2 - 0.8, -D / 2 - 0.1, 1.82, 1.94, white, bevel=0.03)
    front(0, 1.88, 2.3, 0.06, yf - 0.8, 0.02, G("labStrip", C.rgb(0.55, 0.95, 1.0)), bevel=0.0)
    step(0, 1.8, yf - 0.3, grey, d=0.5, hgt=0.08)
    sign_plate(feat, 0, H + 0.45, 1.7, 0.5, yf - 0.3, M("plate", C.rgb(0.98, 0.99, 1.0), hi=0.15, ao=0), cyan, proud=0.06)
    # roof: glass dome, dish, vents, tanks
    C.cylinder((-1.0, 1.4, H + 0.15), 1.05, 0.3, grey, verts=32)
    C.sphere((-1.0, 1.4, H + 0.3), (0.95, 0.95, 0.85), glass, seg=32, rings=16)
    for k in range(4):
        rb = C.torus((-1.0, 1.4, H + 0.3), 0.95, 0.03, grey, rot=(math.pi / 2, 0, math.pi * k / 4), minor_seg=6)
    C.cylinder((1.4, 2.2, H + 0.35), 0.08, 0.6, M("steel", hi=0.3), verts=10)
    dish = C.sphere((1.4, 2.2, H + 0.75), (0.55, 0.55, 0.18), white, seg=24, rings=10)
    dish.rotation_euler = (math.radians(-40), math.radians(25), 0)
    C.cylinder((1.4, 2.0, H + 0.9), 0.05, 0.3, cyan, verts=8)
    for x in (1.0, 1.7):
        vent(x, 0.2, H, grey, white, r=0.16, h=0.35)
    C.cylinder((-1.2, -1.6, H + 0.4), 0.35, 0.8, M("labTank", C.rgb(0.84, 0.88, 0.92)), verts=20)
    C.cylinder((-0.35, -1.6, H + 0.4), 0.35, 0.8, M("labTank", C.rgb(0.84, 0.88, 0.92)), verts=20)
    C.torus((-1.2, -1.6, H + 0.55), 0.36, 0.03, cyan, minor_seg=6)
    C.torus((-0.35, -1.6, H + 0.55), 0.36, 0.03, cyan, minor_seg=6)


# ============================================================================= 7. pump house
@building("bld_pumphouse")
def _pump(feat, W, D, variant=None):
    rnd = random.Random(21)
    H, r = 2.95, 1.5
    yf = -D / 2
    brick, brickD = M("brick", hi=0.1), M("brickDark")
    slate = M("slate", C.rgb(0.40, 0.46, 0.50), hi=0.12, rim=0.15)
    slateD = M("slateD", C.rgb(0.30, 0.34, 0.40))
    moss, mossD = M("moss", ao=0.2), M("mossDark", ao=0.2)
    pipe = M("pipe", C.rgb(0.40, 0.58, 0.50), hi=0.25)
    pipeD = M("pipeD", C.rgb(0.28, 0.40, 0.36))
    slab(-W / 2 - 0.1, W / 2 + 0.1, -D / 2 - 0.1, D / 2 + 0.1, 0, 0.3, M("stoneDark"))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.28, H, brick, bevel=0.02)
    gable_x(W, D, H, r, slate, ov=0.25, ovs=0.25)
    # slate rows parallel to the eave on the front slope
    a = math.atan2(r, D / 2)
    Ls = (D / 2 + 0.25) / math.cos(a)
    for k in range(1, 8):
        s = Ls * k / 8.3
        c = Vector((0, -s * math.cos(a), H + r - s * math.sin(a))) + Vector((0, -math.sin(a), math.cos(a))) * 0.03
        rot_box(c, (W + 0.5, 0.07, 0.035), slateD, (-a, 0, 0))
    C.cylinder((0, 0, H + r + 0.05), 0.12, W + 0.5, slateD, rot=(0, math.pi / 2, 0), verts=12)
    # bricks: proud darker bricks scattered over the front, stone quoins at the corners
    for _ in range(46):
        x = rnd.uniform(-W / 2 + 0.3, W / 2 - 0.3); z = rnd.uniform(0.45, H - 0.45)
        if abs(x) < 1.15 and z < 2.75:
            continue
        if abs(abs(x) - 1.85) < 0.6 and 0.9 < z < 2.1:
            continue
        front(round(x / 0.36) * 0.36, round(z / 0.18) * 0.18, 0.32, 0.14, yf, 0.04, brickD, bevel=0.0)
    for s in (-1, 1):
        for k in range(6):
            front(s * (W / 2 - 0.16), 0.5 + k * 0.4, 0.34 if k % 2 else 0.26, 0.3, yf, 0.07, M("stone"), bevel=0.02)
    # arched iron door
    dw, dh = 1.1, 1.5
    door(feat, 0, dw, dh, yf, M("pumpDoor", C.rgb(0.34, 0.42, 0.44), hi=0.15), M("stone"))
    C.cylinder((0, yf - 0.02, dh), dw / 2 + 0.1, 0.1, M("stone"), rot=(math.pi / 2, 0, 0), verts=24)
    C.cylinder((0, yf - 0.06, dh), dw / 2, 0.1, M("pumpDoor", C.rgb(0.34, 0.42, 0.44), hi=0.15), rot=(math.pi / 2, 0, 0), verts=24)
    for z in (0.3, 0.8, 1.3):
        front(0, z, dw, 0.06, yf, 0.14, M("iron"), bevel=0.0)
    step(0, 1.5, yf, M("stone"), d=0.45, hgt=0.3)
    # round porthole windows
    for s in (-1, 1):
        C.cylinder((s * 1.85, yf - 0.04, 1.55), 0.42, 0.1, M("stone"), rot=(math.pi / 2, 0, 0), verts=24)
        C.cylinder((s * 1.85, yf - 0.08, 1.55), 0.32, 0.06, M("pumpGlass", C.rgb(0.52, 0.72, 0.62), hi=0.2, ao=0),
                   rot=(math.pi / 2, 0, 0), verts=24)
        front(s * 1.85, 1.55, 0.05, 0.64, yf - 0.02, 0.1, M("iron"), bevel=0.0)
        front(s * 1.85, 1.55, 0.64, 0.05, yf - 0.02, 0.1, M("iron"), bevel=0.0)
    sign_plate(feat, 0, 2.43, 2.0, 0.44, yf, M("plate", C.rgb(0.93, 0.92, 0.84), hi=0.15, ao=0), M("iron"),
               bolts=M("steel", ao=0), proud=0.1)
    # big pipes: out of the wall, bend down into the ground
    for s in (-1, 1):
        x = s * (W / 2 - 0.75)
        tube("pipe", [(x, yf + 0.1, 0.95), (x, yf - 0.55, 0.95), (x, yf - 0.75, 0.75), (x, yf - 0.75, 0.0)], 0.2, pipe)
        C.cylinder((x, yf - 0.3, 0.95), 0.25, 0.1, pipeD, rot=(math.pi / 2, 0, 0), verts=16)
        C.cylinder((x, yf - 0.75, 0.45), 0.25, 0.1, pipeD, verts=16)
        C.cylinder((x, yf - 0.75, 0.05), 0.3, 0.1, pipeD, verts=16)
    # side pipe across the roof + valve wheel beside the door
    C.torus((0.85, yf - 0.18, 1.05), 0.2, 0.035, M("valve", C.rgb(0.80, 0.40, 0.34), hi=0.2), rot=(math.pi / 2, 0, 0), minor_seg=8)
    C.cylinder((0.85, yf - 0.1, 1.05), 0.06, 0.2, M("iron"), rot=(math.pi / 2, 0, 0), verts=10)
    # exhaust stack
    C.cylinder((-1.5, 1.2, H + r), 0.22, 1.9, M("iron"), verts=16)
    C.cylinder((-1.5, 1.2, H + r + 0.95), 0.28, 0.14, M("gunmetal"), verts=16)
    # moss patches: along the base, on the roof and over the eave
    for _ in range(18):
        x = rnd.uniform(-W / 2, W / 2)
        C.sphere((x, yf - 0.02, 0.33 + rnd.uniform(0, 0.12)), (rnd.uniform(0.18, 0.4), 0.08, rnd.uniform(0.08, 0.16)),
                 moss if rnd.random() < 0.6 else mossD, seg=12, rings=6)
    for _ in range(9):
        s = rnd.uniform(0.3, Ls - 0.2)
        x = rnd.uniform(-W / 2, W / 2)
        c = Vector((x, -s * math.cos(a), H + r - s * math.sin(a) + 0.07))
        o = C.sphere(c, (rnd.uniform(0.25, 0.5), rnd.uniform(0.15, 0.3), 0.06), moss if rnd.random() < 0.5 else mossD, seg=12, rings=6)
        o.rotation_euler = (-a, 0, 0)
    for x in (-2.4, -1.1, 1.6):
        C.sphere((x, yf - 0.28, H - 0.18), (0.3, 0.05, 0.14), mossD, seg=12, rings=6)


# ============================================================================= 8. rooftop access hut
@building("bld_rooftop")
def _rooftop(feat, W, D, variant=None):
    H = 2.3
    yf = -D / 2
    conc = M("concrete", hi=0.1)
    concD = M("concreteD", C.rgb(0.50, 0.51, 0.56))
    gm, steel = M("gunmetal"), M("steel", hi=0.3)
    slab(-W / 2 - 0.05, W / 2 + 0.05, -D / 2 - 0.05, D / 2 + 0.05, 0, 0.14, concD)
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.12, H, conc, bevel=0.03)
    slab(-W / 2 - 0.18, W / 2 + 0.18, -D / 2 - 0.18, D / 2 + 0.18, H, H + 0.2, concD, bevel=0.03)
    slab(-W / 2, W / 2, -D / 2, D / 2, H + 0.2, H + 0.24, M("tar", C.rgb(0.40, 0.40, 0.46), rim=0.1), bevel=0.0)
    roof_seams(W, D, H + 0.24, M("tarD", C.rgb(0.33, 0.33, 0.39)), inset=0.2)
    # panel seams on the front
    for x in (-1.9, -0.95, 0.95, 1.9):
        front(x, H / 2, 0.04, H - 0.3, yf, 0.03, concD, bevel=0.0)
    # metal door with a small window, green exit lamp over it
    door(feat, 0, 1.05, 1.62, yf, M("hutDoor", C.rgb(0.46, 0.52, 0.60), hi=0.15), gm,
         knob=steel)
    front(0, 1.25, 0.4, 0.3, yf - 0.02, 0.12, M("glassDark", hi=0.15, ao=0), bevel=0.0)
    front(0, 0.95, 0.8, 0.05, yf - 0.02, 0.13, gm, bevel=0.0)
    step(0, 1.4, yf, concD, d=0.4, hgt=0.12)
    C.box((0, yf - 0.1, 1.83), (0.45, 0.14, 0.14), gm, bevel=0.02)
    C.box((0, yf - 0.17, 1.83), (0.36, 0.02, 0.08), G("exitGreen", C.rgb(0.40, 0.95, 0.55)), bevel=0.0)
    sign_plate(feat, 0, H - 0.02, 1.8, 0.4, yf, M("plate", hi=0.15, ao=0), gm, proud=0.2)
    # louvred vents on the front
    for s in (-1, 1):
        x = s * 1.9
        front(x, 1.5, 0.9, 0.7, yf, 0.08, gm, bevel=0.02)
        for k in range(5):
            rot_box((x, yf - 0.1, 1.24 + k * 0.13), (0.8, 0.05, 0.08), steel, (math.radians(35), 0, 0))
        front(x, 0.6, 0.9, 0.5, yf, 0.06, concD, bevel=0.02)
    # roof: big AC unit + mushroom vents + pipes
    z = H + 0.24
    slab(-2.2, 0.2, 0.4, 2.8, z, z + 0.9, M("acBody", C.rgb(0.78, 0.80, 0.84), hi=0.12), bevel=0.06)
    for cx in (-1.55, -0.45):
        C.cylinder((cx, 1.6, z + 0.92), 0.46, 0.06, gm, verts=28)
        C.cylinder((cx, 1.6, z + 0.95), 0.4, 0.04, M("iron"), verts=28)
        for k in range(3):
            b = C.box((cx, 1.6, z + 0.99), (0.76, 0.06, 0.02), steel, bevel=0.0)
            b.rotation_euler = (0, 0, math.pi * k / 3)
        C.cylinder((cx, 1.6, z + 1.0), 0.08, 0.04, steel, verts=12)
    for k in range(6):
        front(-1.0, z + 0.2 + k * 0.1, 2.2, 0.04, 0.4, 0.03, concD, bevel=0.0)
    vent(1.2, 2.0, z, gm, steel, r=0.22, h=0.4)
    vent(1.9, 0.9, z, gm, steel, r=0.18, h=0.3)
    vent(1.5, -1.6, z, gm, steel, r=0.2, h=0.35)
    tube("duct", [(0.2, 1.0, z + 0.35), (0.9, 1.0, z + 0.35), (0.9, -0.8, z + 0.35), (0.9, -0.8, z + 0.05)], 0.12, steel)
    slab(-2.4, -1.2, -2.8, -1.8, z, z + 0.08, gm, bevel=0.01)     # hatch
    C.box((-1.8, -2.3, z + 0.13), (0.4, 0.06, 0.06), steel, bevel=0.01)


# ============================================================================= 9. villain lair
@building("bld_lair")
def _lair(feat, W, D, variant=None):
    H = 2.4
    yf = -D / 2
    stone = M("lairStone", C.rgb(0.42, 0.30, 0.56), hi=0.12, rim=0.3)
    stoneD = M("lairStoneD", C.rgb(0.30, 0.21, 0.42))
    mag = M("lairRoof", C.rgb(0.82, 0.30, 0.66), hi=0.16)
    magD = M("lairRoofD", C.rgb(0.60, 0.20, 0.50))
    glow = G("lairGlow", C.rgb(1.0, 0.52, 0.90))
    glowY = G("lairEye", C.rgb(0.95, 1.0, 0.70))
    slab(-W / 2 - 0.08, W / 2 + 0.08, -D / 2 - 0.08, D / 2 + 0.08, 0, 0.22, stoneD)
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.2, H, stone, bevel=0.03)
    slab(-W / 2 + 0.1, W / 2 - 0.1, -D / 2 + 0.1, D / 2 - 0.1, H, H + 0.08, stoneD, bevel=0.0)
    crenels(-W / 2, W / 2, -D / 2, D / 2, H, stone, size=0.42, gap=0.38, h=0.38)
    # front turrets with pointy (slightly bent) caps
    for s in (-1, 1):
        x = s * (W / 2 - 0.35)
        C.cylinder((x, yf + 0.35, (H + 1.0) / 2), 0.55, H + 1.0, stone, verts=24)
        C.cylinder((x, yf + 0.35, H + 1.05), 0.66, 0.16, stoneD, verts=24)
        c = C.cone((x, yf + 0.35, H + 1.7), 0.72, 0.04, 1.3, mag, verts=24)
        c.rotation_euler = (0, s * -0.12, 0)
        C.sphere((x - s * 0.1, yf + 0.35, H + 2.38), 0.09, glow, seg=10, rings=6)
        front(x, H + 0.3, 0.22, 0.4, yf + 0.35 - 0.5, 0.08, glow, bevel=0.02)
    # central tower at the back with a crooked spire and a big friendly "eye" window
    tx, ty = 0.0, 1.3
    C.cylinder((tx, ty, 2.9), 1.35, 5.8, stone, verts=32)
    for z in (2.6, 4.2):
        C.torus((tx, ty, z), 1.36, 0.07, stoneD, minor_seg=6)
    C.cylinder((tx, ty, 5.9), 1.55, 0.3, stoneD, verts=32)
    sp = C.cone((tx, ty, 6.95), 1.65, 0.05, 2.2, mag, verts=32)
    sp.rotation_euler = (0.06, -0.1, 0)
    C.torus((tx, ty, 6.1), 1.5, 0.06, magD, minor_seg=6)
    C.sphere((tx - 0.2, ty - 0.05, 8.05), 0.16, glow, seg=12, rings=6)
    ey = ty - 1.33
    C.cylinder((tx, ey, 4.95), 0.6, 0.12, stoneD, rot=(math.pi / 2, 0, 0), verts=28)
    C.sphere((tx, ey - 0.06, 4.95), (0.5, 0.06, 0.36), glowY, seg=24, rings=10)
    C.sphere((tx, ey - 0.12, 4.93), (0.2, 0.04, 0.24), M("lairPupil", C.rgb(0.28, 0.12, 0.34), ao=0), seg=16, rings=8)
    C.sphere((tx + 0.06, ey - 0.16, 5.0), 0.05, G("white", C.rgb(1, 1, 1)), seg=8, rings=4)
    for a_deg in (-50, 50):
        a = math.radians(a_deg)
        wx, wy = tx + 1.34 * math.sin(a), ty - 1.34 * math.cos(a)
        w = C.box((wx, wy, 3.4), (0.28, 0.06, 0.5), glow, bevel=0.03)
        w.rotation_euler = (0, 0, a)
    # arched door, glowing trim
    dw, dh = 1.1, 1.65
    door(feat, 0, dw, dh, yf, M("lairDoor", C.rgb(0.30, 0.18, 0.36)), stoneD)
    C.cylinder((0, yf - 0.02, dh), dw / 2 + 0.1, 0.1, stoneD, rot=(math.pi / 2, 0, 0), verts=24)
    C.cylinder((0, yf - 0.06, dh), dw / 2, 0.1, M("lairDoor", C.rgb(0.30, 0.18, 0.36)), rot=(math.pi / 2, 0, 0), verts=24)
    C.torus((0, yf - 0.1, dh), dw / 2 + 0.05, 0.03, glow, rot=(math.pi / 2, 0, 0), minor_seg=6)
    front(0, 0.9, 0.05, 1.6, yf - 0.02, 0.13, stoneD, bevel=0.0)
    step(0, 1.6, yf, stoneD, d=0.45, hgt=0.14)
    # glowing arched windows
    for s in (-1, 1):
        for x in (1.25, 2.0):
            cx = s * x
            front(cx, 1.1, 0.42, 0.7, yf, 0.08, stoneD, bevel=0.02)
            front(cx, 1.1, 0.3, 0.58, yf, 0.1, glow, bevel=0.0)
            C.cylinder((cx, yf - 0.08, 1.39), 0.15, 0.06, glow, rot=(math.pi / 2, 0, 0), verts=16)
    sign_plate(feat, 0, 2.15, 2.1, 0.5, yf, M("plate", C.rgb(0.95, 0.90, 0.97), hi=0.15, ao=0), magD, proud=0.1)
    # little bat-wing shapes flanking the sign
    for s in (-1, 1):
        vs = [(s * 1.2, yf - 0.1, 2.3), (s * 1.75, yf - 0.1, 2.5), (s * 1.62, yf - 0.1, 2.2),
              (s * 1.48, yf - 0.1, 2.28), (s * 1.35, yf - 0.1, 2.05)]
        mesh("wing", vs, [(0, 1, 2, 3, 4)], magD, solid=0.06)


# ============================================================================= 10. fortress
@building("bld_fortress", footprint_pt=(400, 220))
def _fortress(feat, W, D, variant=None):
    rnd = random.Random(3)
    Hw = 3.0
    yf = -D / 2
    plum = M("plum", C.rgb(0.50, 0.36, 0.52), hi=0.12, rim=0.3)
    plumD = M("plumD", C.rgb(0.36, 0.25, 0.40))
    plumL = M("plumL", C.rgb(0.60, 0.46, 0.62))
    mag = M("magenta", C.rgb(0.86, 0.28, 0.66), hi=0.16)
    magD = M("magentaD", C.rgb(0.62, 0.18, 0.48))
    t = 0.8
    # courtyard floor
    slab(-W / 2, W / 2, -D / 2, D / 2, 0, 0.1, plumD, bevel=0.0)
    slab(-W / 2 + t, W / 2 - t, -D / 2 + t, D / 2 - t, 0.1, 0.14, M("flag", C.rgb(0.56, 0.50, 0.58)), bevel=0.0)
    # curtain walls
    slab(-W / 2, W / 2, -D / 2, -D / 2 + t, 0, Hw, plum)
    slab(-W / 2, W / 2, D / 2 - t, D / 2, 0, Hw, plum)
    slab(-W / 2, -W / 2 + t, -D / 2, D / 2, 0, Hw, plum)
    slab(W / 2 - t, W / 2, -D / 2, D / 2, 0, Hw, plum)
    crenels(-W / 2, W / 2, -D / 2, D / 2, Hw, plumL, size=0.45, gap=0.4, h=0.4)
    front(0, 0.25, W, 0.5, yf, 0.1, plumD, bevel=0.02)
    # stone blocks on the front wall
    for _ in range(40):
        x = rnd.uniform(-W / 2 + 0.4, W / 2 - 0.4); z = rnd.uniform(0.7, Hw - 0.3)
        if abs(x) < 1.9:
            continue
        if any(abs(x - bx) < 0.75 for bx in (-3.3, 3.3)) or abs(x) > W / 2 - 2.0:
            continue
        front(round(x / 0.5) * 0.5, round(z / 0.3) * 0.3, 0.44, 0.24, yf, 0.05, plumD, bevel=0.0)
    # keep at the back
    kx0, kx1, ky0, ky1, Hk = -2.8, 2.8, 0.3, D / 2 - 0.2, 5.6
    slab(kx0, kx1, ky0, ky1, 0, Hk, plumL, bevel=0.04)
    slab(kx0 - 0.1, kx1 + 0.1, ky0 - 0.1, ky1 + 0.1, Hk, Hk + 0.15, plumD, bevel=0.02)
    crenels(kx0 - 0.1, kx1 + 0.1, ky0 - 0.1, ky1 + 0.1, Hk + 0.15, plumL, size=0.45, gap=0.4, h=0.42)
    slab(kx0 + 0.4, kx1 - 0.4, ky0 + 0.4, ky1 - 0.4, Hk + 0.1, Hk + 0.2, plumD, bevel=0.0)
    for x in (-1.8, 0, 1.8):
        front(x, 4.2, 0.45, 0.75, ky0, 0.08, plumD, bevel=0.02)
        front(x, 4.2, 0.3, 0.6, ky0, 0.1, G("fortGlow", C.rgb(1.0, 0.55, 0.85)), bevel=0.0)
        C.cylinder((x, ky0 - 0.1, 4.5), 0.15, 0.06, G("fortGlow", C.rgb(1.0, 0.55, 0.85)), rot=(math.pi / 2, 0, 0), verts=16)
    # rose window on the keep (the keep's door is hidden behind the gatehouse)
    C.cylinder((0, ky0 - 0.04, 2.9), 0.75, 0.1, plumD, rot=(math.pi / 2, 0, 0), verts=32)
    C.cylinder((0, ky0 - 0.08, 2.9), 0.6, 0.06, G("fortGlow", C.rgb(1.0, 0.55, 0.85)), rot=(math.pi / 2, 0, 0), verts=32)
    for k in range(4):
        b = C.box((0, ky0 - 0.12, 2.9), (1.2, 0.04, 0.07), plumD, bevel=0.0, smooth=False)
        b.rotation_euler = (0, math.pi * k / 4, 0)
    # keep flag
    C.cylinder((0, (ky0 + ky1) / 2, Hk + 1.2), 0.05, 2.2, M("steel", hi=0.3), verts=10)
    vs = [(0.05, (ky0 + ky1) / 2, Hk + 2.25), (1.2, (ky0 + ky1) / 2, Hk + 2.0), (0.05, (ky0 + ky1) / 2, Hk + 1.7)]
    mesh("flag", vs, [(0, 1, 2)], mag, solid=0.04, offset=0)
    # corner towers
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 1.0), sy * (D / 2 - 1.0)
            Ht = 4.3 if sy < 0 else 4.7
            C.cylinder((x, y, Ht / 2), 0.98, Ht, plum, verts=28)
            C.cylinder((x, y, Ht + 0.1), 1.08, 0.2, plumD, verts=28)
            C.cone((x, y, Ht + 0.95), 1.18, 0.05, 1.7, mag, verts=28)
            C.torus((x, y, Ht + 0.2), 1.1, 0.05, magD, minor_seg=6)
            C.sphere((x, y, Ht + 1.95), 0.12, M("steel", hi=0.3), seg=10, rings=6)
            if sy < 0:
                front(x, 2.3, 0.26, 0.6, y - 0.93, 0.08, plumD, bevel=0.02)
                front(x, 3.3, 0.26, 0.5, y - 0.93, 0.08, G("fortGlow", C.rgb(1.0, 0.55, 0.85)), bevel=0.0)
    # gatehouse bay + arched gate with portcullis
    slab(-1.9, 1.9, yf - 0.4, yf + t, 0, Hw + 0.8, plumL, bevel=0.04)
    crenels(-1.9, 1.9, yf - 0.4, yf + t, Hw + 0.8, plumL, size=0.42, gap=0.35, h=0.4, sides=(0,))
    yg = yf - 0.4
    gw, gh = 1.9, 2.0
    front(0, gh / 2 + 0.05, gw + 0.3, gh + 0.1, yg, 0.06, plumD, bevel=0.02)
    C.cylinder((0, yg - 0.02, gh), gw / 2 + 0.15, 0.1, plumD, rot=(math.pi / 2, 0, 0), verts=28)
    dark = M("gateDark", C.rgb(0.20, 0.14, 0.24), ao=0, rim=0)
    front(0, gh / 2, gw, gh, yg, 0.1, dark, bevel=0.0)
    C.cylinder((0, yg - 0.06, gh), gw / 2, 0.1, dark, rot=(math.pi / 2, 0, 0), verts=28)
    iron = M("iron", hi=0.3)
    for k in range(6):
        x = -gw / 2 + 0.15 + (gw - 0.3) * k / 5
        zt = gh + math.sqrt(max(0.0, (gw / 2) ** 2 - x ** 2)) - 0.1
        front(x, zt / 2, 0.07, zt, yg, 0.16, iron, bevel=0.0)
    for z in (0.5, 1.1, 1.7, 2.3):
        hw = gw / 2 if z <= gh else math.sqrt(max(0.0, (gw / 2) ** 2 - (z - gh) ** 2))
        front(0, z, 2 * hw - 0.05, 0.07, yg, 0.17, iron, bevel=0.0)
    feat.set_door(0, yg, gw, gh + gw / 2)
    slab(-1.3, 1.3, yg - 0.6, yg, 0, 0.1, plumD, bevel=0.02)
    sign_plate(feat, 0, Hw + 0.28, 2.6, 0.55, yg, M("plate", C.rgb(0.95, 0.90, 0.95), hi=0.15, ao=0), plumD,
               bolts=M("steel", ao=0), proud=0.08)
    # magenta banners (plain, with a generic diamond + stripe)
    for s in (-1, 1):
        x = s * 3.3
        C.cylinder((x, yf - 0.15, Hw - 0.15), 0.05, 1.3, iron, rot=(0, math.pi / 2, 0), verts=8)
        vs = [(x - 0.55, yf - 0.12, Hw - 0.2), (x + 0.55, yf - 0.12, Hw - 0.2), (x + 0.55, yf - 0.12, 0.95),
              (x, yf - 0.12, 0.65), (x - 0.55, yf - 0.12, 0.95)]
        mesh("banner", vs, [(0, 1, 2, 3, 4)], mag, solid=0.05)
        vs = [(x, yf - 0.18, 2.3), (x + 0.28, yf - 0.18, 1.85), (x, yf - 0.18, 1.4), (x - 0.28, yf - 0.18, 1.85)]
        mesh("diamond", vs, [(0, 1, 2, 3)], M("bannerMark", C.rgb(0.98, 0.86, 0.94), ao=0), solid=0.02)
        front(x, 2.62, 1.1, 0.08, yf - 0.18, 0.02, magD, bevel=0.0)
        front(x, 1.08, 1.1, 0.08, yf - 0.18, 0.02, magD, bevel=0.0)
    # torches either side of the gate
    for s in (-1, 1):
        C.box((s * 1.45, yg - 0.15, 1.75), (0.14, 0.2, 0.3), iron, bevel=0.02)
        C.sphere((s * 1.45, yg - 0.2, 2.0), (0.12, 0.12, 0.17), G("torch", C.rgb(1.0, 0.60, 0.85)), seg=10, rings=6)


# ============================================================================= 11. bunker
@building("bld_bunker")
def _bunker(feat, W, D, variant=None):
    H = 2.2
    yf = -D / 2
    steel = M("bunkSteel", C.rgb(0.52, 0.56, 0.62), hi=0.14, rim=0.3)
    steelD = M("bunkSteelD", C.rgb(0.36, 0.39, 0.46))
    steelL = M("bunkSteelL", C.rgb(0.66, 0.70, 0.76), hi=0.14)
    cy = G("bunkCyan", C.rgb(0.40, 0.95, 0.92))
    amb, ink = M("hazA", C.rgb(0.90, 0.70, 0.28), ao=0), M("hazK", C.rgb(0.20, 0.21, 0.26), ao=0)
    slab(-W / 2 - 0.1, W / 2 + 0.1, -D / 2 - 0.1, D / 2 + 0.1, 0, 0.22, M("concreteD", C.rgb(0.50, 0.51, 0.56)))
    slab(-W / 2, W / 2, -D / 2, D / 2, 0.2, H, steel, bevel=0.1, seg=2)
    slab(-W / 2 + 0.25, W / 2 - 0.25, -D / 2 + 0.25, D / 2 - 0.25, H, H + 0.35, steelL, bevel=0.12, seg=2)
    for k in range(1, 6):   # armour plate seams
        y = -D / 2 + 0.4 + (D - 0.8) * k / 6
        C.box((0, y, H + 0.355), (W - 0.8, 0.05, 0.012), steelD, bevel=0.0, smooth=False)
    # sloped armour skirts either side of the door
    for s in (-1, 1):
        x0, x1 = (0.95, W / 2) if s > 0 else (-W / 2, -0.95)
        vs = [(x0, yf, 0.2), (x1, yf, 0.2), (x1, yf - 0.6, 0.2), (x0, yf - 0.6, 0.2),
              (x0, yf, 1.1), (x1, yf, 1.1)]
        me = bpy.data.meshes.new("skirt"); me.from_pydata(vs, [], [(0, 3, 2, 1), (3, 0, 4), (1, 2, 5), (2, 3, 4, 5), (0, 1, 5, 4)])
        o = bpy.data.objects.new("skirt", me); bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(steelD)
        bm_fix(o)
        # rivets along the top of the skirt
        for k in range(6):
            x = x0 + 0.2 + (x1 - x0 - 0.4) * k / 5
            C.sphere((x, yf - 0.02, 1.08), 0.04, steelL, seg=8, rings=4)
        # cyan light bars
        front((x0 + x1) / 2, 1.55, x1 - x0 - 0.5, 0.12, yf, 0.08, steelD, bevel=0.02)
        front((x0 + x1) / 2, 1.55, x1 - x0 - 0.6, 0.06, yf - 0.04, 0.08, cy, bevel=0.0)
    # header block with the sign + beacon
    slab(-1.9, 1.9, yf - 0.3, yf + 0.6, 0.2, H + 0.9, steelL, bevel=0.08)
    sign_plate(feat, 0, H + 0.45, 2.5, 0.52, yf - 0.3, M("plate", C.rgb(0.94, 0.96, 0.98), hi=0.15, ao=0), steelD,
               bolts=steelD, proud=0.06)
    for s in (-1, 1):
        C.cylinder((s * 1.55, yf - 0.1, H + 1.0), 0.14, 0.2, steelD, verts=14)
        C.sphere((s * 1.55, yf - 0.1, H + 1.12), (0.12, 0.12, 0.1), cy, seg=12, rings=6)
    # blast door with hazard frame
    dw, dh = 2.1, 1.85
    yd = yf - 0.3
    front(0, dh / 2 + 0.1, dw + 0.5, dh + 0.3, yd, 0.08, ink, bevel=0.02)
    n = 12
    for k in range(n):            # chevrons around the frame (as short slanted bars)
        for s in (-1, 1):
            rot_box((s * (dw / 2 + 0.13), yd - 0.09, 0.2 + dh * (k + 0.5) / n), (0.2, 0.02, 0.07), amb,
                    (0, s * math.radians(35), 0))
    for k in range(9):
        rot_box((-dw / 2 + dw * (k + 0.5) / 9, yd - 0.09, dh + 0.12), (0.07, 0.02, 0.2), amb, (0, math.radians(35), 0))
    for s in (-1, 1):
        front(s * dw / 4, dh / 2, dw / 2 - 0.02, dh, yd, 0.14, M("blast", C.rgb(0.60, 0.64, 0.70), hi=0.15), bevel=0.02)
        for z in (0.45, 1.0, 1.55):
            front(s * dw / 4, z, dw / 2 - 0.2, 0.08, yd, 0.17, steelD, bevel=0.0)
    C.cylinder((0, yd - 0.18, dh / 2 + 0.1), 0.3, 0.1, steelD, rot=(math.pi / 2, 0, 0), verts=24)
    C.cylinder((0, yd - 0.22, dh / 2 + 0.1), 0.12, 0.06, cy, rot=(math.pi / 2, 0, 0), verts=16)
    feat.set_door(0, yd, dw, dh)
    slab(-1.4, 1.4, yd - 0.5, yd, 0, 0.1, ink, bevel=0.01)
    for k in range(7):
        rot_box((-1.2 + 2.4 * k / 6, yd - 0.25, 0.105), (0.12, 0.5, 0.01), amb, (0, 0, math.radians(35)))
    # roof: vents, pipes and a hatch
    z = H + 0.35
    for x, y in ((-1.8, 1.0), (1.8, 1.0), (-1.8, -1.8)):
        slab(x - 0.45, x + 0.45, y - 0.45, y + 0.45, z, z + 0.3, steelD, bevel=0.04)
        for k in range(4):
            C.box((x, y - 0.3 + k * 0.2, z + 0.32), (0.7, 0.06, 0.03), steelL, bevel=0.0)
    C.cylinder((0.8, 2.2, z + 0.25), 0.3, 0.5, steelD, verts=18)
    C.cylinder((0.8, 2.2, z + 0.52), 0.34, 0.06, steelL, verts=18)
    tube("pipeB", [(-2.6, 2.6, z + 0.2), (0.4, 2.6, z + 0.2), (0.4, 2.2, z + 0.2)], 0.1, steelL)


def bm_fix(o):
    """Recalculate outward normals for a closed hand-built mesh."""
    import bmesh
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data); bm.free()


# ============================================================================= render loop
def scene_bounds():
    """Screen-space bounds (units, u = x, v = y cos + z sin) of every mesh and its shadow."""
    dg = bpy.context.evaluated_depsgraph_get()
    sun = E.SHADOW_SUN_DIR
    u0 = v0 = 1e9; u1 = v1 = -1e9
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        for vtx in me.vertices:
            p = mw @ vtx.co
            for q in (p, p - sun * (max(p.z, 0.0) / sun.z)):
                u, v = q.x, q.y * COS + q.z * SIN
                u0, u1, v0, v1 = min(u0, u), max(u1, u), min(v0, v), max(v1, v)
        ev.to_mesh_clear()
    return u0, u1, v0, v1


def building_camera(bounds, margin=0.25):
    """Orthographic 55deg camera with a canvas fitted to `bounds`; returns origin px (raw, y down)."""
    u0, u1, v0, v1 = bounds
    u0 -= margin; v0 -= margin; u1 += margin; v1 += margin
    wpx = int(math.ceil((u1 - u0) * PPU / 8.0) * 8)
    hpx = int(math.ceil((v1 - v0) * PPU / 8.0) * 8)
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"
    cd.ortho_scale = max(wpx, hpx) / PPU
    cd.clip_start = 0.1; cd.clip_end = 200
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam)
    up = Vector((0, COS, SIN)); fwd = Vector((0, SIN, -COS)); right = Vector((1, 0, 0))
    cu = (u0 + u1) / 2; cv = (v0 + v1) / 2
    # snap the centre so the origin lands on a whole raw pixel
    cam.location = right * cu + up * cv - fwd * 60
    cam.rotation_euler = (TILT, 0, 0)
    sc.camera = cam
    sc.render.resolution_x = wpx * C.SS
    sc.render.resolution_y = hpx * C.SS
    ox = (wpx / 2 - cu * PPU)            # origin in FINAL (1x) px, x right
    oy = (hpx / 2 + cv * PPU)            # y down
    return (wpx, hpx), (ox, oy)


def main():
    a = C.script_args()
    out = a[a.index("--out") + 1] if "--out" in a else C.default_raw_dir("buildings")
    only = a[a.index("--only") + 1].split(",") if "--only" in a else None
    os.makedirs(out, exist_ok=True)
    meta_path = os.path.join(out, "_meta.json")
    meta = json.load(open(meta_path)) if (only and os.path.exists(meta_path)) else {}
    t0 = time.time(); n = 0
    for base, fn, cfg in REGISTRY:
        variants = cfg["variants"] or [None]
        W, D = footprint_units(*cfg["footprint_pt"])
        first_shadow = None
        for var in variants:
            name = f"{base}_{var}" if var else base
            if only and name not in only and base not in only:
                continue
            C.reset()
            sc = bpy.context.scene
            sc.eevee.taa_render_samples = 32
            sc.render.dither_intensity = 0.0     # flat toon fills stay flat -> ~3x smaller PNGs
            feat = Feat()
            fn(feat, W, D, var) if var else fn(feat, W, D)
            C.add_key_light()
            C.outline(px=INK[0], inner_px=INK[1])
            bpy.context.view_layer.update()
            size, origin = building_camera(scene_bounds())
            C.render_to(os.path.join(out, name + ".png")); n += 1
            shadow = os.path.join(out, name + "_shadow.png")
            if first_shadow is None:
                E.shadow_pass(shadow, E.mesh_objects(), samples=48,
                              floor_size=4 * max(W, D) + 20)
                first_shadow = shadow; n += 1
            else:
                shutil.copy(first_shadow, shadow)     # same body -> same shadow
            s, d = feat.sign, feat.door
            info = dict(size_raw_1x=list(size), origin_1x=[round(origin[0], 2), round(origin[1], 2)],
                        footprint_pt=list(cfg["footprint_pt"]), footprint_units=[round(W, 3), round(D, 3)],
                        sign_center_pt=to_pt(s["center"]),
                        sign_size_pt=[round(s["w"] * PPU * WS, 1), round(s["h"] * PPU * WS * SIN, 1)],
                        door_pt=to_pt((d["x"], d["y"], 0.0)),
                        door_top_pt=to_pt((d["x"], d["y"], d["h"])),
                        door_width_pt=round(d["w"] * PPU * WS, 1),
                        variant=var, base=base, note=cfg["note"])
            meta[name] = info
            print(f"[sprites] buildings: {name} {size} ({time.time() - t0:.0f}s)")
            json.dump(meta, open(meta_path, "w"), indent=1)
    print(f"[sprites] buildings: {n} images in {time.time() - t0:.1f}s -> {out}")


main()
