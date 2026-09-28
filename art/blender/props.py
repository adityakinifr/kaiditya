"""Toon world props for the 55deg character camera (graphics plan P2).

Every prop is rendered twice from the characters' camera (C.char_camera, PX_PER_UNIT ~116):
  <name>.png         EEVEE colour pass: toon bands + stepped violet AO band + Freestyle ink
  <name>_shadow.png  Cycles shadow-catcher pass: alpha-only cast + contact shadow, falls down-right
Spin sets (coin_0..5, crystal_0..7) share one <set>_shadow.png.

The world origin (centre of the prop's ground footprint) sits at (0.5, anchor) of the raw canvas.
tools/props_post.py crops every sprite (colour + shadow share a crop, spin frames share one crop),
recomputes the SpriteKit anchorPoint and writes art/props_manifest.json.

Run: Blender -b -P props.py -- --out RAW_DIR [--only crate_a,coin]
"""
import os, sys, math, json, time
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import bpy
import common as C
import envkit as E
importlib.reload(C); importlib.reload(E)
from mathutils import Vector, Quaternion

# ----------------------------------------------------------------------------- palette (sRGB)
# Props sit at mid saturation.  Reserved hues: red = danger, warm yellow = sight/light,
# cyan = crystals/objectives, gold = coins/energy.  Nothing decorative uses them at high sat.
COL = {
    "wood":      C.P["wood"],
    "woodDark":  C.scale_col(C.P["wood"], 0.62),
    "woodPale":  C.rgb(0.70, 0.52, 0.34),
    "olive":     C.rgb(0.44, 0.50, 0.36),
    "metal":     C.P["metal"],
    "steel":     C.rgb(0.62, 0.65, 0.72),
    "gunmetal":  C.rgb(0.30, 0.32, 0.40),
    "iron":      C.rgb(0.22, 0.23, 0.30),
    "stone":     C.rgb(0.60, 0.58, 0.66),
    "stoneDark": C.rgb(0.44, 0.42, 0.52),
    "leaf":      C.rgb(0.30, 0.58, 0.32),
    "leafLite":  C.rgb(0.40, 0.68, 0.38),
    "leafDark":  C.rgb(0.22, 0.46, 0.28),
    "bark":      C.rgb(0.45, 0.31, 0.22),
    "villain":   C.P["villain"],
    "copper":    C.rgb(0.66, 0.44, 0.30),
    "danger":    C.rgb(1.00, 0.22, 0.24),     # reserved: red = danger
    "dangerDim": C.rgb(0.55, 0.16, 0.20),
    "sight":     C.rgb(1.00, 0.88, 0.48),     # reserved: warm yellow = sight / light
    "cyan":      C.P["crystal"],              # reserved: cyan = crystals / objectives
    "cyanDeep":  C.rgb(0.10, 0.62, 0.70),
    "gold":      C.rgb(1.00, 0.80, 0.22),     # reserved: gold = coins / energy
    "goldDeep":  C.rgb(0.86, 0.58, 0.14),
    "heroBlue":  C.P["heroBlue"],
    "white":     C.P["white"],
    "offWhite":  C.rgb(0.90, 0.92, 0.95),
}

STATIC_INK = (2.0, 1.2)        # plan: static props
INTERACTIVE_INK = (2.2, 1.3)   # plan: characters + interactive items

REGISTRY = []   # (name, fn, cfg)


def prop(name, frame=320, anchor=0.30, yaw=0.0, kind="static", footprint=(1.0, 1.0),
         shape="rect", height=1.0, spin=None, shadow=True, rim=True, note=""):
    """Register a builder.  footprint = (w, d) ground size in world units BEFORE yaw.
    spin = (count, total_degrees) renders <name>_<i> frames rotating the builder's pivot."""
    def deco(fn):
        REGISTRY.append((name, fn, dict(frame=frame, anchor=anchor, yaw=yaw, kind=kind,
                                        footprint=footprint, shape=shape, height=height,
                                        spin=spin, shadow=shadow, rim=rim, note=note)))
        return fn
    return deco


def M(name, key=None, col=None, **kw):
    """Standard prop toon material (with AO band)."""
    return E.tmat(name, col if col is not None else COL[key or name], **kw)


