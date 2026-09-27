"""Super Sonic vs Dr. Eggman live event: the event's meshes (Blender 4.5, headless, deterministic).

2026-09-26: the art for the event (the server / client code falls back to simple shapes until the owner has
imported this kit). Four assets, single-colour pieces (EV_*) like the Egg Mobile and Flash gate kits:
  * Bomb          Eggman's heavy aerial bomb: a glossy gunmetal teardrop with bevelled seams (two ring grooves,
                  four weld beads, rivets), a yellow hazard band with black diagonal stripes round its widest
                  part, a red rounded nose cap with a small yellow-black hazard rim, a tail stabilizer ring on
                  four canted fins and a small rear fuse / exhaust cap; 3 studs long, standing NOSE-DOWN (-Y)
                  in its own space (Shared/SuperSonicEventFx.Bomb.NoseAxis): turned to fly nose first.
                  EV_Bomb (the body, the PrimaryPart), EV_BombStripe (yellow), EV_BombFins (black: ring, fins,
                  stripes, rim ticks, fuse cap), EV_BombNose (red).
  * ChaosEmerald  the classic Chaos Emerald, a brilliant cut: octagonal flat table, star / bezel (kite) / upper
                  girdle facets on the crown, a knife-edge 16-sided girdle, lower girdle and pavilion main facets
                  down to a culet point; 1.5 high, 1.6 across; flat facets (every kite planar by construction).
                  One mesh, coloured 7 ways in code (the manifest's "variants").
  * SpinBall      Sonic's spin-attack ball: a 6.1-stud shell (an inner surface too, for transparency) with
                  subtle overlapping quill ridges swept round the rolling axis (X); it encloses a standing R6
                  whose HumanoidRootPart sits 0.4 above the ball's centre. One mesh, tinted in code.
  * Cannon        the bomb cannon under the Egg Mobile's front (below the lamp): a grey saddle plate on the
                  black bowl, two cheeks and a trunnion holding a white barrel pitched 20 degrees down, grey
                  bands and muzzle ring, a yellow-black hazard band, the black bore with a cyan charge glow at its
                  bottom. EV_Cannon (the barrel, the PrimaryPart), EV_CannonMetal, EV_CannonDark,
                  EV_CannonStripe, EV_CannonGlow (Neon). Fitted to the Egg Mobile kit's hull (its manifest).

Run:
  "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python audit/event_kit_bpy.py -- [--quick] [--no-render]

Writes (design/event/supersonic/, every FBX written first in an ASCII-only temp folder, then copied):
  EventKit.fbx            all 11 pieces, one object EV_<Name> each, one plain material each (no textures)
  fbx/EV_<Name>.fbx       one FBX per piece (fallback);  obj/EV_<Name>.obj + .mtl (fallback)
  IMPORTAR_EVENTO.md      the owner's import steps (Spanish), written from the manifest's numbers
  event_manifest.json     per piece: asset, role, size, bboxCenterOffset, colour, material, reflectance...; per
                          asset: pieces, PrimaryPart, attachments; the emerald's 7 colours; the cannon's mount / muzzle
  EventKit.blend          the kit objects (editable source)
  preview/*.png           Eevee renders: each piece, the 7 emeralds in a ring, the bomb, the spin ball round a
                          stand-in R6, the cannon mounted on the Egg Mobile (design/npc/eggmobile/EggMobileKit.fbx)
  C:/Users/Public/EventKit/  copies of the FBX / OBJ files and the manifest (an ASCII path for Studio's importer)

Frames:
  Asset space = Roblox axes, studs: +X right, +Y up, -Z forward. Blender (x, y, z) = (X, -Z, Y); the FBX export
  (-Z forward, Y up, UnitScaleFactor 1 like the Egg Mobile kit) gives Roblox (X, Y, Z) back.
  Every piece's origin (its pivot) is its ASSET's origin, identity transforms:
    Bomb, ChaosEmerald, SpinBall: the asset's centre (0, 0, 0);
    Cannon: its MOUNT point, on the Egg Mobile's black bowl (ship space manifest.assets.Cannon.mount.ship), the
            cannon's axes = the ship's (placement: eggFloor * CFrame.new(mount.ship), no rotation).
  A piece goes where it belongs with part.CFrame = assetPivot * CFrame.new(bboxCenterOffset) (* the turn Studio's
  Import 3D added, undone: audit/u4_event_kit with Shared/MeshKitImport); Size = size.
"""
import bpy, bmesh, math, json, sys, time, shutil, tempfile, re, struct
from pathlib import Path
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
QUICK = '--quick' in ARGS
NO_RENDER = '--no-render' in ARGS

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
OUT = ROOT / 'design' / 'event' / 'supersonic'
PREV = OUT / 'preview'
EGG_DIR = ROOT / 'design' / 'npc' / 'eggmobile'
EGG_FBX = EGG_DIR / 'EggMobileKit.fbx'
EGG_MANIFEST = EGG_DIR / 'eggmobile_manifest.json'
PUBLIC = Path('C:/Users/Public/EventKit')
for p in (OUT, PREV, OUT / 'fbx', OUT / 'obj'):
    p.mkdir(parents=True, exist_ok=True)
KIT_VERSION = 1
T0 = time.time()


def log(*a):
    print('[eventkit %6.1fs]' % (time.time() - T0), *a, flush=True)


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
# The Egg Mobile's hull (its manifest's "ship" block): the cannon hugs its black bowl.
# ----------------------------------------------------------------------------------------------
EGG = json.loads(EGG_MANIFEST.read_text())
SHIP = EGG['ship']
Y_BOT, Y_CYL, R_HULL, RIM_TOP = SHIP['hullBottom'], SHIP['wallFrom'], SHIP['hullRadius'], SHIP['rimTop']
HULL_CENTER = SHIP['hullCenter']

# ----------------------------------------------------------------------------------------------
# Pieces: one mesh per colour. Colours are Roblox sRGB. role: body (the asset's PrimaryPart) | trim | gem |
# shell | glow. shading flat = crisp facets (every edge split), smooth = auto-smooth at `sharp` degrees.
# ----------------------------------------------------------------------------------------------
PIECES = [
    # name,             asset,          role,    primary, rgb,             material,        refl, transp, shadow, shading,  sharp
    ('EV_Bomb',         'Bomb',         'body',  True,  (66, 71, 84),    'SmoothPlastic', 0.22, 0.0,  True,  'smooth', 40),
    ('EV_BombStripe',   'Bomb',         'trim',  False, (255, 204, 22),  'SmoothPlastic', 0.0,  0.0,  True,  'smooth', 50),
    ('EV_BombFins',     'Bomb',         'trim',  False, (30, 31, 38),    'SmoothPlastic', 0.1,  0.0,  True,  'smooth', 35),
    ('EV_BombNose',     'Bomb',         'trim',  False, (214, 36, 36),   'SmoothPlastic', 0.12, 0.0,  True,  'smooth', 50),
    ('EV_ChaosEmerald', 'ChaosEmerald', 'gem',   True,  (20, 220, 90),   'Glass',         0.25, 0.15, False, 'flat',   0),
    ('EV_SpinBall',     'SpinBall',     'shell', True,  (35, 95, 235),   'SmoothPlastic', 0.15, 0.0,  False, 'smooth', 80),
    ('EV_Cannon',       'Cannon',       'body',  True,  (230, 233, 238), 'SmoothPlastic', 0.18, 0.0,  True,  'smooth', 45),
    ('EV_CannonMetal',  'Cannon',       'trim',  False, (160, 165, 176), 'SmoothPlastic', 0.15, 0.0,  True,  'smooth', 40),
    ('EV_CannonDark',   'Cannon',       'trim',  False, (26, 26, 32),    'SmoothPlastic', 0.05, 0.0,  False, 'smooth', 45),
    ('EV_CannonStripe', 'Cannon',       'trim',  False, (255, 204, 22),  'SmoothPlastic', 0.0,  0.0,  False, 'smooth', 50),
    ('EV_CannonGlow',   'Cannon',       'glow',  False, (70, 238, 255),  'Neon',          0.0,  0.0,  False, 'smooth', 50),
]
PIECE = {p[0]: p for p in PIECES}
ORDER = [p[0] for p in PIECES]
ASSETS = ['Bomb', 'ChaosEmerald', 'SpinBall', 'Cannon']
ROBLOX_MAX_TRIS, ROBLOX_MAX_VERTS, ROBLOX_MAX_AXIS = 20000, 10000, 2048.0
BUDGET = {'Bomb': 7000, 'ChaosEmerald': 400, 'SpinBall': 16000, 'Cannon': 12000}

# The seven Chaos Emeralds (Roblox sRGB); the game picks Glass or Neon.
EMERALD_COLORS = [
    ('Green', (20, 220, 90)), ('Red', (240, 40, 52)), ('Blue', (40, 110, 255)), ('Yellow', (255, 214, 28)),
    ('Cyan', (60, 228, 255)), ('Purple', (168, 70, 255)), ('White', (236, 242, 255)),
]
SPINBALL_COLORS = [('Blue', (35, 95, 235)), ('Gold', (255, 196, 40))]


