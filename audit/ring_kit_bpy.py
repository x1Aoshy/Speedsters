"""Super Sonic vs Dr. Eggman live event: Sonic's GOLD RING (Blender 4.5, headless, deterministic).

2026-09-26: when Dr. Eggman is defeated he drops a rain of gold rings the players collect; the client clones
ReplicatedStorage.SuperSonicEventAssets.Meshes.Ring (its own fallback ring until the owner has imported this kit).
A SEPARATE mini kit: the owner already imported EventKit.rbxm (audit/event_kit_bpy.py, 11 pieces), which this
script never touches (its manifest, FBX and pieces stay exactly as imported).

  * Ring   the owner's reference (reference/ring_reference.webp): a SMOOTH, glossy, polished gold torus, a round
           thick tube (not faceted, not flattened) whose diameter is a quarter of the ring's, the hole half of it.
           2.40 studs across, a 0.60 tube, a 1.20 hole; 64 x 24 segments (3072 triangles) so the silhouette and
           the highlights stay round up close; every vertex carries the torus's exact normal (custom normals, no
           seams). One mesh EV_Ring standing upright (its hole facing +-Z), pivot at its centre. Coloured in
           Roblox: gold SmoothPlastic with Reflectance (the manifest's color / material / reflectance), not Neon.

Run:
  "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python audit/ring_kit_bpy.py -- [--quick] [--no-render]

Writes (design/event/supersonic/ring/, every FBX written first in an ASCII-only temp folder, then copied):
  RingKit.fbx             the ring, one object EV_Ring, one plain material (no textures)
  fbx/EV_Ring.fbx         the same object alone (fallback);  obj/EV_Ring.obj + .mtl (fallback)
  IMPORTAR_ANILLO.md      the owner's import steps (Spanish), written from the manifest's numbers
  ring_manifest.json      the piece (size, bboxCenterOffset, colour, material, reflectance, tris...), the ring's
                          proportions, the FBX facts, the re-import check
  RingKit.blend           the ring object (editable source)
  preview/*.png           renders: ring_closeup (polished gold on a neutral background, the reference's view),
                          ring_profile (face-on, edge-on, cut in half), rings_on_grass (a scatter of rings and a rain
                          still falling on grass, a stand-in R6 for scale), piece_EV_Ring (the kit's piece view)
  C:/Users/Public/RingKit/  copies of the FBX / OBJ files, the manifest and the guide (an ASCII path for Studio)

Frames:
  Asset space = Roblox axes, studs: +X right, +Y up, -Z forward. Blender (x, y, z) = (X, -Z, Y); the FBX export
  (-Z forward, Y up, UnitScaleFactor 1 like the event kit) gives Roblox (X, Y, Z) back. The ring lies in the XY
  plane (upright), its hole along Z; its origin (pivot) is its centre, identity transform, so the imported
  MeshPart's PivotOffset position is zero (no evidence of Studio's import turn: audit/u4_event_kit reads the turn
  from the MeshPart's size, X and Z swap on a quarter turn, and a half turn leaves the symmetric ring unchanged).
"""
import bpy, bmesh, math, json, sys, time, shutil, tempfile, re, struct, random
from pathlib import Path
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
QUICK = '--quick' in ARGS
NO_RENDER = '--no-render' in ARGS

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
OUT = ROOT / 'design' / 'event' / 'supersonic' / 'ring'
PREV = OUT / 'preview'
EVENT_MANIFEST = ROOT / 'design' / 'event' / 'supersonic' / 'event_manifest.json'   # read only
PUBLIC = Path('C:/Users/Public/RingKit')
for p in (OUT, PREV, OUT / 'fbx', OUT / 'obj'):
    p.mkdir(parents=True, exist_ok=True)
KIT_VERSION = 1
T0 = time.time()


def log(*a):
    print('[ringkit %6.1fs]' % (time.time() - T0), *a, flush=True)


TAU = 2 * math.pi


def rad(d):
    return math.radians(d)


def V(x, y=None, z=None):
    if y is None:
        return Vector(x)
    return Vector((x, y, z))


def r4(v):
    return [round(float(c), 4) for c in v]


# ----------------------------------------------------------------------------------------------
# The ring: a torus, studs. The tube's section is a circle (tubeRadius) round the middle circle (majorRadius).
# ----------------------------------------------------------------------------------------------
RING = {
    'outerRadius': 1.20,        # 2.40 across
    'tubeRadius': 0.30,         # a 0.60 tube: a quarter of the ring's diameter
    'segments': 64,             # round the ring (a multiple of 4: the ring maps onto itself on any quarter turn)
    'tubeSegments': 24,         # round the tube (even: the ring maps onto itself front to back)
}
RING['majorRadius'] = round(RING['outerRadius'] - RING['tubeRadius'], 4)
RING['innerRadius'] = round(RING['outerRadius'] - 2 * RING['tubeRadius'], 4)

# name, asset, role, primary, rgb, material, reflectance, transparency, castShadow, shading
PIECE = ('EV_Ring', 'Ring', 'ring', True, (255, 196, 30), 'SmoothPlastic', 0.35, 0.0, False, 'smooth')
NAME = PIECE[0]
COLORS = {'Gold': (255, 196, 30), 'Sparkle': (255, 238, 150)}
RENDER_FIDELITY = 'Automatic'   # a rain of rings: far ones may drop detail
ROBLOX_MAX_TRIS, ROBLOX_MAX_VERTS, ROBLOX_MAX_AXIS = 20000, 10000, 2048.0
BUDGET = 4000
MIN_TRIS = 1500
MAX_NORMAL_ERROR_DEG = 0.5


def torus_normal(p):
    """The torus's exact outward normal at (or near) the point p (Roblox space)."""
    d = V(p.x, p.y, 0.0)
    d = d.normalized() if d.length > 1e-9 else V(1, 0, 0)
    return (p - d * RING['majorRadius']).normalized()


def build_ring(phi0=0.0, phi1=None, caps=False):
    """Verts and their normals (Roblox space), faces (quads), and each vertex's (k, j) grid index for the UVs
    (None for a cap's own vertices). k runs round the ring from +X, j round the tube from its outer equator
    toward +Z. A partial sweep (phi0..phi1) with flat caps is only for the cut-away preview."""
    P, S = RING['tubeSegments'], RING['segments']
    R, r = RING['majorRadius'], RING['tubeRadius']
    full = phi1 is None
    cols = S if full else S + 1
    verts, normals, grid, faces = [], [], [], []
    for k in range(cols):
        phi = phi0 + (TAU if full else (phi1 - phi0)) * k / S
        d = V(math.cos(phi), math.sin(phi), 0.0)
        for j in range(P):
            theta = TAU * j / P
            n = d * math.cos(theta) + V(0, 0, math.sin(theta))
            verts.append(d * R + n * r)
            normals.append(n)
            grid.append((k, j))
    for k in range(S):
        k1 = (k + 1) % cols if full else k + 1
        for j in range(P):
            j1 = (j + 1) % P
            faces.append((k * P + j, k1 * P + j, k1 * P + j1, k * P + j1))
    if caps and not full:
        for k, sign in ((0, -1.0), (cols - 1, 1.0)):
            phi = phi0 + (phi1 - phi0) * k / S
            tangent = V(-math.sin(phi), math.cos(phi), 0.0) * sign
            base = len(verts)
            for j in range(P):
                verts.append(verts[k * P + j].copy())
                normals.append(tangent)
                grid.append(None)
            faces.append(tuple(base + j for j in range(P)))
    return verts, normals, faces, grid, P, S