# ----------------------------------------------------------------------------- shared shapes
def crate(W, D, H, wood, wood_dark, metal, brace=True, slats=0, parent=None):
    objs = [C.box((0, 0, H / 2), (W - 0.08, D - 0.08, H - 0.08), wood_dark, bevel=0.02, seg=2)]
    t = 0.12
    for sx in (-1, 1):
        for sy in (-1, 1):
            objs.append(C.box((sx * (W / 2 - t / 2), sy * (D / 2 - t / 2), H / 2), (t, t, H), wood, bevel=0.022))
    for z in (t / 2, H - t / 2):
        for sy in (-1, 1):
            objs.append(C.box((0, sy * (D / 2 - t / 2), z), (W, t, t), wood, bevel=0.022))
        for sx in (-1, 1):
            objs.append(C.box((sx * (W / 2 - t / 2), 0, z), (t, D, t), wood, bevel=0.022))
    for face in range(4):
        yaw = face * math.pi / 2
        n = Vector((math.sin(yaw), -math.cos(yaw), 0))
        span = W if face % 2 == 0 else D
        c = n * ((D if face % 2 == 0 else W) / 2 - 0.03) + Vector((0, 0, H / 2))
        if brace:
            diag = math.atan2(H - 2 * t, span - 2 * t)
            L = math.hypot(span - 2 * t, H - 2 * t) - 0.04
            b = C.box(c, (L, 0.045, t * 0.8), wood, bevel=0.018)
            b.rotation_mode = "QUATERNION"
            b.rotation_quaternion = Quaternion((0, 0, 1), yaw) @ Quaternion((0, 1, 0), (1 if face % 2 else -1) * diag)
            objs.append(b)
        for k in range(slats):
            z = t + (H - 2 * t) * (k + 0.5) / slats
            b = C.box(c + Vector((0, 0, z - H / 2)), (span - 2 * t, 0.04, (H - 2 * t) / slats - 0.05), wood, bevel=0.015)
            b.rotation_euler = (0, 0, yaw)
            objs.append(b)
    for i, x in enumerate((-0.25, 0.0, 0.25)):
        objs.append(C.box((x * W / 1.1, 0, H - 0.02), (0.22 * W / 1.1, D - 2 * t + 0.02, 0.045), wood, bevel=0.012))
    for sx in (-1, 1):
        for sy in (-1, 1):
            objs.append(C.box((sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), H - 0.06), (0.09, 0.09, 0.13), metal, bevel=0.02))
    if parent is not None:   # parts were authored around the origin: place them in parent space
        for o in objs:
            o.parent = parent
    return objs


def _reparent(o, parent):
    bpy.context.view_layer.update()
    mw = o.matrix_world.copy(); o.parent = parent; o.matrix_world = mw


def lathe(name, profile, mat, verts=28, smooth=True):
    """Solid of revolution around Z. profile: [(r, z), ...] bottom -> top (r=0 closes)."""
    vs, fs = [], []
    n = len(profile)
    for j, (r, z) in enumerate(profile):
        for i in range(verts):
            a = 2 * math.pi * i / verts
            vs.append((r * math.cos(a), r * math.sin(a), z))
    for j in range(n - 1):
        for i in range(verts):
            a = j * verts + i; b = j * verts + (i + 1) % verts
            fs.append((a, b, b + verts, a + verts))
    vs.append((0, 0, profile[0][1])); vs.append((0, 0, profile[-1][1]))
    cb, ct = len(vs) - 2, len(vs) - 1
    for i in range(verts):
        fs.append((cb, (i + 1) % verts, i))
        fs.append((ct, (n - 1) * verts + i, (n - 1) * verts + (i + 1) % verts))
    o = C.mesh_obj(name, vs, fs, mat, smooth=smooth)
    return o


