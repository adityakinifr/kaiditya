"""Town NPCs - chibi toon villagers sharing one parameterised base body.
  mayor : Mayor Mia   - adult, red dress, gold diagonal sash + badge, dark brown bob
  gran  : Granny Gold - short/round adult, lavender dress, white hair bun, round glasses, necklace
  tommy : Tommy       - kid, light-blue tee, dark shorts, sneakers, red baseball cap
8 directions x (idle + 4-frame walk), 256px, same scale/style as hero.py.
Run: Blender -b -P npc.py -- --npc mayor|gran|tommy [--out DIR] [--quick] [--dirs s,e]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, bpy, bmesh, common as C
importlib.reload(C)
from mathutils import Vector

opts = C.parse_opts()
_a = C.script_args()
NPC = _a[_a.index("--npc") + 1] if "--npc" in _a else "mayor"
if NPC not in ("mayor", "gran", "tommy"):
    raise SystemExit(f"unknown --npc {NPC!r} (mayor|gran|tommy)")
C.reset()

# ---------------------------------------------------------------- shared materials
SKIN = C.toon("skin", C.P["heroSkin"], rim=0.3)
BLUSH = C.toon("blush", C.rgb(1.0, 0.62, 0.62), rim=0.0)
WHITE = C.toon("eyeWhite", C.P["white"], flat=True)
PUPIL = C.toon("pupil", C.rgb(0.08, 0.10, 0.22), flat=True)
MOUTH = C.toon("mouth", C.rgb(0.42, 0.12, 0.14), flat=True)
GOLD = C.toon("gold", C.P["energy"], hi=0.35)
INKM = C.toon("frame", C.rgb(0.16, 0.14, 0.20), hi=0.2)

# ---------------------------------------------------------------- per-NPC config
if NPC == "mayor":
    TOP = C.toon("dress", C.P["heroRed"])
    cfg = dict(
        top=TOP, sleeve=TOP, lower=C.toon("tights", C.rgb(0.22, 0.18, 0.26)),
        shoe=C.toon("shoe", C.rgb(0.18, 0.14, 0.16), hi=0.3), sole=None,
        hair=C.toon("hair", C.rgb(0.30, 0.18, 0.12), hi=0.3, hi_at=0.965),
        hip_z=0.44, hip_x=0.10, leg_r=0.075, leg_skin=False,
        torso_c=(0, 0, 0.74), torso_r=(0.25, 0.21, 0.31),
        sh=(0.245, 0.95), arm_len=0.37, arm_r=0.07, short_sleeve=False,
        head_c=(0, 0, 1.47), head_r=(0.415, 0.385, 0.375), neck_z=1.01,
        skirt=(0.60, 0.235, 0.30, 0.33), eye_scale=1.05, eye_dx=0.15, eye_dz=0.0,
        swing=(30, 32), bob=0.04)
elif NPC == "gran":
    TOP = C.toon("dress", C.rgb(0.80, 0.60, 0.85))
    cfg = dict(
        top=TOP, sleeve=TOP, lower=C.toon("stocking", C.rgb(0.85, 0.78, 0.80)),
        shoe=C.toon("shoe", C.rgb(0.45, 0.28, 0.20), hi=0.3), sole=None,
        hair=C.toon("hair", C.rgb(0.90, 0.90, 0.94), hi=0.12, hi_at=0.965),
        hip_z=0.34, hip_x=0.11, leg_r=0.08, leg_skin=False,
        torso_c=(0, 0, 0.60), torso_r=(0.32, 0.28, 0.29),
        sh=(0.29, 0.79), arm_len=0.31, arm_r=0.075, short_sleeve=False,
        head_c=(0, 0, 1.22), head_r=(0.405, 0.375, 0.365), neck_z=0.84,
        skirt=(0.46, 0.30, 0.25, 0.325), shoe_y=-0.07, eye_scale=0.92, eye_dx=0.15, eye_dz=0.0,
        swing=(24, 18), bob=0.025)
else:   # tommy
    TOP = C.toon("shirt", C.rgb(0.40, 0.60, 0.90))
    cfg = dict(
        top=TOP, sleeve=TOP, lower=C.toon("shorts", C.rgb(0.20, 0.22, 0.34)),
        shoe=C.toon("sneaker", C.P["white"], hi=0.2), sole=C.toon("sole", C.P["heroRed"], hi=0.3),
        hair=C.toon("hair", C.P["heroHair"], hi=0.3, hi_at=0.965),
        hip_z=0.34, hip_x=0.12, leg_r=0.085, leg_skin=True,
        torso_c=(0, 0, 0.58), torso_r=(0.28, 0.235, 0.30),
        sh=(0.265, 0.78), arm_len=0.32, arm_r=0.072, short_sleeve=True,
        head_c=(0, 0, 1.25), head_r=(0.43, 0.40, 0.39), neck_z=0.86,
        skirt=None, eye_scale=1.12, eye_dx=0.15, eye_dz=0.0,
        swing=(34, 36), bob=0.045)

HC, HR = cfg["head_c"], cfg["head_r"]

# ---------------------------------------------------------------- rig
root = C.empty("root")
body = C.empty("body", parent=root)
hz, hx = cfg["hip_z"], cfg["hip_x"]
hipL = C.empty("hipL", (hx, 0, hz), parent=body)
hipR = C.empty("hipR", (-hx, 0, hz), parent=body)
sx, sz = cfg["sh"]
shL = C.empty("shL", (sx, 0, sz), parent=body)
shR = C.empty("shR", (-sx, 0, sz), parent=body)
headP = C.empty("head", (0, 0, cfg["neck_z"]), parent=body)

# ---------------------------------------------------------------- base body
# legs + shoes
for hip, s in ((hipL, 1), (hipR, -1)):
    x = s * hx
    lr = cfg["leg_r"]
    leg_top, leg_bot = hz + 0.03, 0.10
    if cfg["leg_skin"]:   # kid: shorts on the thigh, bare shin
        C.sphere((x, 0, hz - 0.03), (lr + 0.025, lr + 0.025, 0.11), cfg["lower"], parent=hip)
        C.sphere((x, 0, 0.19), (lr - 0.012, lr - 0.012, 0.10), SKIN, parent=hip)
    else:
        C.sphere((x, 0, (leg_top + leg_bot) / 2), (lr, lr, (leg_top - leg_bot) / 2), cfg["lower"], parent=hip)
    C.sphere((x, cfg.get("shoe_y", -0.035), 0.075), (0.098, 0.14, 0.085), cfg["shoe"], parent=hip)
    if cfg["sole"] is not None:
        C.sphere((x, -0.035, 0.035), (0.104, 0.146, 0.04), cfg["sole"], parent=hip)
        C.sphere((x, -0.12, 0.11), (0.05, 0.03, 0.03), cfg["sole"], parent=hip)   # toe stripe

# torso
TC, TR = cfg["torso_c"], cfg["torso_r"]
C.sphere(TC, TR, cfg["top"], parent=body)
if cfg["skirt"]:
    tz, tr, bz, br = cfg["skirt"]
    C.cone((0, 0, (tz + bz) / 2), br, tr, tz - bz, cfg["top"], parent=body, verts=32)
    C.torus((0, 0, bz + 0.012), br - 0.005, 0.022, cfg["top"], parent=body)
elif NPC == "tommy":
    # shorts waistband under the tee
    C.sphere((0, 0, hz + 0.02), (0.245, 0.205, 0.10), cfg["lower"], parent=body)

# arms + hands
for sh, s in ((shL, 1), (shR, -1)):
    al, ar = cfg["arm_len"], cfg["arm_r"]
    ax = s * (sx + 0.03)
    if cfg["short_sleeve"]:
        C.sphere((ax, 0, sz - al * 0.22), (ar + 0.02, ar + 0.02, al * 0.28), cfg["sleeve"], parent=sh,
                 rot=(0, math.radians(s * 9), 0))
        C.sphere((s * (sx + 0.045), 0, sz - al * 0.62), (ar - 0.01, ar - 0.01, al * 0.3), SKIN, parent=sh,
                 rot=(0, math.radians(s * 9), 0))
    else:
        C.sphere((ax, 0, sz - al / 2), (ar, ar, al / 2), cfg["sleeve"], parent=sh,
                 rot=(0, math.radians(s * 9), 0))
    C.sphere((s * (sx + 0.055), -0.01, sz - al - 0.01), 0.068, SKIN, parent=sh)

# head, ears, face
C.sphere(HC, HR, SKIN, parent=headP, seg=48, rings=24)
for s in (1, -1):
    C.sphere((s * HR[0] * 0.98, 0.02, HC[2] - 0.03), (0.05, 0.06, 0.08), SKIN, parent=headP)
C.cartoon_eyes(HC, HR, cfg["eye_dx"], cfg["eye_dz"], headP, WHITE, PUPIL, scale=cfg["eye_scale"])
for s in (1, -1):
    pb = C.on_ellipsoid(HC, HR, s * 0.25, -0.13)
    C.sphere(pb, (0.06, 0.02, 0.035), BLUSH, parent=headP, rot=C.face_rot(HC, HR, pb))
pm = C.on_ellipsoid(HC, HR, 0, -0.2)
sm = C.torus(pm + Vector((0, 0.01, 0.035)), 0.055, 0.015, MOUTH, rot=(math.radians(90), 0, 0))
bm = bmesh.new(); bm.from_mesh(sm.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.012], context="VERTS")  # lower arc
bm.to_mesh(sm.data); bm.free()
sm.rotation_euler = C.face_rot(HC, HR, pm); sm.rotation_euler.x += math.radians(90)
C._finish(sm, None, headP, False, "smile")


def hair_cap(threshold, grow=1.04, lift=0.015, mat=None, thick=0.03, name="hairCap"):
    """Head-shaped shell kept where z_rel > threshold(x_rel, y_rel) (rel = offset from head centre)."""
    c = (HC[0], HC[1] + lift, HC[2] + lift)
    r = (HR[0] * grow, HR[1] * grow, HR[2] * grow)
    cap = C.sphere(c, r, mat or cfg["hair"], seg=48, rings=24)
    bm = bmesh.new(); bm.from_mesh(cap.data)
    def keep(v):
        x = v.co.x * r[0]; y = v.co.y * r[1] + lift; z = v.co.z * r[2] + lift
        return z > threshold(x, y)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v)], context="VERTS")
    bm.to_mesh(cap.data); bm.free()
    sol = cap.modifiers.new("thick", "SOLIDIFY"); sol.thickness = thick; sol.offset = 1
    return C._finish(cap, None, headP, True, name)


def at_head(dx, dz, push=0.0, grow=1.0):
    r = tuple(v * grow for v in HR)
    p = C.on_ellipsoid(HC, r, dx, dz)
    n = C.ellipsoid_normal(HC, r, p)
    return p + n * push, n


def face_dir(o, n):
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = Vector(n).to_track_quat("Z", "Y")


# ---------------------------------------------------------------- per-NPC extras
if NPC == "mayor":
    HAIR = cfg["hair"]
    # bob: covers the crown, sides and back down to the jaw, fringe line swept high on the forehead
    def bob_cut(x, y):
        return max(-0.30, min(0.24, 0.21 - 2.2 * (y + 0.32)))
    hair_cap(bob_cut, grow=1.06, thick=0.035)
    # flicked-out ends of the bob at jaw level
    for s in (1, -1):
        C.sphere((s * 0.39, 0.07, HC[2] - 0.27), (0.09, 0.19, 0.07), HAIR, parent=headP,
                 rot=(0, math.radians(-s * 20), 0))
    C.sphere((0, 0.36, HC[2] - 0.25), (0.30, 0.10, 0.08), HAIR, parent=headP)
    # side-swept fringe
    base, _ = at_head(-0.12, 0.25, push=0.01, grow=1.06)
    C.sphere(base, (0.2, 0.08, 0.07), HAIR, parent=headP, rot=(math.radians(-30), math.radians(-22), 0))
    base, _ = at_head(0.14, 0.27, push=0.0, grow=1.06)
    C.sphere(base, (0.15, 0.07, 0.06), HAIR, parent=headP, rot=(math.radians(-30), math.radians(15), 0))
    # diagonal gold sash: left shoulder -> right hip
    sash = C.torus(TC, 0.30, 0.04, GOLD, rot=(0, math.radians(38), 0),
                   scale=(1.0, TR[1] / TR[0] * 1.04, 1.0))
    C._finish(sash, None, body, True, "sash")
    # badge on the sash, upper chest
    p = C.on_ellipsoid(TC, TR, 0.10, 0.10)
    n = C.ellipsoid_normal(TC, TR, p)
    b = C.cylinder(p + n * 0.045, 0.062, 0.03, GOLD, verts=10)
    face_dir(b, n)
    C._finish(b, None, body, True, "badge")
    b2 = C.cylinder(p + n * 0.064, 0.032, 0.012, C.toon("badgeC", C.P["heroRed"], rim=0.0), verts=10)
    face_dir(b2, n)
    C._finish(b2, None, body, True, "badgeC")
    # white collar
    COL = C.toon("collar", C.P["white"], rim=0.2)
    for s in (1, -1):
        C.sphere((s * 0.08, -0.13, TC[2] + TR[2] - 0.06), (0.09, 0.05, 0.05), COL, parent=body,
                 rot=(math.radians(-25), 0, math.radians(s * 25)))

elif NPC == "gran":
    HAIR = cfg["hair"]
    # soft wavy hairline: crown + sides above the ears, off the forehead
    def gran_cut(x, y):
        return max(-0.02, min(0.24, 0.20 - 1.6 * (y + 0.30)))
    hair_cap(gran_cut, grow=1.05, thick=0.04)
    # fluffy side puffs
    for s in (1, -1):
        C.sphere((s * 0.36, 0.08, HC[2] + 0.02), (0.11, 0.17, 0.13), HAIR, parent=headP)
    # the bun: big round top-knot + little wrap
    C.sphere((0, 0.12, HC[2] + HR[2] + 0.04), (0.15, 0.14, 0.12), HAIR, parent=headP)
    C.torus((0, 0.10, HC[2] + HR[2] - 0.02), 0.11, 0.03, HAIR, parent=headP)
    # round glasses around the eyes
    es = cfg["eye_scale"]
    for s in (1, -1):
        p, n = at_head(s * cfg["eye_dx"], cfg["eye_dz"] - 0.005, push=0.022)
        t = C.torus(p, 0.10 * es + 0.02, 0.013, INKM, major_seg=32, minor_seg=8)
        face_dir(t, n)
        C._finish(t, None, headP, True, "lens")
        # arm towards the ear
        a, _ = at_head(s * 0.33, cfg["eye_dz"], push=0.02)
        C.cylinder((p + a) / 2, 0.01, (a - p).length, INKM, verts=8)
        o = bpy.context.object
        face_dir(o, a - p)
        C._finish(o, None, headP, True, "temple")
    pb, nb = at_head(0, cfg["eye_dz"] + 0.02, push=0.03)
    o = C.cylinder(pb, 0.011, 0.08, INKM, verts=8)
    face_dir(o, (1, 0, 0)); C._finish(o, None, headP, True, "bridge")
    # gold necklace + brooch
    nk = C.torus((0, -0.02, TC[2] + TR[2] - 0.07), 0.19, 0.018, GOLD, rot=(math.radians(-18), 0, 0),
                 scale=(1.0, 0.95, 1.0))
    C._finish(nk, None, body, True, "necklace")
    p = C.on_ellipsoid(TC, TR, 0, 0.13)
    n = C.ellipsoid_normal(TC, TR, p)
    C.sphere(p + n * 0.01, (0.055, 0.03, 0.055), GOLD, parent=body, rot=(-n).to_track_quat("Y", "Z").to_euler())
    C.sphere(p + n * 0.035, (0.028, 0.015, 0.028), C.toon("gem", C.rgb(0.55, 0.30, 0.75), flat=True),
             parent=body, rot=(-n).to_track_quat("Y", "Z").to_euler())
    # white apron-ish collar
    COL = C.toon("collar", C.P["white"], rim=0.2)
    for s in (1, -1):
        C.sphere((s * 0.10, -0.17, TC[2] + TR[2] - 0.08), (0.10, 0.05, 0.055), COL, parent=body,
                 rot=(math.radians(-25), 0, math.radians(s * 22)))

else:  # tommy
    HAIR = cfg["hair"]
    CAP = C.toon("cap", C.P["heroRed"], hi=0.25)
    # brown hair peeking out below the cap at the sides/back + a little fringe
    def tom_cut(x, y):
        return max(-0.08, min(0.25, 0.20 - 2.0 * (y + 0.34)))
    hair_cap(tom_cut, grow=1.04, thick=0.03)
    for x, tilt in ((-0.18, -0.35), (-0.04, -0.1), (0.10, 0.2)):
        base, _ = at_head(x, 0.17, push=0.0, grow=1.05)
        C.cone_dir(base + Vector((0, 0.02, 0)), (tilt * 0.7, -0.4, -0.9), 0.065, 0.10, HAIR, parent=headP)
    # cap dome: head-shaped shell above a plane that dips slightly to the back
    def cap_cut(x, y):
        return 0.15 + 0.08 * y
    cap = hair_cap(cap_cut, grow=1.11, lift=0.02, mat=CAP, thick=0.035, name="capDome")
    C.sphere((0, 0.01, HC[2] + HR[2] * 1.11 + 0.035), 0.035, CAP, parent=headP)   # top button
    # brim facing forward (-Y), flattened disc half-in front of the dome
    bz = HC[2] + 0.15
    brim = C.cylinder((0, -HR[1] * 0.92, bz), 0.25, 0.025, CAP, verts=32,
                      rot=(math.radians(-18), 0, 0))
    brim.scale = (1.0, 0.72, 1.0)
    C._finish(brim, None, headP, True, "brim")
    # white front panel logo
    p, n = at_head(0, 0.30, push=0.045, grow=1.11)
    lg = C.sphere(p, (0.06, 0.012, 0.05), C.toon("logo", C.P["white"], flat=True),
                  rot=(-n).to_track_quat("Y", "Z").to_euler())
    C._finish(lg, None, headP, True, "logo")
    # tee: white star on the chest
    p = C.on_ellipsoid(TC, TR, 0, 0.05)
    n = C.ellipsoid_normal(TC, TR, p)
    st = C.cylinder(p + n * 0.005, 0.07, 0.02, C.toon("tee", C.P["energy"], hi=0.3), verts=5)
    face_dir(st, n)
    C._finish(st, None, body, False, "star")

# ---------------------------------------------------------------- pose + render
HEAD_UP = -10   # tip the face up toward the high camera so eyes read
LEG_SW, ARM_SW = cfg["swing"]
BOB = cfg["bob"]


def pose(phase):
    swing, bob, sway = C.walk_curves(phase)
    walking = phase is not None
    body.location.z = BOB * bob
    body.rotation_euler = (math.radians(4 if walking else 0), math.radians(3 * sway), 0)
    hipL.rotation_euler.x = math.radians(-LEG_SW * swing)
    hipR.rotation_euler.x = math.radians(LEG_SW * swing)
    shL.rotation_euler = (math.radians(ARM_SW * swing), math.radians(-6), 0)
    shR.rotation_euler = (math.radians(-ARM_SW * swing), math.radians(6), 0)
    headP.rotation_euler = (math.radians(HEAD_UP - (3 * bob if walking else 0)), 0, math.radians(2 * sway))


C.add_key_light()
C.char_camera(C.CHAR_FRAME)
C.outline()
C.render_character(f"npc_{NPC}", root, pose, opts)