# ----------------------------------------------------------------------------------------------
# Blender objects
# ----------------------------------------------------------------------------------------------
ROBLOX_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
    return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


def export_material():
    m = bpy.data.materials.new(NAME + '_Mat')
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = lin(PIECE[4])
    m.diffuse_color = lin(PIECE[4])
    bsdf.inputs['Metallic'].default_value = 1.0
    bsdf.inputs['Roughness'].default_value = 0.12
    return m


def gold_material(name='Ring_Gold', rough=0.07, emit=0.0):
    """Polished gold, as in the reference: a mirror metal tinted by the ring's gold."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = lin(COLORS['Gold'])
    b.inputs['Metallic'].default_value = 1.0
    b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = lin(COLORS['Gold'])
        b.inputs['Emission Strength'].default_value = emit
    return m


def roblox_gold_material(name='Ring_Roblox'):
    """How the ring shows in Roblox (gold SmoothPlastic + Reflectance): a bright gold body under a clear mirror
    coat. Outdoors a full metal would mirror the blue sky and turn olive; the game's ring stays yellow-gold."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = lin(COLORS['Gold'])
    b.inputs['Metallic'].default_value = 0.35
    b.inputs['Roughness'].default_value = 0.16
    b.inputs['Emission Color'].default_value = lin(COLORS['Gold'])
    b.inputs['Emission Strength'].default_value = 0.08
    for key, value in (('Coat Weight', 1.0), ('Coat Roughness', 0.02), ('Coat IOR', 1.6)):
        try:
            b.inputs[key].default_value = value
        except Exception:
            pass
    return m


