"""audit/generate_race_assets.py -- Update 4 race art, Sonic "Green Hill" style (2026-09-25).

Builds the race's 3D models in Blender (bpy, headless, deterministic), exports FBX files and
renders preview PNGs:

  RaceLobbyBooth     lobby entrance: stepped grass/checker podium (the join pad) inside a giant
                     gold ring, a chunky checker-cube arch with a grass top, a goal-sign style
                     round RACE board, two palms, The Flash's kiosk (checker platform, wooden
                     counter) with a FlashSpot marker.
  RaceStartGantry    checker-cube arch over the track (grass top, blue timer panel) with 5 Sonic
                     star posts on it: blue poles, the balls are Light_1..5 (red -> green in game).
  RaceLoop           checkered loop-de-loop hoop the track runs through (grass inside, a panel at
                     the top for the distance): the 500 / 1000 / 1500 / LAST 200 markers.
  RaceFinishGantry   checker-cube arch with a checkered-flag banner, FINISH panel, confetti spots
                     and the spinning GOAL signpost (GoalPanel + GoalRim spin around GoalSpin).
  RaceCliff          168-stud causeway module: grass shoulders both sides of the 72-stud track,
                     orange / dark-brown checker cliffs dropping into the sea, grass lip teeth.
  RaceFence          168-stud wooden fence module (posts every 8 studs, two sagging ropes).
  RacePalm, RaceSunflower, RaceTotem, RaceRing, RaceIsland
                     decor instanced along the track (low poly): palm tree, sunflower, totem,
                     gold ring, floating island with a palm and a waterfall.

2026-09-25 WHY: the owner turned down the futuristic set ("what you are doing I don't like") and
asked for Sonic Dash's Green Hill look, matching the lobby (green checker grass, brown checker
cliffs). Meshes can not be uploaded from code (no Open Cloud key): the owner imports the FBX once
in Studio (design/race/IMPORTAR_EN_STUDIO.md) and the build clones the meshes (RaceArenaBuilder).

Style: "Roblox chunky toy": every solid piece gets Bevel (angle limit 35 deg, 2 segments,
superellipse profile, no custom profile) and each role mesh WeightedNormal (face area, keep
sharp). Faces that sit against another surface are not built. One mesh object per COLOUR ROLE,
named <Model>__<Role> (e.g. RaceStartGantry__Light_3): each becomes its own MeshPart that the
builder paints from the role table (Color/Material).

Units: 1 Blender unit = 1 stud. Coordinates below are ROBLOX model space (x right, y up, z back)
converted once (R()): Blender (x, y, z) = (x, -z, y). FBX: Apply Scalings = FBX Units Scale,
forward -Z, up Y, Apply Transform, so a Roblox MeshPart gets identity rotation. Each role
object's origin is its bounding-box centre (a Roblox MeshPart's position). Track pieces: racers run
toward -z and see the faces that point +z; the booth's players come from -z.

Outputs (relative to the project root):
  design/race/fbx/<Model>.fbx              one per model
  design/race/fbx/RaceAssets_All.fbx       every model in one file (one import in Studio)
  design/race/preview/<Model>.png          preview render per model
  design/race/preview/RaceTrack_Overview.png   the assembled track (start, cliffs, loop, decor)
  design/race/race_assets.blend            the scene, for tweaks
  design/race/race_assets_manifest.json    every object: role, centre, size (Roblox space), tris;
                                           markers, colliders, role table, booth piece boxes
  src/common/ServerScriptService/Services/Race/RaceArenaBuilder.luau
                                           the block between "-- BEGIN GENERATED RaceAssetSpec"
                                           and "-- END GENERATED RaceAssetSpec" is rewritten
Run (from anywhere):
  "C:\\Program Files\\Blender Foundation\\Blender 4.5\\blender.exe" -b --factory-startup
      --python audit/generate_race_assets.py -- [--no-render] [--no-spec] [--stats]
"""
import bpy
import bmesh
import glob
import json
import math
import os
import struct
import sys
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = "--no-render" not in ARGS
WRITE_SPEC = "--no-spec" not in ARGS
STATS = "--stats" in ARGS

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DESIGN = os.path.join(ROOT, "design", "race")
FBX_DIR = os.path.join(DESIGN, "fbx")
PREVIEW_DIR = os.path.join(DESIGN, "preview")
MANIFEST = os.path.join(DESIGN, "race_assets_manifest.json")
BLEND = os.path.join(DESIGN, "race_assets.blend")
BUILDER = os.path.join(ROOT, "src", "common", "ServerScriptService", "Services", "Race", "RaceArenaBuilder.luau")
SPEC_BEGIN = "-- BEGIN GENERATED RaceAssetSpec"
SPEC_END = "-- END GENERATED RaceAssetSpec"
ALL_FBX = "RaceAssets_All"

MODELS = ["RaceLobbyBooth", "RaceStartGantry", "RaceLoop", "RaceFinishGantry", "RaceCliff", "RaceFence",
          "RacePalm", "RaceSunflower", "RaceTotem", "RaceRing", "RaceIsland"]
BEVEL_ANGLE = 35.0
BEVEL_SEGMENTS = 2
TRI_BUDGET = (8000, 25000)

# Role -> Roblox look. The builder paints every MeshPart from this (the Lua copy is generated).
# Light is the start light's "off" colour (RaceArenaVisuals LIGHT_OFF); the client recolours it.
ROLES = {
    "Grass": {"color": (92, 196, 54), "material": "SmoothPlastic"},
    "GrassDark": {"color": (44, 138, 40), "material": "SmoothPlastic"},
    "CheckerA": {"color": (222, 132, 48), "material": "SmoothPlastic"},
    "CheckerB": {"color": (116, 60, 24), "material": "SmoothPlastic"},
    "Wood": {"color": (150, 94, 46), "material": "SmoothPlastic"},
    "Rope": {"color": (238, 222, 180), "material": "SmoothPlastic"},
    "Trunk": {"color": (204, 146, 74), "material": "SmoothPlastic"},
    "TrunkDark": {"color": (132, 84, 38), "material": "SmoothPlastic"},
    "Leaf": {"color": (38, 168, 66), "material": "SmoothPlastic"},
    "Gold": {"color": (255, 202, 36), "material": "SmoothPlastic", "reflectance": 0.2},
    "Blue": {"color": (30, 96, 224), "material": "SmoothPlastic"},
    "Red": {"color": (222, 40, 40), "material": "SmoothPlastic"},
    "White": {"color": (248, 248, 248), "material": "SmoothPlastic"},
    "Panel": {"color": (26, 82, 204), "material": "SmoothPlastic"},
    "GoalPanel": {"color": (30, 96, 224), "material": "SmoothPlastic"},
    "Light": {"color": (60, 18, 18), "material": "Neon"},
    "Water": {"color": (96, 196, 255), "material": "Glass", "transparency": 0.25},
    "Checker_White": {"color": (248, 248, 250), "material": "SmoothPlastic"},
    "Checker_Black": {"color": (24, 24, 30), "material": "SmoothPlastic"},
}
EMISSIVE = {"Light"}


def role_of(object_role):
    """Light_3 -> Light; every other object role is its own role."""
    return "Light" if object_role.startswith("Light_") else object_role


# ---------------------------------------------------------------------------------------------
# Coordinates: Roblox model space -> Blender
# ---------------------------------------------------------------------------------------------
def R(x, y, z):
    return Vector((x, -z, y))


def RV(v):
    return Vector((v[0], -v[2], v[1]))


def V3(x, y, z):
    return Vector((x, y, z))


# ---------------------------------------------------------------------------------------------
# Pieces: small bmesh primitives, bevelled on their own, joined per (model, role) later
# ---------------------------------------------------------------------------------------------
PIECES = []  # (model, role, object)
MARKERS = {m: {} for m in MODELS}
COLLIDERS = {m: [] for m in MODELS}
PIECE_BOXES = {m: [] for m in MODELS}  # booth: every piece's box (Roblox space), for placement tests
_serial = [0]


def _finish(model, role, bm, bevel, recalc=True):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for face in bm.faces:
        face.smooth = True
    _serial[0] += 1
    name = "_piece_%04d_%s_%s" % (_serial[0], model, role)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = BEVEL_SEGMENTS
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(BEVEL_ANGLE)
        mod.profile_type = "SUPERELLIPSE"
        mod.profile = 0.5
        mod.use_clamp_overlap = True
        mod.harden_normals = False
    PIECES.append((model, role, obj))
    return obj


def box(model, role, center, size, bevel=0.25):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    c = V3(*center)
    for v in bm.verts:
        o = v.co.copy()
        v.co = RV((c[0] + o.x * size[0], c[1] + o.y * size[1], c[2] + o.z * size[2]))
    return _finish(model, role, bm, bevel)


