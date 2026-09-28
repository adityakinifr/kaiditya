"""Lord Chow-Chow - the boss: a fluffy-but-fearsome purple chow-chow super-villain with a lion
mane, glowing red eyes, snarl, flat slab helmet, X-bandolier, bolt belt, huge puffy clawed arms
and a dark cape (mirrors CharacterFactory.makeVillain). 8 dirs x (idle + 4-frame stomp), 384px.
Run: Blender -b -P chowchow.py -- [--out DIR] [--quick] [--dirs s,e]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, common as C
importlib.reload(C)
from mathutils import Vector

opts = C.parse_opts()
C.reset()

FRAME = 384
SCALE = 1.4           # modelled at hero proportions, then scaled up: a big boss next to the hero

FUR = C.toon("fur", C.P["villainFur"])
FUR_D = C.toon("furDark", C.scale_col(C.P["villainFur"], 0.7))
FUR_L = C.toon("furLight", C.rgb(0.58, 0.44, 0.68))
MANE = C.toon("mane", C.rgb(0.52, 0.36, 0.64))
FACE = C.toon("face", C.rgb(0.66, 0.54, 0.76))
MUZZLE = C.toon("muzzle", C.rgb(0.80, 0.70, 0.84))
CAPE = C.toon("cape", C.scale_col(C.P["villain"], 0.75))
CAPE_IN = C.toon("capeIn", C.rgb(0.55, 0.10, 0.16), rim=0.0)   # blood-red lining
INK = C.toon("ink", C.P["ink"], hi=0.4, hi_at=0.8)
STRAP = C.toon("strap", C.rgb(0.20, 0.16, 0.22), hi=0.3)
GOLD = C.toon("gold", C.P["energy"], hi=0.35)
HELM = C.toon("helmet", C.rgb(0.30, 0.20, 0.42), hi=0.5, hi_at=0.8)
CLAW = C.toon("claw", C.rgb(0.95, 0.92, 0.85), rim=0.2)
EYE = C.toon("eye", C.rgb(1.0, 0.18, 0.12), flat=True)
EYE_HI = C.toon("eyeHi", C.rgb(1.0, 0.85, 0.6), flat=True)
MOUTH = C.toon("mouth", C.rgb(0.12, 0.05, 0.12), flat=True)
TONGUE = C.toon("tongue", C.rgb(0.22, 0.20, 0.55), rim=0.0)   # chow-chows have blue tongues!
WHITE = C.toon("teeth", C.P["white"], rim=0.0)

root = C.empty("root")
root.scale = (SCALE,) * 3
body = C.empty("body", parent=root)
hipL = C.empty("hipL", (0.18, 0, 0.36), parent=body)
hipR = C.empty("hipR", (-0.18, 0, 0.36), parent=body)
shL = C.empty("shL", (0.42, 0, 0.88), parent=body)
shR = C.empty("shR", (-0.42, 0, 0.88), parent=body)
headP = C.empty("head", (0, 0, 1.0), parent=body)

# ---- legs with clawed feet
for hip, x in ((hipL, 0.18), (hipR, -0.18)):
    C.sphere((x, 0, 0.25), (0.14, 0.14, 0.17), FUR, parent=hip)
    C.sphere((x, -0.05, 0.075), (0.15, 0.19, 0.085), FUR_L, parent=hip)
    for dx in (-0.07, 0, 0.07):
        C.cone_dir((x + dx, -0.2, 0.06), (dx * 2, -1, -0.15), 0.03, 0.08, CLAW, parent=hip, verts=8)

# ---- torso, bandolier, belt
TC, TR = (0, 0, 0.68), (0.40, 0.32, 0.37)
C.sphere(TC, TR, FUR, parent=body)
for s in (1, -1):
    C.box((0, -0.29, 0.70), (0.09, 0.05, 0.78), STRAP, parent=body, rot=(math.radians(-8), math.radians(s * 38), 0),
          bevel=0.02)
C.sphere((0, -0.34, 0.72), (0.06, 0.03, 0.06), GOLD, parent=body, seg=6, rings=3)   # strap rivet
C.torus((0, 0, 0.42), 0.37, 0.055, STRAP, parent=body, scale=(1, 0.85, 1))
# lightning-bolt buckle (flat zig-zag prism)
bolt2d = [(0.02, 0.10), (-0.05, -0.005), (0.0, -0.005), (-0.03, -0.10), (0.05, 0.015), (0.0, 0.015)]
verts = [(x * 1.2, -0.35 + dy, 0.42 + z * 1.2) for dy in (0.0, 0.035) for x, z in bolt2d]
nb = len(bolt2d)
faces = [tuple(range(nb))[::-1], tuple(range(nb, 2 * nb))] + [(i, (i + 1) % nb, nb + (i + 1) % nb, nb + i) for i in range(nb)]
C.mesh_obj("bolt", verts, faces, GOLD, parent=body, smooth=False)

# ---- huge puffy arms with clawed fists
for sh, s in ((shL, 1), (shR, -1)):
    for (x, y, z, r) in ((0.50, 0.0, 0.84, 0.17), (0.58, 0.0, 0.66, 0.185), (0.57, -0.02, 0.49, 0.16)):
        C.sphere((s * x, y, z), r, FUR, parent=sh)
    C.sphere((s * 0.56, -0.05, 0.35), (0.13, 0.13, 0.12), FUR_L, parent=sh)
    for dx in (-0.06, 0, 0.06):
        C.cone_dir((s * 0.56 + dx, -0.15, 0.3), (dx * 1.5, -0.7, -0.7), 0.028, 0.08, CLAW, parent=sh, verts=8)

# ---- head: dark fluffy mane, lighter face, muzzle, angry eyes, snarl, ears, slab helmet
HC = (0, 0.02, 1.34)
C.sphere(HC, (0.50, 0.44, 0.44), MANE, parent=headP)
for i in range(16):                                   # fluffy tufts around the mane silhouette
    a = i / 16 * 2 * math.pi
    if math.sin(a) > 0.55:
        continue                                      # top is covered by the helmet
    p = Vector((math.cos(a) * 0.5, 0.06 + math.sin(a) * 0.05, 1.34 + math.sin(a) * 0.43))
    C.sphere(p, 0.13, MANE, parent=headP, seg=16, rings=8)
for i in range(10):                                   # and around the back/top so it reads top-down
    a = i / 10 * 2 * math.pi
    C.sphere((math.cos(a) * 0.36, 0.14 + math.sin(a) * 0.34, 1.5), 0.14, MANE, parent=headP, seg=16, rings=8)
FC, FR = (0, -0.16, 1.30), (0.36, 0.30, 0.33)
C.sphere(FC, FR, FACE, parent=headP)
C.sphere((0, -0.43, 1.20), (0.19, 0.15, 0.12), MUZZLE, parent=headP)
C.sphere((0, -0.575, 1.25), (0.075, 0.05, 0.05), INK, parent=headP)          # nose
# angry glowing eyes + heavy slanted brows
for s in (1, -1):
    _, p, n = C.decal(FC, FR, s * 0.14, 0.09, (0.085, 0.035, 0.06), EYE, headP, push=-0.005)
    rot = (-n).to_track_quat("Y", "Z").to_euler()
    C.sphere(p + n * 0.02 + Vector((s * -0.02, 0, 0.012)), (0.022, 0.012, 0.018), EYE_HI, parent=headP, rot=rot)
    pb = C.on_ellipsoid(FC, FR, s * 0.14, 0.17)
    C.box(pb + Vector((0, -0.01, 0)), (0.2, 0.07, 0.06), FUR_D, parent=headP,
          rot=(0, math.radians(-s * 22), 0), bevel=0.02)
# snarl with teeth + blue tongue
C.box((0, -0.45, 1.075), (0.26, 0.08, 0.075), MOUTH, parent=headP, bevel=0.025)
for i in range(4):
    C.cone_dir((-0.09 + i * 0.06, -0.495, 1.11), (0, -0.2, -1), 0.022, 0.05, WHITE, parent=headP, verts=8)
C.cone_dir((-0.1, -0.49, 1.04), (0, -0.2, 1), 0.025, 0.07, WHITE, parent=headP, verts=8)   # fangs up
C.cone_dir((0.1, -0.49, 1.04), (0, -0.2, 1), 0.025, 0.07, WHITE, parent=headP, verts=8)
C.sphere((0.03, -0.48, 1.05), (0.05, 0.03, 0.02), TONGUE, parent=headP)
# small triangular ears poking out of the mane
for s in (1, -1):
    C.cone_dir((s * 0.36, 0.0, 1.62), (s * 0.8, -0.1, 0.7), 0.09, 0.17, FUR_D, parent=headP)
# flat slab helmet with a shine strip and bolt badge
C.box((0, 0.04, 1.74), (0.74, 0.64, 0.17), HELM, parent=headP, bevel=0.05)
C.box((0, 0.04, 1.68), (0.78, 0.68, 0.05), GOLD, parent=headP, bevel=0.02)   # gold trim
C.box((0, -0.12, 1.83), (0.5, 0.08, 0.015), C.toon("shine", C.rgb(0.6, 0.58, 0.7), flat=True),
      parent=headP, bevel=0.005)
C.sphere((0, -0.29, 1.745), (0.07, 0.025, 0.06), GOLD, parent=headP, seg=4, rings=2)

# ---- cape
for s in (1, -1):
    C.sphere((s * 0.3, -0.12, 0.98), 0.06, GOLD, parent=body)
cape = C.Cape(body, CAPE, CAPE_IN, top_z=1.0, length=0.9, r_top=0.36, r_grow=0.16, back=0.10,
              flare=0.12, spread_top=96, spread_bot=62, thick=0.055)


def pose(phase):
    swing, bob, sway = C.walk_curves(phase)
    walking = phase is not None
    body.location.z = 0.05 * bob
    body.rotation_euler = (math.radians(6 if walking else 0), math.radians(5 * sway), 0)  # heavy stomp
    hipL.rotation_euler.x = math.radians(-26 * swing)
    hipR.rotation_euler.x = math.radians(26 * swing)
    shL.rotation_euler = (math.radians(22 * swing), math.radians(-4), 0)
    shR.rotation_euler = (math.radians(-22 * swing), math.radians(4), 0)
    headP.rotation_euler = (math.radians(-8 - (3 * bob if walking else 0)), 0, math.radians(3 * sway))
    cape.pose(phase, bob, sway)


C.add_key_light()
C.char_camera(FRAME)
C.outline(px=2.4, inner_px=1.3)
C.render_character("chowchow", root, pose, opts)