def mesh_object(name, verts, normals, faces, grid, P, S, coll, mat, full=True):
    """The mesh (Blender axes), triangulated with one fixed diagonal, a UV per grid point (u round the ring, v
    round the tube), smooth-shaded with the exact normals as custom normals (the FBX / OBJ carry them)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(ROBLOX_TO_BLENDER @ p) for p in verts], [], faces)
    me.validate(clean_customdata=False)
    assert len(me.vertices) == len(verts), 'no vertex may be merged or dropped'
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.new('UVMap')
    for f in bm.faces:
        if grid[f.verts[0].index] is None:
            for loop in f.loops:
                q = verts[loop.vert.index]
                loop[uvl].uv = (0.5 + (math.hypot(q.x, q.y) - RING['majorRadius']) * 0.8, 0.5 + q.z * 0.8)
            continue
        ks = [grid[l.vert.index][0] for l in f.loops]
        js = [grid[l.vert.index][1] for l in f.loops]
        wrap_k = full and max(ks) - min(ks) > 1
        wrap_j = max(js) - min(js) > 1
        for l in f.loops:
            k, j = grid[l.vert.index]
            if wrap_k and k == 0:
                k = S
            if wrap_j and j == 0:
                j = P
            l[uvl].uv = (k / S, j / P)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='FIXED', ngon_method='EAR_CLIP')
    # Face winding outward (checked against the exact normals, not guessed).
    for f in bm.faces:
        f.normal_update()
        want = ROBLOX_TO_BLENDER @ normals[f.verts[0].index]
        if f.normal.dot(want) < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    me.materials.append(mat)
    me.shade_smooth()
    me.normals_split_custom_set_from_vertices([tuple((ROBLOX_TO_BLENDER @ n).normalized()) for n in normals])
    return ob


# ----------------------------------------------------------------------------------------------
# Validation (Roblox mesh limits) and facts
# ----------------------------------------------------------------------------------------------
def roblox_bbox(ob):
    co = [ob.matrix_world @ v.co for v in ob.data.vertices]
    rb = [Vector((c.x, c.z, -c.y)) for c in co]
    lo = Vector((min(p.x for p in rb), min(p.y for p in rb), min(p.z for p in rb)))
    hi = Vector((max(p.x for p in rb), max(p.y for p in rb), max(p.z for p in rb)))
    return lo, hi


def validate(ob):
    me = ob.data
    r = {'name': ob.name}
    bad = []
    r['tris'] = len(me.polygons)
    r['ngons'] = sum(1 for p in me.polygons if len(p.vertices) != 3)
    r['verts'] = len(me.vertices)
    keys = set()
    cn = me.corner_normals
    uvl = me.uv_layers.active.data
    for p in me.polygons:
        for li in p.loop_indices:
            n = cn[li].vector
            u = uvl[li].uv
            keys.add((me.loops[li].vertex_index, round(n[0], 4), round(n[1], 4), round(n[2], 4), round(u[0], 5), round(u[1], 5)))
    r['renderVerts'] = len(keys)
    r['degenerate'] = sum(1 for p in me.polygons if p.area < 1e-9)
    used = set()
    for p in me.polygons:
        used.update(p.vertices)
    r['looseVerts'] = len(me.vertices) - len(used)
    # Smooth, exact normals: every corner's normal is its vertex's torus normal (no split edges, no error).
    split, worst = 0, 0.0
    per_vertex = {}
    to_roblox = ROBLOX_TO_BLENDER.inverted()
    for p in me.polygons:
        for li in p.loop_indices:
            per_vertex.setdefault(me.loops[li].vertex_index, []).append(Vector(cn[li].vector))
    for vi, ns in per_vertex.items():
        if max((a - ns[0]).length for a in ns) > 1e-3:
            split += 1
        want = torus_normal(to_roblox @ me.vertices[vi].co)
        for a in ns:
            worst = max(worst, math.degrees((to_roblox @ a).normalized().angle(want, 0.0)))
    r['splitNormalVerts'] = split
    r['maxNormalErrorDeg'] = round(worst, 4)
    r['smoothFaces'] = sum(1 for p in me.polygons if p.use_smooth)
    lo, hi = roblox_bbox(ob)
    dims = hi - lo
    r['size'] = [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)]
    r['center'] = [round((lo.x + hi.x) / 2, 4) + 0.0, round((lo.y + hi.y) / 2, 4) + 0.0, round((lo.z + hi.z) / 2, 4) + 0.0]
    r['min'] = [round(lo.x, 4), round(lo.y, 4), round(lo.z, 4)]
    r['max'] = [round(hi.x, 4), round(hi.y, 4), round(hi.z, 4)]
    r['identity'] = ob.location.length < 1e-9 and Vector(ob.rotation_euler).length < 1e-9 and (ob.scale - Vector((1, 1, 1))).length < 1e-9
    r['ascii'] = ob.name.isascii() and ' ' not in ob.name
    if r['ngons']:
        bad.append('ngons')
    if r['tris'] > ROBLOX_MAX_TRIS or r['tris'] > BUDGET or r['tris'] < MIN_TRIS:
        bad.append('tris')
    if r['renderVerts'] > ROBLOX_MAX_VERTS or r['verts'] > ROBLOX_MAX_VERTS:
        bad.append('verts')
    if r['degenerate']:
        bad.append('degenerate')
    if r['looseVerts']:
        bad.append('loose')
    if max(dims) > ROBLOX_MAX_AXIS:
        bad.append('bbox')
    if len(me.uv_layers) != 1 or len(me.materials) != 1:
        bad.append('uv/material')
    if not r['identity'] or not r['ascii']:
        bad.append('transform/name')
    if r['smoothFaces'] != r['tris'] or split or worst > MAX_NORMAL_ERROR_DEG:
        bad.append('normals')
    if max(abs(c) for c in r['center']) > 1e-4:
        bad.append('pivot not at the centre')
    r['ok'] = not bad
    r['errors'] = bad
    return r


def fbx_facts(path):
    b = Path(path).read_bytes()
    m = re.search(rb'UnitScaleFactorS\x06\x00\x00\x00doubleS\x06\x00\x00\x00NumberS\x00\x00\x00\x00D(.{8})', b, re.S)
    usf = struct.unpack('<d', m.group(1))[0] if m else None
    home = str(Path.home()).encode('utf-8')
    return {'unitScaleFactor': usf, 'asciiOnly': home.isascii() or b.find(home) < 0,
            'userFolderInside': b.find(home) >= 0, 'bytes': len(b)}


def export_all(scene, ob):
    tmp = Path(tempfile.mkdtemp(prefix='ringkit_'))
    assert str(tmp).isascii(), 'the temp folder must be ASCII: %s' % tmp
    # Blender embeds its current source filename in FBX metadata: save under ASCII before exporting.
    bpy.ops.wm.save_as_mainfile(filepath=str(tmp / 'RingKit_Source.blend'))
    (tmp / 'fbx').mkdir()
    (tmp / 'obj').mkdir()
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.01   # UnitScaleFactor 1 (cm): the event kit / Egg Mobile kit settings
    fbx_kw = dict(use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True, mesh_smooth_type='FACE',
                  use_tspace=False, add_leaf_bones=False, bake_anim=False, axis_forward='-Z', axis_up='Y',
                  apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0, apply_unit_scale=True, path_mode='STRIP',
                  embed_textures=False, use_custom_props=False, use_triangles=True)
    obj_kw = dict(export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y', global_scale=1.0,
                  apply_modifiers=True, export_triangulated_mesh=True, export_normals=True, export_uv=True,
                  export_materials=True, path_mode='STRIP', export_smooth_groups=False, export_vertex_groups=False,
                  export_animation=False, export_colors=False)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.fbx(filepath=str(tmp / 'fbx' / (NAME + '.fbx')), **fbx_kw)
    bpy.ops.wm.obj_export(filepath=str(tmp / 'obj' / (NAME + '.obj')), **obj_kw)
    bpy.ops.export_scene.fbx(filepath=str(tmp / 'RingKit.fbx'), **fbx_kw)
    scene.unit_settings.scale_length = 1.0
    facts = {}
    for f in [tmp / 'RingKit.fbx'] + sorted((tmp / 'fbx').glob('*.fbx')):
        facts[f.name] = fbx_facts(f)
    for d in (OUT / 'fbx', OUT / 'obj'):
        for old in d.glob('EV_*.*'):
            old.unlink()
    for f in sorted((tmp / 'fbx').glob('*.fbx')):
        shutil.copy2(f, OUT / 'fbx' / f.name)
    for f in sorted((tmp / 'obj').glob('EV_*.*')):
        shutil.copy2(f, OUT / 'obj' / f.name)
    shutil.copy2(tmp / 'RingKit.fbx', OUT / 'RingKit.fbx')
    try:
        PUBLIC.mkdir(parents=True, exist_ok=True)
        (PUBLIC / 'fbx').mkdir(exist_ok=True)
        (PUBLIC / 'obj').mkdir(exist_ok=True)
        for d in (PUBLIC / 'fbx', PUBLIC / 'obj'):
            for old in d.glob('EV_*.*'):
                old.unlink()
        shutil.copy2(tmp / 'RingKit.fbx', PUBLIC / 'RingKit.fbx')
        for f in sorted((tmp / 'fbx').glob('*.fbx')):
            shutil.copy2(f, PUBLIC / 'fbx' / f.name)
        for f in sorted((tmp / 'obj').glob('EV_*.*')):
            shutil.copy2(f, PUBLIC / 'obj' / f.name)
    except Exception as e:  # the public copy is a convenience
        log('could not copy to', PUBLIC, e)
    assert tmp.resolve().parent == Path(tempfile.gettempdir()).resolve() and tmp.name.startswith('ringkit_')
    shutil.rmtree(tmp, ignore_errors=True)
    bad = {k: v for k, v in facts.items() if not (v['unitScaleFactor'] and abs(v['unitScaleFactor'] - 1.0) < 1e-6 and v['asciiOnly'])}
    assert not bad, bad
    return facts


def reimport_check(expect):
    """Import RingKit.fbx into an empty scene (cm units, as written): the ring comes back with its size, centre,
    triangles and exact normals (Roblox axes). Runs last: it resets the Blender session."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(OUT / 'RingKit.fbx'))
    bpy.context.view_layer.update()
    got = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
    worst, normal_err = 0.0, 0.0
    tris = {}
    to_roblox = ROBLOX_TO_BLENDER.inverted()
    for name, ob in got.items():
        if name not in expect:
            continue
        lo, hi = roblox_bbox(ob)
        size, centre = hi - lo, (lo + hi) / 2
        e = expect[name]
        err = max(max(abs(size[i] - e['size'][i]) for i in range(3)), max(abs(centre[i] - e['center'][i]) for i in range(3)))
        worst = max(worst, err)
        tris[name] = len(ob.data.polygons)
        me = ob.data
        mw = ob.matrix_world
        rot = mw.to_3x3().normalized()
        cn = me.corner_normals
        for p in me.polygons:
            for li in p.loop_indices:
                co = to_roblox @ (mw @ me.vertices[me.loops[li].vertex_index].co)
                n = (to_roblox @ (rot @ Vector(cn[li].vector))).normalized()
                normal_err = max(normal_err, math.degrees(n.angle(torus_normal(co), 0.0)))
    return worst, sorted(set(expect) - set(got)), sorted(set(got) - set(expect)), tris, normal_err