def prism(model, role, pts, origin, U, V, W, w0, w1, bevel=0.1, cap_low=True, cap_high=True):
    """Extrudes the 2D polygon pts (u, v) along W from w0 to w1; frame vectors in Roblox space.
    A cap that sits against another surface (never seen) is left open: no triangles, no bevel."""
    O, U, V, W = V3(*origin), V3(*U), V3(*V), V3(*W)
    bm = bmesh.new()
    low = [bm.verts.new(RV(O + U * u + V * v + W * w0)) for u, v in pts]
    high = [bm.verts.new(RV(O + U * u + V * v + W * w1)) for u, v in pts]
    n = len(pts)
    if cap_low:
        bm.faces.new(list(reversed(low)))
    if cap_high:
        bm.faces.new(high)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    return _finish(model, role, bm, bevel)


def circle_pts(radius, segments, start=0.0):
    return [(radius * math.cos(start + 2 * math.pi * i / segments), radius * math.sin(start + 2 * math.pi * i / segments))
            for i in range(segments)]


def axis_frame(axis):
    W = V3(*axis).normalized()
    helper = V3(0, 0, 1) if abs(W.z) < 0.9 else V3(1, 0, 0)
    U = W.cross(helper).normalized()
    V = W.cross(U).normalized()
    return U, V, W


def cylinder(model, role, center, radius, height, segments=12, axis=(0, 1, 0), bevel=0.15, cap_low=True, cap_high=True):
    """A cylinder centred on `center` along `axis` (Roblox space); cap_low is the -axis end.
    12+ sides stay under the 35 deg bevel limit, so only the rims are bevelled."""
    U, V, W = axis_frame(axis)
    return prism(model, role, circle_pts(radius, segments), center, U, V, W, -height / 2, height / 2, bevel, cap_low, cap_high)


def loft(model, role, c0, c1, r0, r1, segments=10, cap0=False, cap1=True, bevel=None):
    """A frustum from circle (c0, r0) to circle (c1, r1)."""
    c0, c1 = V3(*c0), V3(*c1)
    U, V, W = axis_frame(tuple(c1 - c0))
    bm = bmesh.new()
    ring0 = [bm.verts.new(RV(c0 + U * (r0 * math.cos(2 * math.pi * i / segments)) + V * (r0 * math.sin(2 * math.pi * i / segments))))
             for i in range(segments)]
    ring1 = [bm.verts.new(RV(c1 + U * (r1 * math.cos(2 * math.pi * i / segments)) + V * (r1 * math.sin(2 * math.pi * i / segments))))
             for i in range(segments)]
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
    if cap0:
        bm.faces.new(list(reversed(ring0)))
    if cap1:
        bm.faces.new(ring1)
    return _finish(model, role, bm, bevel)


def sphere(model, role, center, radius, u_segments=10, v_segments=6, squash=(1.0, 1.0, 1.0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u_segments, v_segments=v_segments, radius=radius)
    c = V3(*center)
    for v in bm.verts:
        o = v.co.copy()
        v.co = RV((c[0] + o.x * squash[0], c[1] + o.z * squash[1], c[2] + o.y * squash[2]))
    return _finish(model, role, bm, None)


def sweep(model, role, profile, frames, closed=False, bevel=0.2, open_profile=False, caps=(True, True), scales=None):
    """frames: list of (P, N, B) in Roblox space; profile: (a, b) -> P + s (a N + b B).
    open_profile: the profile's last->first side lies on a surface (a strip): not built."""
    bm = bmesh.new()
    rings = []
    for index, (P, N, B) in enumerate(frames):
        s = scales[index] if scales else 1.0
        rings.append([bm.verts.new(RV(P + (N * a + B * b) * s)) for a, b in profile])
    m = len(profile)
    count = len(rings) if closed else len(rings) - 1
    sides = m - 1 if open_profile else m
    for i in range(count):
        r0, r1 = rings[i], rings[(i + 1) % len(rings)]
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % m], r1[(k + 1) % m], r1[k]))
    if not closed:
        if caps[0]:
            bm.faces.new(list(reversed(rings[0])))
        if caps[1]:
            bm.faces.new(rings[-1])
    return _finish(model, role, bm, bevel)


def path_frames(points, up=(0, 1, 0)):
    """Frames along a path: N perpendicular to the tangent and `up`, B completes the frame."""
    upv = V3(*up)
    frames = []
    n = len(points)
    for i, P in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, n - 1)]
        T = (b - a).normalized()
        N = T.cross(upv)
        if N.length < 1e-6:
            N = T.cross(V3(1, 0, 0))
        N.normalize()
        B = N.cross(T).normalized()
        frames.append((P, N, B))
    return frames


def ring_frames(center, radius, axis, segments):
    U, V, W = axis_frame(axis)
    c = V3(*center)
    out = []
    for i in range(segments):
        t = 2 * math.pi * i / segments
        N = U * math.cos(t) + V * math.sin(t)
        out.append((c + N * radius, N, W))
    return out


def torus(model, role, center, major, minor, axis=(0, 0, 1), major_segments=16, minor_segments=6):
    profile = circle_pts(minor, minor_segments, start=math.pi / minor_segments)
    return sweep(model, role, profile, ring_frames(center, major, axis, major_segments), closed=True, bevel=None)


def raw_faces(model, role, polys):
    """Faces as given (Roblox space, counter-clockwise seen from outside); no bevel."""
    bm = bmesh.new()
    cache = {}

    def vert(p):
        key = (round(p[0], 4), round(p[1], 4), round(p[2], 4))
        if key not in cache:
            cache[key] = bm.verts.new(RV(p))
        return cache[key]

    for poly in polys:
        bm.faces.new([vert(p) for p in poly])
    return _finish(model, role, bm, None, recalc=False)


def teeth(model, role, start, end, out, top_y, depth, tooth, thick=0.3):
    """Grass-lip teeth hanging from top_y along start->end (horizontal), their back face at the
    given line, `thick` studs toward `out` (a unit vector); the back is left open."""
    start, end, out = V3(*start), V3(*end), V3(*out)
    length = (end - start).length
    along = (end - start).normalized()
    count = max(1, int(round(length / tooth)))
    step = length / count
    for k in range(count):
        a = start + along * (k * step)
        pts = [(0.0, 0.0), (step, 0.0), (step * 0.5, -depth)]
        prism(model, role, pts, (a.x, top_y, a.z), tuple(along), (0, 1, 0), tuple(out), 0.0, thick, bevel=None, cap_low=False)


def marker(model, name, point):
    MARKERS[model][name] = [round(float(x), 3) for x in point]


def collider_box(model, name, center, size):
    COLLIDERS[model].append({"name": name, "shape": "Box", "center": [round(float(x), 3) for x in center],
                             "size": [round(float(x), 3) for x in size]})


def collider_cylinder(model, name, center, radius, height):
    COLLIDERS[model].append({"name": name, "shape": "Cylinder", "center": [round(float(x), 3) for x in center],
                             "radius": round(float(radius), 3), "height": round(float(height), 3)})


def checker_role(i, j):
    return "CheckerA" if (i + j) % 2 == 0 else "CheckerB"


# ---------------------------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------------------------
def cube_arch(M, half_span, cube, pillar_cubes, depth=None, bevel=0.35):
    """A chunky arch of checker cubes: two pillars of `pillar_cubes` cubes at the ends and a beam
    of cubes across, from x -half_span to +half_span; the beam's bottom is pillar_cubes * cube."""
    depth = depth or cube
    count = int(round(2 * half_span / cube))
    for i in range(count):
        x = -half_span + cube * (i + 0.5)
        box(M, checker_role(i, pillar_cubes), (x, cube * (pillar_cubes + 0.5), 0), (cube, cube, depth), bevel)
    for side, i in ((-1, 0), (1, count - 1)):
        x = -half_span + cube * (i + 0.5)
        for j in range(pillar_cubes):
            box(M, checker_role(i, j), (x, cube * (j + 0.5), 0), (cube, cube, depth), bevel)
    return cube * (pillar_cubes + 1)  # the beam's top


def grass_cap(M, x0, x1, y, z0, z1, thick=1.0, overhang=0.7, tooth=4.0, depth=1.3, front=True, back=True, ends=True):
    """A grass slab on a top face, overhanging it, with dark grass teeth under the lip."""
    x0o = x0 - (overhang if ends else 0)
    x1o = x1 + (overhang if ends else 0)
    box(M, "Grass", ((x0o + x1o) / 2, y + thick / 2, (z0 + z1) / 2), (x1o - x0o, thick, (z1 - z0) + 2 * overhang), bevel=0.35)
    if front:
        teeth(M, "GrassDark", (x0, 0, z1 + 0.1), (x1, 0, z1 + 0.1), (0, 0, 1), y, depth, tooth)
    if back:
        teeth(M, "GrassDark", (x1, 0, z0 - 0.1), (x0, 0, z0 - 0.1), (0, 0, -1), y, depth, tooth)


