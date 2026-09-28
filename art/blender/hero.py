"""Kaiditya - chibi kid superhero. 8 directions x (idle + 4-frame walk), 256px.
Run: Blender -b -P hero.py -- [--out DIR] [--quick] [--dirs s,e]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, common as C
importlib.reload(C)
from mathutils import Vector

opts = C.parse_opts()
C.reset()

# ---------------------------------------------------------------- materials
SUIT = C.toon("suit", C.P["heroBlue"])
SUIT_D = C.toon("suitDark", C.scale_col(C.P["heroBlue"], 0.62))
CAPE = C.toon("cape", C.P["heroRed"])
CAPE_IN = C.toon("capeIn", C.scale_col(C.P["heroRed"], 0.55), rim=0.0)
GOLD = C.toon("gold", C.P["energy"], hi=0.35)
SKIN = C.toon("skin", C.P["heroSkin"], rim=0.3)
BLUSH = C.toon("blush", C.rgb(1.0, 0.62, 0.62), rim=0.0)
HAIR = C.toon("hair", C.P["heroHair"], hi=0.3, hi_at=0.965)
MASK = C.toon("mask", C.P["mask"], hi=0.25)
BOOT = C.toon("boot", C.P["heroRed"], hi=0.3)
WHITE = C.toon("eyeWhite", C.P["white"], flat=True)
PUPIL = C.toon("pupil", C.rgb(0.08, 0.10, 0.22), flat=True)
IRIS = C.toon("iris", C.rgb(0.25, 0.45, 0.85), flat=True)
MOUTH = C.toon("mouth", C.rgb(0.42, 0.12, 0.14), flat=True)

# ---------------------------------------------------------------- rig
root = C.empty("root")
body = C.empty("body", parent=root)
hipL = C.empty("hipL", (0.12, 0, 0.34), parent=body)
hipR = C.empty("hipR", (-0.12, 0, 0.34), parent=body)
shL = C.empty("shL", (0.27, 0, 0.78), parent=body)
shR = C.empty("shR", (-0.27, 0, 0.78), parent=body)
headP = C.empty("head", (0, 0, 0.86), parent=body)

# legs + boots
for hip, x in ((hipL, 0.12), (hipR, -0.12)):
    C.sphere((x, 0, 0.25), (0.10, 0.10, 0.13), SUIT_D, parent=hip)
    C.sphere((x, -0.035, 0.085), (0.105, 0.145, 0.095), BOOT, parent=hip)
    C.torus((x, 0, 0.17), 0.095, 0.022, BOOT, parent=hip)          # boot cuff

# torso, belt, emblem
TORSO_C, TORSO_R = (0, 0, 0.58), (0.29, 0.245, 0.31)
C.sphere(TORSO_C, TORSO_R, SUIT, parent=body)
C.torus((0, 0, 0.40), 0.255, 0.04, GOLD, parent=body, scale=(1, 0.88, 1))
C.sphere((0, -0.235, 0.40), (0.05, 0.02, 0.045), GOLD, parent=body, seg=4, rings=2)  # buckle
p = C.on_ellipsoid(TORSO_C, TORSO_R, 0, 0.06)
em = C.sphere(p, (0.105, 0.035, 0.13), GOLD, parent=None, seg=4, rings=2)
em.rotation_euler = C.face_rot(TORSO_C, TORSO_R, p)
for poly in em.data.polygons: poly.use_smooth = False
C._finish(em, None, body, False, "emblem")
nrm = Vector(((p.x - TORSO_C[0]) / TORSO_R[0] ** 2, (p.y - TORSO_C[1]) / TORSO_R[1] ** 2,
              (p.z - TORSO_C[2]) / TORSO_R[2] ** 2)).normalized()
k = C.text("K", p + nrm * 0.03, 0.14, CAPE)
k.data.extrude = 0.012
k.rotation_mode = "QUATERNION"; k.rotation_quaternion = nrm.to_track_quat("Z", "Y")
C._finish(k, None, body, False, "K")

# arms + gloves (hang from shoulder pivots)
for sh, s in ((shL, 1), (shR, -1)):
    C.sphere((s * 0.30, 0, 0.63), (0.078, 0.078, 0.16), SUIT, parent=sh, rot=(0, math.radians(s * 9), 0))
    C.sphere((s * 0.325, -0.01, 0.46), (0.078, 0.078, 0.078), BOOT, parent=sh)

# head
HC, HR = (0, 0, 1.25), (0.43, 0.40, 0.39)
C.sphere(HC, HR, SKIN, parent=headP, seg=48, rings=24)
for s in (1, -1):   # ears
    C.sphere((s * 0.42, 0.02, 1.22), (0.05, 0.06, 0.08), SKIN, parent=headP)

# mask band (slightly bigger than the head, thin in z) + tie tails at the back
MC, MR = (0, -0.004, 1.25), (0.442, 0.415, 0.10)
C.sphere(MC, MR, MASK, parent=headP, seg=48, rings=16)
for s in (1, -1):
    C.sphere((s * 0.07, 0.47, 1.18), (0.05, 0.03, 0.12), MASK, parent=headP,
             rot=(math.radians(-25), math.radians(s * 25), 0))

# eyes: big, sitting proud of the mask
for s in (1, -1):
    ex = s * 0.14
    pe = C.on_ellipsoid(MC, MR, ex, 0.0)
    n = (pe - Vector(MC)); n = Vector((n.x / MR[0] ** 2, n.y / MR[1] ** 2, 0)).normalized()
    rot = (-n).to_track_quat("Y", "Z").to_euler()
    pe = pe - n * 0.03
    # domino-mask patch around each eye (wider than the white, slightly flared outwards)
    C.sphere(pe - n * 0.02 + Vector((s * 0.02, 0, 0.005)), (0.15, 0.04, 0.165), MASK, parent=headP, rot=rot)
    C.sphere(pe, (0.10, 0.05, 0.125), WHITE, parent=headP, rot=rot)
    pc = pe + n * 0.04 + Vector((-s * 0.006, 0, -0.012))
    C.sphere(pc, (0.068, 0.03, 0.088), IRIS, parent=headP, rot=rot)
    C.sphere(pc + n * 0.012 + Vector((0, 0, -0.004)), (0.045, 0.025, 0.06), PUPIL, parent=headP, rot=rot)
    C.sphere(pc + n * 0.03 + Vector((0.025, 0, 0.032)), (0.022, 0.015, 0.022), WHITE, parent=headP, rot=rot)

# cheeks + smile
for s in (1, -1):
    pb = C.on_ellipsoid(HC, HR, s * 0.25, -0.13)
    C.sphere(pb, (0.06, 0.02, 0.035), BLUSH, parent=headP, rot=C.face_rot(HC, HR, pb))
pm = C.on_ellipsoid(HC, HR, 0, -0.2)
sm = C.torus(pm + Vector((0, 0.01, 0.035)), 0.06, 0.016, MOUTH, rot=(math.radians(90), 0, 0))
import bmesh
bm = bmesh.new(); bm.from_mesh(sm.data)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.012], context="VERTS")  # keep lower arc
bm.to_mesh(sm.data); bm.free()
sm.rotation_euler = C.face_rot(HC, HR, pm); sm.rotation_euler.x += math.radians(90)
C._finish(sm, None, headP, False, "smile")

# hair: a cap cut by a tilted plane (high at the forehead, low at the nape) + spikes
cap = C.sphere((0, 0.015, 1.265), (0.448, 0.425, 0.412), HAIR, seg=48, rings=24)
bm = bmesh.new(); bm.from_mesh(cap.data)
def keep(v):   # object-space coords are unit-sphere scaled; convert to world offset
    y = v.co.y * 0.425 + 0.015; z = v.co.z * 0.412 + 1.265
    return z > 1.25 - 0.50 * y
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v)], context="VERTS")
bm.to_mesh(cap.data); bm.free()
sol = cap.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.03; sol.offset = 1
C._finish(cap, None, headP, True, "hairCap")

def spike(base, direction, r, length, parent=headP):
    d = Vector(direction).normalized()
    c = C.cone(Vector(base) + d * (length / 2), r, 0.0, length, HAIR, parent=None, verts=16)
    c.rotation_mode = "QUATERNION"; c.rotation_quaternion = d.to_track_quat("Z", "Y")
    return C._finish(c, None, parent, True, None)

# fringe: short tufts sweeping down over the forehead, stopping above the mask
for x, dz, tilt in ((-0.27, -0.02, -0.4), (-0.10, 0.02, -0.12), (0.08, 0.02, 0.15), (0.25, -0.02, 0.4)):
    base = C.on_ellipsoid((0, 0.015, 1.265), (0.45, 0.43, 0.415), x, 0.235 + dz)
    spike(base - Vector((0, -0.03, 0.0)), (tilt * 0.7, -0.35, -0.94), 0.075, 0.12)
# crown spikes (read nicely from the top-down camera)
for base, d, r, l in (((0.02, 0.0, 1.62), (0.1, -0.3, 1), 0.11, 0.17),
                      ((-0.2, -0.05, 1.57), (-0.5, -0.3, 0.8), 0.09, 0.11),
                      ((0, 0.22, 1.56), (0, 0.7, 0.7), 0.12, 0.12)):
    spike(base, d, r, l)

# ---------------------------------------------------------------- cape (procedural cloth)
NU, NV = 24, 14
def cape_fn(phase_sway=0.0, lift=0.0, wave=0.0):
    def fn(u, v):
        th_max = math.radians(92 - 30 * v)
        th = (u - 0.5) * 2 * th_max
        R = 0.25 + 0.13 * v + 0.03 * v * math.cos(u * 2 * math.pi * 2.5 + wave)
        x = R * math.sin(th) * (1 + 0.15 * v)
        y = R * math.cos(th) * 0.9 + 0.05 + 0.10 * v * v + lift * v * v
        z = 0.87 - 0.74 * v + lift * 0.35 * v * v
        x += phase_sway * 0.06 * v * v
        return (x, y, z)
    return fn

verts, faces = C.cloth_grid(NU, NV, cape_fn())
cape = C.mesh_obj("cape", verts, faces, CAPE)
cape.data.materials.append(CAPE_IN)
sol = cape.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.045; sol.offset = 0
sol.material_offset = 1; sol.use_rim = True
sub = cape.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = 1
C._finish(cape, None, body, True, None)
# collar clasp
for s in (1, -1):
    C.sphere((s * 0.22, -0.06, 0.84), 0.045, GOLD, parent=body)

# ---------------------------------------------------------------- pose + render
HEAD_UP = -10   # tip the face up toward the high camera so eyes read
def pose(phase):
    swing, bob, sway = C.walk_curves(phase)
    walking = phase is not None
    body.location.z = 0.045 * bob
    body.rotation_euler = (math.radians(4 if walking else 0), math.radians(3 * sway), 0)
    hipL.rotation_euler.x = math.radians(-32 * swing)
    hipR.rotation_euler.x = math.radians(32 * swing)
    shL.rotation_euler = (math.radians(36 * swing), math.radians(-6), 0)
    shR.rotation_euler = (math.radians(-36 * swing), math.radians(6), 0)
    headP.rotation_euler = (math.radians(HEAD_UP - (3 * bob if walking else 0)), 0, math.radians(2 * sway))
    wave = (phase or 0.0) * 2 * math.pi
    C.update_grid(cape, NU, NV, cape_fn(phase_sway=-sway, lift=(0.10 + 0.05 * bob) if walking else 0.0,
                                        wave=wave))

C.add_key_light()
C.char_camera(C.CHAR_FRAME)
C.outline()
C.render_character("hero", root, pose, opts)