# ----------------------------------------------------------------------------------------------
# Manifest and guide
# ----------------------------------------------------------------------------------------------
def write_manifest(r, facts):
    size = r['size']
    ring = {
        'pieces': [NAME], 'primary': NAME, 'boundsMin': r['min'], 'boundsMax': r['max'], 'size': size,
        'attachments': {},
        'origin': 'the ring\'s centre; it stands upright (in the XY plane), its hole facing +-Z',
        'outerDiameter': round(max(size[0], size[1]), 4), 'innerDiameter': round(2 * RING['innerRadius'], 4),
        'tubeDiameter': round(2 * RING['tubeRadius'], 4), 'thickness': size[2],
        'majorRadius': RING['majorRadius'], 'tubeRadius': RING['tubeRadius'],
        'holeAxis': 'Z', 'spinAxis': 'Y',
        'shape': 'a smooth round torus (the owner\'s reference, reference/ring_reference.webp): the tube a quarter of the '
                 'ring\'s diameter, the hole half of it; exact torus normals, no seams',
        'segments': {'around': RING['segments'], 'tube': RING['tubeSegments']},
        'maxNormalErrorDeg': r['maxNormalErrorDeg'],
        'colors': {k: list(v) for k, v in COLORS.items()},
        'colorNote': 'Gold = the ring (the piece colour); Sparkle = a pale gold for pickup sparkles / trails (effects only, '
                     'the ring itself is never Neon)',
        'lookNote': 'polished gold: SmoothPlastic + Reflectance (the Metal material carries a brushed texture in Roblox)',
        'renderFidelity': RENDER_FIDELITY,
        'reference': 'design/event/supersonic/ring/reference/ring_reference.webp',
    }
    manifest = {
        'generator': 'audit/ring_kit_bpy.py',
        'kitVersion': KIT_VERSION,
        'kit': 'RingKit',
        'event': 'Super Sonic vs Dr. Eggman (the gold rings Dr. Eggman drops when he is defeated)',
        'fbx': 'RingKit.fbx',
        'rbxm': 'Update2/RingKit.rbxm or design/event/supersonic/ring/RingKit.rbxm (saved from Studio after Import 3D, IMPORTAR_ANILLO.md)',
        'publicCopy': str(PUBLIC).replace('\\', '/'),
        'separateFrom': 'design/event/supersonic/EventKit.rbxm (event_manifest.json, 11 pieces): not changed by this kit',
        'units': '1 unit = 1 stud; FBX UnitScaleFactor 1.0 (cm), like EventKit.fbx; axes -Z forward, Y up (Roblox axes)',
        'pivot': 'the ring\'s centre, identity transform: the imported MeshPart\'s PivotOffset position is zero',
        'placement': 'part.CFrame = ringPivot * CFrame.Angles(0, -importTurn, 0); part.Size = size with X / Z swapped on '
                     'an odd turn (audit/u4_event_kit reads importTurn from the MeshPart\'s size; a half turn leaves the '
                     'symmetric ring unchanged)',
        'textures': 'none: one colour; audit/u4_event_kit sets Color / Material / Reflectance / Transparency from here',
        'meshesFolder': 'ReplicatedStorage.SuperSonicEventAssets.Meshes.Ring (MeshPart)',
        'totalTris': r['tris'],
        'budgets': {'Ring': BUDGET},
        'fbxFacts': facts,
        'assets': {'Ring': ring},
        'pieces': [{
            'name': NAME, 'asset': PIECE[1], 'role': PIECE[2], 'primary': PIECE[3], 'size': size,
            'bboxCenterOffset': r['center'], 'pivot': [0, 0, 0], 'color': list(PIECE[4]), 'material': PIECE[5],
            'reflectance': PIECE[6], 'transparency': PIECE[7], 'castShadow': PIECE[8], 'shading': PIECE[9],
            'renderFidelity': RENDER_FIDELITY,
            'tris': r['tris'], 'verts': r['verts'], 'renderVerts': r['renderVerts'],
        }],
    }
    return manifest


def fmt(v):
    return '(' + ', '.join('%.2f' % x for x in v) + ')'