def palm_pieces(M, base, height=11.0, lean=(1.0, 0.0), scale=1.0, fronds=8, coconuts=3, prefix=""):
    """A Green Hill palm: stacked flared trunk segments (two tones), drooping fronds, coconuts."""
    bx, by, bz = base
    segs = 5
    seg_h = height / segs
    lx, lz = lean
    points = []
    for i in range(segs + 1):
        t = i / segs
        points.append(V3(bx + lx * 2.2 * scale * t * t, by + height * t * scale, bz + lz * 2.2 * scale * t * t))
    for i in range(segs):
        role = "Trunk" if i % 2 == 0 else "TrunkDark"
        r = (0.95 - 0.07 * i) * scale
        loft(M, prefix + role, tuple(points[i]), tuple(points[i + 1] + (points[i + 1] - points[i]) * 0.08), r * 0.78, r * 1.08,
             segments=10, cap0=(i == 0 and False), cap1=True, bevel=None)
    top = points[-1] + V3(0, 0.3 * scale, 0)
    sphere(M, prefix + "TrunkDark", tuple(top), 0.9 * scale, 8, 5)
    for k in range(coconuts):
        a = 2 * math.pi * k / coconuts + 0.5
        sphere(M, prefix + "TrunkDark", (top.x + math.cos(a) * 0.9 * scale, top.y - 0.7 * scale, top.z + math.sin(a) * 0.9 * scale),
               0.5 * scale, 6, 4)
    frond = [(-1.0, 0.0), (0.0, 0.28), (1.0, 0.0), (0.0, -0.12)]
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + 0.3
        d = V3(math.cos(a), 0, math.sin(a))
        pts = []
        length = 6.2 * scale
        for i in range(6):
            t = i / 5
            pts.append(top + d * (length * t) + V3(0, (1.2 * t - 3.4 * t * t) * scale, 0))
        frames = path_frames(pts)
        widths = [0.25, 0.85, 1.0, 0.9, 0.6, 0.12]
        sweep(M, prefix + "Leaf", frond, frames, bevel=None, scales=[w * scale for w in widths], caps=(False, True))
    return top


# ---------------------------------------------------------------------------------------------
# RaceCliff: 168-stud causeway module, both sides (origin: track centre, floor top)
# ---------------------------------------------------------------------------------------------
TILE = 168.0
CELL = 6.0
SHOULDER = 52.0   # the cliff face |x|
SEA_Y = -40.0     # the sea's top (the cliff runs 4 studs under it)


def build_cliff():
    M = "RaceCliff"
    L = TILE
    rows = 7
    cols = int(L / CELL)
    for sx in (-1, 1):
        face = sx * SHOULDER
        # the wall (open at the tile ends: tiles meet end to end)
        prism(M, "CheckerA", [(0, -2 - rows * CELL), (0, -2), (-2, -2), (-2, -2 - rows * CELL)],
              (face, 0, 0), (sx, 0, 0), (0, 1, 0), (0, 0, 1), -L / 2, L / 2, bevel=0.3, cap_low=False, cap_high=False)
        # raised dark squares on its face
        for c in range(cols):
            for r in range(rows):
                if (c + r) % 2 == 1:
                    z0 = -L / 2 + c * CELL
                    y1 = -2 - r * CELL
                    prism(M, "CheckerB", [(z0, y1 - CELL), (z0 + CELL, y1 - CELL), (z0 + CELL, y1), (z0, y1)],
                          (0, 0, 0), (0, 0, 1), (0, 1, 0), (sx, 0, 0), abs(face), abs(face) + 0.22,
                          bevel=None, cap_low=False)
        # grass shoulder from the track edge (36) over the lip (52.7)
        inner, outer = 36.0, SHOULDER + 0.7
        prism(M, "Grass", [(inner, -2), (outer, -2), (outer, 0), (inner, 0)], (0, 0, 0), (sx, 0, 0), (0, 1, 0), (0, 0, 1),
              -L / 2, L / 2, bevel=0.3, cap_low=False, cap_high=False)
        teeth(M, "GrassDark", (face + sx * 0.3, 0, -L / 2 if sx > 0 else L / 2), (face + sx * 0.3, 0, L / 2 if sx > 0 else -L / 2),
              (sx, 0, 0), -2, 1.6, CELL)


# ---------------------------------------------------------------------------------------------
# RaceFence: 168-stud fence module on the invisible wall line (origin: the line, floor top)
# ---------------------------------------------------------------------------------------------
POST_EVERY = 8.0


def build_fence():
    M = "RaceFence"
    L = TILE
    posts = int(L / POST_EVERY)
    for i in range(posts + 1 if False else posts):
        z = -L / 2 + POST_EVERY * (i + 0.5)
        cylinder(M, "Wood", (0, 2.3, z), 0.55, 4.6, 12, (0, 1, 0), bevel=0.2, cap_low=False)
    for y0 in (2.2, 3.9):
        pts = []
        steps = int(L / 2)
        for k in range(steps + 1):
            z = -L / 2 + 2 * k
            phase = math.pi * (z - (-L / 2 + POST_EVERY * 0.5)) / POST_EVERY
            pts.append(V3(0, y0 - 0.35 * abs(math.sin(phase)), z))
        sweep(M, "Rope", circle_pts(0.14, 5), path_frames(pts), bevel=None, caps=(False, False))


# ---------------------------------------------------------------------------------------------
# RaceStartGantry: origin = track centre on the floor at the arch; racers see +Z
# ---------------------------------------------------------------------------------------------
START_POSTS_X = [-12, -6, 0, 6, 12]
ARCH_HALF = 50.0
ARCH_CUBE = 5.0


def star_post(M, x, base_y, index):
    cylinder(M, "Gold", (x, base_y + 0.3, 0), 0.9, 0.6, 12, (0, 1, 0), bevel=0.12, cap_low=False)
    cylinder(M, "Blue", (x, base_y + 0.6 + 2.6, 0), 0.34, 5.2, 12, (0, 1, 0), bevel=None, cap_low=False)
    cylinder(M, "Gold", (x, base_y + 5.9, 0), 0.6, 0.35, 12, (0, 1, 0), bevel=0.08)
    sphere(M, "Light_%d" % index, (x, base_y + 7.25, 0), 1.25, 10, 6)


def build_start_gantry():
    M = "RaceStartGantry"
    top = cube_arch(M, ARCH_HALF, ARCH_CUBE, 3)
    grass_cap(M, -ARCH_HALF, ARCH_HALF, top, -ARCH_CUBE / 2, ARCH_CUBE / 2)
    box(M, "Panel", (0, top - ARCH_CUBE / 2, ARCH_CUBE / 2 + 0.15), (30, 4.2, 0.3), bevel=0.1)
    marker(M, "PanelFace", (0, top - ARCH_CUBE / 2, ARCH_CUBE / 2 + 0.3))
    for index, x in enumerate(START_POSTS_X, start=1):
        star_post(M, x, top + 1.0, index)


# ---------------------------------------------------------------------------------------------
# RaceLoop: origin = track centre on the floor; a checker hoop the racers run through
# ---------------------------------------------------------------------------------------------
LOOP_CENTER_Y = 20.0
LOOP_RI, LOOP_RO = 46.5, 50.0
LOOP_HALF_W = 6.0


