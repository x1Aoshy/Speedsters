"""Dr. Eggman's Egg Mobile kit (Blender 4.5, headless, deterministic).

2026-09-26 (owner): the classic Egg Mobile (Sonic Generations style), made in Blender instead of the part-built
ship. References (design/npc/eggmobile/reference/): EggMobile_reference.webp (right side), EggMobile_reference_back.png
(cockpit and back) and Eggman_logo.png (his emblem, traced below as geometry). What it is:
  * an egg pod: a tall white glossy hull (a cylinder wall over a round bottom) with panel seams and rows of rivets,
    the bottom a black sphere; the cockpit open at the top behind a thick rim;
  * a clear glass windshield bubble over the front with a thin metal frame arc over the cockpit, grab handles
    on the rim; under it a curved dashboard with a big round cyan screen and two round red lights; two red
    levers (Eggman's hands) in front of it;
  * a blue padded bench with a taller backrest at the back;
  * one centered round yellow lamp in a grey octagonal bezel at the front, a metal ear with vent slots and a spike in
    front of each, slotted vent grilles with bolts, a yellow-black hazard band ending in an arrow on each side
    under a raised hatch, a grey pod on a flat ledge (small wing) at each back side, his red emblem on both sides;
  * at the back a grey octagonal exhaust nozzle (a thick ring, a grille of fins, a fan turning inside over a cyan
    glow) under a yellow rounded cowl; a cyan plasma emitter under the black bottom.

Run:
  "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python audit/egg_mobile_bpy.py -- [--quick] [--no-render]

Writes (design/npc/eggmobile/, every FBX written first in an ASCII-only temp folder, then copied):
  EggMobileKit.fbx             all pieces, one object "EM_<Name>" each, one plain material each (no textures)
  fbx/EM_<Name>.fbx            one FBX per piece (fallback)
  obj/EM_<Name>.obj + .mtl     one OBJ per piece (fallback)
  eggmobile_manifest.json      per piece: size, bboxCenterOffset, pivot, colour, material, role, glow, tris...
  preview/*.png                Eevee renders: side by side with both references (their angles, a studio look),
                               and lobby renders (bright sky, green baseplate) with a stand-in R6 Eggman seated
  C:/Users/Public/EggMobileKit/  copies of the FBX / OBJ files and the manifest for the owner's import (ASCII path)

Frames:
  Ship space = Roblox axes, studs: origin on the floor spot under the ship, +X Eggman's right, +Y up, -Z forward
  (where he looks). Blender (x, y, z) = (X, -Z, Y); the FBX export (-Z forward, Y up) gives Roblox (X, Y, Z) back.
  Every piece's origin (its pivot) is the ship origin; identity transforms. A piece goes where it belongs with
  part.CFrame = floor * CFrame.new(bboxCenterOffset), Size = size (Shared/EggMobile also undoes the quarter turn
  Studio's Import 3D may add, read from each MeshPart's PivotOffset).
The numbers shared with Shared/EggMobile.luau (seat, levers, nozzle, rim...) go into the manifest's "ship" block;
audit/test_u4_egg_mobile.luau checks they agree.
"""
import bpy, bmesh, math, json, sys, time, shutil, tempfile, re, struct
from pathlib import Path
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
QUICK = '--quick' in ARGS
NO_RENDER = '--no-render' in ARGS

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
OUT = ROOT / 'design' / 'npc' / 'eggmobile'
PREV = OUT / 'preview'
REF_SIDE = OUT / 'reference' / 'EggMobile_reference.webp'
REF_BACK = OUT / 'reference' / 'EggMobile_reference_back.png'
PUBLIC = Path('C:/Users/Public/EggMobileKit')
for p in (OUT, PREV, OUT / 'fbx', OUT / 'obj'):
    p.mkdir(parents=True, exist_ok=True)
KIT_VERSION = 2
T0 = time.time()


def log(*a):
    print('[eggmobile %6.1fs]' % (time.time() - T0), *a, flush=True)


TAU = 2 * math.pi


def rad(d):
    return math.radians(d)


def V(x, y=None, z=None):
    if y is None:
        return Vector(x)
    return Vector((x, y, z))


# ----------------------------------------------------------------------------------------------
# Ship numbers (ship space, studs). Shared/EggMobile.luau keeps the same values.
# ----------------------------------------------------------------------------------------------
Y_BOT = 0.6           # the bottom of the black sphere (the hover keeps it off the floor)
Y_CYL = 3.9           # the round bottom meets the straight wall here (the widest ring)
R_HULL = 3.86         # the hull's radius (the white shell sits WHITE_OUT outside it)
WHITE_OUT = 0.045     # the white shell's thickness over the black sphere
Y_EDGE = 2.05          # where the white shell ends: the lower half is the big glossy black sphere
RIM_TOP = 5.44        # the top of the rim
RIM_IN = 3.56         # the rim's inner radius (the cockpit wall)
FLOOR_TOP = 4.9       # cockpit floor (Eggman's legs stay under it)
HULL_CENTER = (0.0, 3.0, 0.0)               # the hover's pivot (Shared/EggMobile.HullCenter)
SEAT_ROOT = (0.0, 5.55, 0.45)               # Eggman's HumanoidRootPart, on the bench
STICKS = {'R': {'side': 1, 'pivot': (1.7, 5.12, -0.63), 'length': 1.1},
          'L': {'side': -1, 'pivot': (-1.7, 5.12, -0.63), 'length': 1.1}}
NOZZLE = {'y': 3.3, 'z': 3.25, 'depth': 1.35, 'outer': 1.22, 'fanH': 0.62}  # centre height, front z, ring depth / size
FAN_PIVOT = (0.0, NOZZLE['y'], NOZZLE['z'] + NOZZLE['fanH'])
EXHAUST_POINT = (0.0, NOZZLE['y'], NOZZLE['z'] + 0.2)                       # the client's exhaust jet starts here
# Centered windshield; its arc and glass share the same dome boundary.
CANOPY = {'r': 3.68, 'b': 1.72, 'cy': 5.27, 'n': (0.0, 1.0), 'lean': 0.03, 'd': -0.68, 'psi': (-79.35, 79.35)}
LAMP_PHI, LAMP_Y = 0.0, 3.95               # one centered front lamp
EAR_PHI = 15.0
VENT_PHI, VENT_Y = 62.0, 3.35
BAND = {'phiBack': 152.0, 'phiFront': 85.0, 'y0': 3.95, 'y1': 4.55}
POD_PHI, POD_Y = 120.0, 3.05
LOGO = {'phi': 91.0, 'y': 2.98, 'width': 1.45}
PLASMA_BOTTOM = 0.58                        # the underside glow's lowest face (flush with the black sphere)

# ----------------------------------------------------------------------------------------------
# Pieces: one mesh per colour / material group and per moving part. Colours are Roblox sRGB.
#   role static | glow (welded to the hull), fan | stick (on the hull's Motor6Ds; rideOn: welded to that moving
#   piece instead). glow = the client's EggGlow kind. sharp = the auto-smooth angle (degrees).
# ----------------------------------------------------------------------------------------------
PIECES = [
    # name,               rgb,             material,        refl, transp, shadow, role,     glow,        side, rideOn, sharp
    ('EM_HullWhite',      (230, 233, 238), 'SmoothPlastic', 0.18, 0.0,  True,  'static', None,        None, None,  52),
    ('EM_HullBlack',      (26, 26, 32),    'SmoothPlastic', 0.15, 0.0,  True,  'static', None,        None, None,  52),
    ('EM_Metal',          (160, 165, 176), 'SmoothPlastic', 0.15, 0.0,  True,  'static', None,        None, None,  40),
    ('EM_MetalDark',      (72, 74, 88),    'SmoothPlastic', 0.08, 0.0,  True,  'static', None,        None, None,  40),
    ('EM_Black',          (20, 20, 24),    'SmoothPlastic', 0.0,  0.0,  False, 'static', None,        None, None,  52),
    ('EM_TrimYellow',     (255, 204, 22),  'SmoothPlastic', 0.0,  0.0,  True,  'static', None,        None, None,  52),
    ('EM_Seat',           (28, 116, 232),  'SmoothPlastic', 0.06, 0.0,  True,  'static', None,        None, None,  52),
    ('EM_Glass',          (205, 232, 255), 'Glass',         0.3,  0.6,  False, 'static', None,        None, None,  52),
    ('EM_Chrome',         (226, 229, 236), 'SmoothPlastic', 0.3,  0.0,  False, 'static', None,        None, None,  52),
    ('EM_LogoRed',        (165, 25, 25),   'SmoothPlastic', 0.0,  0.0,  False, 'static', None,        None, None,  52),
    ('EM_Lamp',           (255, 212, 36),  'Neon',          0.0,  0.0,  False, 'glow',   'Lamp',      None, None,  52),
    ('EM_DashRed',        (255, 48, 48),   'Neon',          0.0,  0.0,  False, 'glow',   'DashLight', None, None,  52),
    ('EM_Screen',         (70, 230, 255),  'Neon',          0.0,  0.0,  False, 'glow',   'Screen',    None, None,  52),
    ('EM_GlowPlasma',     (70, 238, 255),  'Neon',          0.0,  0.0,  False, 'glow',   'Plasma',    None, None,  52),
    ('EM_GlowPlasmaCore', (205, 255, 255), 'Neon',          0.0,  0.0,  False, 'glow',   'PlasmaCore', None, None, 52),
    ('EM_GlowExhaust',    (70, 238, 255),  'Neon',          0.0,  0.0,  False, 'glow',   'Exhaust',   None, None,  52),
    ('EM_FanRear',        (150, 156, 170), 'SmoothPlastic', 0.12, 0.0,  False, 'fan',    None,        1,    None,  52),
    ('EM_StickL',         (230, 36, 36),   'SmoothPlastic', 0.05, 0.0,  False, 'stick',  None,        -1,   None,  52),
    ('EM_StickR',         (230, 36, 36),   'SmoothPlastic', 0.05, 0.0,  False, 'stick',  None,        1,    None,  52),
]
PIECE = {p[0]: p for p in PIECES}
ORDER = [p[0] for p in PIECES]