def write_guide(manifest):
    """IMPORTAR_ANILLO.md: the owner's steps in Studio (Spanish), with this export's numbers."""
    p = manifest['pieces'][0]
    ring = manifest['assets']['Ring']
    size = p['size']
    swapped = [size[2], size[1], size[0]]
    text = '\n'.join([
        '# Evento Super Sonic vs Dr. Eggman: importar el ANILLO de oro en Studio',
        '',
        'Cuando Dr. Eggman cae, suelta una lluvia de **anillos de oro** que los jugadores recogen. El anillo (como tu',
        'referencia `reference/ring_reference.webp`: un toro redondo, liso y pulido) es ahora **1 malla de Blender**',
        '(`EV_Ring`). Es un kit **aparte**: no toques `EventKit.rbxm` (sus 11 piezas ya están importadas y siguen igual).',
        'Se importa **una sola vez**: el montaje lo pone en `ReplicatedStorage.SuperSonicEventAssets.Meshes.Ring` de los',
        'tres mundos, dorado. Mientras no esté, el juego usa su anillo de respaldo.',
        '',
        'Vista previa (`design/event/supersonic/ring/preview/`): `ring_closeup.png` (un anillo de cerca, oro pulido),',
        '`rings_on_grass.png` (anillos sobre la hierba y cayendo, con un R6 para la escala), `ring_profile.png`',
        '(de frente, de canto y cortado por la mitad) y `piece_EV_Ring.png`.',
        '',
        '## Pasos',
        '',
        '1. En Studio, **File > Import 3D** y elige **`C:\\Users\\Public\\RingKit\\RingKit.fbx`** (es la misma que',
        '   `design/event/supersonic/ring/RingKit.fbx`; usa la de `C:\\Users\\Public`, cuya ruta no tiene acentos).',
        '2. Ajustes del importador:',
        '   - **Scale Unit: Stud**',
        '   - **Merge Meshes: DESACTIVADO**',
        '   - **Upload to Roblox: ACTIVADO**',
        '   - World Forward / Up: los de por defecto. Si el anillo sale girado, no pasa nada: el montaje lo endereza.',
        '3. Comprueba que hay **1 MeshPart** llamado **`EV_Ring`**.',
        '   - Sale gris: es normal, el montaje lo pinta de oro.',
        '   - **Prueba de escala:** `EV_Ring.Size` ≈ **%s** (o **%s**: X y Z pueden salir intercambiadas).' % (fmt(size), fmt(swapped)),
        '     Si sale 100 veces más grande o más pequeño, borra y repite con la otra unidad. Si sale **tumbado**',
        '     (Y ≈ %.2f), repite la importación con World Forward / Up por defecto.' % size[2],
        '4. No cambies el nombre. Clic derecho en el Model importado (o en `EV_Ring`), **Save to File…** y guárdalo',
        '   como **`RingKit.rbxm`** en la carpeta **`Update2`** (`Update2/RingKit.rbxm`; también vale',
        '   `Update2/design/event/supersonic/ring/RingKit.rbxm`).',
        '5. Avísanos. El siguiente montaje (`lune run audit/build_update4.luau`) pone el anillo en',
        '   `SuperSonicEventAssets.Meshes.Ring` en los tres mundos.',
        '',
        '**Si el FBX falla:** prueba `C:\\Users\\Public\\RingKit\\fbx\\EV_Ring.fbx` y, si también falla,',
        '`C:\\Users\\Public\\RingKit\\obj\\EV_Ring.obj`. Pásanos el texto del error (ventana Import 3D u Output).',
        '',
        '## Datos',
        '',
        '- %d triángulos y %d vértices (límite de Roblox: 20.000 triángulos y 10.000 vértices por malla).' % (p['tris'], p['verts']),
        '- 1 unidad = 1 stud. Diámetro exterior **%.2f**, agujero **%.2f**, tubo **%.2f** (redondo, liso, sin facetas).'
        % (ring['outerDiameter'], ring['innerDiameter'], ring['tubeDiameter']),
        '  De pie, con el agujero mirando a ±Z; el pivote en su centro.',
        '- Color oro RGB %s, **%s** con Reflectance **%.2f** (oro pulido; el material Metal de Roblox trae una textura'
        % (tuple(p['color']), p['material'], p['reflectance']),
        '  cepillada), sin sombra, RenderFidelity %s. Salen de `ring_manifest.json`.' % p['renderFidelity'],
        '- Regenerar: `blender.exe -b --factory-startup --python audit/ring_kit_bpy.py`',
        '',
    ])
    (OUT / 'IMPORTAR_ANILLO.md').write_text(text, encoding='utf-8', newline='\n')
    try:
        (PUBLIC / 'IMPORTAR_ANILLO.md').write_text(text, encoding='utf-8', newline='\n')
    except Exception:
        pass


def save_manifest(manifest):
    text = json.dumps(manifest, indent=1)
    (OUT / 'ring_manifest.json').write_text(text, encoding='utf-8', newline='\n')
    try:
        (PUBLIC / 'ring_manifest.json').write_text(text, encoding='utf-8', newline='\n')
    except Exception:
        pass


# ----------------------------------------------------------------------------------------------
# Renders
# ----------------------------------------------------------------------------------------------
def simple_mat(name, rgb, rough=0.4, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = lin(rgb)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = lin(rgb)
        b.inputs['Emission Strength'].default_value = emit
    return m


def add_mesh(name, verts, faces, mat, coll, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(ROBLOX_TO_BLENDER @ V(p)) for p in verts], [], faces)
    me.validate()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=rad(50))
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def rbox(center, size, radius, segs=2):
    """A rounded box, Roblox space (the stand-in R6)."""
    c = V(center)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    n = 2 * segs + 2
    verts, faces = [], []
    idx = {}
    for i in range(n + 1):
        for j in range(n + 1):
            for k in range(n + 1):
                if 0 < i < n and 0 < j < n and 0 < k < n:
                    continue
                p = V((i / n * 2 - 1) * hx, (j / n * 2 - 1) * hy, (k / n * 2 - 1) * hz)
                inner = V(max(-hx + radius, min(hx - radius, p.x)), max(-hy + radius, min(hy - radius, p.y)),
                          max(-hz + radius, min(hz - radius, p.z)))
                d = p - inner
                if d.length > 1e-9:
                    p = inner + d.normalized() * radius
                idx[(i, j, k)] = len(verts)
                verts.append(c + p)
    for a in range(n):
        for b in range(n):
            for face in (
                ((0, a, b), (0, a + 1, b), (0, a + 1, b + 1), (0, a, b + 1)),
                ((n, a, b), (n, a, b + 1), (n, a + 1, b + 1), (n, a + 1, b)),
                ((a, 0, b), (a, 0, b + 1), (a + 1, 0, b + 1), (a + 1, 0, b)),
                ((a, n, b), (a + 1, n, b), (a + 1, n, b + 1), (a, n, b + 1)),
                ((a, b, 0), (a + 1, b, 0), (a + 1, b + 1, 0), (a, b + 1, 0)),
                ((a, b, n), (a, b + 1, n), (a + 1, b + 1, n), (a + 1, b, n)),
            ):
                faces.append(tuple(idx[t] for t in face))
    return verts, faces


def place(ob, pos, rot=None):
    """Put an object at a Roblox-space position / rotation (Matrix 3x3 in Roblox axes)."""
    C = ROBLOX_TO_BLENDER
    R = Matrix.Identity(3) if rot is None else rot
    m = (C @ R @ C.inverted()).to_4x4()
    m.translation = C @ V(pos)
    ob.matrix_world = m


def instance(src, coll, pos, rot=None, mat=None, name=None):
    ob = src.copy()
    ob.name = name or (src.name + '_I')
    coll.objects.link(ob)
    place(ob, pos, rot)
    if mat is not None:
        ob.material_slots[0].link = 'OBJECT'
        ob.material_slots[0].material = mat
    return ob


def aim(ob, loc, target):
    L, T = ROBLOX_TO_BLENDER @ V(loc), ROBLOX_TO_BLENDER @ V(target)
    ob.location = L
    ob.rotation_euler = (T - L).to_track_quat('-Z', 'Y').to_euler()


def add_camera(name, loc, target, lens, coll):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.05
    cd.clip_end = 2000
    ob = bpy.data.objects.new(name, cd)
    coll.objects.link(ob)
    aim(ob, loc, target)
    return ob


def orbit(az_deg, el_deg, dist, target):
    az, el = rad(az_deg), rad(el_deg)
    t = V(target)
    return (t.x + dist * math.cos(el) * math.sin(az), t.y + dist * math.sin(el), t.z - dist * math.cos(el) * math.cos(az))


def use_cycles(scene, samples):
    """Cycles (CPU) for the polished-gold shots: true mirror reflections, the ring reflecting itself."""
    scene.render.engine = 'CYCLES'
    cy = scene.cycles
    cy.device = 'CPU'
    cy.samples = samples
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.02
    cy.max_bounces = 8
    cy.glossy_bounces = 6
    try:
        cy.use_denoising = True
        cy.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    scene.render.film_transparent = False


