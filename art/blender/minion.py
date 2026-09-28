"""Static minion - boxy purple goon with big red-iris scanner eyes and a toothy snarl
(mirrors CharacterFactory.makeMinion). 8 dirs x (idle + 4-frame waddle), 256px.
Run: Blender -b -P minion.py -- [--out DIR] [--quick] [--dirs s,e]"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib, common as C
importlib.reload(C)
from mathutils import Vector

opts = C.parse_opts()
C.reset()

BODY = C.toon("minion", C.P["minion"])
BODY_D = C.toon("minionDark", C.scale_col(C.P["minion"], 0.62))
WHITE = C.toon("eyeWhite", C.P["white"], flat=True)
IRIS = C.toon("iris", C.rgb(1.0, 0.22, 0.20), flat=True)
PUPIL = C.toon("pupil", C.rgb(0.25, 0.02, 0.04), flat=True)
INK = C.toon("mouth", C.rgb(0.16, 0.06, 0.12), flat=True)
TEETH = C.toon("teeth", C.P["white"], rim=0.0)
METAL = C.toon("metal", C.P["metal"], hi=0.3)
BOLT = C.toon("bolt", C.P["energy"], hi=0.3)

root = C.empty("root")
body = C.empty("body", parent=root)
hipL = C.empty("hipL", (0.17, 0, 0.30), parent=body)
hipR = C.empty("hipR", (-0.17, 0, 0.30), parent=body)
shL = C.empty("shL", (0.40, 0, 0.78), parent=body)
shR = C.empty("shR", (-0.40, 0, 0.78), parent=body)

# stubby legs with round feet
for hip, x in ((hipL, 0.17), (hipR, -0.17)):
    C.sphere((x, 0, 0.22), (0.10, 0.10, 0.13), BODY_D, parent=hip)
    C.sphere((x, -0.04, 0.07), (0.12, 0.15, 0.08), BODY_D, parent=hip)

# the big square body/head (pillowy rounded cube)
BC, BS = (0, 0, 0.80), (0.86, 0.66, 0.90)
C.box(BC, BS, BODY, parent=body, bevel=0.2, seg=5)
# approximate the front surface as an ellipsoid for decals
FR = (0.44, 0.335, 0.46)

# stubby side arms
for sh, s in ((shL, 1), (shR, -1)):
    C.sphere((s * 0.49, 0, 0.72), (0.12, 0.10, 0.09), BODY, parent=sh, rot=(0, math.radians(-s * 25), 0))
    C.sphere((s * 0.58, -0.01, 0.64), (0.075, 0.075, 0.075), BODY_D, parent=sh)

# big scanner eyes
front_y = -0.335
for s in (1, -1):
    ex = s * 0.18
    C.sphere((ex, front_y + 0.01, 1.00), (0.155, 0.06, 0.155), WHITE, parent=body)
    C.sphere((ex - s * 0.01, front_y - 0.035, 0.99), (0.075, 0.03, 0.075), IRIS, parent=body)
    C.sphere((ex - s * 0.01, front_y - 0.055, 0.99), (0.032, 0.02, 0.032), PUPIL, parent=body)
    C.sphere((ex + 0.04, front_y - 0.065, 1.04), (0.025, 0.015, 0.025), WHITE, parent=body)
    # angry brow
    C.box((ex, front_y - 0.01, 1.17), (0.2, 0.06, 0.05), BODY_D, parent=body,
          rot=(0, math.radians(s * 16), 0), bevel=0.02)

# V nose + snarl with jagged teeth
C.cone_dir((0, front_y + 0.02, 0.86), (0, -1, -0.3), 0.045, 0.08, BODY_D, parent=body)
C.box((0, front_y + 0.005, 0.66), (0.44, 0.06, 0.17), INK, parent=body, bevel=0.03)
for i in range(5):
    x = -0.16 + i * 0.08
    C.cone_dir((x, front_y - 0.03, 0.74), (0, 0, -1), 0.033, 0.075, TEETH, parent=body, verts=8)
    C.cone_dir((x + 0.04, front_y - 0.03, 0.58), (0, 0, 1), 0.03, 0.065, TEETH, parent=body, verts=8)
# belly bolts
for x in (-0.13, 0, 0.13):
    C.sphere((x, front_y + 0.005, 0.46), (0.03, 0.02, 0.03), BODY_D, parent=body)
# little antenna with a bolt tip (reads from the top-down camera)
C.cylinder((0, 0.05, 1.33), 0.018, 0.18, METAL, parent=body)
C.sphere((0, 0.05, 1.44), 0.05, BOLT, parent=body)


def pose(phase):
    swing, bob, sway = C.walk_curves(phase)
    walking = phase is not None
    body.location.z = 0.04 * bob
    body.rotation_euler = (math.radians(3 if walking else 0), math.radians(6 * sway), 0)   # waddle
    hipL.rotation_euler.x = math.radians(-30 * swing)
    hipR.rotation_euler.x = math.radians(30 * swing)
    shL.rotation_euler = (math.radians(35 * swing), 0, 0)
    shR.rotation_euler = (math.radians(-35 * swing), 0, 0)


C.add_key_light()
C.char_camera(C.CHAR_FRAME)
C.outline()
C.render_character("minion", root, pose, opts)