# Eggman's emblem (design/npc/eggmobile/reference/Eggman_logo.png), traced with marching squares and simplified
# (Ramer-Douglas-Peucker, 0.9 px): the outline first, then the holes (two eyes, the teeth slots). x right, y up,
# the outline's box centred on 0 and 1 wide (0.6875 tall). The eyes are refitted as circles in logo_polys().
LOGO_POLYS = [
    [(-0.119, 0.3427), (-0.1159, 0.3438), (-0.0635, 0.2893), (-0.0333, 0.2954), (0.0252, 0.2954), (0.0575, 0.2893), (0.1099, 0.3438), (0.2268, 0.2913), (0.2298, 0.2843), (0.2157, 0.2117), (0.2359, 0.1935), (0.2692, 0.1522), (0.2833, 0.1583), (0.4183, 0.2389), (0.4194, 0.2339), (0.4153, 0.2218), (0.377, 0.119), (0.38, 0.1159), (0.4909, 0.0958), (0.499, 0.0938), (0.5, 0.0907), (0.3952, 0.0222), (0.4879, -0.0726), (0.3236, -0.0534), (0.3206, -0.0565), (0.3125, -0.1069), (0.2984, -0.1472), (0.2802, -0.1835), (0.254, -0.2218), (0.2147, -0.2631), (0.1865, -0.2853), (0.13, -0.3175), (0.0917, -0.3317), (0.0292, -0.3438), (0.0131, -0.2873), (-0.0222, -0.2883), (-0.0323, -0.3367), (-0.0373, -0.3438), (-0.0655, -0.3397), (-0.1099, -0.3276), (-0.1442, -0.3135), (-0.1825, -0.2913), (-0.2188, -0.2631), (-0.244, -0.2379), (-0.2782, -0.1915), (-0.3044, -0.1391), (-0.3165, -0.1008), (-0.3226, -0.0565), (-0.3256, -0.0534), (-0.4466, -0.0675), (-0.4627, -0.0716), (-0.4879, -0.0726), (-0.3972, 0.0222), (-0.499, 0.0897), (-0.5, 0.0927), (-0.4002, 0.1119), (-0.3901, 0.1159), (-0.38, 0.1159), (-0.377, 0.119), (-0.4153, 0.2198), (-0.4204, 0.2409), (-0.2792, 0.1542), (-0.2712, 0.1522), (-0.252, 0.1794), (-0.2198, 0.2117), (-0.2339, 0.2883)],
    [(-0.12, 0.1643), (-0.1401, 0.1542), (-0.1613, 0.131), (-0.1673, 0.1149), (-0.1653, 0.0786), (-0.1552, 0.0605), (-0.1321, 0.0413), (-0.1139, 0.0353), (-0.0837, 0.0373), (-0.0655, 0.0454), (-0.0464, 0.0645), (-0.0363, 0.0907), (-0.0363, 0.1129), (-0.0464, 0.1371), (-0.0554, 0.1482), (-0.0696, 0.1583), (-0.0837, 0.1643)],
    [(0.0817, 0.1643), (0.0635, 0.1562), (0.0534, 0.1482), (0.0403, 0.131), (0.0343, 0.1149), (0.0343, 0.0847), (0.0464, 0.0605), (0.0655, 0.0433), (0.0877, 0.0353), (0.1179, 0.0373), (0.1381, 0.0474), (0.1573, 0.0685), (0.1653, 0.0907), (0.1633, 0.119), (0.1532, 0.1391), (0.1321, 0.1583), (0.1179, 0.1643)],
    [(0.1179, -0.0272), (0.1149, -0.0302), (0.1159, -0.1885), (0.126, -0.1865), (0.1583, -0.1704), (0.1835, -0.1512), (0.1835, -0.0363), (0.1804, -0.0333)],
    [(-0.1381, -0.0272), (-0.1704, -0.0333), (-0.1845, -0.0333), (-0.1875, -0.0363), (-0.1875, -0.1532), (-0.1603, -0.1724), (-0.122, -0.1885), (-0.121, -0.0282)],
    [(0.0817, -0.0272), (0.0706, -0.0544), (0.0544, -0.0766), (0.0373, -0.0938), (0.0192, -0.1018), (0.0141, -0.1069), (0.0171, -0.2107), (0.0655, -0.2046), (0.0827, -0.1996), (0.0847, -0.0282)],
    [(-0.0877, -0.0272), (-0.0887, -0.1956), (-0.0907, -0.1976), (-0.0817, -0.2026), (-0.0252, -0.2107), (-0.0222, -0.2077), (-0.0222, -0.1048), (-0.0413, -0.0958), (-0.0625, -0.0746), (-0.0746, -0.0585)],
    [(0.2208, -0.0393), (0.2198, -0.1149), (0.2228, -0.1159), (0.2379, -0.0948), (0.248, -0.0746), (0.256, -0.0444)],
    [(-0.2308, -0.0393), (-0.2571, -0.0433), (-0.2581, -0.0524), (-0.246, -0.0867), (-0.2339, -0.1069), (-0.2248, -0.1159), (-0.2238, -0.0403)],
]
LOGO_ASPECT = 0.6875


# ----------------------------------------------------------------------------------------------
# Geometry accumulation (ship space)
# ----------------------------------------------------------------------------------------------
class Geo:
    def __init__(self):
        self.v = []
        self.f = []

    def add(self, verts, faces, closed=False):
        if closed:
            verts, faces = recalc(verts, faces)
        base = len(self.v)
        self.v.extend(Vector(p) for p in verts)
        self.f.extend(tuple(base + i for i in face) for face in faces)


def recalc(verts, faces):
    """Outward normals for a closed item (bmesh recalc per connected island)."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in verts]
    for face in faces:
        try:
            bm.faces.new([vs[i] for i in face])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.index_update()
    out_v = [v.co.copy() for v in bm.verts]
    out_f = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return out_v, out_f


G = {name: Geo() for name in ORDER}


class Frame:
    """A right-handed frame: origin and unit axes x, y, z (ship space)."""

    def __init__(self, origin, x, y, z):
        self.o, self.x, self.y, self.z = V(origin), V(x).normalized(), V(y).normalized(), V(z).normalized()

    def pt(self, a, b, c):
        return self.o + self.x * a + self.y * b + self.z * c

    def vec(self, a, b, c):
        return self.x * a + self.y * b + self.z * c


def lathe(profile, segs, origin=(0, 0, 0), axis=(0, 1, 0), ref=(0, 0, -1), phi0=0.0, phi1=None,
          closed_profile=False, cap_ends=False):
    """Surface of revolution. profile [(r, h)], counterclockwise in the (r right, h up) half plane for outward
    normals (h along `axis`, r from it; phi measured from `ref` toward axis x ref). r == 0 points are poles."""
    axis = V(axis).normalized()
    ref = V(ref).normalized()
    side = axis.cross(ref)
    origin = V(origin)
    full = phi1 is None
    n = segs if full else segs + 1
    span = TAU if full else (phi1 - phi0)
    verts, faces, rings = [], [], []
    for (r, h) in profile:
        if r < 1e-9:
            verts.append(origin + axis * h)
            rings.append([len(verts) - 1])
            continue
        ring = []
        for j in range(n):
            a = phi0 + span * j / segs
            verts.append(origin + axis * h + (ref * math.cos(a) + side * math.sin(a)) * r)
            ring.append(len(verts) - 1)
        rings.append(ring)
    count = len(rings)
    pairs = [(i, i + 1) for i in range(count - 1)]
    if closed_profile:
        pairs.append((count - 1, 0))
    for (i, k) in pairs:
        a, b = rings[i], rings[k]
        for j in range(segs):
            j1 = (j + 1) % n if full else j + 1
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                faces.append((a[0], b[j1], b[j]))
            elif len(b) == 1:
                faces.append((a[j], a[j1], b[0]))
            else:
                faces.append((a[j], a[j1], b[j1], b[j]))
    if cap_ends and not full:
        faces.append(tuple(r[0] for r in reversed(rings)))
        faces.append(tuple(r[-1] for r in rings))
    return verts, faces


def torus(center, axis, ref, major, minor, segs, rings_n, phi0=0.0, phi1=None):
    prof = [(major + minor * math.cos(TAU * k / rings_n - math.pi / 2), minor * math.sin(TAU * k / rings_n - math.pi / 2))
            for k in range(rings_n)]
    return lathe(prof, segs, center, axis, ref, phi0, phi1, closed_profile=True)


def catmull(points, per=8, closed=False):
    pts = [V(p) for p in points]
    if closed:
        ext = [pts[-1]] + pts + [pts[0], pts[1]]
    else:
        ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    segs = len(pts) if closed else len(pts) - 1
    for i in range(segs):
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        for s in range(per):
            t = s / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    if not closed:
        out.append(pts[-1].copy())
    return out


def sweep(pts, radius, sides=8, cap='round', cap_rings=3, up_hint=(0, 1, 0), closed=False):
    """A tube through dense points (parallel-transport frames), round or flat caps."""
    pts = [V(p) for p in pts]
    m = len(pts)
    rfun = radius if callable(radius) else (lambda t: radius)
    tans = []
    for i in range(m):
        if closed:
            d = pts[(i + 1) % m] - pts[i - 1]
        elif i == 0:
            d = pts[1] - pts[0]
        elif i == m - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[i + 1] - pts[i - 1]
        tans.append(d.normalized())
    hint = V(up_hint)
    if abs(tans[0].dot(hint)) > 0.95:
        hint = V(1, 0, 0) if abs(tans[0].x) < 0.9 else V(0, 0, 1)
    n0 = (hint - tans[0] * tans[0].dot(hint)).normalized()
    norms = [n0]
    for i in range(1, m):
        q = tans[i - 1].rotation_difference(tans[i])
        n = q @ norms[-1]
        n = (n - tans[i] * tans[i].dot(n)).normalized()
        norms.append(n)
    rings = []
    for i in range(m):
        t = tans[i]
        b = t.cross(norms[i])
        rings.append((pts[i], t, norms[i], b, rfun(i / max(1, m - 1))))
    seq = []
    if not closed and cap == 'round':
        c, t, n, b, r = rings[0]
        for k in range(cap_rings, 0, -1):
            th = (math.pi / 2) * k / cap_rings
            seq.append((c - t * r * math.sin(th), n, b, r * math.cos(th) if k < cap_rings else 0.0))
    elif not closed and cap == 'flat':
        c, t, n, b, r = rings[0]
        seq.append((c, n, b, 0.0))
    for (c, t, n, b, r) in rings:
        seq.append((c, n, b, r))
    if not closed and cap == 'round':
        c, t, n, b, r = rings[-1]
        for k in range(1, cap_rings + 1):
            th = (math.pi / 2) * k / cap_rings
            seq.append((c + t * r * math.sin(th), n, b, r * math.cos(th) if k < cap_rings else 0.0))
    elif not closed and cap == 'flat':
        c, t, n, b, r = rings[-1]
        seq.append((c, n, b, 0.0))
    verts, faces, idx = [], [], []
    for (c, n, b, r) in seq:
        if r <= 1e-9:
            verts.append(c.copy())
            idx.append([len(verts) - 1])
        else:
            ring = []
            for k in range(sides):
                a = TAU * k / sides
                verts.append(c + (n * math.cos(a) + b * math.sin(a)) * r)
                ring.append(len(verts) - 1)
            idx.append(ring)
    pairs = [(i, i + 1) for i in range(len(idx) - 1)]
    if closed:
        pairs.append((len(idx) - 1, 0))
    for (i, k) in pairs:
        a, bb = idx[i], idx[k]
        for j in range(sides):
            j1 = (j + 1) % sides
            if len(a) == 1:
                faces.append((a[0], bb[j1], bb[j]))
            elif len(bb) == 1:
                faces.append((a[j], a[j1], bb[0]))
            else:
                faces.append((a[j], a[j1], bb[j1], bb[j]))
    return verts, faces


def rbox(center, size, radius, segs=3, frame=None, rot=None):
    """A rounded box (bevelled cube), optionally rotated (Matrix 3x3) then placed in `frame`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    rr = min(radius, min(size) * 0.49)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=rr, segments=segs, profile=0.5,
                    affect='EDGES', clamp_overlap=True)
    bm.verts.index_update()
    verts = []
    for v in bm.verts:
        p = v.co.copy()
        if rot is not None:
            p = rot @ p
        p = p + V(center)
        if frame is not None:
            p = frame.pt(p.x, p.y, p.z)
        verts.append(p)
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def ellipsoid(center, radii, segs=16, rings=10, frame=None):
    prof = [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)]
    prof[0] = (0.0, -1.0)
    prof[-1] = (0.0, 1.0)
    verts, faces = lathe(prof, segs)
    out = []
    for p in verts:
        q = V(p.x * radii[0], p.y * radii[1], p.z * radii[2]) + V(center)
        out.append(frame.pt(q.x, q.y, q.z) if frame else q)
    return out, faces