def use_eevee(scene, samples):
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except TypeError:
        scene.render.engine = 'BLENDER_EEVEE'
    ee = scene.eevee
    ee.taa_render_samples = samples
    for k, v in (('use_shadows', True), ('shadow_ray_count', 3), ('shadow_step_count', 12), ('use_raytracing', True),
                 ('use_fast_gi', True)):
        try:
            setattr(ee, k, v)
        except Exception:
            pass
    try:
        ee.ray_tracing_method = 'SCREEN'
    except Exception:
        pass
    scene.render.film_transparent = False


def view(scene, transform='Standard', look='None', exposure=0.0):
    scene.view_settings.view_transform = transform
    try:
        scene.view_settings.look = look
    except Exception:
        scene.view_settings.look = 'None'
    scene.view_settings.exposure = exposure


def bloom(scene, strength=0.35):
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new('CompositorNodeRLayers')
    comp = nt.nodes.new('CompositorNodeComposite')
    glare = nt.nodes.new('CompositorNodeGlare')
    for k, v in (('glare_type', 'BLOOM'), ('quality', 'HIGH'), ('threshold', 1.0), ('size', 7), ('mix', -0.6)):
        try:
            setattr(glare, k, v)
        except Exception:
            pass
    for k, v in (('Threshold', 1.0), ('Strength', strength), ('Size', 0.5)):
        if k in glare.inputs:
            try:
                glare.inputs[k].default_value = v
            except Exception:
                pass
    nt.links.new(rl.outputs['Image'], glare.inputs['Image'])
    nt.links.new(glare.outputs['Image'], comp.inputs['Image'])


def studio_world(scene, backdrop=(0.96, 0.96, 0.96)):
    """A product-photo studio: the camera sees a plain neutral backdrop; the reflections see a studio with a bright
    ceiling, soft boxes and dark bands (a mirror needs something to mirror), like the reference's gold."""
    w = bpy.data.worlds.get('RK_Studio') or bpy.data.worlds.new('RK_Studio')
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputWorld')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    # Vertical bands (Blender Z = up): floor grey, dark horizon, white wall, grey, bright ceiling.
    vmap = nt.nodes.new('ShaderNodeMapRange')
    vmap.inputs['From Min'].default_value = -1.0
    vmap.inputs['From Max'].default_value = 1.0
    nt.links.new(sep.outputs['Z'], vmap.inputs['Value'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    cr = ramp.color_ramp
    stops = [(0.0, 0.35), (0.40, 0.75), (0.47, 0.04), (0.53, 0.04), (0.60, 1.4), (0.74, 0.22), (0.86, 0.9), (1.0, 2.2)]
    cr.elements[0].position, cr.elements[0].color = stops[0][0], (stops[0][1],) * 3 + (1,)
    cr.elements[1].position, cr.elements[1].color = stops[-1][0], (stops[-1][1],) * 3 + (1,)
    for pos, val in stops[1:-1]:
        e = cr.elements.new(pos)
        e.color = (val,) * 3 + (1,)
    nt.links.new(vmap.outputs['Result'], ramp.inputs['Fac'])
    # A tall soft box on the camera's left and a darker side on the right (Blender X).
    hmap = nt.nodes.new('ShaderNodeMapRange')
    hmap.inputs['From Min'].default_value = -1.0
    hmap.inputs['From Max'].default_value = 1.0
    nt.links.new(sep.outputs['X'], hmap.inputs['Value'])
    hramp = nt.nodes.new('ShaderNodeValToRGB')
    hr = hramp.color_ramp
    hr.elements[0].position, hr.elements[0].color = 0.0, (0.35, 0.35, 0.35, 1)
    hr.elements[1].position, hr.elements[1].color = 1.0, (0.8, 0.8, 0.8, 1)
    for pos, val in ((0.12, 2.6), (0.24, 0.35), (0.62, 1.0), (0.8, 0.25)):
        e = hr.elements.new(pos)
        e.color = (val,) * 3 + (1,)
    nt.links.new(hmap.outputs['Result'], hramp.inputs['Fac'])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(ramp.outputs['Color'], mul.inputs[6])
    nt.links.new(hramp.outputs['Color'], mul.inputs[7])
    lit = nt.nodes.new('ShaderNodeBackground')
    lit.inputs['Strength'].default_value = 1.0
    nt.links.new(mul.outputs[2], lit.inputs['Color'])
    plain = nt.nodes.new('ShaderNodeBackground')
    plain.inputs['Color'].default_value = backdrop + (1,)
    plain.inputs['Strength'].default_value = 1.0
    lp = nt.nodes.new('ShaderNodeLightPath')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(lp.outputs['Is Camera Ray'], mix.inputs['Fac'])
    nt.links.new(lit.outputs['Background'], mix.inputs[1])
    nt.links.new(plain.outputs['Background'], mix.inputs[2])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])


def sky_world(scene, top, bottom, strength=1.0, low=0.0, high=0.3):
    w = bpy.data.worlds.get('RK_Sky') or bpy.data.worlds.new('RK_Sky')
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputWorld')
    bg = nt.nodes.new('ShaderNodeBackground')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    nt.links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    cr = ramp.color_ramp
    cr.elements[0].position = low
    cr.elements[0].color = bottom + (1,)
    cr.elements[1].position = high
    cr.elements[1].color = top + (1,)
    bg.inputs['Strength'].default_value = strength
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])


RENDER_TMP = Path(tempfile.gettempdir()) / 'ringkit_renders'


def render_view(scene, cam, path, rx, ry):
    """Renders into an ASCII temp folder, then copies into preview/ (a save straight into the user folder, whose
    name holds a non-ASCII letter, can fail)."""
    scene.camera = cam
    scene.render.resolution_x = rx
    scene.render.resolution_y = ry
    scene.render.resolution_percentage = 100
    RENDER_TMP.mkdir(exist_ok=True)
    tmp = RENDER_TMP / path.name
    scene.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    for attempt in range(5):
        try:
            shutil.copyfile(tmp, path)
            break
        except OSError:
            time.sleep(0.5)
    else:
        raise RuntimeError('cannot copy %s to %s' % (tmp, path))
    tmp.unlink()
    log('render', path.name)


