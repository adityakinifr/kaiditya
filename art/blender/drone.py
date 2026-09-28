"""Drone minion (dronesStyle levels) - floating white ghost with hypnotic spiral eyes and an
"O" mouth (mirrors CharacterFactory.makeDrone). 8 dirs x (idle + 4-frame float), 256px.
Run: Blender -b -P drone.py -- [--out DIR] [--quick] [--dirs s,e]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, common as C
importlib.reload(C)
from mathutils import Vector

opts = C.parse_opts()
C.reset()

GHOST = C.toon("ghost", C.rgb(0.95, 0.95, 0.97), shadow=C.rgb(0.62, 0.64, 0.82), rim=0.6)
INK = C.toon("ink", C.rgb(0.10, 0.10, 0.16), flat=True)
WHITE = C.toon("white", C.P["white"], flat=True)
MOUTH = C.toon("mouth", C.rgb(0.22, 0.08, 0.14), flat=True)
BLUSH = C.toon("blush", C.rgb(1.0, 0.55, 0.6), rim=0.0)

root = C.empty("root")
body = C.empty("body", (0, 0, 0.0), parent=root)
FLOAT = 0.28   # hovers this high above its ground origin (game draws the shadow)

# lathe profile: round head flowing into a skirt with a scalloped hem
N_AROUND, N_UP = 40, 22
def prof(t):     # t 0 = hem, 1 = crown -> (radius, z)
    z = FLOAT + t * 1.05
    if t > 0.45:
        a = (t - 0.45) / 0.55 * (math.pi / 2)
        r = 0.44 * math.cos(a)
    else:
        r = 0.44 + (0.45 - t) * 0.18
    return r, z
verts, faces = [], []
for j in range(N_UP):
    t = j / (N_UP - 1)
    r, z = prof(t)
    for i in range(N_AROUND):
        a = i / N_AROUND * 2 * math.pi
        zz = z + (0.06 * math.cos(a * 6) if j == 0 else 0)          # scallops
        verts.append((r * math.cos(a), r * math.sin(a), zz))
for j in range(N_UP - 1):
    for i in range(N_AROUND):
        a = j * N_AROUND + i; b = j * N_AROUND + (i + 1) % N_AROUND
        faces.append((a, b, b + N_AROUND, a + N_AROUND))
g = C.mesh_obj("ghost", verts, faces, GHOST, parent=None)
sol = g.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.03
sub = g.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = 1
C._finish(g, None, body, True, None)

# face: approximate the head as an ellipsoid
HC, HR = (0, 0, FLOAT + 0.47), (0.44, 0.44, 0.58)
for s in (1, -1):
    _, p, n = C.decal(HC, HR, s * 0.155, 0.2, (0.105, 0.03, 0.12), INK, body, push=-0.005)
    rot = (-n).to_track_quat("Y", "Z").to_euler()
    ring = C.torus(p + n * 0.026, 0.062, 0.013, WHITE, parent=None, rot=(math.radians(90), 0, 0),
                   minor_seg=6)
    ring.rotation_mode = "QUATERNION"; ring.rotation_quaternion = n.to_track_quat("Z", "Y")
    C._finish(ring, None, body, True, None)
    C.sphere(p + n * 0.026, (0.026, 0.012, 0.026), WHITE, parent=body, rot=rot)
    C.decal(HC, HR, s * 0.28, 0.06, (0.06, 0.02, 0.035), BLUSH, body, push=-0.005)
C.decal(HC, HR, 0, 0.0, (0.06, 0.03, 0.08), MOUTH, body, push=0.0)
# little stubby arms
armL = C.sphere((0.43, -0.02, FLOAT + 0.42), (0.09, 0.08, 0.13), GHOST, parent=body,
                rot=(0, math.radians(-35), 0))
armR = C.sphere((-0.43, -0.02, FLOAT + 0.42), (0.09, 0.08, 0.13), GHOST, parent=body,
                rot=(0, math.radians(35), 0))


def pose(phase):
    walking = phase is not None
    a = (phase or 0.0) * 2 * math.pi
    body.location.z = 0.05 * math.sin(a) if walking else 0.0
    body.rotation_euler = (math.radians(10 if walking else 0), math.radians(5 * math.sin(a) if walking else 0), 0)


C.add_key_light()
C.char_camera(C.CHAR_FRAME)
C.outline()
C.render_character("drone", root, pose, opts)