def prism(poly2d, w0, w1):
    """A flat polygon (list of (u, v)) extruded from w0 to w1: verts (u, v, w), faces (closed)."""
    n = len(poly2d)
    verts = [V(u, v, w0) for (u, v) in poly2d] + [V(u, v, w1) for (u, v) in poly2d]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


# ----------------------------------------------------------------------------------------------
# The hull surface: a round bottom (an ellipse, Y_BOT..Y_CYL) under a straight wall (R_HULL) up to the rim
# ----------------------------------------------------------------------------------------------
def hull_r(y):
    if y >= Y_CYL:
        return R_HULL - 0.13 * ((y - Y_CYL) / (RIM_TOP - Y_CYL)) ** 2
    t = min(1.0, (Y_CYL - y) / (Y_CYL - Y_BOT))
    return R_HULL * math.sqrt(max(0.0, 1 - t * t))


def hull_dr(y):
    e = 1e-4
    return (hull_r(y + e) - hull_r(y - e)) / (2 * e)


def surf(phi, y, out=0.0):
    """The hull point at azimuth phi (degrees right of forward) and height y, `out` studs along the normal."""
    a = rad(phi)
    radial = V(math.sin(a), 0, -math.cos(a))
    d = hull_dr(y)
    n = (radial - V(0, 1, 0) * d).normalized()
    return radial * hull_r(y) + V(0, y, 0) + n * out, n


def decal_frame(phi, y, out=0.0, horizontal=False):
    """x = the viewer's right facing the hull there, y = up along the hull, z = outward."""
    p, n = surf(phi, y, out)
    a = rad(phi)
    if horizontal:
        n = V(math.sin(a), 0, -math.cos(a))
    x = -V(math.cos(a), 0, math.sin(a))
    y_axis = n.cross(x).normalized()
    return Frame(p, x, y_axis, n)


def bend(phi0, y0, out0, verts, mirror=False):
    """Decal coordinates (u = the viewer's right, v up, w out) wrapped onto the hull around (phi0, y0).
    mirror: u runs the other way (the same drawing seen on the other side reads mirrored)."""
    r0 = hull_r(y0)
    res = []
    for q in verts:
        u = -q[0] if mirror else q[0]
        phi = phi0 - math.degrees(u / r0)
        p, _ = surf(phi, y0 + q[1], out0 + q[2])
        res.append(p)
    return res


def bent_prism(name, phi0, y0, poly2d, w0, w1, mirror=False, subdiv=0.25):
    """A flat outline extruded w0..w1 and wrapped onto the hull (edges subdivided so it follows the curve)."""
    pts = []
    for i in range(len(poly2d)):
        a, b = V(poly2d[i][0], poly2d[i][1], 0), V(poly2d[(i + 1) % len(poly2d)][0], poly2d[(i + 1) % len(poly2d)][1], 0)
        k = max(1, int((b - a).length / subdiv))
        for s in range(k):
            p = a + (b - a) * (s / k)
            pts.append((p.x, p.y))
    verts, faces = prism(pts, w0, w1)
    G[name].add(bend(phi0, y0, 0.0, verts, mirror), faces, closed=True)


def bent_panel(name, phi0, y0, u0, u1, v0, v1, w0, w1, cols=None, rows=None, mirror=False):
    """A curved rectangular plate on the hull (a grid, so it hugs the curve), extruded w0..w1."""
    cols = cols or max(2, int((u1 - u0) / 0.2))
    rows = rows or max(2, int((v1 - v0) / 0.25))
    verts, faces, top, bot = [], [], [], []
    for c in range(cols + 1):
        rt, rb = [], []
        for r in range(rows + 1):
            u = u0 + (u1 - u0) * c / cols
            v = v0 + (v1 - v0) * r / rows
            verts.append(V(u, v, w1))
            rt.append(len(verts) - 1)
            verts.append(V(u, v, w0))
            rb.append(len(verts) - 1)
        top.append(rt)
        bot.append(rb)
    for c in range(cols):
        for r in range(rows):
            faces.append((top[c][r], top[c + 1][r], top[c + 1][r + 1], top[c][r + 1]))
            faces.append((bot[c][r], bot[c][r + 1], bot[c + 1][r + 1], bot[c + 1][r]))
        faces.append((top[c][0], bot[c][0], bot[c + 1][0], top[c + 1][0]))
        faces.append((top[c][rows], top[c + 1][rows], bot[c + 1][rows], bot[c][rows]))
    for r in range(rows):
        faces.append((top[0][r], top[0][r + 1], bot[0][r + 1], bot[0][r]))
        faces.append((top[cols][r], bot[cols][r], bot[cols][r + 1], top[cols][r + 1]))
    G[name].add(bend(phi0, y0, 0.0, verts, mirror), faces, closed=True)


def hull_path(points_phi_y, out):
    return [surf(phi, y, out)[0] for (phi, y) in points_phi_y]


def rivet(phi, y, out=WHITE_OUT, name='EM_Chrome', r=0.075):
    f = decal_frame(phi, y, out)
    prof = [(0.0, -0.03), (r, -0.03), (r * 0.95, r * 0.3), (r * 0.58, r * 0.66), (0.0, r * 0.78)]
    verts, faces = lathe(prof, 7, f.o, f.z, f.y)
    G[name].add(verts, faces)


def seam(points_phi_y, radius=0.03, sides=5, out=WHITE_OUT):
    pts = catmull(hull_path(points_phi_y, out), per=3)
    G['EM_MetalDark'].add(*sweep(pts, radius, sides, cap='round', cap_rings=1))


# ----------------------------------------------------------------------------------------------
# Build
# ----------------------------------------------------------------------------------------------
def white_edge(phi):
    # A single rounded lamp recess exposes the same black bowl underneath.
    dist = abs((phi + LAMP_PHI + 180) % 360 - 180)
    return Y_EDGE + 1.70 * math.exp(-(dist / 16.0) ** 6)


def build_hull():
    prof = [(0.0, Y_BOT)]
    for k in range(1, 25):
        th = (math.pi/2) * k/24
        prof.append((R_HULL*math.sin(th),Y_CYL-(Y_CYL-Y_BOT)*math.cos(th)))
    G['EM_HullBlack'].add(*lathe(prof, 96))
    # The curved shell's lower edge follows the lamp recess, all other panels reach down the bowl.
    verts,faces=[],[]
    cols,rows=144,16
    for j in range(cols):
        phi=-180+360*j/cols
        bottom=white_edge(phi)
        for k in range(rows+1):
            y=bottom+(RIM_TOP-0.16-bottom)*k/rows
            p,_=surf(phi,y,WHITE_OUT)
            verts.append(p)
    for j in range(cols):
        for k in range(rows):
            a=j*(rows+1)+k; b=((j+1)%cols)*(rows+1)+k
            faces.append((a,a+1,b+1,b))
    G['EM_HullWhite'].add(verts,faces)
    outer=hull_r(RIM_TOP-.16)+WHITE_OUT
    G['EM_HullWhite'].add(*lathe([(outer,RIM_TOP-.16),(outer-.015,RIM_TOP-.07),
       (outer-.07,RIM_TOP-.012),(RIM_IN+.08,RIM_TOP),(RIM_IN+.015,RIM_TOP-.06),
       (RIM_IN,RIM_TOP-.14),(RIM_IN,FLOOR_TOP-.02)],96))
    G['EM_MetalDark'].add(*lathe([(RIM_IN+.02,FLOOR_TOP),(2,FLOOR_TOP),(0,FLOOR_TOP)],64))
    # Restrained seams and rivets sit on the true shell surface.
    for phi in (0,50,-64,140,-140,180):
        y=white_edge(phi)
        seam([(phi,y+.10),(phi,(y+RIM_TOP)/2),(phi,RIM_TOP-.19)],radius=.012)
    for k in range(48):
        phi=-180+k*7.5+3.75
        rivet(phi,white_edge(phi)+.18,r=.060)


def canopy_point(psi, th, shrink=0.0):
    c = CANOPY
    r, b = c['r'] - shrink, c['b'] - shrink
    return V(r * math.cos(th) * math.sin(psi), c['cy'] + b * math.sin(th), -r * math.cos(th) * math.cos(psi))


def canopy_side(p):
    """< 0 on the glass's side of the cutting plane (the front-left), > 0 on Eggman's."""
    c = CANOPY
    return c['n'][0] * p.x + c['n'][1] * p.z + c['lean'] * (p.y - c['cy']) - c['d']


def canopy_th_max(psi, shrink=0.0):
    lo, hi = 0.0, math.pi / 2
    f = lambda th: canopy_side(canopy_point(psi, th, shrink))
    if f(lo) >= 0:
        return 0.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if f(mid) < 0:
            lo = mid
        else:
            hi = mid
    return lo


def build_canopy():
    # The centered glass bubble over the front: part of a dome, cut symmetrically (its frame arc runs along the cut).
    p0, p1 = rad(CANOPY['psi'][0]), rad(CANOPY['psi'][1])
    cols, rows = 44, 12
    verts, faces, outer, inner = [], [], [], []
    for c in range(cols + 1):
        psi = p0 + (p1 - p0) * c / cols
        tm = max(canopy_th_max(psi), 1e-3)
        ro, ri = [], []
        for r in range(rows + 1):
            th = tm * r / rows
            verts.append(canopy_point(psi, th))
            ro.append(len(verts) - 1)
            verts.append(canopy_point(psi, th, 0.05))
            ri.append(len(verts) - 1)
        outer.append(ro)
        inner.append(ri)
    for c in range(cols):
        for r in range(rows):
            faces.append((outer[c][r], outer[c + 1][r], outer[c + 1][r + 1], outer[c][r + 1]))
            faces.append((inner[c][r], inner[c][r + 1], inner[c + 1][r + 1], inner[c + 1][r]))
        faces.append((outer[c][0], inner[c][0], inner[c + 1][0], outer[c + 1][0]))
        faces.append((outer[c][rows], outer[c + 1][rows], inner[c + 1][rows], inner[c][rows]))
    for r in range(rows):
        faces.append((outer[0][r], outer[0][r + 1], inner[0][r + 1], inner[0][r]))
        faces.append((outer[cols][r], inner[cols][r], inner[cols][r + 1], outer[cols][r + 1]))
    G['EM_Glass'].add(verts, faces, closed=True)
    # The thin metal frame along its back edge, diving into the rim at both ends.
    edge = []
    for c in range(0, cols + 1):
        psi = p0 + (p1 - p0) * c / cols
        edge.append(canopy_point(psi, canopy_th_max(psi)) + V(0, 0.02, 0))
    edge = [edge[0] + V(0, -0.25, 0)] + edge + [edge[-1] + V(0, -0.25, 0)]
    G['EM_Metal'].add(*sweep(catmull(edge, per=2), 0.07, 8, cap='round', cap_rings=2))