def stand_in_r6(coll, root):
    """A stand-in R6 (for scale only; Sonic blue): torso 2x2x1, arms / legs 1x2x1, a 1.25 head, its root at `root`."""
    blue = simple_mat('SI_Blue', (35, 95, 235), 0.45)
    skin = simple_mat('SI_Skin', (240, 200, 160), 0.5)
    red = simple_mat('SI_Red', (215, 40, 40), 0.4)
    white = simple_mat('SI_White', (240, 242, 248), 0.5)
    r = V(root)
    obs = [add_mesh('SI_Torso', *rbox(r, (2.0, 2.0, 1.0), 0.08, 2), blue, coll),
           add_mesh('SI_Head', *rbox(r + V(0, 1.62, 0), (1.25, 1.25, 1.25), 0.4, 3), blue, coll),
           add_mesh('SI_Face', *rbox(r + V(0, 1.5, 0.45), (0.9, 0.7, 0.4), 0.18, 2), skin, coll)]
    for sx in (-1, 1):
        obs.append(add_mesh('SI_Arm%d' % sx, *rbox(r + V(sx * 1.5, 0, 0), (1.0, 2.0, 1.0), 0.08, 2), skin, coll))
        obs.append(add_mesh('SI_Glove%d' % sx, *rbox(r + V(sx * 1.5, -0.8, 0), (1.06, 0.5, 1.06), 0.15, 2), white, coll))
        obs.append(add_mesh('SI_Leg%d' % sx, *rbox(r + V(sx * 0.5, -2.0, 0), (1.0, 2.0, 1.0), 0.08, 2), blue, coll))
        obs.append(add_mesh('SI_Shoe%d' % sx, *rbox(r + V(sx * 0.5, -2.75, 0.1), (1.04, 0.5, 1.2), 0.15, 2), red, coll))
    return obs