def build_loop():
    M = "RaceLoop"
    cy = LOOP_CENTER_Y
    theta0 = math.asin((-3.0 - cy) / LOOP_RO)  # both feet end 3 studs under the shoulders
    theta1 = math.pi - theta0
    segs = 28
    angles = [theta0 + (theta1 - theta0) * i / segs for i in range(segs + 1)]

    def P(t, r, z):
        return (r * math.cos(t), cy + r * math.sin(t), z)

    rows = [(-LOOP_HALF_W, 0.0), (0.0, LOOP_HALF_W)]
    polys = {"CheckerA": [], "CheckerB": []}
    for i in range(segs):
        t0, t1 = angles[i], angles[i + 1]
        for j, (z0, z1) in enumerate(rows):
            role = checker_role(i, j)
            polys[role].append([P(t0, LOOP_RO, z0), P(t1, LOOP_RO, z0), P(t1, LOOP_RO, z1), P(t0, LOOP_RO, z1)])
        # the two side faces (the racers see the +z one)
        polys[checker_role(i, 1)].append([P(t0, LOOP_RI, LOOP_HALF_W), P(t0, LOOP_RO, LOOP_HALF_W),
                                          P(t1, LOOP_RO, LOOP_HALF_W), P(t1, LOOP_RI, LOOP_HALF_W)])
        polys[checker_role(i, 0)].append([P(t1, LOOP_RI, -LOOP_HALF_W), P(t1, LOOP_RO, -LOOP_HALF_W),
                                          P(t0, LOOP_RO, -LOOP_HALF_W), P(t0, LOOP_RI, -LOOP_HALF_W)])
    for role, faces in polys.items():
        raw_faces(M, role, faces)
    # grass on the inside (the loop's running surface), overhanging the band a little
    frames = []
    for t in angles:
        N = V3(math.cos(t), math.sin(t), 0)
        frames.append((V3(0, cy, 0) + N * LOOP_RI, N, V3(0, 0, 1)))
    sweep(M, "Grass", [(-1.0, -LOOP_HALF_W - 0.4), (0.0, -LOOP_HALF_W - 0.4), (0.0, LOOP_HALF_W + 0.4), (-1.0, LOOP_HALF_W + 0.4)],
          frames, bevel=0.3, caps=(False, False))
    top_inner = cy + LOOP_RI - 1.0
    box(M, "Panel", (0, top_inner - 2.5, LOOP_HALF_W - 0.2), (20, 5, 0.4), bevel=0.12)
    marker(M, "PanelFace", (0, top_inner - 2.5, LOOP_HALF_W))


# ---------------------------------------------------------------------------------------------
# RaceFinishGantry: origin = track centre on the finish line; racers see +Z
# ---------------------------------------------------------------------------------------------
GOAL_SIGN = (42.0, 11.6, 8.0)


def build_finish_gantry():
    M = "RaceFinishGantry"
    top = cube_arch(M, ARCH_HALF, ARCH_CUBE, 3)
    grass_cap(M, -ARCH_HALF, ARCH_HALF, top, -ARCH_CUBE / 2, ARCH_CUBE / 2)
    beam_y0, beam_y1 = top - ARCH_CUBE, top
    front = ARCH_CUBE / 2
    # checkered-flag banners either side of the FINISH panel
    for sx in (-1, 1):
        xa, xb = sorted((sx * 17.0, sx * 47.0))
        box(M, "Checker_White", ((xa + xb) / 2, (beam_y0 + beam_y1) / 2, front + 0.1), (xb - xa, 4.4, 0.2), bevel=0.06)
        cols, rows = 12, 2
        cw, ch = (xb - xa) / cols, 4.4 / rows
        for c in range(cols):
            for r in range(rows):
                if (c + r) % 2 == 0:
                    x0 = xa + c * cw
                    y0 = (beam_y0 + beam_y1) / 2 - 2.2 + r * ch
                    prism(M, "Checker_Black", [(x0, y0), (x0 + cw, y0), (x0 + cw, y0 + ch), (x0, y0 + ch)], (0, 0, 0),
                          (1, 0, 0), (0, 1, 0), (0, 0, 1), front + 0.2, front + 0.32, bevel=None, cap_low=False)
    box(M, "Panel", (0, (beam_y0 + beam_y1) / 2, front + 0.15), (30, 4.2, 0.3), bevel=0.1)
    marker(M, "PanelFace", (0, (beam_y0 + beam_y1) / 2, front + 0.3))
    # the GOAL signpost beside the arch (its disc + rim spin around GoalSpin's vertical axis)
    gx, gy, gz = GOAL_SIGN
    cylinder(M, "White", (gx, (gy - 2.8) / 2, gz), 0.35, gy - 2.8, 12, (0, 1, 0), bevel=0.1, cap_low=False)
    cylinder(M, "White", (gx, 0.2, gz), 0.9, 0.4, 12, (0, 1, 0), bevel=0.12, cap_low=False)
    cylinder(M, "GoalPanel", (gx, gy, gz), 2.8, 0.5, 24, (0, 0, 1), bevel=0.12)
    torus(M, "GoalRim", (gx, gy, gz), 2.9, 0.3, axis=(0, 0, 1), major_segments=24, minor_segments=5)
    marker(M, "GoalSpin", (gx, gy, gz))
    for index, x in enumerate((-33, -11, 11, 33), start=1):
        marker(M, "ConfettiSpot_%d" % index, (x, beam_y0 - 1.5, 0))


# ---------------------------------------------------------------------------------------------
# Decor (origin: the base on the ground; faces +z toward the racers)
# ---------------------------------------------------------------------------------------------
def build_palm():
    palm_pieces("RacePalm", (0, 0, 0), height=11.0, lean=(0.8, 0.3))


def build_sunflower():
    M = "RaceSunflower"
    cylinder(M, "Leaf", (0, 2.6, 0), 0.25, 5.2, 6, (0, 1, 0), bevel=None, cap_low=False)
    leaf = [(0.0, 0.0), (1.2, 0.45), (2.2, 0.0), (1.2, -0.45)]
    for sx, y in ((1, 1.6), (-1, 2.6)):
        prism(M, "Leaf", leaf, (0, y, 0), (sx * 0.9, 0.44, 0), (0, 0, 1), (sx * -0.44, 0.9, 0), -0.08, 0.08, bevel=None)
    petals = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        r = 2.3 if i % 2 == 0 else 1.45
        petals.append((r * math.cos(a), r * math.sin(a)))
    prism(M, "Gold", petals, (0, 6.2, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), -0.15, 0.15, bevel=None)
    cylinder(M, "Wood", (0, 6.2, 0.3), 1.05, 0.5, 12, (0, 0, 1), bevel=0.12, cap_low=False)


def build_totem():
    M = "RaceTotem"
    colours = ["CheckerA", "Blue", "CheckerA"]
    for i, role in enumerate(colours):
        y = 1.6 + i * 3.2
        box(M, role, (0, y, 0), (3.0, 3.2, 3.0), bevel=0.35)
        for sx in (-1, 1):
            box(M, "White", (sx * 0.65, y + 0.45, 1.55), (0.6, 0.8, 0.12), bevel=None)
        prism(M, "Gold", [(-0.45, 0.0), (0.45, 0.0), (0.0, -0.75)], (0, y - 0.1, 1.5), (1, 0, 0), (0, 1, 0), (0, 0, 1), 0.0, 0.5,
              bevel=None, cap_low=False)
    for sx in (-1, 1):
        wing = [(0.0, 0.0), (2.4, 0.9), (2.2, 1.9), (0.0, 1.4)]
        prism(M, "Red", wing, (sx * 1.5, 4.0, 0), (sx, 0, 0), (0, 1, 0), (0, 0, 1), -0.25, 0.25, bevel=None, cap_low=True)
    box(M, "Red", (0, 9.95, 0), (2.2, 0.5, 2.2), bevel=0.15)


def build_ring():
    torus("RaceRing", "Gold", (0, 0, 0), 1.7, 0.3, axis=(0, 0, 1), major_segments=16, minor_segments=6)


ISLAND_R = 22.0


def build_island():
    M = "RaceIsland"
    n = 12
    radii = [ISLAND_R * f for f in (1.0, 0.92, 1.05, 0.96, 0.88, 1.02, 0.94, 1.06, 0.9, 1.0, 0.95, 1.03)]
    outline = [(radii[i] * math.cos(2 * math.pi * i / n), radii[i] * math.sin(2 * math.pi * i / n)) for i in range(n)]
    # grass top slab (u = x, v = z) from y -2.5 to 0
    prism(M, "Grass", outline, (0, 0, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0), -2.5, 0.0, bevel=0.5)
    # checker earth underneath: two rings of alternating facets down to a tip
    levels = [(-2.5, 1.0), (-11.0, 0.72), (-20.0, 0.38)]
    tip = (0.0, -28.0, 0.0)
    polys = {"CheckerA": [], "CheckerB": []}
    for li in range(len(levels) - 1):
        (ya, fa), (yb, fb) = levels[li], levels[li + 1]
        for i in range(n):
            j = (i + 1) % n
            a0 = (outline[i][0] * fa, ya, outline[i][1] * fa)
            a1 = (outline[j][0] * fa, ya, outline[j][1] * fa)
            b0 = (outline[i][0] * fb, yb, outline[i][1] * fb)
            b1 = (outline[j][0] * fb, yb, outline[j][1] * fb)
            polys[checker_role(i, li)].append([a0, b0, b1, a1])
    yl, fl = levels[-1]
    for i in range(n):
        j = (i + 1) % n
        polys[checker_role(i, len(levels) - 1)].append([(outline[i][0] * fl, yl, outline[i][1] * fl), tip,
                                                         (outline[j][0] * fl, yl, outline[j][1] * fl)])
    for role, faces in polys.items():
        raw_faces(M, role, faces)
    # the waterfall on the -x side (the builder turns the island so it faces the track)
    wx = -ISLAND_R - 0.8
    box(M, "Water", (wx, -52.0, 2.0), (1.0, 104.0, 7.0), bevel=None)
    sphere(M, "White", (wx + 0.6, 0.2, 2.0), 1.6, 8, 5, squash=(1.2, 0.6, 2.4))
    sphere(M, "White", (wx, -103.5, 2.0), 3.0, 8, 5, squash=(1.3, 0.5, 1.6))
    palm_pieces(M, (4.0, 0.0, -3.0), height=12.0, lean=(0.6, -0.4), scale=1.2)
    teeth(M, "GrassDark", (-12, 0, ISLAND_R * 0.95), (12, 0, ISLAND_R * 0.95), (0, 0, 1), -2.5, 1.4, 3.0)