def blob_cluster(spec, mats, seg=20):
    """spec: [(x, y, z, rx, ry, rz, mat_index)] -> spheres."""
    return [C.sphere((x, y, z), (rx, ry, rz), mats[m], seg=seg, rings=seg // 2) for x, y, z, rx, ry, rz, m in spec]


def star_mesh(name, r_out, r_in, t, mat, points=5):
    """Chunky star in the XZ plane (facing -Y), thickness 2t, bevelled."""
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
    o = C.mesh_obj(name, vs, fs, mat, smooth=False)
    m = o.modifiers.new("bevel", "BEVEL"); m.width = 0.02; m.segments = 2
    m.limit_method = "ANGLE"; m.angle_limit = math.radians(30)
    return o


def tube(name, pts, radius, mat, res=4):
    """Poly curve with a round bevel, converted to mesh (Freestyle needs meshes)."""
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


# ============================================================================= crates
@prop("crate_a", yaw=30, footprint=(1.1, 1.1), height=0.92)
def _crate_a(root):
    crate(1.1, 1.1, 0.92, M("wood"), M("woodDark"), M("metal", hi=0.35), brace=True)


@prop("crate_b", yaw=-22, footprint=(1.15, 0.9), height=0.78)
def _crate_b(root):
    olive = M("olive"); oliveD = M("oliveDark", col=C.scale_col(COL["olive"], 0.66))
    crate(1.15, 0.9, 0.78, M("woodPale"), oliveD, M("gunmetal", hi=0.3), brace=False, slats=3)
    # stencil band (low-sat, non-reserved)
    C.box((0, -0.455, 0.39), (0.42, 0.012, 0.16), M("stencil", col=C.rgb(0.80, 0.78, 0.66), rim=0, ao=0), bevel=0.005)


@prop("crate_stack", frame=448, anchor=0.25, yaw=18, footprint=(2.1, 1.05), height=1.8)
def _crate_stack(root):
    wood, woodD, metal = M("wood"), M("woodDark"), M("metal", hi=0.35)
    for x in (-0.53, 0.53):
        g = C.empty("g", (x, 0, 0))
        crate(1.02, 1.02, 0.86, wood, woodD, metal, brace=True, parent=g)
    top = C.empty("top", (0.05, 0.02, 0.86))
    top.rotation_euler = (0, 0, math.radians(-14))
    olive = M("olive"); oliveD = M("oliveDark", col=C.scale_col(COL["olive"], 0.66))
    crate(0.95, 0.8, 0.72, M("woodPale"), oliveD, M("gunmetal", hi=0.3), brace=False, slats=3, parent=top)


@prop("barrel", footprint=(0.68, 0.68), shape="circle", height=0.9, yaw=15)
def _barrel(root):
    H = 0.9
    prof = [(0.29, 0.0)] + [(0.29 + 0.05 * math.sin(math.pi * k / 8), H * k / 8) for k in range(1, 8)] + [(0.29, H)]
    lathe("barrel", prof, M("woodPale", ao=0.25), verts=24, smooth=True)
    # staves: thin dark lines as slightly proud strips
    staves = M("woodDark", ao=0)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        r = 0.335
        b = C.box((r * math.cos(a), r * math.sin(a), H / 2), (0.012, 0.012, H * 0.8), staves, bevel=0)
        b.rotation_euler = (0, 0, a)
    for z, rr in ((0.12, 0.315), (H - 0.12, 0.315), (H / 2, 0.345)):
        C.torus((0, 0, z), rr, 0.022, M("iron", hi=0.3), minor_seg=8)
    C.cylinder((0, 0, H - 0.01), 0.27, 0.03, M("woodDark"), verts=24)


# ============================================================================= plants
def bush(scale, seed):
    import random
    rnd = random.Random(seed)
    mats = [M("leaf"), M("leafLite"), M("leafDark")]
    spec = [(0, 0.05, 0.36, 0.46, 0.40, 0.36, 0), (-0.36, 0.08, 0.28, 0.32, 0.30, 0.28, 2),
            (0.38, 0.06, 0.30, 0.34, 0.30, 0.30, 0), (-0.14, -0.20, 0.30, 0.30, 0.26, 0.27, 1),
            (0.20, -0.18, 0.26, 0.28, 0.24, 0.24, 1), (0.06, 0.18, 0.58, 0.30, 0.26, 0.24, 1),
            (-0.22, 0.10, 0.52, 0.24, 0.22, 0.20, 0)]
    out = []
    for x, y, z, rx, ry, rz, m in spec:
        j = 1 + 0.08 * (rnd.random() - 0.5)
        out.append((x * scale, y * scale, z * scale, rx * scale * j, ry * scale * j, rz * scale * j, m))
    blob_cluster(out, mats, seg=18)
    # a few tiny berries/leaf tips for texture (muted, not reserved hues)
    tip = M("leafTip", col=C.rgb(0.52, 0.76, 0.44), ao=0)
    for _ in range(6):
        a = rnd.random() * math.pi * 2
        C.sphere((math.cos(a) * 0.32 * scale, math.sin(a) * 0.22 * scale - 0.1 * scale, (0.45 + 0.2 * rnd.random()) * scale),
                 0.05 * scale, tip, seg=10, rings=6)


@prop("bush_a", footprint=(1.4, 1.0), shape="ellipse", height=0.85)
def _bush_a(root):
    bush(1.0, 3)


@prop("bush_b", footprint=(0.9, 0.7), shape="ellipse", height=0.55, rim=False)
def _bush_b(root):
    bush(0.64, 11)


@prop("tree", frame=448, anchor=0.20, footprint=(0.45, 0.45), shape="circle", height=2.7,
      note="footprint = trunk (collision); canopy is ~1.9 x 1.5 units")
def _tree(root):
    bark = M("bark", hi=0.1)
    lathe("trunk", [(0.22, 0.0), (0.16, 0.12), (0.13, 0.6), (0.12, 1.3)], bark, verts=16)
    for a in (0.3, 2.4, 4.3):
        C.cone_dir((0.08 * math.cos(a), 0.08 * math.sin(a), 0.05), (math.cos(a), math.sin(a), -0.25), 0.07, 0.22, bark)
    C.cone_dir((0.02, 0, 1.0), (0.8, -0.2, 0.7), 0.05, 0.45, bark)
    mats = [M("leaf"), M("leafLite"), M("leafDark")]
    blob_cluster([(0, 0.05, 1.55, 0.78, 0.70, 0.62, 0), (-0.52, 0.12, 1.40, 0.50, 0.46, 0.44, 2),
                  (0.55, 0.08, 1.45, 0.52, 0.46, 0.46, 0), (0.0, 0.10, 2.05, 0.56, 0.50, 0.46, 1),
                  (-0.26, -0.32, 1.40, 0.42, 0.36, 0.38, 1), (0.30, -0.30, 1.35, 0.40, 0.34, 0.36, 0),
                  (-0.30, 0.0, 1.95, 0.40, 0.36, 0.34, 0), (0.34, 0.0, 1.90, 0.40, 0.38, 0.34, 1)], mats, seg=22)


# ============================================================================= architecture
@prop("pillar", frame=384, anchor=0.20, footprint=(0.8, 0.8), height=2.1, yaw=0)
def _pillar(root):
    st, stD, band = M("stone"), M("stoneDark"), M("gunmetal", hi=0.35)
    C.box((0, 0, 0.11), (0.86, 0.86, 0.22), stD, bevel=0.03)
    C.box((0, 0, 0.27), (0.74, 0.74, 0.10), st, bevel=0.02)
    shaft = C.box((0, 0, 1.08), (0.58, 0.58, 1.54), st, bevel=0.07, seg=1)
    # fluting: shallow vertical grooves on the two camera-facing faces
    for f in range(4):
        yaw = f * math.pi / 2
        n = Vector((math.sin(yaw), -math.cos(yaw), 0)); tng = Vector((math.cos(yaw), math.sin(yaw), 0))
        for k in (-1, 1):
            g = C.box(n * 0.287 + tng * (k * 0.13) + Vector((0, 0, 1.08)), (0.05, 0.02, 1.2), stD, bevel=0.008)
            g.rotation_euler = (0, 0, yaw)
    for z in (0.62, 1.55):
        C.box((0, 0, z), (0.64, 0.64, 0.08), band, bevel=0.015)
    C.box((0, 0, 1.90), (0.74, 0.74, 0.10), st, bevel=0.02)
    C.box((0, 0, 2.02), (0.88, 0.88, 0.16), stD, bevel=0.03)


@prop("lamp_post", frame=384, anchor=0.14, footprint=(0.45, 0.45), shape="circle", height=2.6)
def _lamp_post(root):
    iron, gm = M("iron", hi=0.3), M("gunmetal", hi=0.35)
    lathe("base", [(0.22, 0), (0.22, 0.08), (0.15, 0.14), (0.10, 0.30), (0.07, 0.36)], iron, verts=20)
    C.cylinder((0, 0, 1.25), 0.045, 1.8, gm, verts=14)
    C.torus((0, 0, 0.5), 0.06, 0.02, iron, minor_seg=6)
    C.torus((0, 0, 2.1), 0.06, 0.02, iron, minor_seg=6)
    # lantern
    z0 = 2.18
    C.box((0, 0, z0), (0.26, 0.26, 0.05), iron, bevel=0.01)
    glass = E.glow("lampGlass", COL["sight"])
    C.box((0, 0, z0 + 0.17), (0.20, 0.20, 0.28), glass, bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            C.box((sx * 0.11, sy * 0.11, z0 + 0.17), (0.03, 0.03, 0.30), iron, bevel=0.005)
    cap = C.cone((0, 0, z0 + 0.39), 0.22, 0.03, 0.16, iron, verts=4)
    cap.rotation_euler = (0, 0, math.pi / 4)
    C.sphere((0, 0, z0 + 0.49), 0.035, iron, seg=10, rings=6)


# ============================================================================= mechanics
@prop("cage_closed", kind="interactive", frame=448, anchor=0.22, footprint=(1.2, 1.2), height=1.5, yaw=0)
def _cage_closed(root):
    cage(False)


@prop("cage_open", kind="interactive", frame=448, anchor=0.22, footprint=(1.2, 1.2), height=1.5, yaw=0)
def _cage_open(root):
    cage(True)


def cage(open_):
    W, H = 1.2, 1.42
    iron, bar, accent = M("iron", hi=0.3), M("steel", hi=0.4, ao=0.2), M("villain", hi=0.2)
    C.box((0, 0, 0.07), (W, W, 0.14), iron, bevel=0.03)
    C.box((0, 0, 0.16), (W - 0.12, W - 0.12, 0.04), accent, bevel=0.01)
    C.box((0, 0, H - 0.05), (W, W, 0.1), iron, bevel=0.03)
    dome = C.sphere((0, 0, H), (W * 0.42, W * 0.42, 0.18), accent, seg=24, rings=12)
    C.torus((0, 0, H + 0.2), 0.09, 0.025, iron, rot=(math.pi / 2, 0, 0), minor_seg=8)
    r = 0.028
    n = 5
    door_w = W * 0.5
    for side in range(4):
        yaw = side * math.pi / 2
        for k in range(n):
            u = -W / 2 + 0.07 + (W - 0.14) * k / (n - 1)
            p = Vector((math.cos(yaw) * u - math.sin(yaw) * (-(W / 2 - 0.05)),
                        math.sin(yaw) * u + math.cos(yaw) * (-(W / 2 - 0.05)), 0))
            if side == 0 and abs(u) < door_w / 2:
                continue   # door bars
            C.cylinder((p.x, p.y, H / 2 + 0.05), r, H - 0.16, bar, verts=10)
    # horizontal mid rail
    for side in range(4):
        yaw = side * math.pi / 2
        c = Vector((math.sin(yaw) * (W / 2 - 0.05), -math.cos(yaw) * (W / 2 - 0.05), 0.72))
        if side == 0:
            for sx in (-1, 1):
                C.box((sx * (W / 2 + door_w / 2) / 2, c.y, 0.72), ((W - door_w) / 2, 0.05, 0.05), iron, bevel=0.01)
            continue
        b = C.box(c, (W, 0.05, 0.05), iron, bevel=0.01); b.rotation_euler = (0, 0, yaw)
    # door (hinged on its left edge)
    hinge = C.empty("hinge", (-door_w / 2, -(W / 2 - 0.05), 0))
    parts = []
    for k in range(3):
        x = -door_w / 2 + door_w * (k + 0.5) / 3
        parts.append(C.cylinder((x, -(W / 2 - 0.05), H / 2 + 0.05), r, H - 0.2, bar, verts=10))
    for z in (0.24, 0.72, H - 0.18):
        parts.append(C.box((0, -(W / 2 - 0.05), z), (door_w, 0.05, 0.06), iron, bevel=0.01))
    lock = C.box((door_w / 2 - 0.06, -(W / 2 + 0.01), 0.66), (0.14, 0.07, 0.14), accent, bevel=0.02)
    parts.append(lock)
    if not open_:
        parts.append(C.torus((door_w / 2 - 0.06, -(W / 2 + 0.01), 0.76), 0.045, 0.014, M("steel"),
                             rot=(math.pi / 2, 0, 0), minor_seg=6))
    for p in parts:
        _reparent(p, hinge)
    if open_:
        hinge.rotation_euler = (0, 0, math.radians(-105))


def generator(on):
    body, dark, gm = M("gunmetal", hi=0.3), M("iron", hi=0.25), M("steel", hi=0.4)
    C.box((0, 0, 0.05), (1.1, 0.86, 0.10), dark, bevel=0.02)
    C.box((0, 0, 0.42), (0.98, 0.74, 0.66), body, bevel=0.05)
    for k in range(4):   # front vents
        C.box((-0.18, -0.375, 0.26 + 0.09 * k), (0.46, 0.02, 0.035), dark, bevel=0.005)
    # control panel (right of vents) with status light
    C.box((0.27, -0.375, 0.47), (0.28, 0.02, 0.36), dark, bevel=0.01)
    lamp = E.glow("genLampOn", COL["cyan"]) if on else M("genLampOff", col=C.rgb(0.28, 0.30, 0.36), ao=0)
    C.sphere((0.27, -0.39, 0.56), (0.055, 0.03, 0.055), lamp, seg=12, rings=8)
    C.box((0.27, -0.39, 0.40), (0.16, 0.02, 0.05), gm, bevel=0.005)
    # energy core on top: glass tube + copper coils
    C.cylinder((0, 0.02, 0.79), 0.24, 0.08, dark, verts=24)
    core = E.glow("coreOn", COL["cyan"]) if on else M("coreOff", col=C.rgb(0.24, 0.30, 0.36), hi=0.2, ao=0)
    C.cylinder((0, 0.02, 1.0), 0.13, 0.38, core, verts=20)
    if on:
        C.cylinder((0, 0.02, 1.0), 0.07, 0.40, E.glow("coreHot", C.rgb(0.85, 1.0, 0.98)), verts=12)
    for z in (0.88, 1.0, 1.12):
        C.torus((0, 0.02, z), 0.16, 0.028, M("copper", hi=0.3), minor_seg=8)
    C.cylinder((0, 0.02, 1.22), 0.2, 0.06, dark, verts=24)
    # side cable
    tube("cable", [(0.49, 0.1, 0.5), (0.62, 0.1, 0.35), (0.66, 0.0, 0.08), (0.75, -0.15, 0.03)], 0.035, dark)
    if not on:   # sabotaged: loose panel + scorch
        p = C.box((-0.58, -0.25, 0.03), (0.3, 0.2, 0.025), gm, bevel=0.005)
        p.rotation_euler = (0, 0, 0.4)


@prop("generator_on", kind="interactive", footprint=(1.1, 0.86), height=1.25, yaw=20)
def _gen_on(root):
    generator(True)


@prop("generator_off", kind="interactive", footprint=(1.1, 0.86), height=1.25, yaw=20)
def _gen_off(root):
    generator(False)


@prop("laser_emitter", kind="interactive", footprint=(0.56, 0.56), shape="circle", height=1.0)
def _laser(root):
    dark, gm = M("iron", hi=0.25), M("gunmetal", hi=0.35)
    lathe("base", [(0.28, 0), (0.28, 0.07), (0.22, 0.12), (0.12, 0.16)], dark, verts=8, smooth=False)
    C.cylinder((0, 0, 0.45), 0.08, 0.6, gm, verts=16)
    C.cylinder((0, 0, 0.72), 0.16, 0.08, dark, verts=16)
    C.sphere((0, 0, 0.86), (0.16, 0.16, 0.13), gm, seg=20, rings=10)
    red = E.glow("laserRed", COL["danger"])
    C.torus((0, 0, 0.84), 0.16, 0.035, red, minor_seg=8)
    C.sphere((0, 0, 0.99), 0.05, red, seg=12, rings=8)
    C.sphere((0, -0.17, 0.86), (0.07, 0.03, 0.07), E.glow("laserHot", C.rgb(1.0, 0.72, 0.70)), seg=12, rings=8)


@prop("searchlight_base", kind="interactive", footprint=(0.9, 0.9), shape="circle", height=1.2)
def _searchlight(root):
    dark, gm, steel = M("iron", hi=0.25), M("gunmetal", hi=0.35), M("steel", hi=0.4)
    for a in (90, 210, 330):
        r = math.radians(a)
        tube(f"leg{a}", [(0, 0, 0.55), (0.42 * math.cos(r), 0.42 * math.sin(r), 0.02)], 0.035, dark)
        C.sphere((0.42 * math.cos(r), 0.42 * math.sin(r), 0.02), (0.06, 0.06, 0.03), dark, seg=10, rings=6)
    C.cylinder((0, 0, 0.62), 0.07, 0.22, gm, verts=14)
    # yoke
    C.box((0, 0, 0.76), (0.44, 0.08, 0.05), gm, bevel=0.01)
    for sx in (-1, 1):
        C.box((sx * 0.2, 0, 0.9), (0.04, 0.08, 0.28), gm, bevel=0.01)
    # lamp drum pointing towards the camera, tilted down
    ax = Vector((0, -math.sin(math.radians(105)), math.cos(math.radians(105))))
    c = Vector((0, 0, 0.95))
    C.cylinder(c, 0.17, 0.30, steel, rot=(math.radians(105), 0, 0), verts=24)
    C.cylinder(c - ax * 0.12, 0.13, 0.12, dark, rot=(math.radians(105), 0, 0), verts=20)
    C.torus(c + ax * 0.15, 0.17, 0.025, dark, rot=(math.radians(105), 0, 0), minor_seg=8)
    C.cylinder(c + ax * 0.155, 0.15, 0.01, E.glow("searchLens", COL["sight"]), rot=(math.radians(105), 0, 0), verts=24)


@prop("trap", kind="interactive", footprint=(1.0, 1.0), height=0.1, rim=False, anchor=0.40)
def _trap(root):
    plate, dark = M("gunmetal", hi=0.3, ao=0.2), M("iron", hi=0.2, ao=0)
    C.box((0, 0, 0.035), (1.0, 1.0, 0.07), plate, bevel=0.03)
    C.box((0, 0, 0.072), (0.84, 0.84, 0.01), dark, bevel=0.0)
    red, redD = E.glow("trapRed", COL["danger"]), E.glow("trapRedDim", COL["dangerDim"])
    for k in range(-1, 2):   # glowing coil grid
        C.box((k * 0.26, 0, 0.083), (0.035, 0.8, 0.012), red, bevel=0)
        C.box((0, k * 0.26, 0.083), (0.8, 0.035, 0.012), redD, bevel=0)
    C.cylinder((0, 0, 0.09), 0.08, 0.03, red, verts=16)
    for sx in (-1, 1):
        for sy in (-1, 1):
            C.sphere((sx * 0.43, sy * 0.43, 0.075), (0.035, 0.035, 0.02), M("steel", ao=0), seg=10, rings=6)


def half_drum(name, c, r, w, mat, seg=16):
    """Half cylinder lying along X (the rounded chest lid), flat side down at c."""
    cx, cy, cz = c
    ring = [(r * math.cos(math.pi * k / seg), r * math.sin(math.pi * k / seg)) for k in range(seg + 1)]
    n = len(ring)
    vs = [(cx - w / 2, cy + y, cz + z) for y, z in ring] + [(cx + w / 2, cy + y, cz + z) for y, z in ring]
    fs = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
    fs.append(tuple(range(n))[::-1]); fs.append(tuple(range(n, 2 * n)))
    fs.append((0, n, 2 * n - 1, n - 1))
    o = C.mesh_obj(name, vs, fs, mat, smooth=True)
    m = o.modifiers.new("bevel", "BEVEL"); m.width = 0.012; m.segments = 2
    m.limit_method = "ANGLE"; m.angle_limit = math.radians(50)
    return o


def chest(open_):
    W, D, H = 0.9, 0.6, 0.42
    wood, woodD, gold, goldD = M("wood"), M("woodDark"), M("gold", hi=0.25, ao=0.2), M("goldDeep", ao=0.2)
    C.box((0, 0, H / 2), (W, D, H), wood, bevel=0.035)
    for x in (-0.3, 0.3):   # gold straps
        C.box((x, 0, H / 2), (0.07, D + 0.02, H + 0.01), gold, bevel=0.01)
    C.box((0, 0, 0.03), (W + 0.02, D + 0.02, 0.06), woodD, bevel=0.01)
    hinge = C.empty("lidHinge", (0, D / 2, H))
    lid = []
    lid.append(half_drum("lid", (0, 0, H), D / 2, W, wood))
    for x in (-0.3, 0.3):
        lid.append(half_drum("strap", (x, 0, H), D / 2 + 0.012, 0.075, gold))
    for x in (-W / 2 + 0.02, W / 2 - 0.02):
        lid.append(half_drum("rim", (x, 0, H), D / 2 + 0.01, 0.04, woodD))
    for o in lid:
        _reparent(o, hinge)
    lock = C.box((0, -D / 2 - 0.02, H - 0.02), (0.12, 0.05, 0.14), goldD, bevel=0.015)
    if open_:
        hinge.rotation_euler = (math.radians(-108), 0, 0)
        # treasure: coin heap + glow
        C.box((0, 0, H - 0.04), (W - 0.1, D - 0.1, 0.02), M("chestIn", col=C.rgb(0.30, 0.18, 0.12), ao=0), bevel=0)
        import random
        rnd = random.Random(5)
        for i in range(22):
            x = (rnd.random() - 0.5) * (W - 0.2); y = (rnd.random() - 0.5) * (D - 0.2)
            z = H - 0.02 + 0.08 * (1 - (2 * x / W) ** 2) * (1 - (2 * y / D) ** 2) + 0.02 * rnd.random()
            C.cylinder((x, y, z), 0.06, 0.02, gold if i % 3 else goldD,
                       rot=(rnd.random() * 0.5, rnd.random() * 0.5, 0), verts=14)
        C.sphere((0, 0, H + 0.02), (0.30, 0.18, 0.08), gold, seg=20, rings=10)
        lock.location.z = H - 0.06


@prop("chest_closed", kind="interactive", footprint=(0.9, 0.6), height=0.72, yaw=-12)
def _chest_c(root):
    chest(False)


@prop("chest_open", kind="interactive", footprint=(0.9, 0.6), height=0.72, yaw=-12)
def _chest_o(root):
    chest(True)


# ============================================================================= pickups
@prop("coin", kind="interactive", footprint=(0.44, 0.44), shape="circle", height=0.6, spin=(6, 180), rim=False,
      note="floats: coin centre 0.36 units above the anchor; frames spin 180deg (both faces identical)")
def _coin(root):
    piv = C.empty("spin", (0, 0, 0.36))
    gold, goldD = M("gold", hi=0.35, ao=0), M("goldDeep", ao=0)
    parts = [C.cylinder((0, 0, 0.36), 0.2, 0.06, goldD, rot=(math.pi / 2, 0, 0), verts=32, bevel=0.01)]
    for s in (-1, 1):
        parts.append(C.cylinder((0, s * 0.028, 0.36), 0.165, 0.012, gold, rot=(math.pi / 2, 0, 0), verts=32))
        st = star_mesh("st", 0.10, 0.045, 0.008, goldD)
        st.location = (0, s * 0.036, 0.36)
        parts.append(st)
    for p in parts:
        _reparent(p, piv)
    return piv


@prop("crystal", kind="interactive", footprint=(0.44, 0.44), shape="circle", height=0.85, spin=(8, 60), rim=False,
      note="floats: gem centre 0.46 units above the anchor; 8 frames over the hexagonal 60deg period")
def _crystal(root):
    piv = C.empty("spin", (0, 0, 0))
    cz, r, top, bot = 0.46, 0.17, 0.30, 0.22
    vs = [(r * math.cos(math.radians(30 + 60 * k)), r * math.sin(math.radians(30 + 60 * k)), cz) for k in range(6)]
    vs2 = [(r * 0.62 * math.cos(math.radians(30 + 60 * k)), r * 0.62 * math.sin(math.radians(30 + 60 * k)), cz + top * 0.55) for k in range(6)]
    vs += vs2 + [(0, 0, cz + top), (0, 0, cz - bot)]
    fs = []
    for k in range(6):
        j = (k + 1) % 6
        fs.append((k, j, 6 + j, 6 + k))
        fs.append((6 + k, 6 + j, 12))
        fs.append((j, k, 13))
    cy = M("gem", col=COL["cyan"], hi=0.45, rim=0.5, ao=0, hi_at=0.8)
    g = C.mesh_obj("gem", vs, fs, cy, smooth=False)
    inner = C.mesh_obj("gemCore", [(x * 0.5, y * 0.5, cz + (z - cz) * 0.5) for x, y, z in vs], fs,
                       E.glow("gemCore", C.rgb(0.75, 1.0, 0.97)), smooth=False)
    _reparent(g, piv)
    _reparent(inner, piv)
    return piv


@prop("keycard", kind="interactive", footprint=(0.44, 0.3), height=0.65, rim=False,
      note="floats ~0.4 units above the anchor")
def _keycard(root):
    piv = C.empty("card", (0, 0, 0.42))
    parts = [C.box((0, 0, 0.42), (0.40, 0.03, 0.26), M("offWhite", hi=0.2, ao=0), bevel=0.02)]
    parts.append(C.box((0, -0.017, 0.48), (0.40, 0.01, 0.07), E.glow("cardStripe", COL["cyan"]), bevel=0.0))
    parts.append(C.box((-0.1, -0.017, 0.37), (0.09, 0.01, 0.07), M("chip", col=C.rgb(0.62, 0.64, 0.70), ao=0), bevel=0.005))
    parts.append(C.box((0.08, -0.017, 0.37), (0.14, 0.008, 0.02), M("cardInk", col=C.rgb(0.40, 0.44, 0.54), ao=0), bevel=0))
    parts.append(C.box((0.08, -0.017, 0.33), (0.10, 0.008, 0.02), M("cardInk", col=C.rgb(0.40, 0.44, 0.54), ao=0), bevel=0))
    for p in parts:
        _reparent(p, piv)
    piv.rotation_euler = (math.radians(-28), 0, math.radians(18))


@prop("powerup_star", kind="interactive", footprint=(0.5, 0.5), shape="circle", height=0.8, rim=False,
      note="floats ~0.45 units above the anchor")
def _star(root):
    s = star_mesh("star", 0.27, 0.13, 0.06, M("gold", hi=0.35, ao=0))
    s.location = (0, 0, 0.46)
    s.rotation_euler = (math.radians(-15), 0, math.radians(12))
    C.sphere((0.06, -0.09, 0.53), (0.035, 0.02, 0.05), E.glow("starShine", C.rgb(1, 0.98, 0.9)), seg=10, rings=6)


@prop("powerup_magnet", kind="interactive", footprint=(0.5, 0.5), shape="circle", height=0.8, rim=False,
      note="floats ~0.45 units above the anchor; hero blue body (red is reserved for danger)")
def _magnet(root):
    piv = C.empty("mag", (0, 0, 0.45))
    R, L = 0.14, 0.12
    pts = [(-R, 0, 0.45 - L)] + [(R * math.cos(math.pi - math.pi * k / 16), 0, 0.45 + R * math.sin(math.pi - math.pi * k / 16)) for k in range(17)] + [(R, 0, 0.45 - L)]
    body = tube("magnet", pts, 0.065, M("heroBlue", hi=0.3, ao=0), res=4)
    parts = [body]
    for sx in (-1, 1):
        parts.append(C.cylinder((sx * R, 0, 0.45 - L - 0.06), 0.068, 0.11, M("steel", hi=0.5, ao=0), verts=20))
    for p in parts:
        _reparent(p, piv)
    piv.rotation_euler = (math.radians(-20), math.radians(-25), 0)


@prop("grapple_anchor", kind="interactive", footprint=(0.6, 0.6), shape="circle", height=0.95)
def _grapple(root):
    dark, gm, steel = M("iron", hi=0.25), M("gunmetal", hi=0.35), M("steel", hi=0.45)
    lathe("base", [(0.30, 0), (0.30, 0.06), (0.24, 0.10), (0.10, 0.12)], dark, verts=24)
    C.torus((0, 0, 0.065), 0.25, 0.018, E.glow("grappleGlow", C.rgb(0.45, 0.66, 1.0)), minor_seg=6)
    C.cylinder((0, 0, 0.38), 0.065, 0.54, gm, verts=16)
    C.cylinder((0, 0, 0.5), 0.075, 0.1, M("heroBlue", hi=0.3), verts=16)
    C.torus((0, 0, 0.84), 0.16, 0.04, steel, rot=(math.pi / 2, 0, math.radians(20)), minor_seg=10)
    C.sphere((0, 0, 0.66), 0.08, gm, seg=14, rings=8)


# ============================================================================= render loop
def footprint_aabb(w, d, yaw, shape):
    if shape in ("circle", "ellipse") and shape == "circle":
        return w, d
    a = math.radians(yaw)
    if shape == "ellipse":
        # AABB of a rotated ellipse
        rx, ry = w / 2, d / 2
        return (2 * math.sqrt((rx * math.cos(a)) ** 2 + (ry * math.sin(a)) ** 2),
                2 * math.sqrt((rx * math.sin(a)) ** 2 + (ry * math.cos(a)) ** 2))
    return (abs(w * math.cos(a)) + abs(d * math.sin(a)), abs(w * math.sin(a)) + abs(d * math.cos(a)))


def main():
    a = C.script_args()
    out = a[a.index("--out") + 1] if "--out" in a else C.default_raw_dir("props")
    only = a[a.index("--only") + 1].split(",") if "--only" in a else None
    os.makedirs(out, exist_ok=True)
    meta_path = os.path.join(out, "_meta.json")
    meta = json.load(open(meta_path)) if (only and os.path.exists(meta_path)) else {}
    t0 = time.time(); n = 0
    for name, fn, cfg in REGISTRY:
        if only and name not in only:
            continue
        C.reset()
        sc = bpy.context.scene
        sc.eevee.taa_render_samples = 32
        root = C.empty("root")
        piv = fn(root)
        for o in list(sc.objects):
            if o is not root and o.parent is None and o.type in ("MESH", "EMPTY", "CURVE"):
                _reparent(o, root)
        root.rotation_euler = (0, 0, math.radians(cfg["yaw"]))
        C.add_key_light()
        ink = INTERACTIVE_INK if cfg["kind"] == "interactive" else STATIC_INK
        C.outline(px=ink[0], inner_px=ink[1])
        C.char_camera(cfg["frame"], anchor=cfg["anchor"])
        casters = E.mesh_objects()
        fw, fd = footprint_aabb(*cfg["footprint"], cfg["yaw"], cfg["shape"])
        info = dict(frame=cfg["frame"], anchor=cfg["anchor"], kind=cfg["kind"], yaw=cfg["yaw"],
                    footprint_units=[round(fw, 3), round(fd, 3)], shape=cfg["shape"],
                    height_units=cfg["height"], note=cfg["note"])
        if cfg["spin"]:
            count, total = cfg["spin"]
            names = [f"{name}_{i}" for i in range(count)]
            for i, nm in enumerate(names):
                piv.rotation_euler = (0, 0, math.radians(total * i / count))
                C.render_to(os.path.join(out, nm + ".png")); n += 1
                meta[nm] = dict(info, group=name, shadow=f"{name}_shadow")
            piv.rotation_euler = (0, 0, math.radians(total * 0.25))
            E.shadow_pass(os.path.join(out, f"{name}_shadow.png"), casters); n += 1
            meta[f"{name}_shadow"] = dict(info, group=name, shadow_for=names)
        else:
            C.render_to(os.path.join(out, name + ".png")); n += 1
            meta[name] = dict(info, group=name, shadow=f"{name}_shadow")
            E.shadow_pass(os.path.join(out, f"{name}_shadow.png"), casters); n += 1
            meta[f"{name}_shadow"] = dict(info, group=name, shadow_for=[name])
        print(f"[sprites] props: {name} done ({time.time() - t0:.0f}s)")
        json.dump(meta, open(meta_path, "w"), indent=1)
    dt = time.time() - t0
    print(f"[sprites] props: {n} images in {dt:.1f}s -> {out}")


main()
