"""Shared toolkit for the Kaiditya sprite pipeline (Blender 5.1, headless).

Everything an asset script needs:
  * palette   - game colours (mirrors Sources/Game/Theme.swift Palette), sRGB -> linear
  * toon()    - flat 3-band toon material (Diffuse -> Shader to RGB -> constant ramp)
                + procedural cool rim light, output as Emission so bands stay flat
  * parts     - sphere / box / cylinder / cone / torus / custom-mesh helpers with pivots
  * rig       - orthographic camera (character 3/4 view or straight-down vehicle view),
                warm key sun from screen top-left, Freestyle ink outline
  * render    - 8-direction x frame loops writing 2x-supersampled PNGs to a raw dir;
                tools/finish.py downsamples them into Resources/Sprites and builds sheets.

Conventions
  * World units: 1 unit ~= 29 game points. Characters stand on z=0 at the origin and face -Y
    (towards the camera) at yaw 0 == direction "s".
  * Pixel density is identical for every asset: PX_PER_UNIT final pixels per unit.
"""
import bpy, bmesh, math, os, sys, time
from mathutils import Vector, Matrix, Euler

# ----------------------------------------------------------------------------- args
def script_args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

def parse_opts():
    """--out DIR (raw render dir), --quick (only s/e dirs, idle), --dirs s,e,..."""
    a = script_args()
    opts = {"out": None, "quick": False, "dirs": None}
    i = 0
    while i < len(a):
        if a[i] == "--out": opts["out"] = a[i + 1]; i += 1
        elif a[i] == "--quick": opts["quick"] = True
        elif a[i] == "--dirs": opts["dirs"] = a[i + 1].split(","); i += 1
        i += 1
    return opts

# ----------------------------------------------------------------------------- constants
SS = 2                          # supersample factor (render at SS x final size)
CHAR_FRAME = 256                # final px for hero / minion / NPC frames
CHAR_ORTHO = 2.2                # ortho scale (world units across) for a CHAR_FRAME canvas
PX_PER_UNIT = CHAR_FRAME / CHAR_ORTHO   # ~116 final px per world unit, shared by ALL assets
CAM_TILT = 55.0                 # degrees from straight-down (Blender camera X rotation)
ANCHOR_Y = 0.18                 # feet/ground origin sits 18% up from the bottom of the frame

# Direction order used everywhere (yaw is CCW around +Z; model faces -Y == "s").
DIRECTIONS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
DIR_YAW = {"s": 0, "se": 45, "e": 90, "ne": 135, "n": 180, "nw": 225, "w": 270, "sw": 315}
SHEET_ORDER = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]   # order promised in README

# ----------------------------------------------------------------------------- colour
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rgb(r, g, b):
    """sRGB 0..1 floats (as used by SKColor) -> linear tuple."""
    return (srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b))

def hexc(h):
    h = h.lstrip("#")
    return rgb(*[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

# Mirrors Theme.swift Palette (sRGB), plus a few extras used by the models.
P = {
    "heroBlue": rgb(0.20, 0.45, 0.95),
    "heroRed":  rgb(0.94, 0.28, 0.30),
    "heroSkin": rgb(0.98, 0.80, 0.66),
    "heroHair": rgb(0.36, 0.23, 0.15),     # a touch lighter than Palette.heroHair so it reads in 3D
    "mask":     rgb(0.10, 0.20, 0.52),
    "villain":  rgb(0.32, 0.22, 0.45),
    "villainFur": rgb(0.40, 0.26, 0.50),
    "minion":   rgb(0.55, 0.30, 0.62),
    "energy":   rgb(1.00, 0.82, 0.25),
    "crystal":  rgb(0.30, 0.92, 0.85),
    "ink":      rgb(0.10, 0.12, 0.18),
    "white":    rgb(0.97, 0.97, 0.98),
    "glass":    rgb(0.60, 0.85, 0.95),
    "tyre":     rgb(0.14, 0.14, 0.16),
    "metal":    rgb(0.55, 0.57, 0.62),
    "wood":     rgb(0.62, 0.42, 0.26),
}
INK_SRGB = (0.10, 0.12, 0.18)
INK_LIN = rgb(*INK_SRGB)

def scale_col(c, k):
    return tuple(max(0.0, min(1.0, x * k)) for x in c)

def mix_col(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))

# ----------------------------------------------------------------------------- scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()   # cached materials die with the old scene
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except TypeError:
        pass
    sc.eevee.taa_render_samples = 16
    world = bpy.data.worlds.new("world")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0, 0, 0, 1)   # no ambient: bands come from the key only
    bg.inputs["Strength"].default_value = 0.0
    return sc

