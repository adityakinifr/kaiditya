"""Environment helpers shared by props.py and tiles.py (on top of common.py).

  * add_ao_band()   - stepped (one flat step) violet ambient-occlusion band inside a C.toon material
  * glow()          - flat emissive material for lenses / cores (reserved-palette colours)
  * shadow_pass()   - Cycles shadow-catcher render: alpha-only cast + contact shadow (<name>_shadow)
  * use_gpu()       - Metal for Cycles when available

Shadow convention (graphics plan, section 3): cast shadows fall DOWN-RIGHT on screen, soft edge.
The PNG stores black RGB with the shadow in alpha (fully dark = 1); the game tints it violet
and draws it at ~0.4 alpha under the prop.
"""
import math
import bpy
from mathutils import Vector
import common as C

# Towards the shadow sun: from screen upper-left / behind, so shadows fall down-right (+x, -y).
# Horizontal/vertical ratio 0.6 -> a 1-unit tall prop throws a ~0.6-unit shadow.
SHADOW_SUN_DIR = Vector((-0.55, 0.30, 1.05)).normalized()


def use_gpu():
    try:
        p = bpy.context.preferences.addons["cycles"].preferences
        p.compute_device_type = "METAL"
        p.get_devices()
        for d in p.devices:
            d.use = True
        bpy.context.scene.cycles.device = "GPU"
    except Exception as e:  # CPU fallback is fine, just slower
        print("[envkit] GPU unavailable:", e)


def add_ao_band(mat, strength=0.30, dist=0.25, threshold=0.72, tint=None):
    """Insert a stepped ambient-occlusion band into a C.toon material (keeps it flat/toon).
    Crevices darker than `threshold` get multiplied by the cool violet shadow tint."""
    nt = mat.node_tree
    if any(n.type == "AMBIENT_OCCLUSION" for n in nt.nodes):
        return mat   # C.toon caches materials; don't double-insert
    emit = next(n for n in nt.nodes if n.type == "EMISSION")
    if emit.inputs["Color"].links:
        src = emit.inputs["Color"].links[0].from_socket
    else:  # flat material: wrap the constant colour in an RGB node
        rgbn = nt.nodes.new("ShaderNodeRGB")
        rgbn.outputs[0].default_value = emit.inputs["Color"].default_value
        src = rgbn.outputs[0]
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = dist
    ao.samples = 16
    step = nt.nodes.new("ShaderNodeMath"); step.operation = "LESS_THAN"
    step.inputs[1].default_value = threshold
    nt.links.new(ao.outputs["AO"], step.inputs[0])
    fac = nt.nodes.new("ShaderNodeMath"); fac.operation = "MULTIPLY"
    fac.inputs[1].default_value = strength
    nt.links.new(step.outputs[0], fac.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    nt.links.new(fac.outputs[0], mix.inputs["Factor"])
    nt.links.new(src, mix.inputs[6])
    mix.inputs[7].default_value = (*(tint or C.SHADOW_TINT), 1)
    nt.links.new(mix.outputs[2], emit.inputs["Color"])
    return mat


def tmat(name, col, rim=0.35, hi=0.12, ao=0.30, ao_dist=0.22, **kw):
    """Toon + AO band in one call (the standard prop material)."""
    m = C.toon(name, col, rim=rim, hi=hi, **kw)
    if ao:
        add_ao_band(m, strength=ao, dist=ao_dist)
    return m


def glow(name, col, boost=1.0):
    """Unshaded emissive colour (lenses, energy cores). col is linear RGB."""
    return C.toon(name, tuple(min(1.0, c * boost) for c in col), flat=True)


def _override_material():
    m = bpy.data.materials.get("_shadow_caster")
    if m is None:
        m = bpy.data.materials.new("_shadow_caster")
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (0.5, 0.5, 0.5, 1)
    return m


def shadow_pass(path, casters, samples=64, sun_angle_deg=7.0, sky=0.35, floor_size=14.0):
    """Re-render the current camera in Cycles with a shadow-catcher floor.  The casters are
    hidden from the camera (so only their shadow remains) and rendered with a plain diffuse
    override material so emissive parts don't light the floor.  Scene is restored after."""
    sc = bpy.context.scene
    prev_engine = sc.render.engine
    prev_fs = sc.render.use_freestyle
    sc.render.engine = "CYCLES"
    use_gpu()
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.use_freestyle = False
    sc.render.film_transparent = True
    sc.render.filter_size = 1.5

    bpy.ops.mesh.primitive_plane_add(size=floor_size, location=(0, 0, 0))
    floor = bpy.context.object
    floor.is_shadow_catcher = True

    sun_d = bpy.data.lights.new("shadow_sun", "SUN")
    sun_d.energy = 3.0
    sun_d.angle = math.radians(sun_angle_deg)
    sun = bpy.data.objects.new("shadow_sun", sun_d)
    sc.collection.objects.link(sun)
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = C.look_quat(SHADOW_SUN_DIR)

    # other lights (the toon key) must not add a second shadow
    hidden_lights = []
    for o in sc.objects:
        if o.type == "LIGHT" and o is not sun:
            o.hide_render = True
            hidden_lights.append(o)

    for o in casters:
        o.visible_camera = False
    vl = sc.view_layers[0]
    vl.material_override = _override_material()
    w = sc.world.node_tree.nodes["Background"]
    w.inputs["Color"].default_value = (1, 1, 1, 1)
    w.inputs["Strength"].default_value = sky   # sky occlusion -> soft contact shadow

    C.render_to(path)

    vl.material_override = None
    bpy.data.objects.remove(floor)
    bpy.data.objects.remove(sun)
    for o in hidden_lights:
        o.hide_render = False
    for o in casters:
        o.visible_camera = True
    w.inputs["Strength"].default_value = 0.0
    sc.render.engine = prev_engine
    sc.render.use_freestyle = prev_fs


def mesh_objects(root=None):
    """All mesh / curve objects in the scene (optionally only descendants of root)."""
    out = []
    for o in bpy.context.scene.objects:
        if o.type not in ("MESH", "CURVE", "FONT"):
            continue
        if root is not None:
            p = o.parent
            while p is not None and p is not root:
                p = p.parent
            if p is None:
                continue
        out.append(o)
    return out