def build_cockpit():
    # The dashboard: a curved panel standing in front of the levers, higher in the middle, facing Eggman.
    r_in, r_out = 2.05, 2.17
    cols, rows = 24, 6
    verts, faces, fi, fo = [], [], [], []
    for c in range(cols + 1):
        phi = -48 + 96 * c / cols
        top = 5.55 + 1.05 * math.exp(-(phi / 24.0)**2)
        a = rad(phi)
        ci, co = [], []
        for r in range(rows + 1):
            y = FLOOR_TOP - 0.02 + (top - FLOOR_TOP + 0.02) * r / rows
            verts.append(V(r_in * math.sin(a), y, -r_in * math.cos(a)))
            ci.append(len(verts) - 1)
            verts.append(V(r_out * math.sin(a), y, -r_out * math.cos(a)))
            co.append(len(verts) - 1)
        fi.append(ci)
        fo.append(co)
    for c in range(cols):
        for r in range(rows):
            faces.append((fi[c][r], fi[c][r + 1], fi[c + 1][r + 1], fi[c + 1][r]))
            faces.append((fo[c][r], fo[c + 1][r], fo[c + 1][r + 1], fo[c][r + 1]))
        faces.append((fi[c][rows], fo[c][rows], fo[c + 1][rows], fi[c + 1][rows]))
        faces.append((fi[c][0], fi[c + 1][0], fo[c + 1][0], fo[c][0]))
    for r in range(rows):
        faces.append((fi[0][r], fo[0][r], fo[0][r + 1], fi[0][r + 1]))
        faces.append((fi[cols][r], fi[cols][r + 1], fo[cols][r + 1], fo[cols][r]))
    G['EM_Metal'].add(verts, faces, closed=True)
    # Its big round cyan screen and the two round red lights, in dark bezels; a row of small black keys.
    screen_c = V(0, 5.98, -r_in + 0.02)
    G['EM_Screen'].add(*lathe([(0.0, 0.0), (0.56, 0.0), (0.56, 0.04), (0.36, 0.075), (0.0, 0.085)], 40, screen_c, (0, 0, 1), (0, 1, 0)))
    G['EM_MetalDark'].add(*torus(screen_c + V(0, 0, 0.03), (0, 0, 1), (0, 1, 0), 0.61, 0.065, 40, 8))
    for sx in (-1, 1):
        a = rad(sx * 30.0)
        c = V(r_in * math.sin(a), 5.92, -r_in * math.cos(a))
        ax = V(-math.sin(a), 0, math.cos(a))
        c = c + ax * 0.02
        G['EM_DashRed'].add(*lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.05), (0.18, 0.12), (0.0, 0.14)], 24, c, ax, (0, 1, 0)))
        G['EM_MetalDark'].add(*torus(c + ax * 0.03, ax, (0, 1, 0), 0.29, 0.05, 24, 6))
    for k in range(-2, 3):
        a = rad(k * 6.0)
        c = V(r_in * math.sin(a), 5.2, -r_in * math.cos(a)) + V(-math.sin(a), 0, math.cos(a)) * 0.03
        G['EM_Black'].add(*rbox(c, (0.16, 0.08, 0.05), 0.015, 1))
    # Raised instrument lip and sparse physical ticks remain readable without an emissive white blob.
    G['EM_Chrome'].add(*torus(screen_c+V(0,0,.04),(0,0,1),(0,1,0),.635,.025,40,6))
    for i in range(8):
        a=TAU*i/8
        G['EM_Chrome'].add(*rbox(screen_c+V(.43*math.sin(a),.43*math.cos(a),.077),(.034,.048,.012),.004,1))
    # The two red levers (on their Motor6Ds), their pods and rubber boots.
    for key, st in STICKS.items():
        p = V(st['pivot'])
        L = st['length']
        G['EM_MetalDark'].add(*lathe([(0.0, FLOOR_TOP - 0.05), (0.3, FLOOR_TOP - 0.05), (0.3, p.y - 0.06), (0.26, p.y - 0.01),
                                      (0.0, p.y - 0.01)], 24, (p.x, 0, p.z)))
        G['EM_Black'].add(*lathe([(0.0, -0.08), (0.2, -0.08), (0.2, 0.0), (0.17, 0.08), (0.1, 0.13), (0.0, 0.145)], 20, p))
        lever = [(0.0, 0.0), (0.075, 0.0), (0.068, L - 0.34), (0.11, L - 0.3), (0.13, L - 0.2), (0.13, L - 0.02),
                 (0.11, L + 0.06), (0.06, L + 0.1), (0.0, L + 0.11)]
        G['EM_Stick' + key].add(*lathe(lever, 16, p))
    # The wide low blue bench: two padded back cushions, two seat cushions, the frame and its ends.
    tilt = rad(10)
    bf = Frame((0, FLOOR_TOP - 0.02, 1.50), (1, 0, 0), (0, math.cos(tilt), math.sin(tilt)), (0, -math.sin(tilt), math.cos(tilt)))
    for sx in (-1, 1):
        G['EM_Seat'].add(*rbox((sx * 0.90, 1.03, 0.30), (1.73, 1.86, 0.48), 0.2, 4, frame=bf))
        G['EM_Seat'].add(*rbox((sx * 0.90, 0.12, -0.42), (1.73, 0.34, 1.18), 0.14, 3, frame=bf))
        G['EM_Seat'].add(*rbox((sx * 1.98, 0.94, 0.0), (0.46, 1.95, 0.80), 0.12, 3, frame=bf))
    G['EM_Seat'].add(*rbox((0, 0.95, 0.59), (4.10, 1.90, 0.22), 0.12, 3, frame=bf))


def build_back():
    # The octagonal exhaust nozzle: a thick ring (a flat side on top), the dark inside, the cyan glow, the fan
    # (turning on its Motor6D) and a grille of fins over it; the yellow rounded cowl over it all.
    o = V(0, NOZZLE['y'], NOZZLE['z'])
    ax, rf = V(0, 0, 1), V(0, 1, 0)
    ph = math.pi / 8
    D, Ro = NOZZLE['depth'], NOZZLE['outer']
    ring = [(0.8, 0.0), (Ro - 0.04, 0.0), (Ro, 0.4), (Ro, D - 0.28), (Ro - 0.06, D - 0.08), (Ro - 0.16, D),
            (0.86, D), (0.8, D - 0.08)]
    G['EM_Metal'].add(*lathe(ring, 8, o, ax, rf, phi0=ph, closed_profile=True))
    # A darker band round the ring's middle and short ribs (slots) inside its mouth.
    G['EM_MetalDark'].add(*lathe([(Ro - 0.02, 0.62), (Ro + 0.03, 0.62), (Ro + 0.03, 0.82), (Ro - 0.02, 0.82)], 8, o, ax, rf, phi0=ph, closed_profile=True))
    for k in range(8):
        alpha = TAU * k / 8
        er = V(math.sin(alpha), math.cos(alpha), 0)
        et = ax.cross(er).normalized()
        c = o + ax * (D - 0.3) + er * 0.76
        G['EM_MetalDark'].add(*rbox((0, 0, 0), (0.09, 0.5, 0.12), 0.02, 1, frame=Frame(c, et, ax, er)))
    G['EM_Black'].add(*lathe([(0.0, 0.2), (0.82, 0.2), (0.82, 0.26), (0.0, 0.26)], 8, o, ax, rf, phi0=ph))
    G['EM_MetalDark'].add(*lathe([(0.8, 0.26), (0.8, D - 0.1)], 8, o, ax, rf, phi0=ph))
    G['EM_GlowExhaust'].add(*lathe([(0.0, 0.28), (0.72, 0.28), (0.72, 0.36), (0.0, 0.36)], 32, o, ax, rf))
    fan = G['EM_FanRear']
    fo = V(FAN_PIVOT)
    for k in range(8):
        alpha = TAU * k / 8
        er = V(math.sin(alpha), math.cos(alpha), 0)
        et = ax.cross(er).normalized()
        sections = []
        for s in range(5):
            u = s / 4
            r = 0.15 + (0.7 - 0.15) * u
            chord = 0.26 + 0.1 * u
            beta = rad(50 - 18 * u)
            c = fo + er * r
            cdir = et * math.cos(beta) + ax * math.sin(beta)
            ddir = cdir.cross(er).normalized()
            t = 0.035
            sections.append([c + cdir * (chord / 2) + ddir * (t / 2), c - cdir * (chord / 2) + ddir * (t / 2),
                             c - cdir * (chord / 2) - ddir * (t / 2), c + cdir * (chord / 2) - ddir * (t / 2)])
        verts, faces = [], []
        for sec in sections:
            verts.extend(sec)
        for s in range(len(sections) - 1):
            a, b = 4 * s, 4 * (s + 1)
            for q in range(4):
                q1 = (q + 1) % 4
                faces.append((a + q, a + q1, b + q1, b + q))
        faces.append((0, 1, 2, 3))
        m = 4 * (len(sections) - 1)
        faces.append((m + 3, m + 2, m + 1, m + 0))
        fan.add(verts, faces, closed=True)
    fan.add(*lathe([(0.0, -0.12), (0.2, -0.12), (0.21, 0.02), (0.15, 0.14), (0.0, 0.22)], 20, fo, ax, rf))
    # The cowl: the upper-back quarter of an ellipsoid shell, over the nozzle.
    cc = V(0, 4.45, 3.6)
    ra = (1.08, 0.86, 1.1)
    verts, faces, outer, inner = [], [], [], []
    cols, rows = 20, 8
    for c in range(cols + 1):
        th = rad(-92 + 184 * c / cols)
        ro, ri = [], []
        for r in range(rows + 1):
            e = rad(88.0 * r / rows)
            for shrink, lst in ((0.0, ro), (0.07, ri)):
                verts.append(cc + V((ra[0] - shrink) * math.sin(th) * math.cos(e), (ra[1] - shrink) * math.sin(e),
                                    (ra[2] - shrink) * math.cos(th) * math.cos(e)))
                lst.append(len(verts) - 1)
        outer.append(ro)
        inner.append(ri)
    for c in range(cols):
        for r in range(rows):
            faces.append((outer[c][r], outer[c + 1][r], outer[c + 1][r + 1], outer[c][r + 1]))
            faces.append((inner[c][r], inner[c][r + 1], inner[c + 1][r + 1], inner[c + 1][r]))
        faces.append((outer[c][0], inner[c][0], inner[c + 1][0], outer[c + 1][0]))
        faces.append((outer[c][rows], outer[c + 1][rows], inner[c + 1][rows], inner[c][rows]))
    for r in range(rows):
        faces.append((outer[0][r], outer[0][r + 1], inner[0][r + 1], inner[0][r]))
        faces.append((outer[cols][r], inner[cols][r], inner[cols][r + 1], outer[cols][r + 1]))
    G['EM_TrimYellow'].add(verts, faces, closed=True)