def grass_material():
    m = bpy.data.materials.new('Grass')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get('Principled BSDF')
    b.inputs['Roughness'].default_value = 0.85
    tc = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 0.35
    noise.inputs['Detail'].default_value = 6.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = lin((58, 142, 38))
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = lin((104, 186, 58))
    fine = nt.nodes.new('ShaderNodeTexNoise')
    fine.inputs['Scale'].default_value = 14.0
    fine.inputs['Detail'].default_value = 3.0
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.35
    nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
    nt.links.new(tc.outputs['Object'], fine.inputs['Vector'])
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(fine.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    return m


def blade_material():
    m = bpy.data.materials.new('Blades')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get('Principled BSDF')
    b.inputs['Roughness'].default_value = 0.7
    attr = nt.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Col'
    nt.links.new(attr.outputs['Color'], b.inputs['Base Color'])
    return m


def grass_blades(coll, region, count, seed=7):
    """Short tapered blades (one triangle each) over region (x0, x1, z0, z1), Roblox space."""
    rnd = random.Random(seed)
    x0, x1, z0, z1 = region
    verts, faces, cols = [], [], []
    for i in range(count):
        x, z = rnd.uniform(x0, x1), rnd.uniform(z0, z1)
        h = rnd.uniform(0.14, 0.34)
        w = rnd.uniform(0.035, 0.06)
        yaw = rnd.uniform(0, TAU)
        lean = rnd.uniform(-0.08, 0.08)
        dx, dz = math.cos(yaw) * w, math.sin(yaw) * w
        lx, lz = -math.sin(yaw) * lean, math.cos(yaw) * lean
        base = len(verts)
        verts += [V(x - dx, 0.0, z - dz), V(x + dx, 0.0, z + dz), V(x + lx, h, z + lz)]
        faces.append((base, base + 1, base + 2))
        g = rnd.uniform(0, 1)
        cols.append((46 + 50 * g, 132 + 60 * g, 30 + 34 * g))
    me = bpy.data.meshes.new('Blades')
    me.from_pydata([tuple(ROBLOX_TO_BLENDER @ p) for p in verts], [], faces)
    me.validate()
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
    for pi, poly in enumerate(me.polygons):
        c = lin(cols[pi])
        for k, li in enumerate(poly.loop_indices):
            tip = 1.0 if k == 2 else 0.72
            ca.data[li].color = (c[0] * tip, c[1] * tip, c[2] * tip, 1.0)
    me.materials.append(blade_material())
    ob = bpy.data.objects.new('Blades', me)
    coll.objects.link(ob)
    return ob


def area_light(coll, name, energy, size, loc, target, shape='RECTANGLE', size_y=None):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy = energy
    ld.shape = shape
    ld.size = size
    if size_y is not None:
        ld.size_y = size_y
    ob = bpy.data.objects.new(name, ld)
    coll.objects.link(ob)
    aim(ob, loc, target)
    return ob


def renders(scene, ring):
    q = 0.5 if QUICK else 1.0
    kit = bpy.data.collections['RingKit']
    gold = gold_material()
    hero = bpy.data.collections.new('Hero')
    scene.collection.children.link(hero)

    def solo(on):
        for ob in hero.objects:
            ob.hide_render = ob not in on

    # 1. One ring close-up: polished gold on a neutral backdrop, turned like the reference (Cycles).
    use_cycles(scene, 48 if QUICK else 256)
    view(scene, 'Standard', 'None', 0.0)
    bloom(scene, 0.25)
    studio_world(scene)
    kit.hide_render = True
    close = instance(ring, hero, (0, 0, 0), Matrix.Rotation(rad(-30), 3, 'Y') @ Matrix.Rotation(rad(4), 3, 'X'), gold, 'Ring_Close')
    key = area_light(hero, 'Key', 260, 3.0, (-4.5, 3.5, -3.5), (0, 0, 0), size_y=5.0)
    fill = area_light(hero, 'Fill', 90, 4.0, (5.0, 1.0, -2.0), (0, 0, 0), size_y=4.0)
    top = area_light(hero, 'Top', 160, 5.0, (0.5, 6.0, 1.0), (0, 0, 0), size_y=2.0)
    solo([close, key, fill, top])
    cam = add_camera('Cam_close', orbit(-4, 6, 5.6, (0, 0, 0)), (0, 0, 0), 60, hero)
    render_view(scene, cam, PREV / 'ring_closeup.png', int(1200 * q), int(1200 * q))

    # 2. The profile: face-on, edge-on and a half ring cut open (its round section toward the camera).
    # (the cameras look toward +Z from the front, so +X shows on the LEFT of the picture)
    face_on = instance(ring, hero, (3.3, 0, 0), None, gold, 'Ring_Face')
    edge_on = instance(ring, hero, (0, 0, 0), Matrix.Rotation(rad(90), 3, 'Y'), gold, 'Ring_Edge')
    hv, hn, hf, hg, P, S = build_ring(-math.pi / 2, math.pi / 2, caps=True)
    half = mesh_object('Ring_Half', hv, hn, hf, hg, P, S, hero, gold, full=False)
    place(half, (-2.7, 0, 0), Matrix.Rotation(rad(-58), 3, 'Y'))
    solo([face_on, edge_on, half, key, fill, top])
    cam = add_camera('Cam_profile', orbit(0, 6, 13, (0.2, 0, 0)), (0.2, 0, 0), 50, hero)
    render_view(scene, cam, PREV / 'ring_profile.png', int(1600 * q), int(800 * q))

    # 3. The piece alone (the kit's piece-render convention, grey stage) - Eevee from here on.
    use_eevee(scene, 24 if QUICK else 96)
    view(scene, 'AgX', 'AgX - Medium High Contrast', 0.2)
    bloom(scene, 0.45)
    sky_world(scene, (0.30, 0.33, 0.38), (0.11, 0.12, 0.14), 0.9, 0.35, 0.75)
    stage = bpy.data.collections.new('Stage')
    scene.collection.children.link(stage)
    floor = add_mesh('Floor', [(-300, 0, -300), (300, 0, -300), (300, 0, 300), (-300, 0, 300)], [(0, 1, 2, 3)],
                     simple_mat('Floor', (104, 110, 122), rough=0.75), stage, False)
    lo, hi = roblox_bbox(ring)
    ctr, size = (lo + hi) / 2, max(hi - lo)
    floor.location.z = lo.y - 0.001
    rig = []
    for name, (az, el, dd), e in (('PKey', (-45, 45, 1.0), 900), ('PFill', (60, 20, 1.1), 450), ('PRim', (160, 40, 1.0), 1000)):
        k = size * 3.2 / 10.0
        ob = area_light(stage, name, e * k * k, 6 * k, orbit(az, el, size * 3.2 * dd, ctr), ctr, shape='DISK')
        rig.append(ob)
    kit.hide_render = False
    solo([])
    cam = add_camera('Cam_piece', orbit(-38, 22, size * 2.7, ctr), ctr, 50, stage)
    render_view(scene, cam, PREV / ('piece_%s.png' % NAME), int(900 * q), int(900 * q))
    kit.hide_render = True
    stage.hide_render = True

    # 4. A scatter of rings on grass (and a rain still falling), a stand-in R6 (Sonic blue) for scale.
    view(scene, 'Standard', 'None', -0.2)
    bloom(scene, 0.3)
    ground = add_mesh('Ground', [(-60, 0, -60), (60, 0, -60), (60, 0, 60), (-60, 0, 60)], [(0, 1, 2, 3)], grass_material(), hero, False)
    blades = grass_blades(hero, (-16, 16, -18, 12), 70000 if QUICK else 180000)
    field_gold = roblox_gold_material()
    rnd = random.Random(26)
    rings, spots = [], []
    for i in range(30):
        for attempt in range(60):
            x, z = rnd.uniform(-10.5, 10.5), rnd.uniform(-13.0, 5.0)
            if all((x - a) ** 2 + (z - b) ** 2 > 2.5 ** 2 for a, b in spots) and not (abs(x + 4.2) < 2.0 and abs(z + 1.0) < 1.6):
                break
        spots.append((x, z))
        yaw = rnd.uniform(0, 180)
        rings.append(instance(ring, hero, (x, 1.2 - 0.03, z), Matrix.Rotation(rad(yaw), 3, 'Y'), field_gold, 'Ring_G%d' % i))
    for i in range(16):
        x, z = -9.5 + 19.0 * (i + rnd.uniform(0.1, 0.9)) / 16, rnd.uniform(-11, 2)
        y = rnd.uniform(3.8, 9.5)
        rot = Matrix.Rotation(rad(rnd.uniform(0, 180)), 3, 'Y') @ Matrix.Rotation(rad(rnd.uniform(-25, 25)), 3, 'X')
        rings.append(instance(ring, hero, (x, y, z), rot, field_gold, 'Ring_F%d' % i))
    r6 = stand_in_r6(hero, (-4.2, 3.0, -1.0))
    sun_d = bpy.data.lights.new('Sun', 'SUN')
    sun_d.energy = 3.4
    sun_d.angle = rad(1.5)
    sun = bpy.data.objects.new('Sun', sun_d)
    hero.objects.link(sun)
    aim(sun, (6, 14, 9), (0, 0, 0))
    solo(rings + r6 + [ground, blades, sun])
    sky_world(scene, (0.10, 0.32, 1.0), (0.62, 0.78, 1.0), 0.85, 0.0, 0.3)
    cam = add_camera('Cam_grass', (0.0, 6.0, 18.5), (0.0, 2.6, -2.5), 34, hero)
    render_view(scene, cam, PREV / 'rings_on_grass.png', int(1600 * q), int(1000 * q))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    coll = bpy.data.collections.new('RingKit')
    scene.collection.children.link(coll)
    verts, normals, faces, grid, P, S = build_ring()
    ring = mesh_object(NAME, verts, normals, faces, grid, P, S, coll, export_material())
    bpy.context.view_layer.update()
    r = validate(ring)
    log('%s: %d tris, %d verts, %d render verts, size %s, centre %s, normals off by %.4f deg at most, %s' % (
        NAME, r['tris'], r['verts'], r['renderVerts'], 'x'.join('%.3f' % v for v in r['size']), r['center'],
        r['maxNormalErrorDeg'], 'OK' if r['ok'] else 'FAIL ' + ','.join(r['errors'])))
    assert r['ok'], r['errors']
    assert abs(r['size'][0] - 2 * RING['outerRadius']) < 1e-3 and abs(r['size'][1] - r['size'][0]) < 1e-3, r['size']
    assert abs(r['size'][2] - 2 * RING['tubeRadius']) < 1e-3, r['size']
    # The event kit is not touched (its manifest has no EV_Ring; its files keep their bytes).
    if EVENT_MANIFEST.exists():
        ev = json.loads(EVENT_MANIFEST.read_text(encoding='utf-8'))
        assert NAME not in [p['name'] for p in ev['pieces']], 'EV_Ring must not be an EventKit piece'
    facts = export_all(scene, ring)
    log('FBX written', {k: (v['unitScaleFactor'], v['asciiOnly']) for k, v in facts.items()})
    manifest = write_manifest(r, facts)
    bpy.context.preferences.filepaths.save_version = 0   # no RingKit.blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'RingKit.blend'))
    if not NO_RENDER:
        renders(scene, ring)
    worst, missing, extra, tris, normal_err = reimport_check({NAME: r})
    log('re-import: worst size / centre error %.5f studs, missing %s, extra %s, tris %s, normals off by %.4f deg'
        % (worst, missing, extra, tris, normal_err))
    manifest['reimportCheck'] = {'worstErrorStuds': round(worst, 5), 'missing': missing, 'extra': extra, 'tris': tris,
                                 'maxNormalErrorDeg': round(normal_err, 4)}
    save_manifest(manifest)
    write_guide(manifest)
    log('manifest and IMPORTAR_ANILLO.md written')
    assert worst < 0.01 and not missing and tris.get(NAME) == r['tris'] and normal_err < MAX_NORMAL_ERROR_DEG, (worst, missing, tris, normal_err)
    log('done')


if __name__ == '__main__':
    main()