# ----------------------------------------------------------------------------------------------
# Geometry helpers (the Egg Mobile kit's, asset space)
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
    """A right-handed frame: origin and unit axes x, y, z."""

    def __init__(self, origin, x, y, z):
        self.o, self.x, self.y, self.z = V(origin), V(x).normalized(), V(y).normalized(), V(z).normalized()

    def pt(self, a, b, c):
        return self.o + self.x * a + self.y * b + self.z * c


def lathe(profile, segs, origin=(0, 0, 0), axis=(0, 1, 0), ref=(0, 0, -1), phi0=0.0, phi1=None,
          closed_profile=False):
    """Surface of revolution. profile [(r, h)]: h along `axis`, r from it; points ordered bottom -> right -> up
    -> top (counterclockwise with r right, h up) face outward, the reverse faces the axis. r == 0: a pole.
    phi runs from `ref` toward axis x ref."""
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
    return verts, faces


def torus(center, axis, ref, major, minor, segs, rings_n):
    prof = [(major + minor * math.cos(TAU * k / rings_n - math.pi / 2), minor * math.sin(TAU * k / rings_n - math.pi / 2))
            for k in range(rings_n)]
    return lathe(prof, segs, center, axis, ref, closed_profile=True)


def sweep(pts, radius, sides=6, cap='round', cap_rings=2, up_hint=(0, 1, 0)):
    """A tube through dense points (parallel-transport frames), round or flat caps."""
    pts = [V(p) for p in pts]
    m = len(pts)
    tans = []
    for i in range(m):
        if i == 0:
            d = pts[1] - pts[0]
        elif i == m - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[i + 1] - pts[i - 1]
        tans.append(d.normalized())
    hint = V(up_hint)
    if abs(tans[0].dot(hint)) > 0.95:
        hint = V(1, 0, 0) if abs(tans[0].x) < 0.9 else V(0, 0, 1)
    norms = [(hint - tans[0] * tans[0].dot(hint)).normalized()]
    for i in range(1, m):
        q = tans[i - 1].rotation_difference(tans[i])
        n = q @ norms[-1]
        norms.append((n - tans[i] * tans[i].dot(n)).normalized())
    rings = [(pts[i], tans[i], norms[i], tans[i].cross(norms[i]), radius) for i in range(m)]
    seq = []
    if cap == 'round':
        c, t, n, b, r = rings[0]
        for k in range(cap_rings, 0, -1):
            th = (math.pi / 2) * k / cap_rings
            seq.append((c - t * r * math.sin(th), n, b, r * math.cos(th) if k < cap_rings else 0.0))
    else:
        c, t, n, b, r = rings[0]
        seq.append((c, n, b, 0.0))
    for (c, t, n, b, r) in rings:
        seq.append((c, n, b, r))
    if cap == 'round':
        c, t, n, b, r = rings[-1]
        for k in range(1, cap_rings + 1):
            th = (math.pi / 2) * k / cap_rings
            seq.append((c + t * r * math.sin(th), n, b, r * math.cos(th) if k < cap_rings else 0.0))
    else:
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
    for i in range(len(idx) - 1):
        a, bb = idx[i], idx[i + 1]
        for j in range(sides):
            j1 = (j + 1) % sides
            if len(a) == 1:
                faces.append((a[0], bb[j1], bb[j]))
            elif len(bb) == 1:
                faces.append((a[j], a[j1], bb[0]))
            else:
                faces.append((a[j], a[j1], bb[j1], bb[j]))
    return verts, faces


def rbox(center, size, radius, segs=2, frame=None):
    """A rounded box (bevelled cube) placed in `frame` (its size along the frame's x, y, z)."""
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
        p = v.co.copy() + V(center)
        verts.append(frame.pt(p.x, p.y, p.z) if frame is not None else p)
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def ellipsoid(center, radii, segs=16, rings=10):
    prof = [(math.sin(math.pi * k / rings), -math.cos(math.pi * k / rings)) for k in range(rings + 1)]
    prof[0] = (0.0, -1.0)
    prof[-1] = (0.0, 1.0)
    verts, faces = lathe(prof, segs)
    return [V(p.x * radii[0], p.y * radii[1], p.z * radii[2]) + V(center) for p in verts], faces


def prism(poly2d, w0, w1):
    """A flat polygon [(u, v)] extruded from w0 to w1: verts (u, v, w), faces (closed)."""
    n = len(poly2d)
    verts = [V(u, v, w0) for (u, v) in poly2d] + [V(u, v, w1) for (u, v) in poly2d]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def patch(fn, cols, rows, w0, w1):
    """A curved slab: fn(u, v, w) -> point for u, v in [0, 1], thickness w0..w1 (closed)."""
    verts, faces, top, bot = [], [], [], []
    for c in range(cols + 1):
        rt, rb = [], []
        for r in range(rows + 1):
            u, v = c / cols, r / rows
            verts.append(V(fn(u, v, w1)))
            rt.append(len(verts) - 1)
            verts.append(V(fn(u, v, w0)))
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
    return verts, faces


def bevelled(verts, faces, offset, segs=2):
    """A closed convex item with every edge rounded (bmesh bevel)."""
    bm = bmesh.new()
    vs = [bm.verts.new(V(p)) for p in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=offset, segments=segs, profile=0.5, affect='EDGES', clamp_overlap=True)
    bm.verts.index_update()
    out_v = [v.co.copy() for v in bm.verts]
    out_f = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return out_v, out_f


def dome(center, normal, r, segs=6):
    """A small rivet head on a surface (its base 0.02 under it)."""
    n = V(normal).normalized()
    ref = V(0, 1, 0) if abs(n.y) < 0.9 else V(1, 0, 0)
    ref = (ref - n * ref.dot(n)).normalized()
    prof = [(0.0, -0.02), (r, -0.02), (r * 0.92, r * 0.35), (r * 0.55, r * 0.7), (0.0, r * 0.8)]
    return lathe(prof, segs, center, n, ref)