def build_side(side):
    """Everything on one side: side = 1 his right, -1 his left (azimuths mirrored)."""
    s = side
    mir = side < 0      # on his left the viewer's right runs backward: mirror drawings that point forward
    # The yellow lamp in its octagonal bezel: one only, centered at X=0 (latest owner correction).
    ph = math.pi / 8
    if side < 0:
        f = decal_frame(s * LAMP_PHI, LAMP_Y, WHITE_OUT)
        bezel = [(0.6, -0.35), (0.92, -0.35), (0.95, 0.05), (0.9, 0.2), (0.74, 0.27), (0.63, 0.22), (0.6, 0.1)]
        vv,ff=lathe(bezel,64,f.o,f.z,f.y,phi0=ph,closed_profile=True)
        # Polygonal outside, genuinely circular inner aperture.
        for k,p in enumerate(vv):
            layer=k//64
            r,h=bezel[layer]
            local=p-f.o-f.z*h
            a=TAU*(k%64)/64+ph
            octradius=math.cos(math.pi/8)/math.cos((a % (math.pi/4))-math.pi/8)
            influence=max(0,min(1,(r-.70)/.14))
            rr=max(r,.70) * (1+(octradius-1)*influence)
            vv[k]=f.o+f.z*h+local.normalized()*rr
        G['EM_Metal'].add(vv,ff,closed=True)
        G['EM_Lamp'].add(*lathe([(0.0, -0.1), (0.69, -0.1), (0.69, 0.12), (0.59, 0.25), (0.34, 0.32), (0.0, 0.35)], 48, f.o, f.z, f.y, phi0=ph))
    # The ear in front of it: a vent plate with slots and a spike, a strip down to the black bottom.
    bent_panel('EM_Metal', s * EAR_PHI, 4.55, -0.28, 0.28, -0.65, 0.65, WHITE_OUT - 0.02, WHITE_OUT + 0.1, mirror=mir)
    for v in (0.4, 0.2, 0.0):
        bent_panel('EM_Black', s * EAR_PHI, 4.55, -0.17, 0.17, v - 0.045, v + 0.045, WHITE_OUT + 0.09, WHITE_OUT + 0.115, 2, 1, mir)
    fe = decal_frame(s * EAR_PHI, 4.18, WHITE_OUT + 0.1)
    d = (fe.z + V(s * 0.35, 0, 0) + V(0, 0, -0.35)).normalized()
    G['EM_Metal'].add(*lathe([(0.0, -0.05), (0.15, -0.05), (0.13, 0.12), (0.07, 0.36), (0.0, 0.6)], 12, fe.o, d, fe.y))
    strip = [(-0.13 + 0.3 * t, 0.55 - 1.3 * t) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
    poly = [(u - 0.14, v) for (u, v) in strip] + [(u + 0.14, v) for (u, v) in reversed(strip)]
    bent_prism('EM_Metal', s * (EAR_PHI + 7), 3.2, poly, WHITE_OUT - 0.02, WHITE_OUT + 0.07, mirror=mir, subdiv=0.2)
    for t in (0.1, 0.45, 0.8):
        u = -0.13 + 0.3 * t
        v = 0.55 - 1.3 * t
        uu = -u if mir else u
        phi = s * (EAR_PHI + 7) - math.degrees(uu / hull_r(3.2))
        rivet(phi, 3.2 + v, WHITE_OUT + 0.07)
    # The slotted vent grille with its four bolts.
    bent_panel('EM_Metal', s * VENT_PHI, VENT_Y, -0.58, 0.58, -0.64, 0.64, WHITE_OUT - 0.03, WHITE_OUT + 0.07, mirror=mir)
    for v in (0.3, 0.0, -0.3):
        pts = []
        for k in range(8):
            a = math.pi / 2 + math.pi * k / 7
            pts.append((-0.33 + 0.07 * math.cos(a), v + 0.07 * math.sin(a)))
        for k in range(8):
            a = -math.pi / 2 + math.pi * k / 7
            pts.append((0.33 + 0.07 * math.cos(a), v + 0.07 * math.sin(a)))
        bent_prism('EM_Black', s * VENT_PHI, VENT_Y, pts, WHITE_OUT + 0.06, WHITE_OUT + 0.085, mirror=mir, subdiv=0.15)
    for (u, v) in ((-0.47, 0.52), (0.47, 0.52), (-0.47, -0.52), (0.47, -0.52)):
        uu = -u if mir else u
        rivet(s * VENT_PHI - math.degrees(uu / hull_r(VENT_Y)), VENT_Y + v, WHITE_OUT + 0.07, r=0.06)
    # The hazard band from the back to its arrow (pointing forward), the stripes, the hatch over it.
    yb = (BAND['y0'] + BAND['y1']) / 2
    half = (BAND['y1'] - BAND['y0']) / 2
    mid = (BAND['phiBack'] + BAND['phiFront']) / 2
    rr = hull_r(yb)
    f_len = math.radians(BAND['phiBack'] - BAND['phiFront']) * rr / 2   # half length (forward positive)
    fwd = not mir   # on his right, forward is the viewer's right (+u); on his left it is -u
    def fu(f):
        return f if side > 0 else -f
    band = [(fu(-f_len), -half), (fu(f_len), -half), (fu(f_len), half), (fu(-f_len), half)]
    bent_prism('EM_TrimYellow', s * mid, yb, band, WHITE_OUT - 0.01, WHITE_OUT + 0.04, subdiv=0.2)
    arrow = [(fu(f_len - 0.05), -0.46), (fu(f_len + 0.8), 0.0), (fu(f_len - 0.05), 0.46)]
    bent_prism('EM_TrimYellow', s * mid, yb, arrow, WHITE_OUT - 0.01, WHITE_OUT + 0.04, subdiv=0.15)
    k = 0
    f0 = -f_len + 0.1
    while f0 + 0.17 < f_len - 0.25:
        q = [(f0, -half), (f0 + 0.17, -half), (min(f_len - 0.02, f0 + 0.17 + 0.28), half), (min(f_len - 0.02, f0 + 0.28), half)]
        bent_prism('EM_Black', s * mid, yb, [(fu(a), b) for (a, b) in q], WHITE_OUT + 0.035, WHITE_OUT + 0.048, subdiv=0.2)
        f0 += 0.36
        k += 1
    bent_panel('EM_HullWhite', s * (mid + 8), 5.02, -1.05, 1.05, -0.18, 0.18, WHITE_OUT - 0.01, WHITE_OUT + 0.05, mirror=mir)
    for dv in (-0.06, 0.06):
        bent_panel('EM_Black', s * (mid + 8), 5.02, fu(0.8) - 0.1, fu(0.8) + 0.1, dv - 0.022, dv + 0.022, WHITE_OUT + 0.045, WHITE_OUT + 0.06, 2, 1)
    # The pod on its flat ledge (a small wing) with fins under it.
    fp = decal_frame(s * POD_PHI, POD_Y, 0.0, horizontal=True)
    profile=[(-.91,-.13),(-.81,.17),(-.61,.43),(-.38,.56),(.38,.56),(.61,.43),(.81,.17),(.91,-.13)]
    vv,ff=[],[]
    for w in (-.14,.28,.88,1.05):
        for x,y in profile:
            for d in (0,.09):
                vv.append(fp.pt(x,y-d,w))
    n=len(profile)*2
    for row in range(3):
        for j in range(len(profile)-1):
            a=row*n+j*2;b=a+n
            ff += [(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)]
    for row in (0,3):
        for j in range(len(profile)-1):
            a=row*n+j*2;ff.append((a,a+2,a+3,a+1))
    for row in range(3):
        for j in (0,len(profile)-1):
            a=row*n+j*2;b=a+n;ff.append((a,a+1,b+1,b))
    G['EM_Metal'].add(vv,ff,closed=True)
    for dx in (0.18, 0.36):
        G['EM_Black'].add(*rbox((dx * s, 0.563, 0.53), (0.07, 0.02, 0.5), 0.008, 1, frame=fp))
    G['EM_Metal'].add(*rbox((0, -0.22, 0.54), (2.16, 0.16, 1.68), 0.06, 2, frame=fp))
    for dx in (-0.8, 0.0, 0.8):
        G['EM_MetalDark'].add(*rbox((dx, -0.39, 0.54), (0.09, 0.23, 1.0), 0.03, 1, frame=fp))
    # His red emblem, below the band between the grille and the pod.
    build_logo(s * LOGO['phi'], LOGO['y'], LOGO['width'])
    # Grab handles on the rim.
    for phi in ((-85.0, -140.0) if side < 0 else (85.0, 140.0)):
        a = rad(phi)
        rmid = (RIM_IN + R_HULL + WHITE_OUT) / 2
        o = V(rmid * math.sin(a), RIM_TOP, -rmid * math.cos(a))
        t = V(math.cos(a), 0, math.sin(a))
        hf = Frame(o, t, (0, 1, 0), t.cross(V(0, 1, 0)))
        pts = [hf.pt(x, y, 0) for (x, y) in ((-0.2, -0.04), (-0.2, 0.15), (-0.14, 0.24), (0.14, 0.24), (0.2, 0.15), (0.2, -0.04))]
        G['EM_Metal'].add(*sweep(catmull(pts, per=3), 0.032, 6, cap='flat'))


def logo_polys():
    """LOGO_POLYS with the two eyes refitted as round circles."""
    polys = [list(LOGO_POLYS[0])]
    for poly in LOGO_POLYS[1:]:
        xs = [p[0] for p in poly]
        ys = [p[1] for p in poly]
        w, h = max(xs) - min(xs), max(ys) - min(ys)
        if abs(w - h) < 0.12 * max(w, h) and len(poly) > 12:
            cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
            r = (w + h) / 4
            polys.append([(cx + r * math.cos(TAU * k / 28), cy + r * math.sin(TAU * k / 28)) for k in range(28)])
        else:
            polys.append(list(poly))
    return polys


_LOGO_MESH = None


def logo_mesh(width, thick):
    """The emblem as a flat mesh (holes cut) extruded `thick`: Blender fills a 2D curve with its holes."""
    global _LOGO_MESH
    if _LOGO_MESH is not None:
        return _LOGO_MESH
    cu = bpy.data.curves.new('EggmanLogo', 'CURVE')
    cu.dimensions = '2D'
    cu.fill_mode = 'BOTH'
    cu.extrude = thick / 2
    for poly in logo_polys():
        sp = cu.splines.new('POLY')
        sp.points.add(len(poly) - 1)
        for i, (x, y) in enumerate(poly):
            sp.points[i].co = (x * width, y * width, 0.0, 1.0)
        sp.use_cyclic_u = True
    ob = bpy.data.objects.new('EggmanLogo', cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bm.verts.index_update()
    verts = [v.co.copy() for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)
    _LOGO_MESH = (verts, faces)
    return _LOGO_MESH


def build_logo(phi, y, width):
    verts, faces = logo_mesh(width, 0.1)
    # Subdivide long flat triangles so the emblem hugs the hull (a 1.8-stud chord bows ~0.1 on a 3.9 radius).
    word = [V(p.x, p.y, p.z + 0.05 + WHITE_OUT - 0.015) for p in verts]
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in word]
    for face in faces:
        try:
            bm.faces.new([vs[i] for i in face])
        except ValueError:
            pass
    long_edges = [e for e in bm.edges if e.calc_length() > 0.3]
    if long_edges:
        bmesh.ops.subdivide_edges(bm, edges=long_edges, cuts=2, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bm.verts.index_update()
    v2 = [v.co.copy() for v in bm.verts]
    f2 = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    G['EM_LogoRed'].add(bend(phi, y, 0.0, v2), f2)


def build_underside():
    b = PLASMA_BOTTOM
    cap = [(0.0, b + 0.06), (1.15, b + 0.06), (1.35, b + 0.11), (1.47, b + 0.26), (1.5, b + 0.48), (1.2, b + 0.68), (0.0, b + 0.73)]
    G['EM_MetalDark'].add(*lathe(cap, 56))
    G['EM_Chrome'].add(*torus((0, b + 0.065, 0), (0, 1, 0), (0, 0, -1), 1.1, 0.08, 48, 8))
    G['EM_GlowPlasma'].add(*lathe([(0.0, b + 0.03), (1.0, b + 0.03), (1.0, b + 0.72), (0.0, b + 0.72)], 48))
    G['EM_GlowPlasmaCore'].add(*lathe([(0.0, b), (0.46, b), (0.46, b + 0.7), (0.0, b + 0.7)], 32))


def build_all():
    build_hull()
    build_canopy()
    build_cockpit()
    build_back()
    build_side(1)
    build_side(-1)
    build_underside()


# ----------------------------------------------------------------------------------------------
# Blender objects
# ----------------------------------------------------------------------------------------------
ROBLOX_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_material(name, spec):
    _, rgb, material, refl, transp, _, role, glow, _, _, _ = spec
    m = bpy.data.materials.new(name + '_Mat')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    lin = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
    bsdf.inputs['Base Color'].default_value = lin
    m.diffuse_color = lin
    bsdf.inputs['Roughness'].default_value = 0.3
    if refl >= 0.25:
        bsdf.inputs['Metallic'].default_value = 0.9
        bsdf.inputs['Roughness'].default_value = 0.14
    elif refl >= 0.1:
        dark = max(rgb) < 80   # glossy black paint, not grey metal
        bsdf.inputs['Metallic'].default_value = 0.0 if dark else (0.3 if refl >= 0.15 else 0.05)
        bsdf.inputs['Roughness'].default_value = 0.16
        if dark:
            try:
                bsdf.inputs['Coat Weight'].default_value = 1.0
                bsdf.inputs['Coat Roughness'].default_value = 0.05
            except Exception:
                pass
        try:
            bsdf.inputs['Coat Weight'].default_value = 0.35
            bsdf.inputs['Coat Roughness'].default_value = 0.08
        except Exception:
            pass
    if material == 'Neon':
        bsdf.inputs['Emission Color'].default_value = lin
        bsdf.inputs['Emission Strength'].default_value = {'Lamp': 0.25, 'DashLight': 0.5, 'Screen': 0.65}.get(glow, 4.0)
    if material == 'Glass':
        bsdf.inputs['Roughness'].default_value = 0.02
        bsdf.inputs['Metallic'].default_value = 0.0
        try:
            bsdf.inputs['Coat Weight'].default_value = 1.0
            bsdf.inputs['Coat Roughness'].default_value = 0.0
            bsdf.inputs['Specular IOR Level'].default_value = 0.35
        except Exception:
            pass
        try:
            bsdf.inputs['Transmission Weight'].default_value = 0.0
        except Exception:
            pass
    if transp > 0:
        bsdf.inputs['Alpha'].default_value = 0.10 if material == 'Glass' else 1-transp
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    return m


def geo_to_object(name, geo, coll):
    me = bpy.data.meshes.new(name)
    verts = [ROBLOX_TO_BLENDER @ p for p in geo.v]
    me.from_pydata([tuple(v) for v in verts], [], geo.f)
    me.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-7)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    bad = [f for f in bm.faces if f.calc_area() < 1e-9]
    if bad:
        bmesh.ops.delete(bm, geom=bad, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(me)
    bm.free()
    # One UV map (a simple projection: no textures, but importers expect one).
    uv = me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co[a] * 0.1, co[b] * 0.1)
    me.shade_smooth()
    me.set_sharp_from_angle(angle=rad(PIECE[name][10]))
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    mat = make_material(name, PIECE[name])
    me.materials.append(mat)
    # Weighted normals: flat faces read flat, round forms read round (no smeared shading).
    wn = ob.modifiers.new('WeightedNormal', 'WEIGHTED_NORMAL')
    wn.keep_sharp = True
    wn.weight = 50
    wn.mode = 'FACE_AREA'
    dg = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    ob.modifiers.clear()
    old = ob.data
    ob.data = baked
    baked.name = name
    bpy.data.meshes.remove(old)
    if not baked.materials:
        baked.materials.append(mat)
    return ob


# ----------------------------------------------------------------------------------------------
# Validation (Roblox mesh limits) and facts
# ----------------------------------------------------------------------------------------------
ROBLOX_MAX_TRIS, ROBLOX_MAX_VERTS, ROBLOX_MAX_AXIS = 20000, 10000, 2048.0


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
    lo, hi = roblox_bbox(ob)
    dims = hi - lo
    r['size'] = [round(dims.x, 4), round(dims.y, 4), round(dims.z, 4)]
    r['center'] = [round((lo.x + hi.x) / 2, 4), round((lo.y + hi.y) / 2, 4), round((lo.z + hi.z) / 2, 4)]
    r['min'] = [round(lo.x, 4), round(lo.y, 4), round(lo.z, 4)]
    r['max'] = [round(hi.x, 4), round(hi.y, 4), round(hi.z, 4)]
    r['identity'] = ob.location.length < 1e-9 and Vector(ob.rotation_euler).length < 1e-9 and (ob.scale - Vector((1, 1, 1))).length < 1e-9
    r['ascii'] = ob.name.isascii() and ' ' not in ob.name
    if r['ngons']:
        bad.append('ngons')
    if r['tris'] > ROBLOX_MAX_TRIS:
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


def export_all(scene, objs):
    tmp = Path(tempfile.mkdtemp(prefix='eggmobile_kit_'))
    assert str(tmp).isascii(), 'the temp folder must be ASCII: %s' % tmp
    # Blender embeds its current source filename in FBX metadata. Save under ASCII before exporting.
    bpy.ops.wm.save_as_mainfile(filepath=str(tmp / 'EggMobile_Source.blend'))
    (tmp / 'fbx').mkdir()
    (tmp / 'obj').mkdir()
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.01   # UnitScaleFactor 1 (cm): the settings the Green Hill kit imported with
    fbx_kw = dict(use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True, mesh_smooth_type='FACE',
                  use_tspace=False, add_leaf_bones=False, bake_anim=False, axis_forward='-Z', axis_up='Y',
                  apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0, apply_unit_scale=True, path_mode='STRIP',
                  embed_textures=False, use_custom_props=False, use_triangles=True)
    obj_kw = dict(export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y', global_scale=1.0,
                  apply_modifiers=True, export_triangulated_mesh=True, export_normals=True, export_uv=True,
                  export_materials=True, path_mode='STRIP', export_smooth_groups=False, export_vertex_groups=False,
                  export_animation=False, export_colors=False)
    for name in ORDER:
        bpy.ops.object.select_all(action='DESELECT')
        objs[name].select_set(True)
        bpy.context.view_layer.objects.active = objs[name]
        bpy.ops.export_scene.fbx(filepath=str(tmp / 'fbx' / (name + '.fbx')), **fbx_kw)
        bpy.ops.wm.obj_export(filepath=str(tmp / 'obj' / (name + '.obj')), **obj_kw)
    bpy.ops.object.select_all(action='DESELECT')
    for name in ORDER:
        objs[name].select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(tmp / 'EggMobileKit.fbx'), **fbx_kw)
    scene.unit_settings.scale_length = 1.0
    facts = {}
    for f in [tmp / 'EggMobileKit.fbx'] + sorted((tmp / 'fbx').glob('*.fbx')):
        facts[f.name] = fbx_facts(f)
    for d in (OUT / 'fbx', OUT / 'obj'):
        for old in d.glob('EM_*.*'):
            old.unlink()
    for f in sorted((tmp / 'fbx').glob('*.fbx')):
        shutil.copy2(f, OUT / 'fbx' / f.name)
    for f in sorted((tmp / 'obj').glob('EM_*.*')):
        shutil.copy2(f, OUT / 'obj' / f.name)
    shutil.copy2(tmp / 'EggMobileKit.fbx', OUT / 'EggMobileKit.fbx')
    try:
        PUBLIC.mkdir(parents=True, exist_ok=True)
        (PUBLIC / 'fbx').mkdir(exist_ok=True)
        (PUBLIC / 'obj').mkdir(exist_ok=True)
        shutil.copy2(tmp / 'EggMobileKit.fbx', PUBLIC / 'EggMobileKit.fbx')
        for f in sorted((tmp / 'fbx').glob('*.fbx')):
            shutil.copy2(f, PUBLIC / 'fbx' / f.name)
        for f in sorted((tmp / 'obj').glob('EM_*.*')):
            shutil.copy2(f, PUBLIC / 'obj' / f.name)
    except Exception as e:  # the public copy is a convenience
        log('could not copy to', PUBLIC, e)
    assert tmp.resolve().parent == Path(tempfile.gettempdir()).resolve() and tmp.name.startswith('eggmobile_kit_')
    shutil.rmtree(tmp, ignore_errors=True)
    bad = {k: v for k, v in facts.items() if not (v['unitScaleFactor'] and abs(v['unitScaleFactor'] - 1.0) < 1e-6 and v['asciiOnly'])}
    assert not bad, bad
    return facts