# ---------------------------------------------------------------------------------------------
# RaceLobbyBooth: origin = the join pad's centre on the floor; players come from -Z (Face)
# ---------------------------------------------------------------------------------------------
PODIUM_Z = -1.8
KIOSK = (-19.0, 0.0, 0.0)
FLASH_SPOT = (-19.0, 1.0, 0.6)


def podium_tier(M, center, radius, y0, y1, segments=16):
    cx, _, cz = center
    grass = 0.2
    polys = {"CheckerA": [], "CheckerB": []}
    for i in range(segments):
        a0 = 2 * math.pi * i / segments
        a1 = 2 * math.pi * (i + 1) / segments
        p = lambda a, y: (cx + radius * math.cos(a), y, cz + radius * math.sin(a))
        polys[checker_role(i, 0)].append([p(a0, y0), p(a0, y1 - grass), p(a1, y1 - grass), p(a1, y0)])
    for role, faces in polys.items():
        raw_faces(M, role, faces)
    cylinder(M, "Grass", (cx, y1 - grass / 2, cz), radius + 0.15, grass, 24, (0, 1, 0), bevel=0.08, cap_low=False)


def build_booth():
    M = "RaceLobbyBooth"
    # Entrance podium (the pad): two checker tiers with grass tops, inside a giant gold ring.
    podium_tier(M, (0, 0, PODIUM_Z), 6.0, 0.0, 0.5)
    podium_tier(M, (0, 0, PODIUM_Z), 5.0, 0.5, 1.0)
    torus(M, "Gold", (0, 1.25, PODIUM_Z), 3.6, 0.28, axis=(0, 1, 0), major_segments=20, minor_segments=5)
    collider_cylinder(M, "PodiumStep", (0, 0.25, PODIUM_Z), 6.0, 0.5)
    collider_cylinder(M, "PodiumTop", (0, 0.5, PODIUM_Z), 5.0, 1.0)

    # Arch: chunky checker cubes, grass on top.
    cube = 3.0
    top = cube_arch(M, 12.0, cube, 4)
    grass_cap(M, -12.0, 12.0, top, -cube / 2, cube / 2, tooth=3.0, depth=1.0)
    for side in (-1, 1):
        collider_box(M, "Pillar" + ("L" if side < 0 else "R"), (side * 10.5, 6.0, 0), (3.0, 12.0, 3.0))

    # Goal-sign style RACE board on the arch.
    board_y = top + 1.0 + 4.3
    cylinder(M, "White", (0, top + 1.0 + 0.6, 0), 0.3, 1.2, 12, (0, 1, 0), bevel=None, cap_low=False)
    cylinder(M, "Panel", (0, board_y, 0), 3.6, 0.5, 24, (0, 0, 1), bevel=0.12)
    torus(M, "Gold", (0, board_y, 0), 3.7, 0.32, axis=(0, 0, 1), major_segments=24, minor_segments=5)
    marker(M, "RacePanel", (0, board_y, 0))
    marker(M, "SignAnchor", (0, board_y + 6.0, 0))

    # Two palms leaning out.
    palm_pieces(M, (-14.0, 0.0, -2.5), height=10.5, lean=(-0.7, -0.2), scale=0.95)
    palm_pieces(M, (14.0, 0.0, -2.5), height=10.5, lean=(0.7, -0.2), scale=0.95)
    for side in (-1, 1):
        box(M, "GrassDark", (side * 14.0, 0.15, -2.5), (2.6, 0.3, 2.6), bevel=0.1)

    # The Flash's kiosk: a checker platform (grass top) and a curved wooden counter with a ring.
    kx, _, kz = KIOSK
    for i, (dx, dz) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        box(M, checker_role(i, 0), (kx + dx * 1.75, 0.4, kz + dz * 1.75), (3.5, 0.8, 3.5), bevel=0.18)
    box(M, "Grass", (kx, 0.9, kz), (7.3, 0.2, 7.3), bevel=0.08)
    collider_box(M, "Kiosk", (kx, 0.5, kz), (7.0, 1.0, 7.0))
    fx, fy, fz = FLASH_SPOT
    arc = []
    for i in range(9):
        theta = math.radians(-64 + 16 * i)
        radial = V3(math.sin(theta), 0, -math.cos(theta))
        arc.append((V3(fx, 0, fz) + radial * 2.5, radial, V3(0, 1, 0)))
    sweep(M, "Wood", [(-0.45, 1.0), (0.45, 1.0), (0.55, 2.9), (-0.45, 2.9)], arc, bevel=0.12)
    sweep(M, "White", [(-0.6, 2.88), (0.75, 2.88), (0.75, 3.12), (-0.6, 3.12)], arc, bevel=0.08)
    torus(M, "Gold", (fx, 2.0, fz - 3.1), 0.75, 0.16, axis=(0, 0, 1), major_segments=12, minor_segments=4)
    collider_box(M, "Counter", (fx, 2.0, fz - 1.9), (5.4, 2.0, 2.2))

    marker(M, "FlashSpot", FLASH_SPOT)
    MARKERS[M]["PadTrigger"] = {"center": [0.0, 0.2, 0.0], "size": [12.0, 0.4, 12.0]}


# ---------------------------------------------------------------------------------------------
# Join per role, WeightedNormal, materials
# ---------------------------------------------------------------------------------------------
def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MATERIALS = {}


def material_for(object_role):
    key = object_role
    if key in MATERIALS:
        return MATERIALS[key]
    role = ROLES[role_of(object_role)]
    mat = bpy.data.materials.new("RA_" + key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    color = role["color"]
    # Preview only: star-post balls shown red, red, red, green, green (the client colours them).
    if object_role.startswith("Light_"):
        color = (255, 40, 40) if int(object_role[6:]) <= 3 else (70, 230, 90)
    rgba = (srgb_to_linear(color[0]), srgb_to_linear(color[1]), srgb_to_linear(color[2]), 1.0)
    mat.diffuse_color = rgba
    if bsdf:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = 0.55
        if role_of(object_role) in ("Gold", "GoalRim"):
            bsdf.inputs["Metallic"].default_value = 0.55
            bsdf.inputs["Roughness"].default_value = 0.25
        if role_of(object_role) in EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = rgba
            bsdf.inputs["Emission Strength"].default_value = 3.0
        if role_of(object_role) == "Water":
            bsdf.inputs["Alpha"].default_value = 1.0 - role.get("transparency", 0)
            bsdf.inputs["Emission Color"].default_value = rgba
            bsdf.inputs["Emission Strength"].default_value = 0.4
            mat.surface_render_method = "BLENDED"
    MATERIALS[key] = mat
    return mat


def join_roles():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for model, role, obj in PIECES:
        groups.setdefault((model, role), []).append(obj)
    result = {m: [] for m in MODELS}
    for (model, role) in sorted(groups):
        bm = bmesh.new()
        for obj in groups[(model, role)]:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = bpy.data.meshes.new_from_object(evaluated)
            if model == "RaceLobbyBooth":
                plo = Vector((min(v.co.x for v in mesh.vertices), min(v.co.y for v in mesh.vertices), min(v.co.z for v in mesh.vertices)))
                phi = Vector((max(v.co.x for v in mesh.vertices), max(v.co.y for v in mesh.vertices), max(v.co.z for v in mesh.vertices)))
                pc, ps = to_roblox_box(plo, phi)
                PIECE_BOXES[model].append({"role": role, "center": pc, "size": ps})
            if STATS:
                print("  piece %-44s %5d tris" % (obj.name, sum(len(p.vertices) - 2 for p in mesh.polygons)))
            bm.from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
        for face in bm.faces:
            face.smooth = True
            face.material_index = 0
        lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
        hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
        centre = (lo + hi) * 0.5
        bmesh.ops.translate(bm, vec=-centre, verts=bm.verts[:])
        name = "%s__%s" % (model, role)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material_for(role))
        obj = bpy.data.objects.new(name, mesh)
        obj.location = centre
        bpy.context.scene.collection.objects.link(obj)
        wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        wn.mode = "FACE_AREA"
        wn.weight = 50
        wn.keep_sharp = True
        result[model].append(obj)
    for model, role, obj in PIECES:
        mesh = obj.data
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(mesh)
    PIECES.clear()
    bpy.context.view_layer.update()  # matrix_world of the new objects (bounds() reads it)
    return result