def hull2d(points):
    """Convex hull (monotone chain), counterclockwise."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in points))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


# ----------------------------------------------------------------------------------------------
# 1. The bomb (modelled along Z, nose -Z, then stood nose-down: bomb space = origin at its centre, nose -Y)
# ----------------------------------------------------------------------------------------------
BOMB = {
    'length': 3.0, 'rMax': 0.74, 'hMax': -0.30, 'hNose': -1.478, 'hTail': 1.05, 'tailShrink': 0.62,
    'capBack': -0.98, 'capOut': 0.022, 'band': (-0.14, 0.18), 'bandOut': 0.022, 'seams': (-0.72, 0.45),
    'ring': (0.93, 1.30, 0.60, 0.668), 'end': 1.5, 'finCant': 7.0, 'stripes': 10,
}
BOMB_AXIS = V(0, 0, 1)
BOMB_SEGS = 32
BOMB_STAND = Matrix.Rotation(rad(-90), 3, 'X')   # modelled nose -Z -> stands nose -Y, tail +Y
BOMB_NOSE_AXIS = '-Y'


def bomb_r(h):
    b = BOMB
    hm, hn, R = b['hMax'], b['hNose'], b['rMax']
    if h <= hm:
        t = (h - hm) / (hm - hn)
        return R * math.sqrt(max(0.0, 1 - t * t))
    t = min(1.0, (h - hm) / (b['hTail'] - hm))
    return R * (1 - b['tailShrink'] * t ** 1.8)


def bomb_dr(h):
    e = 1e-4
    return (bomb_r(h + e) - bomb_r(h - e)) / (2 * e)


def bomb_er(alpha):
    """The radial direction at azimuth alpha (radians from +Y toward -X, the lathe's phi)."""
    return V(-math.sin(alpha), math.cos(alpha), 0)


def bomb_et(alpha):
    return V(-math.cos(alpha), -math.sin(alpha), 0)


def bomb_pt(alpha, h, out=0.0):
    er = bomb_er(alpha)
    n = (er - BOMB_AXIS * bomb_dr(h)).normalized()
    return er * bomb_r(h) + BOMB_AXIS * h + n * out, n


def build_bomb():
    b = BOMB
    ax, rf = (0, 0, 1), (0, 1, 0)
    # The body: a teardrop lathe (its front hidden under the nose cap), two V grooves (the seams), the tail.
    h0 = -1.08
    samples = []
    n = 22
    for k in range(n + 1):
        h = h0 + (b['hTail'] - h0) * k / n
        if all(abs(h - s) > 0.045 for s in b['seams']):
            samples.append((bomb_r(h), h))
    for s in b['seams']:
        samples += [(bomb_r(s - 0.032), s - 0.032), (bomb_r(s) - 0.028, s - 0.01), (bomb_r(s) - 0.028, s + 0.01),
                    (bomb_r(s + 0.032), s + 0.032)]
    samples.sort(key=lambda p: p[1])
    prof = [(0.0, h0)] + samples + [(bomb_r(b['hTail']) - 0.03, b['hTail'] + 0.07), (0.0, b['hTail'] + 0.07)]
    G['EV_Bomb'].add(*lathe(prof, BOMB_SEGS, (0, 0, 0), ax, rf), closed=True)
    # Rivets beside each seam, and four weld beads along the body between the seams.
    for s, dh in ((b['seams'][0], 0.085), (b['seams'][1], -0.085)):
        for k in range(8):
            a = TAU * (k + 0.5) / 8
            p, nrm = bomb_pt(a, s + dh)
            G['EV_Bomb'].add(*dome(p, nrm, 0.034, 5))
    for k in range(4):
        a = TAU * k / 4
        pts = [bomb_pt(a, b['seams'][0] + 0.06 + (b['seams'][1] - b['seams'][0] - 0.12) * i / 12, 0.004)[0] for i in range(13)]
        G['EV_Bomb'].add(*sweep(pts, 0.016, 4, cap='round', cap_rings=1))
    # The hazard band: a yellow ring round the widest part, ten black diagonal stripes on it.
    h_a, h_b = b['band']
    t = b['bandOut']
    band = [(bomb_r(h_a) - 0.02, h_a), (bomb_r(h_a) + t * 0.55, h_a), (bomb_r(h_a + 0.012) + t, h_a + 0.012)]
    for i in range(1, 5):
        h = h_a + 0.03 + (h_b - h_a - 0.06) * i / 5
        band.append((bomb_r(h) + t, h))
    band += [(bomb_r(h_b - 0.012) + t, h_b - 0.012), (bomb_r(h_b) + t * 0.55, h_b), (bomb_r(h_b) - 0.02, h_b)]
    G['EV_BombStripe'].add(*lathe(band, 40, (0, 0, 0), ax, rf, closed_profile=True), closed=True)
    hc = (h_a + h_b) / 2
    width = 0.46 * TAU / b['stripes']
    for k in range(b['stripes']):
        a0 = TAU * k / b['stripes']

        def fn(u, v, w, a0=a0):
            h = h_a + 0.02 + (h_b - h_a - 0.04) * v
            a = a0 + width * u + (h - hc) * 1.0
            return V(bomb_er(a) * (bomb_r(h) + t + w)) + BOMB_AXIS * h
        G['EV_BombFins'].add(*patch(fn, 2, 3, -0.006, 0.011), closed=True)
    # The red nose cap (the teardrop's front, 0.022 proud) and its hazard rim: a yellow bead with black ticks.
    A = b['hMax'] - b['hNose'] + b['capOut']
    Rc = b['rMax'] + b['capOut']
    th_back = math.acos((b['hMax'] - b['capBack']) / A)
    cap = [(0.0, b['hMax'] - A)]
    for i in range(1, 12):
        th = th_back * i / 11
        cap.append((Rc * math.sin(th), b['hMax'] - A * math.cos(th)))
    cap.append((0.0, b['capBack']))
    G['EV_BombNose'].add(*lathe(cap, BOMB_SEGS, (0, 0, 0), ax, rf), closed=True)
    rim_h = b['capBack'] + 0.004
    rim_r = Rc * math.sin(th_back) + 0.004
    G['EV_BombStripe'].add(*torus((0, 0, rim_h), ax, rf, rim_r, 0.042, 36, 6), closed=True)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        f = Frame(bomb_er(a) * (rim_r + 0.012) + BOMB_AXIS * rim_h, bomb_et(a), bomb_er(a), BOMB_AXIS)
        G['EV_BombFins'].add(*rbox((0, 0, 0), (0.085, 0.07, 0.096), 0.012, 1, frame=f), closed=True)
    # The tail: the stabilizer ring on four canted fins, the fuse / exhaust cap (a recess with a stub).
    h1, h2, ri, ro = b['ring']
    ring = [(ri, h1), (ro - 0.02, h1), (ro, h1 + 0.025), (ro, h2 - 0.025), (ro - 0.02, h2), (ri, h2), (ri - 0.008, h2 - 0.02),
            (ri - 0.008, h1 + 0.02)]
    G['EV_BombFins'].add(*lathe(ring, 36, (0, 0, 0), ax, rf, closed_profile=True), closed=True)
    fin = [(bomb_r(0.38) - 0.05, 0.38), (0.63, 0.95), (0.63, 1.27), (0.2, 1.27), (0.2, 1.12), (bomb_r(1.0) - 0.05, 1.0),
           (bomb_r(0.8) - 0.05, 0.8), (bomb_r(0.6) - 0.05, 0.6)]
    beta, hcf = rad(b['finCant']), 0.85
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        er, et = bomb_er(a), bomb_et(a)
        za = BOMB_AXIS * math.cos(beta) + et * math.sin(beta)
        wa = -BOMB_AXIS * math.sin(beta) + et * math.cos(beta)
        verts, faces = prism(fin, -0.028, 0.028)
        G['EV_BombFins'].add([er * p.x + BOMB_AXIS * hcf + za * (p.y - hcf) + wa * p.z for p in verts], faces, closed=True)
    e = b['end']
    fuse = [(0.0, 1.08), (0.24, 1.08), (0.255, 1.11), (0.255, 1.42), (0.24, e - 0.02), (0.215, e), (0.15, e), (0.14, e - 0.03),
            (0.14, 1.38), (0.0, 1.38)]
    G['EV_BombFins'].add(*lathe(fuse, 24, (0, 0, 0), ax, rf))
    G['EV_BombFins'].add(*lathe([(0.0, 1.37), (0.05, 1.37), (0.05, 1.44), (0.03, 1.47), (0.0, 1.48)], 10, (0, 0, 0), ax, rf))
    for name in ('EV_Bomb', 'EV_BombStripe', 'EV_BombFins', 'EV_BombNose'):
        G[name].v = [BOMB_STAND @ v for v in G[name].v]


# ----------------------------------------------------------------------------------------------
# 2. The Chaos Emerald (gem space: origin at its centre, the table up)
# ----------------------------------------------------------------------------------------------
GEM = {'girdleR': 0.80, 'tableR': 0.47, 'yTable': 0.75, 'yGirdle': 0.25, 'yCulet': -0.75, 'star': 0.45, 'pavilion': 0.42}


def gem_pt(a_deg, r, y):
    a = rad(a_deg)
    return V(r * math.sin(a), y, -r * math.cos(a))


def build_emerald():
    g = GEM
    rt, R, yt, yg, yc = g['tableR'], g['girdleR'], g['yTable'], g['yGirdle'], g['yCulet']
    c22 = math.cos(rad(22.5))
    T = [gem_pt(45 * i, rt, yt) for i in range(8)]
    Gd = [gem_pt(22.5 * k, R, yg) for k in range(16)]
    u = g['star']
    S = [gem_pt(45 * i + 22.5, (rt + u * (R - rt)) / c22, yt + u * (yg - yt)) for i in range(8)]
    p = g['pavilion']
    Q = [gem_pt(45 * i + 22.5, R * (1 - p) / c22, yg + p * (yc - yg)) for i in range(8)]
    C = V(0, yc, 0)
    verts = T + Gd + S + Q + [C]
    iT, iG, iS, iQ, iC = 0, 8, 24, 32, 40
    faces = [tuple(iT + i for i in range(8))]
    for i in range(8):
        j = (i + 1) % 8
        faces.append((iT + i, iT + j, iS + i))                                       # star
        faces.append((iT + i, iS + (i - 1) % 8, iG + 2 * i, iS + i))                 # bezel (kite)
        faces.append((iS + i, iG + 2 * i, iG + 2 * i + 1))                           # upper girdle
        faces.append((iS + i, iG + 2 * i + 1, iG + (2 * i + 2) % 16))
        faces.append((iG + 2 * i, iG + 2 * i + 1, iQ + i))                           # lower girdle
        faces.append((iG + 2 * i + 1, iG + (2 * i + 2) % 16, iQ + i))
        faces.append((iG + 2 * i, iQ + (i - 1) % 8, iC, iQ + i))                     # pavilion main (kite)
    # Every facet flat: the kites are planar by construction (their side points' midpoint on the long diagonal).
    worst = 0.0
    for f in faces:
        if len(f) < 4:
            continue
        a, b_, c = verts[f[0]], verts[f[1]], verts[f[2]]
        nrm = (b_ - a).cross(c - a).normalized()
        worst = max(worst, max(abs((verts[k] - a).dot(nrm)) for k in f))
    assert worst < 1e-6, 'a facet is not flat: %g' % worst
    G['EV_ChaosEmerald'].add(verts, faces, closed=True)


# ----------------------------------------------------------------------------------------------
# 3. The spin ball (ball space: origin at its centre; the rolling axis X)
# ----------------------------------------------------------------------------------------------
BALL = {'r': 3.05, 'inner': 2.95, 'quill': 0.19, 'cols': 96, 'rows': 68, 'width': 8.0, 'overlap': 1.45, 'swirl': 12.0,
        'lanes': [(-46.0, 5), (-23.0, 6), (0.0, 7), (23.0, 6), (46.0, 5)], 'rootOffset': (0.0, 0.4, 0.0)}


def ball_dir(theta, phi):
    """theta round the X axis (0 = +Y, 90 = +Z), phi the latitude (+90 = +X), degrees."""
    t, p = rad(theta), rad(phi)
    return V(math.sin(p), math.cos(p) * math.cos(t), math.cos(p) * math.sin(t))


QUILLS = []
for _li, (_lat, _n) in enumerate(BALL['lanes']):
    _step = 360.0 / _n
    for _k in range(_n):
        QUILLS.append((_lat, (_k * _step + (_li % 2) * _step / 2 + 11.0 * _li) % 360.0, _step * BALL['overlap']))


def quill_h(theta, phi):
    """The quills' height at (theta, phi): each a ridge with a crest line that rises steeply at its base and
    tapers to its tip (theta grows from base to tip) while drifting `swirl` degrees in latitude, overlapping the
    next like a curled hedgehog's quills."""
    best = 0.0
    W = BALL['width']
    for (lat, th0, L) in QUILLS:
        d = (theta - th0) % 360.0
        if d >= L:
            continue
        t = d / L
        c = lat + BALL['swirl'] * (t - 0.5)
        w = W * (1 - t) ** 0.7 + 0.5
        x = abs(phi - c) / w
        if x >= 1:
            continue
        h = BALL['quill'] * smoothstep(t / 0.1) * (1 - t) ** 1.1 * (1 - x) ** 1.6
        best = max(best, h)
    return best


def build_spinball():
    b = BALL
    cols, rows = b['cols'], b['rows']
    verts, faces, ring_idx = [], [], []
    verts.append(V(-b['r'], 0, 0))
    for j in range(1, rows):
        phi = -90.0 + 180.0 * j / rows
        ring = []
        for i in range(cols):
            theta = 360.0 * i / cols
            verts.append(ball_dir(theta, phi) * (b['r'] + quill_h(theta, phi)))
            ring.append(len(verts) - 1)
        ring_idx.append(ring)
    verts.append(V(b['r'], 0, 0))
    south, north = 0, len(verts) - 1
    for i in range(cols):
        i1 = (i + 1) % cols
        faces.append((south, ring_idx[0][i1], ring_idx[0][i]))
        faces.append((north, ring_idx[-1][i], ring_idx[-1][i1]))
    for j in range(len(ring_idx) - 1):
        a, c = ring_idx[j], ring_idx[j + 1]
        for i in range(cols):
            i1 = (i + 1) % cols
            faces.append((a[i], a[i1], c[i1], c[i]))
    G['EV_SpinBall'].add(verts, faces, closed=True)
    # The inner surface faces inward (seen through a transparent shell).
    iv, jf = ellipsoid((0, 0, 0), (b['inner'], b['inner'], b['inner']), 40, 20)
    G['EV_SpinBall'].add(iv, [tuple(reversed(f)) for f in jf])


# ----------------------------------------------------------------------------------------------
# 4. The cannon (modelled in Egg Mobile ship space, then moved so its origin is the mount point)
# ----------------------------------------------------------------------------------------------
CANNON = {'mountY': 1.95, 'saddlePhi': 26.0, 'saddleY': (1.24, 2.66), 'trunnion': (0.0, 1.80, -3.60), 'pitch': 20.0,
          'face': 2.36, 'bore': 0.848, 'boreBottom': 0.9, 'cheekX': (1.05, 1.3), 'spawnAhead': 1.7}


def hull_r(y):
    if y >= Y_CYL:
        return R_HULL - 0.13 * ((y - Y_CYL) / (RIM_TOP - Y_CYL)) ** 2
    t = min(1.0, (Y_CYL - y) / (Y_CYL - Y_BOT))
    return R_HULL * math.sqrt(max(0.0, 1 - t * t))


def hull_dr(y):
    e = 1e-4
    return (hull_r(y + e) - hull_r(y - e)) / (2 * e)


def surf(phi, y, out=0.0):
    """The Egg Mobile's black bowl at azimuth phi (degrees right of forward) and height y, `out` along its normal."""
    a = rad(phi)
    radial = V(math.sin(a), 0, -math.cos(a))
    n = (radial - V(0, 1, 0) * hull_dr(y)).normalized()
    return radial * hull_r(y) + V(0, y, 0) + n * out, n


def barrel_r(s):
    return 1.0 - 0.08 * max(0.0, min(1.0, (s - 0.45) / 1.35))


def cannon_frames():
    c = CANNON
    p = rad(c['pitch'])
    P = V(c['trunnion'])
    d = V(0, -math.sin(p), -math.cos(p))
    up = V(0, math.cos(p), -math.sin(p))
    mount = surf(0.0, c['mountY'])[0]
    return P, d, up, mount


def build_cannon():
    c = CANNON
    P, d, up, mount = cannon_frames()
    g = {k: Geo() for k in ('EV_Cannon', 'EV_CannonMetal', 'EV_CannonDark', 'EV_CannonStripe', 'EV_CannonGlow')}
    # The white barrel: the cascabel knob, the rounded breech (inside the bowl), the tube tapering to the muzzle.
    prof = [(0.0, -1.35), (0.12, -1.345), (0.19, -1.31), (0.2, -1.25), (0.17, -1.18), (0.12, -1.13), (0.12, -1.09),
            (0.42, -1.07), (0.62, -1.0), (0.8, -0.88), (0.92, -0.74), (0.98, -0.6), (1.0, -0.45)]
    for i in range(0, 13):
        s = -0.3 + (1.8 + 0.3) * i / 12
        prof.append((barrel_r(s), s))
    prof += [(0.95, 1.9), (0.99, 1.97), (0.99, 2.0), (0.86, 2.0)]
    g['EV_Cannon'].add(*lathe(prof, 48, P, d, up))
    # Grey: two bands, the muzzle ring (its face is the muzzle), the trunnion, the cheeks, the saddle plate.
    for (s0, s1) in ((0.2, 0.42), (1.1, 1.28)):
        rb0, rb1 = barrel_r(s0), barrel_r(s1)
        band = [(rb0 - 0.02, s0), (rb0 + 0.045, s0), (rb0 + 0.065, s0 + 0.02), (rb1 + 0.065, s1 - 0.02), (rb1 + 0.045, s1),
                (rb1 - 0.02, s1)]
        g['EV_CannonMetal'].add(*lathe(band, 48, P, d, up, closed_profile=True), closed=True)
    F = c['face']
    muzzle = [(c['bore'] - 0.003, 1.94), (0.96, 1.94), (1.06, 1.97), (1.12, 2.04), (1.13, 2.22), (1.1, F - 0.05),
              (1.03, F), (0.88, F), (c['bore'], F - 0.03)]
    g['EV_CannonMetal'].add(*lathe(muzzle, 48, P, d, up, closed_profile=True), closed=True)
    X = V(1, 0, 0)
    g['EV_CannonMetal'].add(*lathe([(0.0, -1.34), (0.26, -1.34), (0.26, 1.34), (0.0, 1.34)], 24, P, X, up), closed=True)
    for side in (-1, 1):
        g['EV_CannonDark'].add(*lathe([(0.0, 1.32), (0.33, 1.32), (0.35, 1.35), (0.35, 1.4), (0.31, 1.43), (0.0, 1.44)], 24, P,
                                      X * side, up), closed=True)
        xa, xb = c['cheekX']
        xm = side * (xa + xb) / 2
        pts = [(P.z + 0.58 * math.cos(TAU * k / 24), P.y + 0.58 * math.sin(TAU * k / 24)) for k in range(24)]
        for y in (1.3, 1.6, 1.95, 2.3, 2.58):
            z = -math.sqrt(max(0.0, hull_r(y) ** 2 - xm * xm)) + 0.12
            pts.append((z, y))
        poly = hull2d(pts)
        verts, faces = bevelled(*prism(poly, xa * side, xb * side), 0.035, 2)
        g['EV_CannonMetal'].add([V(p.z, p.y, p.x) for p in verts], faces, closed=True)
    y0, y1 = c['saddleY']
    ph = c['saddlePhi']

    def saddle(u, v, w):
        return surf(-ph + 2 * ph * u, y0 + (y1 - y0) * v, w)[0]
    g['EV_CannonMetal'].add(*patch(saddle, 16, 8, -0.02, 0.09), closed=True)
    for (u, v) in ((0.06, 0.1), (0.5, 0.06), (0.94, 0.1), (0.06, 0.9), (0.94, 0.9), (0.03, 0.5), (0.97, 0.5)):
        p, n = surf(-ph + 2 * ph * u, y0 + (y1 - y0) * v, 0.09)
        g['EV_CannonDark'].add(*dome(p, n, 0.06, 7))
    # The hazard band near the muzzle (yellow) with twelve black diagonal stripes.
    s0, s1 = 1.42, 1.8
    band = [(barrel_r(s0) - 0.02, s0), (barrel_r(s0) + 0.014, s0), (barrel_r(s0) + 0.022, s0 + 0.012),
            (barrel_r(s1) + 0.022, s1 - 0.012), (barrel_r(s1) + 0.014, s1), (barrel_r(s1) - 0.02, s1)]
    g['EV_CannonStripe'].add(*lathe(band, 48, P, d, up, closed_profile=True), closed=True)
    side_ax = d.cross(up)
    width = 0.45 * TAU / 12
    for k in range(12):
        a0 = TAU * k / 12

        def fn(u, v, w, a0=a0):
            s = s0 + 0.02 + (s1 - s0 - 0.04) * v
            a = a0 + width * u + (s - (s0 + s1) / 2) * 1.1
            rr = barrel_r(s) + 0.022 + w
            return P + d * s + (up * math.cos(a) + side_ax * math.sin(a)) * rr
        g['EV_CannonDark'].add(*patch(fn, 3, 4, -0.006, 0.01), closed=True)
    # The black bore (it faces the axis) and the cyan charge glow at its bottom.
    g['EV_CannonDark'].add(*lathe([(c['bore'], F - 0.015), (c['bore'], c['boreBottom']), (0.0, c['boreBottom'])], 48, P, d, up))
    g['EV_CannonGlow'].add(*lathe([(0.0, c['boreBottom'] + 0.005), (0.66, c['boreBottom'] + 0.005), (0.66, c['boreBottom'] + 0.05),
                                   (0.55, c['boreBottom'] + 0.09), (0.0, c['boreBottom'] + 0.1)], 40, P, d, up), closed=True)
    g['EV_CannonGlow'].add(*torus(P + d * (c['boreBottom'] + 0.03), d, up, 0.76, 0.035, 40, 6), closed=True)
    # Into cannon space: the mount point is the origin.
    for name, geo in g.items():
        G[name].add([p - mount for p in geo.v], geo.f)


def cannon_points():
    c = CANNON
    P, d, up, mount = cannon_frames()
    muzzle = P + d * c['face']
    spawn = P + d * (c['face'] + c['spawnAhead'])
    return {
        'mount': {
            'ship': r4(mount), 'hull': r4(mount - V(HULL_CENTER)),
            'azimuth': 0.0, 'onBowlAtY': c['mountY'],
            'placement': 'cannon:PivotTo(eggFloor * CFrame.new(mount.ship)) or EggHull.CFrame * CFrame.new(mount.hull); '
                         'no rotation: the cannon\'s axes are the ship\'s (its barrel already points %g degrees down)' % c['pitch'],
        },
        'muzzle': {
            'local': r4(muzzle - mount), 'ship': r4(muzzle), 'hull': r4(muzzle - V(HULL_CENTER)), 'direction': r4(d),
            'up': r4(up), 'boreRadius': c['bore'], 'boreDepth': round(c['face'] - c['boreBottom'], 4),
            'spawnLocal': r4(spawn - mount), 'spawnShip': r4(spawn), 'spawnHull': r4(spawn - V(HULL_CENTER)),
            'note': 'the muzzle face centre; a 3-stud bomb spawned at spawn* with its nose along direction clears the barrel',
        },
        'trunnion': {'local': r4(P - mount), 'ship': r4(P), 'hull': r4(P - V(HULL_CENTER))},
        'frames': 'ship = the Egg Mobile floor frame (its manifest ship space); hull = from EggMobile.HullCenter '
                  '(the EggHull part), same axes; local = from the cannon pivot (the mount point)',
        'pitchDegrees': c['pitch'],
        'fitTo': {'eggMobileKitVersion': EGG.get('kitVersion'), 'eggMobileRevision': EGG.get('revision'),
                  'hullBottom': Y_BOT, 'wallFrom': Y_CYL, 'hullRadius': R_HULL},
    }


def build_all():
    build_bomb()
    build_emerald()
    build_spinball()
    build_cannon()


# ----------------------------------------------------------------------------------------------
# Blender objects
# ----------------------------------------------------------------------------------------------
ROBLOX_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
    return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


def make_material(name, rgb, material, refl, glow_strength=3.0):
    m = bpy.data.materials.new(name + '_Mat')
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    col = lin(rgb)
    bsdf.inputs['Base Color'].default_value = col
    m.diffuse_color = col
    bsdf.inputs['Roughness'].default_value = 0.32
    if material == 'Glass':
        deep = tuple(c * 0.55 for c in col[:3]) + (1.0,)
        bsdf.inputs['Base Color'].default_value = deep
        bsdf.inputs['Roughness'].default_value = 0.02
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = 0.3
        for key, value in (('Coat Weight', 1.0), ('Coat Roughness', 0.0), ('Specular IOR Level', 1.0), ('IOR', 1.9)):
            try:
                bsdf.inputs[key].default_value = value
            except Exception:
                pass
    elif material == 'Neon':
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = glow_strength
    elif refl >= 0.2:
        bsdf.inputs['Metallic'].default_value = 0.55 if max(rgb) < 120 else 0.1
        bsdf.inputs['Roughness'].default_value = 0.2
        try:
            bsdf.inputs['Coat Weight'].default_value = 0.6
            bsdf.inputs['Coat Roughness'].default_value = 0.05
        except Exception:
            pass
    elif refl >= 0.1:
        bsdf.inputs['Metallic'].default_value = 0.25 if max(rgb) > 120 else 0.0
        bsdf.inputs['Roughness'].default_value = 0.2
        try:
            bsdf.inputs['Coat Weight'].default_value = 0.35
            bsdf.inputs['Coat Roughness'].default_value = 0.08
        except Exception:
            pass
    return m


def geo_to_object(name, geo, coll):
    spec = PIECE[name]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(ROBLOX_TO_BLENDER @ p) for p in geo.v], [], geo.f)
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
    uv = me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (co[a] * 0.1, co[b] * 0.1)
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    mat = make_material(name, spec[4], spec[5], spec[6])
    me.materials.append(mat)
    if spec[9] == 'flat':
        me.shade_flat()
        return ob
    me.shade_smooth()
    me.set_sharp_from_angle(angle=rad(spec[10]))
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
    tmp = Path(tempfile.mkdtemp(prefix='eventkit_'))
    assert str(tmp).isascii(), 'the temp folder must be ASCII: %s' % tmp
    # Blender embeds its current source filename in FBX metadata: save under ASCII before exporting.
    bpy.ops.wm.save_as_mainfile(filepath=str(tmp / 'EventKit_Source.blend'))
    (tmp / 'fbx').mkdir()
    (tmp / 'obj').mkdir()
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.01   # UnitScaleFactor 1 (cm): the Egg Mobile / Green Hill kit settings
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
    bpy.ops.export_scene.fbx(filepath=str(tmp / 'EventKit.fbx'), **fbx_kw)
    scene.unit_settings.scale_length = 1.0
    facts = {}
    for f in [tmp / 'EventKit.fbx'] + sorted((tmp / 'fbx').glob('*.fbx')):
        facts[f.name] = fbx_facts(f)
    for d in (OUT / 'fbx', OUT / 'obj'):
        for old in d.glob('EV_*.*'):
            old.unlink()
    for f in sorted((tmp / 'fbx').glob('*.fbx')):
        shutil.copy2(f, OUT / 'fbx' / f.name)
    for f in sorted((tmp / 'obj').glob('EV_*.*')):
        shutil.copy2(f, OUT / 'obj' / f.name)
    shutil.copy2(tmp / 'EventKit.fbx', OUT / 'EventKit.fbx')
    try:
        PUBLIC.mkdir(parents=True, exist_ok=True)
        (PUBLIC / 'fbx').mkdir(exist_ok=True)
        (PUBLIC / 'obj').mkdir(exist_ok=True)
        for d in (PUBLIC / 'fbx', PUBLIC / 'obj'):
            for old in d.glob('EV_*.*'):
                old.unlink()
        shutil.copy2(tmp / 'EventKit.fbx', PUBLIC / 'EventKit.fbx')
        for f in sorted((tmp / 'fbx').glob('*.fbx')):
            shutil.copy2(f, PUBLIC / 'fbx' / f.name)
        for f in sorted((tmp / 'obj').glob('EV_*.*')):
            shutil.copy2(f, PUBLIC / 'obj' / f.name)
    except Exception as e:  # the public copy is a convenience
        log('could not copy to', PUBLIC, e)
    assert tmp.resolve().parent == Path(tempfile.gettempdir()).resolve() and tmp.name.startswith('eventkit_')
    shutil.rmtree(tmp, ignore_errors=True)
    bad = {k: v for k, v in facts.items() if not (v['unitScaleFactor'] and abs(v['unitScaleFactor'] - 1.0) < 1e-6 and v['asciiOnly'])}
    assert not bad, bad
    return facts