# ----------------------------------------------------------------------------- toon material
KEY_DIR = Vector((-0.55, -0.40, 0.75)).normalized()   # towards the key light (screen top-left, high)
RIM_DIR = Vector((0.75, 0.35, 0.55)).normalized()     # cool rim from screen right / behind
SHADOW_TINT = (0.52, 0.50, 0.78)                      # shadows go cool purple, not grey
MID_TINT = (0.80, 0.78, 0.92)
RIM_COL = rgb(0.72, 0.86, 1.0)
_mats = {}

def toon(name, col, rim=0.45, hi=0.10, shadow=None, flat=False, hi_at=0.90):
    """Flat 3-band toon material.  col: linear RGB.  hi: highlight lift for the top band.
    flat=True -> pure emission, no shading (eye whites/pupils/glows)."""
    key = (name, tuple(round(c, 4) for c in col), rim, hi, flat, hi_at)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    if flat:
        emit.inputs["Color"].default_value = (*col, 1)
        _mats[key] = m
        return m

    sh = shadow or tuple(c * t for c, t in zip(col, SHADOW_TINT))
    mid = tuple(c * t for c, t in zip(col, MID_TINT))
    lit = col
    top = tuple(min(1.0, c * (1 + 2.2 * hi) + 0.02 * hi) for c in col)   # brighter, keeps saturation

    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs["Color"], bw.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position = 0.0; els[0].color = (*sh, 1)
    els[1].position = 0.10; els[1].color = (*mid, 1)
    e = els.new(0.42); e.color = (*lit, 1)
    e = els.new(hi_at); e.color = (*top, 1)
    nt.links.new(bw.outputs[0], ramp.inputs["Fac"])

    # Procedural rim: grazing-angle mask * facing the rim direction (world space, so it stays
    # put while the character yaws - consistent lighting across all 8 directions).
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    gt = nt.nodes.new("ShaderNodeMath"); gt.operation = "GREATER_THAN"
    gt.inputs[1].default_value = 0.62
    nt.links.new(lw.outputs["Facing"], gt.inputs[0])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = RIM_DIR
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    gt2 = nt.nodes.new("ShaderNodeMath"); gt2.operation = "GREATER_THAN"
    gt2.inputs[1].default_value = 0.25
    nt.links.new(dot.outputs["Value"], gt2.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
    nt.links.new(gt.outputs[0], mul.inputs[0]); nt.links.new(gt2.outputs[0], mul.inputs[1])
    mul2 = nt.nodes.new("ShaderNodeMath"); mul2.operation = "MULTIPLY"
    mul2.inputs[1].default_value = rim
    nt.links.new(mul.outputs[0], mul2.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "SCREEN"
    nt.links.new(mul2.outputs[0], mix.inputs["Factor"])
    nt.links.new(ramp.outputs["Color"], mix.inputs[6])          # A
    mix.inputs[7].default_value = (*RIM_COL, 1)                  # B
    nt.links.new(mix.outputs[2], emit.inputs["Color"])
    _mats[key] = m
    return m

# ----------------------------------------------------------------------------- objects
def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if parent is not None:
        o.parent = parent
    return o

def _finish(o, mat, parent, smooth, name):
    if name:
        o.name = name
    if mat is not None:
        o.data.materials.append(mat)
    if smooth and hasattr(o.data, "polygons"):
        for p in o.data.polygons:
            p.use_smooth = True
    if parent is not None:
        # parts are authored in WORLD rest-pose coordinates; keep them there under the pivot
        bpy.context.view_layer.update()
        mw = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = mw
    return o

def sphere(loc, scale, mat, parent=None, rot=(0, 0, 0), seg=32, rings=16, name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc,
                                         rotation=rot)
    o = bpy.context.object
    o.scale = scale if hasattr(scale, "__len__") else (scale,) * 3
    return _finish(o, mat, parent, True, name)

def box(loc, size, mat, parent=None, rot=(0, 0, 0), bevel=0.05, seg=3, subsurf=0, name=None,
        smooth=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = seg
        m.limit_method = "NONE"
    if subsurf:
        m = o.modifiers.new("sub", "SUBSURF"); m.levels = subsurf; m.render_levels = subsurf
    return _finish(o, mat, parent, smooth, name)

def cylinder(loc, radius, depth, mat, parent=None, rot=(0, 0, 0), verts=32, name=None,
             smooth=True, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.object
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL"); m.width = bevel; m.segments = 2
        m.limit_method = "ANGLE"
    if smooth:
        o.data.set_sharp_from_angle(angle=math.radians(40)) if hasattr(o.data, "set_sharp_from_angle") else None
    return _finish(o, mat, parent, smooth, name)

def cone(loc, r1, r2, depth, mat, parent=None, rot=(0, 0, 0), verts=24, name=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=loc, rotation=rot)
    o = bpy.context.object
    return _finish(o, mat, parent, True, name)

def torus(loc, R, r, mat, parent=None, rot=(0, 0, 0), scale=(1, 1, 1), name=None,
          major_seg=48, minor_seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot,
                                     major_segments=major_seg, minor_segments=minor_seg)
    o = bpy.context.object
    o.scale = scale
    return _finish(o, mat, parent, True, name)

def mesh_obj(name, verts, faces, mat, parent=None, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return _finish(o, mat, parent, smooth, None)

def text(body, loc, size, mat, parent=None, rot=(0, 0, 0), extrude=0.01):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = body; cu.size = size; cu.extrude = extrude
    cu.align_x = "CENTER"; cu.align_y = "CENTER"
    o = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = rot
    o.data.materials.append(mat)
    if parent is not None:
        bpy.context.view_layer.update()
        mw = o.matrix_world.copy(); o.parent = parent; o.matrix_world = mw
    return o

def on_ellipsoid(center, radii, dx, dz, front=-1):
    """Point on the front (-Y) surface of an ellipsoid at local offsets dx, dz."""
    cx, cy, cz = center; rx, ry, rz = radii
    t = 1 - (dx / rx) ** 2 - (dz / rz) ** 2
    y = ry * math.sqrt(max(t, 0.0))
    return Vector((cx + dx, cy + front * y, cz + dz))

def face_rot(center, radii, p):
    """Euler that makes a flat decal at p follow the ellipsoid surface normal."""
    n = Vector(((p.x - center[0]) / radii[0] ** 2, (p.y - center[1]) / radii[1] ** 2,
                (p.z - center[2]) / radii[2] ** 2)).normalized()
    # decal's thin axis is local Y; point local -Y along n
    q = (-n).to_track_quat("Y", "Z")
    return q.to_euler()

# ----------------------------------------------------------------------------- cloth strip
def cloth_grid(nu, nv, fn):
    """Build verts/faces for a (nu x nv) grid; fn(u, v) -> (x, y, z)."""
    verts = [fn(i / (nu - 1), j / (nv - 1)) for j in range(nv) for i in range(nu)]
    faces = []
    for j in range(nv - 1):
        for i in range(nu - 1):
            a = j * nu + i
            faces.append((a, a + 1, a + nu + 1, a + nu))
    return verts, faces

def update_grid(obj, nu, nv, fn):
    me = obj.data
    for j in range(nv):
        for i in range(nu):
            me.vertices[j * nu + i].co = fn(i / (nu - 1), j / (nv - 1))
    me.update()

# ----------------------------------------------------------------------------- rig
def look_quat(direction):
    return Vector(direction).normalized().to_track_quat("Z", "Y")

def add_key_light(strength=math.pi, angle_deg=3.0):
    d = bpy.data.lights.new("key", "SUN")
    d.energy = strength
    d.color = (1.0, 0.96, 0.90)
    d.angle = math.radians(angle_deg)
    o = bpy.data.objects.new("key", d)
    bpy.context.scene.collection.objects.link(o)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = look_quat(KEY_DIR)
    return o

def char_camera(frame_px, ortho=None, tilt=CAM_TILT, anchor=ANCHOR_Y):
    """3/4 orthographic camera; world origin lands at (0.5, anchor) of the frame."""
    sc = bpy.context.scene
    ortho = ortho or CHAR_ORTHO * frame_px / CHAR_FRAME
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = ortho
    cd.clip_start = 0.1; cd.clip_end = 100
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam)
    t = math.radians(tilt)
    up = Vector((0, math.cos(t), math.sin(t)))
    fwd = Vector((0, math.sin(t), -math.cos(t)))
    center = up * ((0.5 - anchor) * ortho)
    cam.location = center - fwd * 20
    cam.rotation_euler = (t, 0, 0)
    sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = frame_px * SS
    return cam

def topdown_camera(w_units, h_units, tilt=0.0):
    """Straight-down camera framing a w x h (world units) rectangle centred on the origin.
    Canvas size follows PX_PER_UNIT so vehicles share the characters' pixel density."""
    sc = bpy.context.scene
    wpx = int(math.ceil(w_units * PX_PER_UNIT / 8.0) * 8)
    hpx = int(math.ceil(h_units * PX_PER_UNIT / 8.0) * 8)
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"
    cd.ortho_scale = max(wpx, hpx) / PX_PER_UNIT
    cd.clip_start = 0.1; cd.clip_end = 100
    cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam)
    t = math.radians(tilt)
    cam.location = (0, -20 * math.sin(t), 20 * math.cos(t))
    cam.rotation_euler = (t, 0, 0)
    sc.camera = cam
    sc.render.resolution_x = wpx * SS
    sc.render.resolution_y = hpx * SS
    return cam, (wpx, hpx)

def outline(px=2.2, inner_px=1.3):
    """Freestyle ink: thick external contour + thinner inner silhouettes. px are FINAL pixels."""
    sc = bpy.context.scene
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    vl = sc.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    fs.crease_angle = math.radians(100)
    while len(fs.linesets):
        fs.linesets.remove(fs.linesets[0])

    def lineset(name, thick, **sel):
        ls = fs.linesets.new(name)
        ls.select_by_visibility = True
        ls.visibility = "VISIBLE"
        ls.select_by_edge_types = True
        for k in ("select_silhouette", "select_border", "select_crease", "select_contour",
                  "select_external_contour", "select_material_boundary", "select_edge_mark"):
            setattr(ls, k, sel.get(k, False))
        st = bpy.data.linestyles.new(name)
        st.color = INK_LIN
        st.thickness = thick * SS
        st.thickness_position = "CENTER"
        st.caps = "ROUND"
        ls.linestyle = st
        return ls

    lineset("outer", px, select_external_contour=True)
    lineset("inner", inner_px, select_silhouette=True, select_border=True, select_crease=True)

# ----------------------------------------------------------------------------- render
def render_to(path):
    sc = bpy.context.scene
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def default_raw_dir(asset):
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(here, "..", ".cache", "raw", asset)

def render_character(asset, root, pose, opts, walk_frames=4, idle=True, extra=None):
    """root: empty whose Z rotation is the facing yaw.  pose(phase or None) poses the rig
    (phase in [0,1) for walk frames, None for idle).  Writes <asset>_idle_<dir>.png and
    <asset>_walk_<dir>_<i>.png into the raw dir."""
    out = opts["out"] or default_raw_dir(asset)
    dirs = opts["dirs"] or (["s", "e", "n", "se"] if opts["quick"] else DIRECTIONS)
    t0 = time.time(); n = 0
    root.rotation_mode = "XYZ"
    for d in dirs:
        root.rotation_euler = (0, 0, math.radians(DIR_YAW[d]))
        if idle:
            pose(None)
            render_to(os.path.join(out, f"{asset}_idle_{d}.png")); n += 1
        if opts["quick"]:
            continue
        for i in range(walk_frames):
            pose(i / walk_frames)
            render_to(os.path.join(out, f"{asset}_walk_{d}_{i}.png")); n += 1
    dt = time.time() - t0
    print(f"[sprites] {asset}: {n} frames in {dt:.1f}s ({dt / max(n, 1):.2f}s/frame) -> {out}")

def walk_curves(phase):
    """Shared 4-frame walk timing. Returns (swing -1..1, bob 0..1, sway -1..1)."""
    if phase is None:
        return 0.0, 0.0, 0.0
    a = phase * 2 * math.pi
    swing = math.cos(a)             # +1 left leg forward (frame 0), -1 right leg forward (frame 2)
    bob = abs(math.sin(a))          # high on the passing frames (1, 3)
    sway = math.sin(a)
    return swing, bob, sway

# ----------------------------------------------------------------------------- reusable parts
def cone_dir(base, direction, r, length, mat, parent=None, verts=16, r2=0.0):
    """Cone whose base sits at `base` and tip points along `direction` (spikes, claws, ears)."""
    d = Vector(direction).normalized()
    c = cone(Vector(base) + d * (length / 2), r, r2, length, mat, parent=None, verts=verts)
    c.rotation_mode = "QUATERNION"; c.rotation_quaternion = d.to_track_quat("Z", "Y")
    return _finish(c, None, parent, True, None)

def ellipsoid_normal(center, radii, p):
    return Vector(((p.x - center[0]) / radii[0] ** 2, (p.y - center[1]) / radii[1] ** 2,
                   (p.z - center[2]) / radii[2] ** 2)).normalized()

def decal(center, radii, dx, dz, size, mat, parent, push=0.0):
    """Flattened ellipsoid lying on the front of an ellipsoid (eyes, blush, badges)."""
    p = on_ellipsoid(center, radii, dx, dz)
    n = ellipsoid_normal(center, radii, p)
    p = p + n * push
    return sphere(p, size, mat, parent=parent, rot=(-n).to_track_quat("Y", "Z").to_euler()), p, n

def cartoon_eyes(center, radii, dx, dz, parent, white, pupil, scale=1.0, pupil_col=None):
    """Simple big friendly eyes (white + dark pupil + highlight) for NPCs."""
    for s in (1, -1):
        _, p, n = decal(center, radii, s * dx, dz, (0.085 * scale, 0.035, 0.11 * scale), white, parent,
                        push=-0.012)
        rot = (-n).to_track_quat("Y", "Z").to_euler()
        pc = p + n * 0.022 + Vector((0, 0, -0.012 * scale))
        sphere(pc, (0.055 * scale, 0.025, 0.07 * scale), pupil, parent=parent, rot=rot)
        sphere(pc + n * 0.02 + Vector((0.02 * scale, 0, 0.025 * scale)), (0.018 * scale, 0.012, 0.018 * scale),
               white, parent=parent, rot=rot)

class Cape:
    """Procedural cloth cape: a tapered, curved, solidified strip that wraps the back of the
    shoulders, flares out and gets thicker folds at the hem. Re-shaped every frame by pose()."""
    NU, NV = 24, 14

    def __init__(self, parent, mat, mat_in, top_z=0.87, length=0.74, r_top=0.25, r_grow=0.13,
                 back=0.05, flare=0.10, spread_top=92, spread_bot=62, thick=0.045, sx=1.0):
        self.k = dict(top_z=top_z, length=length, r_top=r_top, r_grow=r_grow, back=back, flare=flare,
                      spread_top=spread_top, spread_bot=spread_bot, sx=sx)
        v, f = cloth_grid(self.NU, self.NV, self.fn())
        o = mesh_obj("cape", v, f, mat)
        o.data.materials.append(mat_in)
        sol = o.modifiers.new("thick", "SOLIDIFY"); sol.thickness = thick; sol.offset = 0
        sol.material_offset = 1; sol.use_rim = True
        sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = 1
        self.obj = _finish(o, None, parent, True, None)

    def fn(self, sway=0.0, lift=0.0, wave=0.0):
        k = self.k
        def f(u, v):
            th_max = math.radians(k["spread_top"] + (k["spread_bot"] - k["spread_top"]) * v)
            th = (u - 0.5) * 2 * th_max
            R = k["r_top"] + k["r_grow"] * v + 0.03 * v * math.cos(u * 2 * math.pi * 2.5 + wave) * k["sx"]
            x = R * math.sin(th) * (1 + 0.15 * v) * k["sx"]
            y = R * math.cos(th) * 0.9 + k["back"] + k["flare"] * v * v + lift * v * v
            z = k["top_z"] - k["length"] * v + lift * 0.35 * v * v
            x += sway * 0.06 * v * v * k["sx"]
            return (x, y, z)
        return f

    def pose(self, phase, bob=0.0, sway=0.0):
        walking = phase is not None
        update_grid(self.obj, self.NU, self.NV,
                    self.fn(sway=-sway, lift=(0.10 + 0.05 * bob) * self.k["sx"] if walking else 0.0,
                            wave=(phase or 0.0) * 2 * math.pi))