def reimport_check(expect):
    """Import EggMobileKit.fbx into an empty scene (cm units, as written): every piece comes back with its
    size and centre (Roblox axes). Runs last: it resets the Blender session."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(OUT / 'EggMobileKit.fbx'))
    bpy.context.view_layer.update()
    got = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
    worst = 0.0
    for name, ob in got.items():
        if name not in expect:
            continue
        lo, hi = roblox_bbox(ob)
        size, centre = hi - lo, (lo + hi) / 2
        e = expect[name]
        err = max(max(abs(size[i] - e['size'][i]) for i in range(3)), max(abs(centre[i] - e['center'][i]) for i in range(3)))
        worst = max(worst, err)
    return worst, sorted(set(expect) - set(got)), sorted(set(got) - set(expect))


# ----------------------------------------------------------------------------------------------
# Manifest
# ----------------------------------------------------------------------------------------------
def motor_pivot(name):
    spec = PIECE[name]
    role, side = spec[6], spec[8]
    if spec[9]:
        return None
    if role == 'fan':
        return [round(v, 4) for v in FAN_PIVOT]
    if role == 'stick':
        return list(STICKS['R' if side > 0 else 'L']['pivot'])
    return None


def bottom_points(objs):
    """The ship's lowest vertices (ship space), the lowest per 15-degree sector and 0.5-stud ring: the hover test
    tilts these (a MeshPart's box corner is air under a round bottom)."""
    best = {}
    for ob in objs.values():
        for v in ob.data.vertices:
            c = ob.matrix_world @ v.co
            x, y, z = c.x, c.z, -c.y
            if y > Y_BOT + 0.9:
                continue
            key = (int((math.degrees(math.atan2(x, -z)) + 180) // 15), int(math.hypot(x, z) // 0.5))
            if key not in best or y < best[key][1]:
                best[key] = (x, y, z)
    return [[round(p[0], 3), round(p[1], 3), round(p[2], 3)] for _, p in sorted(best.items())]


def write_manifest(table, facts, objs):
    total = sum(r['tris'] for r in table.values())
    ship_lo = [min(r['min'][i] for r in table.values()) for i in range(3)]
    ship_hi = [max(r['max'][i] for r in table.values()) for i in range(3)]
    manifest = {
        'generator': 'audit/egg_mobile_bpy.py',
        'kitVersion': KIT_VERSION,
        'revision': 'centered-round-lamp-reference-alignment-2026-09-26',
        'design': 'classic Egg Mobile (white hull, black bottom, glass bubble, blue bench, octagonal nozzle)',
        'fbx': 'EggMobileKit.fbx',
        'rbxm': 'design/npc/EggMobileKit.rbxm (saved from Studio after Import 3D)',
        'units': '1 unit = 1 stud; FBX UnitScaleFactor 1.0 (cm), like GreenHillKit.fbx; axes -Z forward, Y up (Roblox axes)',
        'pivot': 'every piece: the ship origin (the floor spot under the ship centre); identity transforms',
        'placement': 'part.CFrame = floor * CFrame.new(bboxCenterOffset) * CFrame.Angles(0, -importYaw, 0); part.Size = size '
                     '(importYaw: the quarter turn Studio added, read from the MeshParts\' PivotOffset against -bboxCenterOffset)',
        'textures': 'none: every piece is one colour; Shared/EggMobile sets Color / Material / Reflectance / Transparency from here',
        'totalTris': total,
        'shipBounds': {'min': ship_lo, 'max': ship_hi},
        'ship': {
            'hullCenter': list(HULL_CENTER), 'seatRoot': list(SEAT_ROOT), 'floorTop': FLOOR_TOP,
            'rimTop': RIM_TOP, 'rimInner': RIM_IN, 'hullRadius': R_HULL, 'whiteOut': WHITE_OUT,
            'hullBottom': Y_BOT, 'wallFrom': Y_CYL, 'whiteEdge': Y_EDGE,
            'sticks': {k: {'side': v['side'], 'pivot': list(v['pivot']), 'length': v['length']} for k, v in STICKS.items()},
            'fanPivot': [round(v, 4) for v in FAN_PIVOT], 'exhaustPoint': [round(v, 4) for v in EXHAUST_POINT],
            'nozzle': NOZZLE, 'canopy': CANOPY, 'plasmaBottom': PLASMA_BOTTOM,
        },
        'fbxFacts': facts,
        'bottomPoints': bottom_points(objs),
        'pieces': [],
    }
    for name in ORDER:
        spec = PIECE[name]
        r = table[name]
        manifest['pieces'].append({
            'name': name, 'role': spec[6], 'size': r['size'], 'bboxCenterOffset': r['center'],
            'pivot': [0, 0, 0], 'color': list(spec[1]), 'material': spec[2], 'reflectance': spec[3],
            'transparency': spec[4], 'castShadow': spec[5], 'glow': spec[7], 'side': spec[8], 'rideOn': spec[9],
            'motorPivot': motor_pivot(name), 'tris': r['tris'], 'verts': r['verts'], 'renderVerts': r['renderVerts'],
        })
    return manifest


def save_manifest(manifest):
    text = json.dumps(manifest, indent=1)
    (OUT / 'eggmobile_manifest.json').write_text(text)
    try:
        (PUBLIC / 'eggmobile_manifest.json').write_text(text)
    except Exception:
        pass


# ----------------------------------------------------------------------------------------------
# Renders: a stand-in R6 Eggman; a studio look (the references' grey) and a lobby look (sky, green baseplate)
# ----------------------------------------------------------------------------------------------
def simple_mat(name, rgb, rough=0.4, metal=0.0, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    lin = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
    b.inputs['Base Color'].default_value = lin
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = lin
        b.inputs['Emission Strength'].default_value = emit
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
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


def stand_in_eggman(coll):
    """A stand-in R6 Eggman seated at SEAT_ROOT, fists on the levers (for scale in the previews only)."""
    red = simple_mat('SI_Red', (205, 30, 34), 0.45)
    yellow = simple_mat('SI_Yellow', (255, 200, 30), 0.45)
    white = simple_mat('SI_White', (245, 245, 245), 0.4)
    skin = simple_mat('SI_Skin', (250, 205, 170), 0.5)
    stache = simple_mat('SI_Stache', (170, 80, 30), 0.6)
    blue = simple_mat('SI_Goggle', (60, 130, 230), 0.1, 0.3)
    black = simple_mat('SI_Black', (25, 25, 30), 0.4)
    pink = simple_mat('SI_Nose', (240, 130, 130), 0.4)
    root = V(SEAT_ROOT)
    add_mesh('SI_Torso', *rbox(root, (2.0, 2.0, 1.0), 0.16, 3), red, coll)
    add_mesh('SI_Yoke', *rbox(root + V(0, 0.72, 0), (2.06, 0.56, 1.06), 0.16, 3), yellow, coll)
    add_mesh('SI_Collar', *rbox(root + V(0, 1.02, 0.05), (1.3, 0.3, 0.9), 0.12, 2), yellow, coll)
    add_mesh('SI_Zip', *rbox(root + V(0, -0.2, -0.505), (0.16, 1.5, 0.05), 0.02, 1), white, coll)
    add_mesh('SI_Belt', *rbox(root + V(0, -0.82, 0), (2.04, 0.22, 1.04), 0.05, 1), black, coll)
    for sx, key in ((1, 'R'), (-1, 'L')):
        pivot = root + V(sx * 1.5, 0.5, 0)
        grip = V(STICKS[key]['pivot']) + V(0, STICKS[key]['length'] - 0.1, 0)
        d = (grip - pivot).normalized()
        up = V(0, 1, 0)
        xa = d.cross(up).normalized() if abs(d.dot(up)) < 0.99 else V(1, 0, 0)
        za = xa.cross(-d).normalized()
        f = Frame(pivot, xa, -d, za)
        add_mesh('SI_Arm' + key, *rbox((0, -0.35, 0), (0.95, 1.7, 0.95), 0.2, 3, frame=f), red, coll)
        add_mesh('SI_Shoulder' + key, *ellipsoid(pivot + V(sx * 0.05, 0.15, 0), (0.56, 0.5, 0.56), 16, 10), yellow, coll)
        add_mesh('SI_Cuff' + key, *rbox((0, -0.95, 0), (1.02, 0.34, 1.02), 0.12, 2, frame=f), yellow, coll)
        add_mesh('SI_Glove' + key, *ellipsoid(pivot + d * 1.3, (0.42, 0.4, 0.42), 16, 10), white, coll)
    head = root + V(0, 1.6, 0.02)
    add_mesh('SI_Head', *ellipsoid(head, (0.66, 0.74, 0.64), 24, 14), skin, coll)
    add_mesh('SI_GoggleBand', *torus(head + V(0, 0.3, 0), (0, 1, 0), (0, 0, -1), 0.66, 0.07, 32, 6), black, coll)
    for sx in (-1, 1):
        g = head + V(sx * 0.25, 0.3, -0.6)
        add_mesh('SI_GoggleRim%d' % sx, *torus(g, (0, 0, -1), (0, 1, 0), 0.17, 0.05, 20, 6), black, coll)
        add_mesh('SI_Goggle%d' % sx, *lathe([(0.0, -0.06), (0.17, -0.06), (0.17, 0.04), (0.0, 0.07)], 20, g, (0, 0, -1), (0, 1, 0)), blue, coll)
    add_mesh('SI_Nose', *ellipsoid(head + V(0, 0.0, -0.74), (0.15, 0.13, 0.15), 14, 8), pink, coll)
    for sx in (-1, 1):
        for k, (dx, dy, ang, rx) in enumerate(((0.45, -0.1, 12, 0.55), (0.85, 0.02, 24, 0.42), (1.18, 0.16, 38, 0.26))):
            rot = Matrix.Rotation(rad(sx * -ang), 3, 'Z')
            c = head + V(sx * dx, dy - 0.12, -0.56 + 0.1 * k)
            v, fcs = ellipsoid((0, 0, 0), (rx, 0.17 - 0.03 * k, 0.2 - 0.03 * k), 16, 8)
            add_mesh('SI_Stache%d_%d' % (sx, k), [c + rot @ p for p in v], fcs, stache, coll)


def world_nodes(scene, look):
    w = bpy.data.worlds.get('EM_World') or bpy.data.worlds.new('EM_World')
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
    if look == 'studio':
        cr.elements[0].position = 0.0
        cr.elements[0].color = (0.62, 0.62, 0.64, 1)
        cr.elements[1].position = 0.5
        cr.elements[1].color = (0.42, 0.42, 0.45, 1)
        bg.inputs['Strength'].default_value = 1.0
    else:
        cr.elements[0].position = 0.0
        cr.elements[0].color = (0.55, 0.78, 1.0, 1)
        cr.elements[1].position = 0.32
        cr.elements[1].color = (0.05, 0.32, 0.95, 1)
        bg.inputs['Strength'].default_value = 0.9
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])


def make_grounds(coll):
    # The lobby's green baseplate.
    m = bpy.data.materials.new('EM_Baseplate')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get('Principled BSDF')
    brick = nt.nodes.new('ShaderNodeTexBrick')
    brick.inputs['Color1'].default_value = (0.06, 0.42, 0.02, 1)
    brick.inputs['Color2'].default_value = (0.07, 0.46, 0.025, 1)
    brick.inputs['Mortar'].default_value = (0.035, 0.26, 0.012, 1)
    brick.inputs['Scale'].default_value = 0.5
    brick.inputs['Mortar Size'].default_value = 0.025
    brick.offset = 0.0
    tc = nt.nodes.new('ShaderNodeTexCoord')
    nt.links.new(tc.outputs['Object'], brick.inputs['Vector'])
    nt.links.new(brick.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.8
    me = bpy.data.meshes.new('GroundLobby')
    s = 400
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(m)
    lobby = bpy.data.objects.new('GroundLobby', me)
    coll.objects.link(lobby)
    # The studio floor (light grey tiles, like the references).
    m2 = bpy.data.materials.new('EM_StudioFloor')
    m2.use_nodes = True
    nt2 = m2.node_tree
    b2 = nt2.nodes.get('Principled BSDF')
    br2 = nt2.nodes.new('ShaderNodeTexBrick')
    br2.inputs['Color1'].default_value = (0.5, 0.5, 0.52, 1)
    br2.inputs['Color2'].default_value = (0.52, 0.52, 0.54, 1)
    br2.inputs['Mortar'].default_value = (0.38, 0.38, 0.4, 1)
    br2.inputs['Scale'].default_value = 0.12
    br2.inputs['Mortar Size'].default_value = 0.01
    br2.offset = 0.0
    tc2 = nt2.nodes.new('ShaderNodeTexCoord')
    nt2.links.new(tc2.outputs['Object'], br2.inputs['Vector'])
    nt2.links.new(br2.outputs['Color'], b2.inputs['Base Color'])
    b2.inputs['Roughness'].default_value = 0.55
    me2 = bpy.data.meshes.new('GroundStudio')
    me2.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    me2.materials.append(m2)
    studio = bpy.data.objects.new('GroundStudio', me2)
    coll.objects.link(studio)
    # The plasma under the ship (the game draws it with Beams): a soft cyan cone and a glow on the ground.
    cone_m = bpy.data.materials.new('EM_PlasmaCone')
    cone_m.use_nodes = True
    cn = cone_m.node_tree
    cn.nodes.clear()
    o = cn.nodes.new('ShaderNodeOutputMaterial')
    em = cn.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (0.1, 0.85, 1.0, 1)
    em.inputs['Strength'].default_value = 2.0
    tr = cn.nodes.new('ShaderNodeBsdfTransparent')
    mix = cn.nodes.new('ShaderNodeMixShader')
    lw = cn.nodes.new('ShaderNodeLayerWeight')
    lw.inputs['Blend'].default_value = 0.35
    inv = cn.nodes.new('ShaderNodeMath')
    inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1.0
    cn.links.new(lw.outputs['Facing'], inv.inputs[1])
    cn.links.new(inv.outputs[0], mix.inputs['Fac'])
    cn.links.new(tr.outputs['BSDF'], mix.inputs[1])
    cn.links.new(em.outputs['Emission'], mix.inputs[2])
    cn.links.new(mix.outputs['Shader'], o.inputs['Surface'])
    try:
        cone_m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    v, f = lathe([(0.0, 0.02), (2.4, 0.02), (0.95, PLASMA_BOTTOM + 0.05), (0.0, PLASMA_BOTTOM + 0.05)], 48)
    cone = add_mesh('PlasmaCone', v, f, cone_m, coll)
    gm = bpy.data.materials.new('EM_GroundGlow')
    gm.use_nodes = True
    gn = gm.node_tree
    gn.nodes.clear()
    go = gn.nodes.new('ShaderNodeOutputMaterial')
    ge = gn.nodes.new('ShaderNodeEmission')
    ge.inputs['Color'].default_value = (0.15, 0.9, 1.0, 1)
    ge.inputs['Strength'].default_value = 1.2
    gt = gn.nodes.new('ShaderNodeBsdfTransparent')
    gmix = gn.nodes.new('ShaderNodeMixShader')
    grad = gn.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'SPHERICAL'
    gtc = gn.nodes.new('ShaderNodeTexCoord')
    gmap = gn.nodes.new('ShaderNodeMapping')
    gmap.inputs['Scale'].default_value = (0.2, 0.2, 0.2)
    gn.links.new(gtc.outputs['Object'], gmap.inputs['Vector'])
    gn.links.new(gmap.outputs['Vector'], grad.inputs['Vector'])
    gn.links.new(grad.outputs['Fac'], gmix.inputs['Fac'])
    gn.links.new(gt.outputs['BSDF'], gmix.inputs[1])
    gn.links.new(ge.outputs['Emission'], gmix.inputs[2])
    gn.links.new(gmix.outputs['Shader'], go.inputs['Surface'])
    try:
        gm.surface_render_method = 'BLENDED'
    except Exception:
        pass
    me3 = bpy.data.meshes.new('GroundGlow')
    s3 = 5.0
    me3.from_pydata([(-s3, -s3, 0.01), (s3, -s3, 0.01), (s3, s3, 0.01), (-s3, s3, 0.01)], [], [(0, 1, 2, 3)])
    me3.materials.append(gm)
    glow = bpy.data.objects.new('GroundGlow', me3)
    coll.objects.link(glow)
    return lobby, studio, [cone, glow]


def add_lights(coll):
    ld = bpy.data.lights.new('Sun', 'SUN')
    ld.energy = 4.0
    ld.angle = rad(4.0)
    ld.color = (1.0, 0.97, 0.9)
    sun = bpy.data.objects.new('Sun', ld)
    coll.objects.link(sun)
    d = ROBLOX_TO_BLENDER @ V(0.45, -1.0, 0.6).normalized()
    sun.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    fill = bpy.data.lights.new('Fill', 'AREA')
    fill.energy = 1200
    fill.size = 14
    fill.color = (0.9, 0.94, 1.0)
    fo = bpy.data.objects.new('Fill', fill)
    coll.objects.link(fo)
    return sun, fo


def aim(ob, loc, target):
    L, T = ROBLOX_TO_BLENDER @ V(loc), ROBLOX_TO_BLENDER @ V(target)
    ob.location = L
    ob.rotation_euler = (T - L).to_track_quat('-Z', 'Y').to_euler()


def add_camera(name, loc, target, lens, coll):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.1
    cd.clip_end = 2000
    ob = bpy.data.objects.new(name, cd)
    coll.objects.link(ob)
    aim(ob, loc, target)
    return ob


def orbit(az_deg, el_deg, dist, target):
    az, el = rad(az_deg), rad(el_deg)
    t = V(target)
    return (t.x + dist * math.cos(el) * math.sin(az), t.y + dist * math.sin(el), t.z - dist * math.cos(el) * math.cos(az))


def setup_render(scene):
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except TypeError:
        scene.render.engine = 'BLENDER_EEVEE'
    ee = scene.eevee
    ee.taa_render_samples = 32 if QUICK else 128
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
    try:
        scene.view_settings.view_transform = 'AgX'
        scene.view_settings.look = 'AgX - Punchy'
    except Exception:
        pass
    scene.view_settings.exposure = 0.55
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new('CompositorNodeRLayers')
    comp = nt.nodes.new('CompositorNodeComposite')
    glare = nt.nodes.new('CompositorNodeGlare')
    for k, v in (('glare_type', 'BLOOM'), ('quality', 'HIGH'), ('threshold', 1.2), ('size', 7), ('mix', -0.55)):
        try:
            setattr(glare, k, v)
        except Exception:
            pass
    for k, v in (('Threshold', 1.2), ('Strength', 0.5), ('Size', 0.5)):
        if k in glare.inputs:
            try:
                glare.inputs[k].default_value = v
            except Exception:
                pass
    nt.links.new(rl.outputs['Image'], glare.inputs['Image'])
    nt.links.new(glare.outputs['Image'], comp.inputs['Image'])


def render_view(scene, cam, path, rx, ry):
    scene.camera = cam
    scene.render.resolution_x = rx
    scene.render.resolution_y = ry
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log('render', path.name)


def side_by_side(ref_path, render_path, out_path):
    """The reference (left) and the render (right), same height."""
    import numpy as np
    ref = bpy.data.images.load(str(ref_path))
    ren = bpy.data.images.load(str(render_path))
    rw, rh = ref.size
    ww, wh = ren.size
    a = np.array(ref.pixels[:], dtype=np.float32).reshape(rh, rw, 4)
    b = np.array(ren.pixels[:], dtype=np.float32).reshape(wh, ww, 4)
    nh, nw = wh, int(round(rw * wh / rh))
    ys = np.linspace(0, rh - 1, nh)
    xs = np.linspace(0, rw - 1, nw)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.minimum(y0 + 1, rh - 1)
    x1 = np.minimum(x0 + 1, rw - 1)
    fy = (ys - y0)[:, None, None]
    fx = (xs - x0)[None, :, None]
    top = a[y0][:, x0] * (1 - fx) + a[y0][:, x1] * fx
    bot = a[y1][:, x0] * (1 - fx) + a[y1][:, x1] * fx
    ra = top * (1 - fy) + bot * fy
    gap = np.ones((wh, 16, 4), dtype=np.float32)
    out = np.concatenate([ra, gap, b], axis=1)
    img = bpy.data.images.new(out_path.stem, out.shape[1], out.shape[0], alpha=True)
    img.pixels = out.ravel().tolist()
    img.filepath_raw = str(out_path)
    img.file_format = 'PNG'
    img.save()
    log('side by side', out_path.name)


def renders(scene):
    coll = bpy.data.collections.new('Preview')
    scene.collection.children.link(coll)
    lobby, studio, plasma = make_grounds(coll)
    sun, fill = add_lights(coll)
    eggman = bpy.data.collections.new('StandInEggman')
    scene.collection.children.link(eggman)
    stand_in_eggman(eggman)
    setup_render(scene)
    q = 0.5 if QUICK else 1.0
    target = (0.0, 3.6, 0.3)

    def look(kind):
        world_nodes(scene, kind)
        lobby.hide_render = kind != 'lobby'
        studio.hide_render = kind != 'studio'
        for ob in plasma:
            ob.hide_render = kind != 'lobby'
        sun.data.energy = 3.2 if kind == 'studio' else 4.0

    def with_eggman(on):
        eggman.hide_render = not on

    # 1. The references' angles in the studio look, side by side with them (empty ship, then with Eggman).
    look('studio')
    aim(fill, (-12, 10, -12), target)
    views = [('side', REF_SIDE, -80, 12, 12.5, 30, (1920, 1080)), ('back', REF_BACK, -148, 36, 15.5, 36, (1280, 720))]
    for key, ref, az, el, dist, lens, (rx, ry) in views:
        studio.hide_render = key == 'side'
        for egg in (False, True):
            # With Eggman aboard the frame opens up (his head rises over the ship).
            tgt = (target[0], target[1] + (0.8 if egg else 0.0), target[2])
            cam = add_camera('Cam_ref_%s_%d' % (key, egg), orbit(az, el, dist * (1.25 if egg else 1.0), tgt), tgt, lens, coll)
            with_eggman(egg)
            name = 'EggMobile_ref_%s%s.png' % (key, '_eggman' if egg else '')
            render_view(scene, cam, PREV / name, int(rx * q), int(ry * q))
            if ref.exists():
                side_by_side(ref, PREV / name, PREV / ('EggMobile_vs_reference_%s%s.png' % (key, '_eggman' if egg else '')))
    # 2. The lobby look with Eggman at the controls: a low front three-quarter, his left side, the back, the top.
    look('lobby')
    with_eggman(True)
    aim(fill, (-10, 9, -14), target)
    lobby_views = [
        ('EggMobile_front34', orbit(-32, 7, 16.5, target), target, 36, (1600, 1000)),
        ('EggMobile_side_left', orbit(-92, 9, 17.5, target), target, 40, (1500, 900)),
        ('EggMobile_back34', orbit(148, 22, 17.0, target), target, 38, (1500, 1000)),
        ('EggMobile_top', (0.01, 25.0, 0.6), (0, 3, 0.2), 40, (1100, 1100)),
    ]
    for name, loc, tgt, lens, (rx, ry) in lobby_views:
        cam = add_camera('Cam_' + name, loc, tgt, lens, coll)
        render_view(scene, cam, PREV / (name + '.png'), int(rx * q), int(ry * q))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    build_all()
    coll = bpy.data.collections.new('EggMobileKit')
    scene.collection.children.link(coll)
    objs = {}
    for name in ORDER:
        assert G[name].f, 'empty piece ' + name
        objs[name] = geo_to_object(name, G[name], coll)
    bpy.context.view_layer.update()
    table = {name: validate(objs[name]) for name in ORDER}
    total = 0
    print('%-20s %6s %6s %7s %-26s %-26s %s' % ('piece', 'tris', 'verts', 'rVerts', 'size X x Y x Z', 'centre', 'result'))
    for name in ORDER:
        r = table[name]
        total += r['tris']
        print('%-20s %6d %6d %7d %-26s %-26s %s' % (name, r['tris'], r['verts'], r['renderVerts'],
              'x'.join('%.3f' % v for v in r['size']), ','.join('%.3f' % v for v in r['center']),
              'OK' if r['ok'] else 'FAIL ' + ','.join(r['errors'])), flush=True)
    log('TOTAL TRIS', total)
    failed = [(n, r['errors']) for n, r in table.items() if not r['ok']]
    assert not failed, failed
    assert total <= 40000, total
    facts = export_all(scene, objs)
    log('FBX written', {k: (v['unitScaleFactor'], v['asciiOnly']) for k, v in list(facts.items())[:2]})
    manifest = write_manifest(table, facts, objs)   # saved once, after the re-import check (the tests read it)
    if not NO_RENDER:
        import runpy
        runpy.run_path(str(SCRIPT.with_name('egg_mobile_finish.py')), init_globals={'em': sys.modules[__name__]})
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'EggMobile_Corrected.blend'))
    worst, missing, extra = reimport_check({n: table[n] for n in ORDER})
    log('re-import: worst size / centre error %.5f studs, missing %s, extra %s' % (worst, missing, extra))
    manifest['reimportCheck'] = {'worstErrorStuds': round(worst, 5), 'missing': missing, 'extra': extra}
    save_manifest(manifest)
    log('manifest written')
    assert worst < 0.01 and not missing, (worst, missing)
    log('done')


if __name__ == '__main__':
    main()