def triangles(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def bounds(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return lo, hi


def to_roblox_box(lo, hi):
    c = (lo + hi) * 0.5
    s = hi - lo
    return [round(c.x, 3), round(c.z, 3), round(-c.y, 3)], [round(s.x, 3), round(s.z, 3), round(s.y, 3)]


# ---------------------------------------------------------------------------------------------
# Export and checks
# ---------------------------------------------------------------------------------------------
def export_fbx(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(FBX_DIR, name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,
        use_mesh_modifiers=True,
        mesh_smooth_type="OFF",
        use_triangles=True,
        use_tspace=False,
        use_custom_props=False,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="AUTO",
        embed_textures=False,
    )
    return path


# Where each model sits in RaceAssets_All.fbx (Roblox x), so the one-file import is readable in
# Studio; the builder never uses imported positions.
ALL_LAYOUT_X = {"RaceLobbyBooth": 0, "RaceStartGantry": 140, "RaceLoop": 260, "RaceFinishGantry": 380, "RaceCliff": 520,
                "RaceFence": 600, "RacePalm": 640, "RaceSunflower": 660, "RaceTotem": 680, "RaceRing": 700, "RaceIsland": 760}


def fbx_unit_scale(path):
    with open(path, "rb") as handle:
        data = handle.read()
    at = data.find(b"UnitScaleFactor")
    if at < 0:
        return None
    window = data[at:at + 160]
    idx = window.find(b"S\x00\x00\x00\x00D")
    if idx < 0:
        return None
    return struct.unpack("<d", window[idx + 6:idx + 14])[0]


def luau_number(x):
    text = ("%.3f" % x).rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def luau_vec(v):
    return "{ %s }" % ", ".join(luau_number(x) for x in v)


def write_spec(manifest):
    lines = [SPEC_BEGIN + " (audit/generate_race_assets.py %s; do not edit by hand)" % manifest["generated"]]
    lines.append("RaceArenaBuilder.AssetModels = { %s }" % ", ".join('"%s"' % m for m in MODELS))
    lines.append("-- Role -> look of every asset MeshPart (Color RGB 0-255, Material, optional Transparency/Reflectance).")
    lines.append("RaceArenaBuilder.AssetRoles = {")
    for role in sorted(ROLES):
        info = ROLES[role]
        extra = ""
        if "transparency" in info:
            extra += ", Transparency = %s" % luau_number(info["transparency"])
        if "reflectance" in info:
            extra += ", Reflectance = %s" % luau_number(info["reflectance"])
        lines.append("\t%s = { Color = %s, Material = \"%s\"%s }," % (role, luau_vec(info["color"]), info["material"], extra))
    lines.append("}")
    lines.append("-- Per model: every MeshPart (name, role, bounding-box centre and size in the model's frame,")
    lines.append("-- studs; x right, y up, -z = the booth's front / the racers' forward), markers, colliders.")
    lines.append("RaceArenaBuilder.AssetSpec = {")
    for model in MODELS:
        info = manifest["models"][model]
        lines.append("\t%s = {" % model)
        lines.append("\t\tSize = %s, Triangles = %d," % (luau_vec(info["size"]), info["triangles"]))
        lines.append("\t\tParts = {")
        for part in info["parts"]:
            lines.append("\t\t\t{ Name = \"%s\", Role = \"%s\", Center = %s, Size = %s }," % (
                part["name"], part["role"], luau_vec(part["center"]), luau_vec(part["size"])))
        lines.append("\t\t},")
        lines.append("\t\tMarkers = {")
        for name in sorted(info["markers"]):
            value = info["markers"][name]
            if isinstance(value, dict):
                lines.append("\t\t\t%s = { Center = %s, Size = %s }," % (name, luau_vec(value["center"]), luau_vec(value["size"])))
            else:
                lines.append("\t\t\t%s = %s," % (name, luau_vec(value)))
        lines.append("\t\t},")
        lines.append("\t\tColliders = {")
        for col in info["colliders"]:
            if col["shape"] == "Box":
                lines.append("\t\t\t{ Name = \"%s\", Shape = \"Box\", Center = %s, Size = %s }," % (
                    col["name"], luau_vec(col["center"]), luau_vec(col["size"])))
            else:
                lines.append("\t\t\t{ Name = \"%s\", Shape = \"Cylinder\", Center = %s, Radius = %s, Height = %s }," % (
                    col["name"], luau_vec(col["center"]), luau_number(col["radius"]), luau_number(col["height"])))
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append(SPEC_END)
    block = "\n".join(lines)
    with open(BUILDER, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    crlf = "\r\n" in source
    source = source.replace("\r\n", "\n")
    begin = source.find(SPEC_BEGIN)
    end = source.find(SPEC_END)
    if begin < 0 or end < begin:
        print("WARNING: %s has no generated RaceAssetSpec block; not written" % BUILDER)
        return False
    end += len(SPEC_END)
    source = source[:begin] + block + source[end:]
    if crlf:
        source = source.replace("\n", "\r\n")
    with open(BUILDER, "w", encoding="utf-8", newline="") as handle:
        handle.write(source)
    return True


# ---------------------------------------------------------------------------------------------
# Preview renders: sunny Green Hill scenes (context objects are never exported)
# ---------------------------------------------------------------------------------------------
def context_material(name, rgb, rough=0.7, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    col = (srgb_to_linear(rgb[0]), srgb_to_linear(rgb[1]), srgb_to_linear(rgb[2]), 1.0)
    mat.diffuse_color = col
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    return mat


def checker_material(name, rgb_a, rgb_b, cells_per_unit):
    """The lobby's checker look for context floors (Blender checker texture in object space)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.75
    coord = nodes.new("ShaderNodeTexCoord")
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = cells_per_unit
    checker.inputs["Color1"].default_value = tuple(srgb_to_linear(c) for c in rgb_a) + (1.0,)
    checker.inputs["Color2"].default_value = tuple(srgb_to_linear(c) for c in rgb_b) + (1.0,)
    links.new(coord.outputs["Generated"], checker.inputs["Vector"])
    links.new(checker.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def context_box(collection, name, center, size, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        o = v.co.copy()
        v.co = RV((center[0] + o.x * size[0], center[1] + o.y * size[1], center[2] + o.z * size[2]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def cloud(collection, name, center, scale, mat):
    for k, (dx, dy, r) in enumerate(((0, 0, 1.0), (1.1, 0.25, 0.8), (-1.1, 0.15, 0.75), (0.5, 0.6, 0.7), (-0.4, 0.55, 0.65))):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r * scale)
        for v in bm.verts:
            o = v.co.copy()
            v.co = R(center[0] + dx * scale + o.x, center[1] + dy * scale + o.z * 0.7, center[2] + o.y * 0.8)
        mesh = bpy.data.meshes.new("%s_%d" % (name, k))
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(mesh.name, mesh)
        collection.objects.link(obj)


def dummy(collection, name, feet, mat_body, mat_head):
    """A 5-stud R6-sized stand-in (scale reference only)."""
    x, y, z = feet
    context_box(collection, name + "_legs", (x, y + 1.0, z), (2.0, 2.0, 1.0), mat_body)
    context_box(collection, name + "_torso", (x, y + 3.0, z), (2.0, 2.0, 1.0), mat_body)
    context_box(collection, name + "_arms", (x, y + 3.0, z), (4.0, 2.0, 1.0), mat_body)
    context_box(collection, name + "_head", (x, y + 4.6, z), (1.2, 1.2, 1.2), mat_head)


def place_copy(collection, objects, offset, yaw=0.0):
    """Linked copies of a model's role objects at `offset` (Roblox space), turned `yaw` about y."""
    c, s = math.cos(yaw), math.sin(yaw)
    for src in objects:
        dup = src.copy()
        dup.name = "ctx_" + src.name
        lx, ly, lz = src.location.x, src.location.z, -src.location.y  # Roblox-space centre
        rx, rz = lx * c + lz * s, -lx * s + lz * c
        dup.location = R(offset[0] + rx, offset[1] + ly, offset[2] + rz)
        dup.rotation_euler = (0, 0, yaw)
        collection.objects.link(dup)


def setup_render():
    scene = bpy.context.scene
    engines = {item.identifier for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
        scene.eevee.use_shadows = True
    except AttributeError:
        pass
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("RA_World")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    bg = nodes["Background"]
    # Sky: a vertical gradient (horizon pale blue -> zenith deep blue).
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[0].color = (0.55, 0.78, 1.0, 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (0.12, 0.38, 0.95, 1.0)
    mapr = nodes.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -1.0
    mapr.inputs["From Max"].default_value = 1.0
    links.new(coord.outputs["Window"] if False else coord.outputs["Generated"], sep.inputs["Vector"])
    links.new(sep.outputs["Z"], mapr.inputs["Value"])
    links.new(mapr.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    sun_data = bpy.data.lights.new("RA_Sun", "SUN")
    sun_data.energy = 4.0
    sun_data.color = (1.0, 0.96, 0.88)
    sun_data.angle = math.radians(4)
    sun = bpy.data.objects.new("RA_Sun", sun_data)
    sun.rotation_euler = (math.radians(42), math.radians(-18), math.radians(28))
    scene.collection.objects.link(sun)
    cam_data = bpy.data.cameras.new("RA_Camera")
    cam_data.lens = 32
    cam_data.clip_start = 0.5
    cam_data.clip_end = 5000
    cam = bpy.data.objects.new("RA_Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def aim_camera(cam, target, direction, distance):
    d = Vector(direction).normalized()
    cam.location = target + d * distance
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def render_previews(objects_by_model):
    scene = bpy.context.scene
    cam = setup_render()
    grass = checker_material("RA_ctx_grass", (96, 204, 60), (80, 184, 50), 18.0)
    lobby = checker_material("RA_ctx_lobby", (70, 176, 52), (58, 160, 44), 12.0)
    sea = context_material("RA_ctx_sea", (40, 150, 240), rough=0.15)
    body = context_material("RA_ctx_dummy", (255, 200, 60))
    flash = context_material("RA_ctx_flash", (200, 30, 30))
    skin = context_material("RA_ctx_skin", (250, 215, 170))
    white = context_material("RA_ctx_cloud", (255, 255, 255), rough=0.9)
    O = objects_by_model

    def track_bit(col, s0, s1, fences=True, cliffs=True):
        """Floor, cliff and fence tiles from s0 to s1 (s = -z)."""
        context_box(col, "ctx_floor", (0, -1.0, -(s0 + s1) / 2), (72, 2.0, s1 - s0), grass)
        k = s0
        while k < s1:
            mid = k + TILE / 2
            if cliffs:
                place_copy(col, O["RaceCliff"], (0, 0, -mid))
            if fences:
                for sx in (-1, 1):
                    place_copy(col, O["RaceFence"], (sx * 38.1, 0, -mid))
            k += TILE

    scenes = {}
    for model in MODELS + ["Overview"]:
        col = bpy.data.collections.new("ctx_" + model)
        scene.collection.children.link(col)
        scenes[model] = col

    # Per-model context.
    c = scenes["RaceLobbyBooth"]
    context_box(c, "ctx_floor", (0, -0.5, 0), (120, 1.0, 90), lobby)
    dummy(c, "ctx_player", (0, 1.0, -3.0), body, skin)
    dummy(c, "ctx_flash", FLASH_SPOT, flash, skin)
    for m in ("RaceStartGantry", "RaceLoop", "RaceFinishGantry"):
        c = scenes[m]
        track_bit(c, -170, 170)
        context_box(c, "ctx_sea", (0, SEA_Y - 0.5, 0), (1400, 1.0, 1400), sea)
        for i, x in enumerate((-13.5, -4.5, 4.5, 13.5)):
            dummy(c, "ctx_racer%d" % i, (x, 0, 18.0), body, skin)
    c = scenes["RaceCliff"]
    track_bit(c, -84, 84, fences=False)
    context_box(c, "ctx_sea", (0, SEA_Y - 0.5, 0), (1400, 1.0, 1400), sea)
    c = scenes["RaceFence"]
    track_bit(c, -84, 84, cliffs=True)
    context_box(c, "ctx_sea", (0, SEA_Y - 0.5, 0), (1400, 1.0, 1400), sea)
    dummy(c, "ctx_player", (30.0, 0, 0.0), body, skin)
    for m in ("RacePalm", "RaceSunflower", "RaceTotem", "RaceRing"):
        c = scenes[m]
        context_box(c, "ctx_floor", (0, -0.5, 0), (60, 1.0, 60), lobby)
        dummy(c, "ctx_player", (4.0, 0, 3.0), body, skin)
    c = scenes["RaceIsland"]
    context_box(c, "ctx_sea", (0, -100.5, 0), (1400, 1.0, 1400), sea)
    for i, (x, y, z, s) in enumerate(((-60, 40, -150, 14), (80, 70, -220, 18))):
        cloud(c, "ctx_cloud%d" % i, (x, y, z), s, white)

    # Overview: the start of the track down to the first loop, decor, islands, sea, clouds.
    c = scenes["Overview"]
    track_bit(c, -170, 3 * TILE + 60)
    context_box(c, "ctx_sea", (0, SEA_Y - 0.5, -600), (3000, 1.0, 3000), sea)
    place_copy(c, O["RaceStartGantry"], (0, 0, -16))
    place_copy(c, O["RaceLoop"], (0, 0, -420))
    for s_, sx in ((60, 1), (150, -1), (240, 1), (330, -1), (480, 1)):
        place_copy(c, O["RacePalm"], (sx * 46.0, 0, -s_))
    for s_, sx in ((95, -1), (190, 1), (285, -1), (380, 1)):
        place_copy(c, O["RaceSunflower"], (sx * 44.0, 0, -s_))
    for s_, sx in ((120, 1), (300, -1)):
        place_copy(c, O["RaceTotem"], (sx * 47.0, 0, -s_))
    for k in range(5):
        place_copy(c, O["RaceRing"], (-9.0, 8.0 + 2.5 * math.sin(math.pi * k / 4), -(200 + 9 * k)))
    place_copy(c, O["RaceIsland"], (260, 70, -520))
    place_copy(c, O["RaceIsland"], (-300, 90, -760), yaw=math.pi)
    for i, (x, y, z, s) in enumerate(((-120, 150, -700, 22), (180, 180, -900, 26), (40, 200, -1300, 30), (-300, 170, -1100, 24))):
        cloud(c, "ctx_cloud%d" % i, (x, y, z), s, white)
    for i, x in enumerate((-13.5, -4.5, 4.5, 13.5, -22.5, 22.5)):
        dummy(c, "ctx_racer%d" % i, (x, 0, 10.0 + (i // 4) * 12), body, skin)

    views = {
        # model: (target (Roblox) or None = the model's centre, direction from target, distance factor)
        "RaceLobbyBooth": (None, (0.45, 0.32, -1.0), 1.15),
        "RaceStartGantry": (None, (0.35, 0.25, 1.0), 1.0),
        "RaceLoop": (None, (0.42, 0.18, 1.0), 1.05),
        "RaceFinishGantry": (None, (0.42, 0.22, 1.0), 1.0),
        "RaceCliff": ((52, -18, 0), (1.0, 0.25, 0.75), 70.0),
        "RaceFence": ((34, 3, 0), (-0.55, 0.45, 1.0), 26.0),
        "RacePalm": (None, (0.6, 0.35, 1.0), 1.6),
        "RaceSunflower": (None, (0.5, 0.3, 1.0), 1.7),
        "RaceTotem": (None, (0.6, 0.3, 1.0), 1.7),
        "RaceRing": (None, (0.4, 0.2, 1.0), 1.8),
        "RaceIsland": (None, (1.0, 0.25, 0.5), 1.3),
        "Overview": ((0, 10, -150), (0.28, 0.42, 1.0), 170.0),
    }
    written = {}
    for name in MODELS + ["Overview"]:
        for other in MODELS:
            for obj in objects_by_model[other]:
                obj.hide_render = not (other == name)
        for key, col in scenes.items():
            col.hide_render = key != name
        target, direction, factor = views[name]
        if target is None:
            lo = Vector((1e9, 1e9, 1e9))
            hi = Vector((-1e9, -1e9, -1e9))
            for obj in objects_by_model[name]:
                a, b = bounds(obj)
                lo = Vector((min(lo.x, a.x), min(lo.y, a.y), min(lo.z, a.z)))
                hi = Vector((max(hi.x, b.x), max(hi.y, b.y), max(hi.z, b.z)))
            centre = (lo + hi) * 0.5
            radius = (hi - lo).length * 0.5
            fov = 2 * math.atan(18.0 / cam.data.lens)
            aim_camera(cam, centre, RV(direction), radius / math.sin(fov / 2) * factor)
        else:
            aim_camera(cam, R(*target), RV(direction), factor)
        path = os.path.join(PREVIEW_DIR, ("RaceTrack_Overview" if name == "Overview" else name) + ".png")
        scene.render.filepath = path
        try:
            bpy.ops.render.render(write_still=True)
        except Exception as err:
            print("Eevee failed (%s); trying Workbench" % err)
            scene.render.engine = "BLENDER_WORKBENCH"
            scene.display.shading.color_type = "MATERIAL"
            bpy.ops.render.render(write_still=True)
        written[name] = os.path.relpath(path, ROOT).replace("\\", "/")
        print("preview %s" % written[name])
    for obj in bpy.data.objects:
        obj.hide_render = False
    return written


# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    for folder in (DESIGN, FBX_DIR, PREVIEW_DIR):
        os.makedirs(folder, exist_ok=True)
    # Only this run's files stay (a model that was renamed or dropped leaves nothing behind).
    for stale in glob.glob(os.path.join(FBX_DIR, "*.fbx")) + glob.glob(os.path.join(PREVIEW_DIR, "*.png")):
        os.remove(stale)

    build_booth()
    build_start_gantry()
    build_loop()
    build_finish_gantry()
    build_cliff()
    build_fence()
    build_palm()
    build_sunflower()
    build_totem()
    build_ring()
    build_island()
    objects_by_model = join_roles()

    manifest = {
        "version": 2,
        "style": "Sonic Green Hill",
        "generated": "2026-09-25",
        "generator": "audit/generate_race_assets.py",
        "units": "1 Blender unit = 1 stud; FBX: Apply Scalings = FBX Units Scale, forward -Z, up Y, Apply Transform",
        "space": "Roblox model space: x right, y up, z back (Blender x, -z, y)",
        "bevel": {"angle_limit_deg": BEVEL_ANGLE, "segments": BEVEL_SEGMENTS, "profile": "superellipse 0.5",
                  "normals": "WeightedNormal face area 50, keep sharp"},
        "all_in_one": "fbx/%s.fbx" % ALL_FBX,
        "roles": {role: {"color": list(info["color"]), "material": info["material"],
                         **({"transparency": info["transparency"]} if "transparency" in info else {}),
                         **({"reflectance": info["reflectance"]} if "reflectance" in info else {})}
                  for role, info in sorted(ROLES.items())},
        "models": {},
    }
    total = 0
    for model in MODELS:
        objs = sorted(objects_by_model[model], key=lambda o: o.name)
        parts = []
        mlo = Vector((1e9, 1e9, 1e9))
        mhi = Vector((-1e9, -1e9, -1e9))
        model_tris = 0
        for obj in objs:
            lo, hi = bounds(obj)
            mlo = Vector((min(mlo.x, lo.x), min(mlo.y, lo.y), min(mlo.z, lo.z)))
            mhi = Vector((max(mhi.x, hi.x), max(mhi.y, hi.y), max(mhi.z, hi.z)))
            centre, size = to_roblox_box(lo, hi)
            tris = triangles(obj)
            model_tris += tris
            object_role = obj.name.split("__", 1)[1]
            parts.append({"name": obj.name, "role": role_of(object_role), "center": centre, "size": size, "triangles": tris})
        _, msize = to_roblox_box(mlo, mhi)
        total += model_tris
        manifest["models"][model] = {
            "fbx": "fbx/%s.fbx" % model,
            "preview": "preview/%s.png" % model,
            "triangles": model_tris,
            "size": msize,
            "parts": parts,
            "markers": MARKERS[model],
            "colliders": COLLIDERS[model],
        }
        if model == "RaceLobbyBooth":
            manifest["models"][model]["pieces"] = PIECE_BOXES[model]
    manifest["total_triangles"] = total
    manifest["total_meshparts"] = sum(len(m["parts"]) for m in manifest["models"].values())

    everything = []
    for model in MODELS:
        objs = sorted(objects_by_model[model], key=lambda o: o.name)
        path = export_fbx(model, objs)
        manifest["models"][model]["fbx_unit_scale_factor"] = fbx_unit_scale(path)
        print("exported %s" % os.path.relpath(path, ROOT))
        everything.extend(objs)
    # The one-file import: every model side by side (moved for the export only).
    moved = []
    for model in MODELS:
        shift = R(ALL_LAYOUT_X[model], 0, 0)
        for obj in objects_by_model[model]:
            obj.location = obj.location + shift
            moved.append((obj, shift))
    bpy.context.view_layer.update()
    export_fbx(ALL_FBX, everything)
    for obj, shift in moved:
        obj.location = obj.location - shift
    bpy.context.view_layer.update()
    print("exported design/race/fbx/%s.fbx" % ALL_FBX)

    if RENDER:
        manifest["previews"] = render_previews(objects_by_model)

    # Empties for the markers (only in the .blend, never exported).
    for model in MODELS:
        for name, value in MARKERS[model].items():
            point = value["center"] if isinstance(value, dict) else value
            empty = bpy.data.objects.new("marker_%s_%s" % (model, name), None)
            empty.empty_display_type = "CUBE" if isinstance(value, dict) else "ARROWS"
            empty.empty_display_size = 0.6
            empty.location = R(*point)
            scene.collection.objects.link(empty)
    bpy.context.preferences.filepaths.save_version = 0  # no race_assets.blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)

    # Round trip: re-import every FBX into an empty scene; boxes must come back in studs.
    expected = {}
    for model in MODELS:
        for part in manifest["models"][model]["parts"]:
            expected[part["name"]] = (model, part)
    problems = []

    def check_file(fbx_name, models, layout):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=os.path.join(FBX_DIR, fbx_name + ".fbx"))
        bpy.context.view_layer.update()
        seen = set()
        for obj in bpy.data.objects:
            if obj.type != "MESH":
                continue
            seen.add(obj.name)
            entry = expected.get(obj.name)
            if not entry or entry[0] not in models:
                problems.append("unexpected object %s in %s.fbx" % (obj.name, fbx_name))
                continue
            model, want = entry
            lo, hi = bounds(obj)
            centre, size = to_roblox_box(lo, hi)
            if layout:
                centre[0] = round(centre[0] - ALL_LAYOUT_X[model], 3)
            for axis in range(3):
                if abs(size[axis] - want["size"][axis]) > 0.02 or abs(centre[axis] - want["center"][axis]) > 0.02:
                    problems.append("%s (%s.fbx): re-imported box %s/%s != %s/%s" % (obj.name, fbx_name, centre, size, want["center"], want["size"]))
                    break
            tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            if tris != want["triangles"]:
                problems.append("%s: %d triangles in %s.fbx, %d in the scene" % (obj.name, tris, fbx_name, want["triangles"]))
            if obj.name == "RaceCliff__Grass" and not layout:
                known = size[2]
                if abs(known - TILE) > 0.01:
                    problems.append("known dimension: RaceCliff__Grass is %.3f long after the round trip, not %.1f" % (known, TILE))
                manifest["known_dimension"] = "RaceCliff__Grass length after the FBX round trip: %.3f studs (built as %.1f)" % (known, TILE)
        for name, (model, _) in expected.items():
            if model in models and name not in seen:
                problems.append("%s missing from %s.fbx" % (name, fbx_name))

    for model in MODELS:
        check_file(model, {model}, False)
    check_file(ALL_FBX, set(MODELS), True)
    manifest["roundtrip"] = "ok" if not problems else problems

    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=1, sort_keys=True)
        handle.write("\n")
    spec_written = write_spec(manifest) if WRITE_SPEC else False

    print("")
    print("RACE ASSETS, Green Hill (1 unit = 1 stud)")
    for model in MODELS:
        info = manifest["models"][model]
        print("  %-18s %6d tris  size %-18s parts %2d  FBX UnitScaleFactor %s" % (
            model, info["triangles"], "x".join("%.1f" % s for s in info["size"]), len(info["parts"]),
            info["fbx_unit_scale_factor"]))
    print("  total %d triangles (budget up to %d), %d MeshParts" % (total, TRI_BUDGET[1], manifest["total_meshparts"]))
    print("  round trip: %s" % ("ok" if not problems else "; ".join(problems[:6])))
    print("  %s" % manifest.get("known_dimension", "known dimension not checked"))
    print("  spec block in RaceArenaBuilder: %s" % ("written" if spec_written else "not written"))
    if problems:
        raise SystemExit("round trip failed")
    if not (TRI_BUDGET[0] <= total <= TRI_BUDGET[1]):
        print("WARNING: total triangles outside the budget")


if __name__ == "__main__":
    main()
