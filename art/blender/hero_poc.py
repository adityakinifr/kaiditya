# Headless proof of concept: chibi Kaiditya hero, toon-shaded, rendered top-down 3/4 for a sprite.
# Run: Blender -b -P hero.py -- OUT.png [angle_deg]
import bpy, math, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/hero.png"
YAW = float(argv[1]) if len(argv) > 1 else 0.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, rgb, rough=0.55, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m

def srgb(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

BLUE, RED, YELLOW = mat("suit", srgb("3A6FF0")), mat("cape", srgb("E0414B")), mat("gold", srgb("FFC933"), 0.3)
SKIN, HAIR, MASK = mat("skin", srgb("F2C9A0")), mat("hair", srgb("4A2E1E")), mat("mask", srgb("1F3C8F"))
WHITE, BOOT = mat("eye", (1, 1, 1), 0.2), mat("boot", srgb("C9303A"))

def add(obj, m, smooth=True):
    obj.data.materials.append(m)
    if smooth: bpy.ops.object.shade_smooth()
    return obj

def sphere(loc, scale, m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=loc)
    o = bpy.context.object; o.scale = scale; return add(o, m)

rig = bpy.data.objects.new("rig", None); scene.collection.objects.link(rig)
def parent(o): o.parent = rig; return o

# Body (squashed capsule), belt, emblem
parent(sphere((0, 0, 0.62), (0.34, 0.28, 0.42), BLUE))
bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.045, location=(0, 0, 0.48))
parent(add(bpy.context.object, YELLOW))
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.11, depth=0.04, location=(0, -0.27, 0.72), rotation=(math.pi/2, 0, 0))
parent(add(bpy.context.object, YELLOW, smooth=False))
# Legs / boots
for x in (-0.13, 0.13):
    parent(sphere((x, 0, 0.14), (0.11, 0.13, 0.15), BOOT))
# Arms
for x in (-0.36, 0.36):
    parent(sphere((x, 0, 0.62), (0.09, 0.09, 0.22), BLUE))
    parent(sphere((x, -0.02, 0.40), (0.08, 0.08, 0.08), SKIN))
# Head (big chibi head), hair cap, mask band, eyes
parent(sphere((0, 0, 1.30), (0.40, 0.38, 0.38), SKIN))
hair = parent(sphere((0, 0.05, 1.42), (0.42, 0.40, 0.30), HAIR))
parent(sphere((0, -0.02, 1.30), (0.405, 0.385, 0.11), MASK))
for x in (-0.14, 0.14):
    parent(sphere((x, -0.35, 1.31), (0.075, 0.03, 0.05), WHITE))
# Cape: curved plane behind the body
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0.30, 0.62))
cape = bpy.context.object; cape.scale = (0.62, 0.9, 1); cape.rotation_euler = (math.radians(80), 0, 0)
bpy.ops.object.modifier_add(type="SIMPLE_DEFORM"); cape.modifiers[-1].deform_method = "BEND"
cape.modifiers[-1].angle = math.radians(70); cape.modifiers[-1].deform_axis = "Y"
bpy.ops.object.modifier_add(type="SOLIDIFY"); cape.modifiers[-1].thickness = 0.03
parent(add(cape, RED))
rig.rotation_euler = (0, 0, math.radians(YAW))

# Camera: orthographic, looking down at ~55 degrees (matches top-down 3/4 game view)
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 2.3
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
tilt = math.radians(55)
cam.location = Vector((0, -6 * math.sin(tilt), 0.75 + 6 * math.cos(tilt)))
cam.rotation_euler = (tilt, 0, 0)
scene.camera = cam

# Lights: warm key, cool rim
def light(kind, loc, energy, rgb, rot=(0, 0, 0)):
    d = bpy.data.lights.new(kind, kind); d.energy = energy; d.color = rgb
    o = bpy.data.objects.new(kind, d); o.location = loc; o.rotation_euler = rot
    scene.collection.objects.link(o); return o
light("SUN", (3, -3, 5), 4.0, (1.0, 0.95, 0.88), (math.radians(40), math.radians(20), math.radians(30)))
light("SUN", (-3, 3, 2), 2.5, (0.6, 0.75, 1.0), (math.radians(-60), math.radians(-30), 0))
world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.4, 0.5, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

# Render: EEVEE, transparent, Freestyle ink outline for a cartoon read at small sizes
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
scene.view_settings.view_transform = "Standard"
scene.render.use_freestyle = True
fs = scene.view_layers[0].freestyle_settings
ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("ink")
if ls.linestyle is None: ls.linestyle = bpy.data.linestyles.new("ink")
ls.linestyle.color = (0.08, 0.06, 0.12); ls.linestyle.thickness = 3.0
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