def reimport_check(expect):
    """Import EventKit.fbx into an empty scene (cm units, as written): every piece comes back with its size and
    centre (Roblox axes). Runs last: it resets the Blender session."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(OUT / 'EventKit.fbx'))
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
def asset_block(table):
    def bounds(asset):
        names = [n for n in ORDER if PIECE[n][1] == asset]
        lo = [min(table[n]['min'][i] for n in names) for i in range(3)]
        hi = [max(table[n]['max'][i] for n in names) for i in range(3)]
        return names, lo, hi
    out = {}
    for asset in ASSETS:
        names, lo, hi = bounds(asset)
        primary = [n for n in names if PIECE[n][3]][0]
        out[asset] = {'pieces': names, 'primary': primary, 'boundsMin': lo, 'boundsMax': hi,
                      'size': [round(hi[i] - lo[i], 4) for i in range(3)], 'attachments': {}}
    b = out['Bomb']
    b.update({'origin': 'the bomb centre; it stands nose-down: nose toward -Y, tail +Y (turn -Y onto the flight)',
              'noseAxis': BOMB_NOSE_AXIS, 'length': b['size'][1], 'diameter': round(max(b['size'][0], b['size'][2]), 4)})
    b['attachments'] = {'Nose': {'position': [0.0, b['boundsMin'][1], 0.0], 'direction': [0.0, -1.0, 0.0]},
                        'Fuse': {'position': [0.0, 1.44, 0.0], 'direction': [0.0, 1.0, 0.0]}}
    e = out['ChaosEmerald']
    e.update({'origin': 'the gem\'s centre; the table up', 'height': e['size'][1],
              'diameter': round(max(e['size'][0], e['size'][2]), 4), 'facets': 'flat (split normals)',
              'variants': {k: list(v) for k, v in EMERALD_COLORS}, 'variantOrder': [k for k, _ in EMERALD_COLORS],
              'materials': ['Glass', 'Neon']})
    e['attachments'] = {'Center': {'position': [0.0, 0.0, 0.0], 'direction': [0.0, 0.0, -1.0]}}
    s = out['SpinBall']
    s.update({'origin': 'the ball\'s centre; rolling axis X (quills sweep round it)', 'outerRadius': BALL['r'],
              'innerRadius': BALL['inner'], 'quillHeight': BALL['quill'], 'diameter': round(max(s['size']), 4),
              'rootOffset': list(BALL['rootOffset']),
              'rootNote': 'an R6 HumanoidRootPart at ballCentre * CFrame.new(rootOffset) stands inside the inner shell',
              'colors': {k: list(v) for k, v in SPINBALL_COLORS}})
    s['attachments'] = {'Center': {'position': [0.0, 0.0, 0.0], 'direction': [0.0, 0.0, -1.0]},
                        'Root': {'position': list(BALL['rootOffset']), 'direction': [0.0, 0.0, -1.0]}}
    c = out['Cannon']
    pts = cannon_points()
    c.update({'origin': 'the MOUNT point on the Egg Mobile\'s black bowl (front, under the lamp); axes = the ship\'s'})
    c.update(pts)
    c['attachments'] = {'Mount': {'position': [0.0, 0.0, 0.0], 'direction': [0.0, 0.0, -1.0]},
                        'Muzzle': {'position': pts['muzzle']['local'], 'direction': pts['muzzle']['direction']},
                        'Spawn': {'position': pts['muzzle']['spawnLocal'], 'direction': pts['muzzle']['direction']}}
    return out


def write_manifest(table, facts):
    total = sum(r['tris'] for r in table.values())
    manifest = {
        'generator': 'audit/event_kit_bpy.py',
        'kitVersion': KIT_VERSION,
        'event': 'Super Sonic vs Dr. Eggman',
        'fbx': 'EventKit.fbx',
        'rbxm': 'design/event/supersonic/EventKit.rbxm (saved from Studio after Import 3D, IMPORTAR_EVENTO.md)',
        'publicCopy': str(PUBLIC).replace('\\', '/'),
        'units': '1 unit = 1 stud; FBX UnitScaleFactor 1.0 (cm), like EggMobileKit.fbx; axes -Z forward, Y up (Roblox axes)',
        'pivot': 'every piece: its asset\'s origin (Bomb / ChaosEmerald / SpinBall: the asset centre; Cannon: its mount '
                 'point); identity transforms, so an imported MeshPart\'s PivotOffset is -bboxCenterOffset (turned by the import)',
        'placement': 'part.CFrame = assetPivot * CFrame.new(bboxCenterOffset) * CFrame.Angles(0, -importTurn, 0); part.Size = size '
                     '(audit/u4_event_kit reads importTurn from the pivots with Shared/MeshKitImport, one turn for the whole kit)',
        'textures': 'none: every piece is one colour; audit/u4_event_kit sets Color / Material / Reflectance / Transparency from here',
        'meshesFolder': 'ReplicatedStorage.SuperSonicEventAssets.Meshes: Bomb (Model), ChaosEmerald (MeshPart), SpinBall (MeshPart), Cannon (Model)',
        'totalTris': total,
        'budgets': BUDGET,
        'fbxFacts': facts,
        'assets': asset_block(table),
        'pieces': [],
    }
    for name in ORDER:
        spec = PIECE[name]
        r = table[name]
        manifest['pieces'].append({
            'name': name, 'asset': spec[1], 'role': spec[2], 'primary': spec[3], 'size': r['size'],
            'bboxCenterOffset': r['center'], 'pivot': [0, 0, 0], 'color': list(spec[4]), 'material': spec[5],
            'reflectance': spec[6], 'transparency': spec[7], 'castShadow': spec[8], 'shading': spec[9],
            'tris': r['tris'], 'verts': r['verts'], 'renderVerts': r['renderVerts'],
        })
    return manifest


def fmt(v):
    return '(' + ', '.join('%.2f' % x for x in v) + ')'


def write_guide(manifest):
    """IMPORTAR_EVENTO.md: the owner's steps in Studio (Spanish), with this export's numbers."""
    pieces = {p['name']: p for p in manifest['pieces']}
    per = {a: sum(p['tris'] for p in manifest['pieces'] if p['asset'] == a) for a in ASSETS}
    biggest = max(manifest['pieces'], key=lambda p: p['tris'])
    names = ', '.join('`%s`' % n for n in ORDER)
    c = manifest['assets']['Cannon']
    text = '\n'.join([
        '# Evento Super Sonic vs Dr. Eggman: importar las mallas en Studio',
        '',
        'La bomba de Eggman, la Esmeralda del Caos, la bola de spin de Sonic y el cañón del Egg Mobile son ahora',
        '**%d mallas de Blender** de un solo color. Se importan **una sola vez**: el montaje las pone en' % len(ORDER),
        '`ReplicatedStorage.SuperSonicEventAssets.Meshes` de los tres mundos con su color y material. Mientras no',
        'estén, el evento usa sus formas simples.',
        '',
        'Vista previa (`preview/`): `kit_overview.png`, `bomb_standing.png`, `emeralds_ring.png`, `spinball_r6.png`,',
        '`cannon_on_eggmobile_front34.png` y una imagen por pieza (`piece_EV_*.png`).',
        '',
        '## Pasos',
        '',
        '1. En Studio, **File > Import 3D** y elige **`C:\\Users\\Public\\EventKit\\EventKit.fbx`** (es la misma que',
        '   `design/event/supersonic/EventKit.fbx`; usa la de `C:\\Users\\Public`, cuya ruta no tiene acentos).',
        '2. Ajustes del importador:',
        '   - **Scale Unit: Stud**',
        '   - **Merge Meshes: DESACTIVADO** (cada pieza, su MeshPart)',
        '   - **Upload to Roblox: ACTIVADO**',
        '   - World Forward / Up: los de por defecto. Si el kit sale girado, no pasa nada: el montaje lo endereza.',
        '3. Comprueba que hay **%d MeshParts**: %s.' % (len(ORDER), names),
        '   - Salen grises y unas encima de otras (cada objeto en su origen): es normal, el montaje las pinta y las separa.',
        '   - **Prueba de escala:** `EV_Bomb.Size` ≈ **%s** y `EV_SpinBall.Size` ≈ **%s**'
        % (fmt(pieces['EV_Bomb']['size']), fmt(pieces['EV_SpinBall']['size'])),
        '     (X y Z pueden salir intercambiadas). Si sale 100 veces más grande o más pequeño, borra y repite con la otra unidad.',
        '4. No cambies los nombres. Clic derecho en el Model importado, **Save to File…** y guárdalo como',
        '   **`Update2/design/event/supersonic/EventKit.rbxm`**.',
        '5. Avísanos. El siguiente montaje (`lune run audit/build_update4.luau`) llena `SuperSonicEventAssets.Meshes`',
        '   (Bomb, ChaosEmerald, SpinBall y Cannon) en los tres mundos.',
        '',
        '**Si el FBX falla:** prueba las piezas sueltas de `C:\\Users\\Public\\EventKit\\fbx\\` y, si alguna falla, su `.obj`',
        'de `design/event/supersonic/obj/`. Pásanos el texto del error (ventana Import 3D u Output).',
        '',
        '## Datos',
        '',
        '- %d triángulos en total (bomba %d, esmeralda %d, bola %d, cañón %d); la malla mayor, `%s`, tiene %d'
        % (manifest['totalTris'], per['Bomb'], per['ChaosEmerald'], per['SpinBall'], per['Cannon'], biggest['name'], biggest['tris']),
        '  (límite de Roblox: 20.000 triángulos y 10.000 vértices por malla).',
        '- 1 unidad = 1 stud. Cada pieza tiene el pivote en el origen de su objeto: la bomba, la esmeralda y la bola en su',
        '  centro (la bomba de pie, con la punta hacia abajo); el cañón en su punto de montaje sobre la esfera negra del',
        '  Egg Mobile, %s en el espacio del barco, apuntando %g° hacia abajo.' % (fmt(c['mount']['ship']), c['pitchDegrees']),
        '- Colores, materiales, los 7 colores de las esmeraldas, la boca del cañón y los puntos de enganche salen de',
        '  `event_manifest.json`.',
        '- Regenerar: `blender.exe -b --factory-startup --python audit/event_kit_bpy.py`',
        '',
    ])
    (OUT / 'IMPORTAR_EVENTO.md').write_text(text, encoding='utf-8', newline='\n')
    try:
        (PUBLIC / 'IMPORTAR_EVENTO.md').write_text(text, encoding='utf-8', newline='\n')
    except Exception:
        pass


def save_manifest(manifest):
    text = json.dumps(manifest, indent=1)
    (OUT / 'event_manifest.json').write_text(text)
    try:
        (PUBLIC / 'event_manifest.json').write_text(text)
    except Exception:
        pass


# ----------------------------------------------------------------------------------------------
# Renders
# ----------------------------------------------------------------------------------------------
def simple_mat(name, rgb, rough=0.4, metal=0.0, emit=0.0, alpha=1.0, method='BLENDED'):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = lin(rgb)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = lin(rgb)
        b.inputs['Emission Strength'].default_value = emit
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        try:
            m.surface_render_method = method
            m.use_transparency_overlap = method == 'BLENDED'
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


def setup_render(scene):
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except TypeError:
        scene.render.engine = 'BLENDER_EEVEE'
    ee = scene.eevee
    ee.taa_render_samples = 24 if QUICK else 80
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
        scene.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    scene.view_settings.exposure = 0.2
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new('CompositorNodeRLayers')
    comp = nt.nodes.new('CompositorNodeComposite')
    glare = nt.nodes.new('CompositorNodeGlare')
    for k, v in (('glare_type', 'BLOOM'), ('quality', 'HIGH'), ('threshold', 1.0), ('size', 7), ('mix', -0.5)):
        try:
            setattr(glare, k, v)
        except Exception:
            pass
    for k, v in (('Threshold', 1.0), ('Strength', 0.55), ('Size', 0.5)):
        if k in glare.inputs:
            try:
                glare.inputs[k].default_value = v
            except Exception:
                pass
    nt.links.new(rl.outputs['Image'], glare.inputs['Image'])
    nt.links.new(glare.outputs['Image'], comp.inputs['Image'])


def world_gradient(scene, top, bottom, strength=1.0):
    w = bpy.data.worlds.get('EV_World') or bpy.data.worlds.new('EV_World')
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
    cr.elements[0].position = 0.35
    cr.elements[0].color = bottom + (1,)
    cr.elements[1].position = 0.75
    cr.elements[1].color = top + (1,)
    bg.inputs['Strength'].default_value = strength
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])


RENDER_TMP = Path(tempfile.gettempdir()) / 'eventkit_renders'


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
    """A stand-in R6 (for scale only): torso 2x2x1, arms / legs 1x2x1, a 1.25 head, its root at `root`."""
    blue = simple_mat('SI_Blue', (40, 90, 220), 0.45)
    skin = simple_mat('SI_Skin', (240, 200, 160), 0.5)
    grey = simple_mat('SI_Grey', (200, 205, 215), 0.5)
    red = simple_mat('SI_Red', (215, 40, 40), 0.4)
    r = V(root)
    obs = [add_mesh('SI_Torso', *rbox(r, (2.0, 2.0, 1.0), 0.08, 2), blue, coll),
           add_mesh('SI_Head', *rbox(r + V(0, 1.62, 0), (1.25, 1.25, 1.25), 0.4, 3), blue, coll),
           add_mesh('SI_Face', *rbox(r + V(0, 1.5, -0.45), (0.9, 0.7, 0.4), 0.18, 2), skin, coll)]
    for sx in (-1, 1):
        obs.append(add_mesh('SI_Arm%d' % sx, *rbox(r + V(sx * 1.5, 0, 0), (1.0, 2.0, 1.0), 0.08, 2), skin, coll))
        obs.append(add_mesh('SI_Leg%d' % sx, *rbox(r + V(sx * 0.5, -2.0, 0), (1.0, 2.0, 1.0), 0.08, 2), grey, coll))
        obs.append(add_mesh('SI_Shoe%d' % sx, *rbox(r + V(sx * 0.5, -2.75, -0.1), (1.04, 0.5, 1.2), 0.15, 2), red, coll))
    return obs


def import_egg_mobile(coll):
    """design/npc/eggmobile/EggMobileKit.fbx, coloured from its manifest (preview only)."""
    scene = bpy.context.scene
    before = set(bpy.data.objects)
    scene.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(EGG_FBX))
    scene.unit_settings.scale_length = 1.0
    new = [o for o in bpy.data.objects if o not in before]
    spec = {p['name']: p for p in EGG['pieces']}
    for ob in new:
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        coll.objects.link(ob)
        if ob.type != 'MESH':
            continue
        key = ob.name.split('.')[0]
        p = spec.get(key)
        if not p:
            continue
        if p['material'] == 'Glass':
            m = simple_mat('EGG_' + key, p['color'], 0.03, 0.0, alpha=0.18)
        elif p['material'] == 'Neon':
            m = simple_mat('EGG_' + key, p['color'], 0.3, 0.0, emit=2.5)
        else:
            m = make_material('EGG_' + key, p['color'], p['material'], p['reflectance'])
        ob.data.materials.clear()
        ob.data.materials.append(m)
    bpy.context.view_layer.update()
    hull = next((o for o in new if o.name.startswith('EM_HullWhite')), None)
    if hull:
        lo, hi = roblox_bbox(hull)
        log('Egg Mobile imported: EM_HullWhite', r4(hi - lo), 'centre', r4((lo + hi) / 2))
    return new


def renders(scene, objs, manifest):
    setup_render(scene)
    q = 0.5 if QUICK else 1.0
    kit = bpy.data.collections['EventKit']
    stage = bpy.data.collections.new('Stage')
    scene.collection.children.link(stage)
    floor_mat = simple_mat('Floor', (104, 110, 122), rough=0.75)
    floor = add_mesh('Floor', [(-300, 0, -300), (300, 0, -300), (300, 0, 300), (-300, 0, 300)], [(0, 1, 2, 3)], floor_mat, stage, False)
    lights = []
    for name, power, size in (('Key', 900, 6), ('Fill', 500, 8), ('Rim', 1100, 5)):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy = power
        ld.shape = 'DISK'
        ld.size = size
        ob = bpy.data.objects.new(name, ld)
        stage.objects.link(ob)
        lights.append(ob)

    def light_rig(target, dist):
        k = dist / 10.0
        for ob, (az, el, dd), e in zip(lights, ((-45, 45, 1.0), (60, 20, 1.1), (160, 40, 1.0)), (900, 450, 1000)):
            aim(ob, orbit(az, el, dist * dd, target), target)
            ob.data.energy = e * k * k
            ob.data.size = 6 * k
    world_gradient(scene, (0.30, 0.33, 0.38), (0.11, 0.12, 0.14), 0.9)
    # 1. Each piece alone.
    for ob in objs.values():
        ob.hide_render = True
    for name in ORDER:
        ob = objs[name]
        ob.hide_render = False
        lo, hi = roblox_bbox(ob)
        ctr, dims = (lo + hi) / 2, hi - lo
        size = max(dims)
        floor.location.z = lo.y - 0.001
        light_rig(ctr, size * 3.2)
        cam = add_camera('Cam_' + name, orbit(-38, 22, size * 2.7, ctr), ctr, 50, stage)
        render_view(scene, cam, PREV / ('piece_%s.png' % name), int(900 * q), int(900 * q))
        ob.hide_render = True
    kit.hide_render = True
    floor.location.z = 0.0
    hero = bpy.data.collections.new('Hero')
    scene.collection.children.link(hero)
    bomb_names = manifest['assets']['Bomb']['pieces']
    cannon_names = manifest['assets']['Cannon']['pieces']

    def solo(on):
        for ob in hero.objects:
            ob.hide_render = ob not in on

    # 2. The bomb: resting on its fins at a 3/4 view, and a side view in flight.
    tilt = Matrix.Rotation(math.pi, 3, 'X')                                     # nose up, standing on its fuse cap
    bombs = []
    for n in bomb_names:
        bombs.append(instance(objs[n], hero, (0, 1.5, 0), tilt, name=n + '_Up'))
    flight = Matrix.Rotation(rad(-78), 3, 'Z')                                  # nose toward -X, dipping 12 degrees
    bombs2 = [instance(objs[n], hero, (0, 1.4, 0), flight, name=n + '_Fly') for n in bomb_names]
    solo(bombs)
    light_rig((0, 1.5, 0), 8)
    cam = add_camera('Cam_bomb', orbit(-35, 14, 7.5, (0, 1.55, 0)), (0, 1.55, 0), 50, hero)
    render_view(scene, cam, PREV / 'bomb_standing.png', int(1200 * q), int(1200 * q))
    solo(bombs2)
    cam = add_camera('Cam_bomb_side', orbit(-15, 8, 7.0, (0, 1.4, 0)), (0, 1.4, 0), 50, hero)
    render_view(scene, cam, PREV / 'bomb_flight.png', int(1600 * q), int(1000 * q))
    # 3. The seven emeralds in a ring.
    gems = []
    for i, (key, rgb) in enumerate(EMERALD_COLORS):
        a = TAU * i / len(EMERALD_COLORS)
        m = make_material('Gem_' + key, rgb, 'Glass', 0.25)
        gems.append(instance(objs['EV_ChaosEmerald'], hero, (2.3 * math.sin(a), 1.25 + 0.12 * math.sin(3 * a), -2.3 * math.cos(a)),
                             Matrix.Rotation(-a + rad(10), 3, 'Y'), m, 'Gem_' + key))
    solo(gems)
    floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = lin((34, 38, 52))
    scene.view_settings.look = 'AgX - Punchy'
    light_rig((0, 1.2, 0), 9)
    cam = add_camera('Cam_emeralds', orbit(0, 32, 9.5, (0, 0.9, 0)), (0, 0.9, 0), 45, hero)
    render_view(scene, cam, PREV / 'emeralds_ring.png', int(1600 * q), int(1100 * q))
    scene.view_settings.look = 'AgX - Medium High Contrast'
    floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = lin((104, 110, 122))
    # 4. The spin ball round a stand-in R6 (blue, translucent), and the gold one beside it.
    centre = V(0, 3.4, 0)
    rig = stand_in_r6(hero, centre + V(BALL['rootOffset']))
    blue = simple_mat('Ball_Blue', SPINBALL_COLORS[0][1], 0.12, 0.0, emit=0.2, alpha=0.5, method='DITHERED')
    gold = simple_mat('Ball_Gold', SPINBALL_COLORS[1][1], 0.12, 0.6, emit=0.5)
    balls = [instance(objs['EV_SpinBall'], hero, centre, None, blue, 'Ball_Blue'),
             instance(objs['EV_SpinBall'], hero, centre + V(7.6, 0, 1.5), Matrix.Rotation(rad(35), 3, 'X'), gold, 'Ball_Gold')]
    solo(rig + balls)
    light_rig((3.5, 3.2, 0.5), 22)
    cam = add_camera('Cam_ball', orbit(-18, 12, 20, (3.6, 3.1, 0.6)), (3.6, 3.1, 0.6), 50, hero)
    render_view(scene, cam, PREV / 'spinball_r6.png', int(1600 * q), int(1000 * q))
    # 5. The cannon on the Egg Mobile (its FBX), a bomb leaving the muzzle; front 3/4 and side.
    egg = bpy.data.collections.new('EggMobile')
    scene.collection.children.link(egg)
    ship = import_egg_mobile(egg)
    cpts = manifest['assets']['Cannon']
    mount = V(cpts['mount']['ship'])
    cannon = [instance(objs[n], hero, mount, None, name=n + '_OnShip') for n in cannon_names]
    d = V(cpts['muzzle']['direction'])
    pitch = math.asin(-d.y)
    fired = [instance(objs[n], hero, V(cpts['muzzle']['spawnShip']) + d * 1.4, Matrix.Rotation(math.pi / 2 - pitch, 3, 'X'),
                      name=n + '_Fired')
             for n in bomb_names]
    solo(cannon + fired)
    egg.hide_render = False
    floor.location.z = -3.0
    light_rig((0, 3.0, -2.0), 20)
    for key, az, el, dist, tgt in (('front34', -38, 10, 21, (0, 2.6, -2.6)), ('side', -90, 4, 21, (0, 2.5, -2.6)),
                                   ('under', -20, -8, 15, (0, 2.2, -3.2))):
        cam = add_camera('Cam_ship_' + key, orbit(az, el, dist, tgt), tgt, 45, hero)
        floor.hide_render = key == 'under'
        render_view(scene, cam, PREV / ('cannon_on_eggmobile_%s.png' % key), int(1600 * q), int(1100 * q))
    floor.hide_render = False
    floor.location.z = 0.0
    solo(cannon)
    light_rig((0, 1.6, -4.5), 9)
    tgt = (0.0, 1.7, -4.4)
    cam = add_camera('Cam_cannon_close', orbit(-40, 14, 8.5, tgt), tgt, 45, hero)
    render_view(scene, cam, PREV / 'cannon_closeup.png', int(1400 * q), int(1000 * q))
    egg.hide_render = True
    # 6. The whole kit side by side at true scale.
    row = []
    for n in bomb_names:
        row.append(instance(objs[n], hero, (-3.2, 1.3, 0), Matrix.Rotation(rad(-90), 3, 'Z'), name=n + '_Row'))
    m = make_material('Gem_Row', EMERALD_COLORS[0][1], 'Glass', 0.25)
    row.append(instance(objs['EV_ChaosEmerald'], hero, (-0.4, 0.95, 0), Matrix.Rotation(rad(12), 3, 'Y'), m, 'Gem_Row'))
    row.append(instance(objs['EV_SpinBall'], hero, (4.4, 3.2, 0.5), None, simple_mat('Ball_Row', SPINBALL_COLORS[0][1], 0.2, 0.0, 0.15), 'Ball_Row'))
    for n in cannon_names:
        row.append(instance(objs[n], hero, V(-8.2, 1.25, 0) - V(cpts['trunnion']['local']) + V(0, 1.2, 0), Matrix.Rotation(rad(-30), 3, 'Y'),
                            name=n + '_Row'))
    solo(row)
    light_rig((-1.5, 2.2, 0), 22)
    cam = add_camera('Cam_kit', orbit(-12, 14, 23, (-1.8, 2.0, 0)), (-1.8, 2.0, 0), 45, hero)
    render_view(scene, cam, PREV / 'kit_overview.png', int(1800 * q), int(900 * q))
    return ship


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    build_all()
    coll = bpy.data.collections.new('EventKit')
    scene.collection.children.link(coll)
    objs = {}
    for name in ORDER:
        assert G[name].f, 'empty piece ' + name
        objs[name] = geo_to_object(name, G[name], coll)
    bpy.context.view_layer.update()
    table = {name: validate(objs[name]) for name in ORDER}
    print('%-16s %-12s %6s %6s %7s %-24s %-24s %s' % ('piece', 'asset', 'tris', 'verts', 'rVerts', 'size X x Y x Z', 'centre', 'result'))
    per_asset = {a: 0 for a in ASSETS}
    for name in ORDER:
        r = table[name]
        per_asset[PIECE[name][1]] += r['tris']
        print('%-16s %-12s %6d %6d %7d %-24s %-24s %s' % (name, PIECE[name][1], r['tris'], r['verts'], r['renderVerts'],
              'x'.join('%.3f' % v for v in r['size']), ','.join('%.3f' % v for v in r['center']),
              'OK' if r['ok'] else 'FAIL ' + ','.join(r['errors'])), flush=True)
    log('TRIS per asset', per_asset, 'total', sum(per_asset.values()))
    failed = [(n, r['errors']) for n, r in table.items() if not r['ok']]
    assert not failed, failed
    over = {a: t for a, t in per_asset.items() if t > BUDGET[a]}
    assert not over, over
    facts = export_all(scene, objs)
    log('FBX written', {k: (v['unitScaleFactor'], v['asciiOnly']) for k, v in list(facts.items())[:2]})
    manifest = write_manifest(table, facts)
    bpy.context.preferences.filepaths.save_version = 0   # no EventKit.blend1 backups
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'EventKit.blend'))
    if not NO_RENDER:
        renders(scene, objs, manifest)
    worst, missing, extra = reimport_check({n: table[n] for n in ORDER})
    log('re-import: worst size / centre error %.5f studs, missing %s, extra %s' % (worst, missing, extra))
    manifest['reimportCheck'] = {'worstErrorStuds': round(worst, 5), 'missing': missing, 'extra': extra}
    save_manifest(manifest)
    write_guide(manifest)
    log('manifest and IMPORTAR_EVENTO.md written')
    assert worst < 0.01 and not missing, (worst, missing)
    log('done')


if __name__ == '__main__':
    main()
