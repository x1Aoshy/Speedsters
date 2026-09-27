"""The Flash's race-gate arch kit (Blender 4.5, headless, deterministic).

2026-09-26 (owner): the part-built arch (RaceArenaBuilder.BuildGate v2) was rejected; this models the
reference (design/race/flashgate/reference/flash_gate_reference.jpg) as smooth, bevelled meshes: a
big red arch with a rounded profile, a gold band set into both faces that stops short of the top, a
red lip under the medallion, a glossy gold medallion with a cream face and a crisp raised lightning
bolt (gold edge + Neon core), and the sign-up pad's dark disc with its cyan / gold Neon rings.

Run (from anywhere; paths come from this file):
  blender.exe -b --factory-startup --python audit/flash_gate_bpy.py -- [--quick] [--no-render]

Writes design/race/flashgate/:
  FlashGateKit.fbx              every piece, one object FG_<Name> each (the file the owner imports)
  fbx/FG_<Name>.fbx, obj/FG_<Name>.obj (+ .mtl)   one file per piece (fallbacks)
  flashgate_manifest.json       per piece: size, bboxCenterOffset (pivot), colour, material, flags, tris
  preview/*.png                 Eevee renders (compare_front.png = the reference | ours) + a .blend
and copies the FBX files to C:/Users/Public/FlashGateKit/ (an ASCII path for Studio's importer), and
rewrites the "GENERATED FlashGateKit" block of src/common/ReplicatedStorage/Shared/FlashGate.luau
(FlashGate.Kit: what RaceArenaBuilder.BuildGate reads at run time).

Frames:
  Blender (bx, by, bz) <-> Roblox gate frame (x, y, z) = (bx, bz, -by); FBX export: -Z forward, Y up.
  Gate frame (RaceArenaBuilder.GateCFrame): x = the gate's right, y up from the floor, -z toward the
  players (Blender +Y). The viewer facing the gate has the gate's -x on his right.
  Pivot of EVERY piece: the gate origin, the floor point under the arch's centre; identity transforms,
  so an imported MeshPart's PivotOffset is -bboxCenterOffset (turned by whatever turn Studio applies:
  RaceArenaBuilder undoes it, Shared/MeshKitImport).
  Placement: part.CFrame = gateCFrame * CFrame.new(bboxCenterOffset) * yaw(-importTurn); Size = size.
"""
import bpy, bmesh, math, json, sys, time, shutil, os, re, tempfile
from pathlib import Path
from mathutils import Vector, geometry
import numpy as np

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
QUICK = '--quick' in ARGS
NO_RENDER = '--no-render' in ARGS

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
OUT = ROOT / 'design' / 'race' / 'flashgate'
PREV = OUT / 'preview'
REF = OUT / 'reference' / 'flash_gate_reference.jpg'
PUBLIC = Path('C:/Users/Public/FlashGateKit')
FLASHGATE_LUAU = ROOT / 'src' / 'common' / 'ReplicatedStorage' / 'Shared' / 'FlashGate.luau'
BLOCK_BEGIN = '-- BEGIN GENERATED FlashGateKit'
BLOCK_END = '-- END GENERATED FlashGateKit'
for p in (OUT, PREV, OUT / 'fbx', OUT / 'obj'):
    p.mkdir(parents=True, exist_ok=True)
T0 = time.time()


def log(*a):
    print('[flashgate %6.1fs]' % (time.time() - T0), *a, flush=True)


# ------------------------------------------------------------------------------------------------
# Numbers. The arch keeps FlashGate.Arch's footprint (the manifest's "gate" block repeats these and
# audit/test_u4_flash_gate checks them against the Luau): 25 wide, 13.5 tall, opening 18.6.
# ------------------------------------------------------------------------------------------------
INNER, OUTER, DEPTH, LEG = 9.3, 12.5, 2.6, 1.0
MID = (INNER + OUTER) / 2               # 10.9: the arch's centre line (a half circle centred LEG up)
BAND_IN, BAND_OUT = 10.3, 11.5
# The medallion after the reference's proportions (its diameter ~1.2 x the arch's thickness, 1.2
# under the arch's top, the bolt reaching past it top and bottom): smaller than the part-built one.
MED_Y = 12.3                            # the medallion's centre
RIM = 1.95                              # its outer radius
RIM_IN = 1.5                            # the rim's inner radius (the cream face shows inside)
GLOW = 2.25                             # MedallionGlow (a Neon Part the client breathes) peeks out to here
GLOW_DEPTH = 1.2                        # inside the rim (3.3): only the ring past the rim glows
PAD_R = 6.6                             # FlashGate.Pad.Radius
LEG_SPLIT = math.radians(20.0)          # FG_LegL / FG_LegR (they collide) end here; FG_ArchRed goes on
BAND_TIP = math.radians(75.0)           # the band's rounded end reaches this angle (0.95 short of the rim)
ARC_STEP = math.radians(2.5)            # sweep sampling along the arch (silhouette error < 0.004 stud)
YAX = Vector((0.0, 1.0, 0.0))           # the arch's depth axis (Blender +Y = toward the players)
BUDGET_TOTAL = 25000
ROBLOX_MAX_TRIS = 20000
ROBLOX_MAX_VERTS = 10000

# Colours (Roblox RGB, sRGB): picked from the reference for the arch (a deeper crimson, a richer
# gold, a warm cream face); the Neon ones and the pad are FlashGate.Colors'. Materials are Roblox's.
COLORS = {
    'Red': (210, 28, 46), 'Gold': (234, 178, 52), 'Cream': (255, 240, 200), 'Bolt': (255, 205, 40),
    'Cyan': (0, 225, 255), 'PadDark': (16, 26, 48), 'GoldGlow': (255, 214, 70), 'NeonGold': (255, 193, 37),
}
# name, group (the Model it goes in), colour, Roblox material, reflectance, castShadow, canCollide, what it is
PIECES = [
    ('FG_ArchRed', 'Arch', 'Red', 'SmoothPlastic', 0.0, True, False, 'the red arch from 20 to 160 degrees, with the raised lip under the medallion'),
    ('FG_LegL', 'Arch', 'Red', 'SmoothPlastic', 0.0, True, True, "the arch's foot on the gate's left (-x, the viewer's right): floor to 20 degrees; collides"),
    ('FG_LegR', 'Arch', 'Red', 'SmoothPlastic', 0.0, True, True, "the arch's foot on the gate's right (+x, the viewer's left): floor to 20 degrees; collides"),
    ('FG_BandGold', 'Arch', 'Gold', 'SmoothPlastic', 0.2, True, False, 'the gold band set into both faces, floor to its rounded ends short of the medallion'),
    ('FG_MedallionRim', 'Medallion', 'Gold', 'SmoothPlastic', 0.25, True, False, "the medallion's glossy gold rim"),
    ('FG_MedallionFace', 'Medallion', 'Cream', 'SmoothPlastic', 0.05, True, False, "the medallion's cream face, gently domed on both sides"),
    ('FG_BoltEdge', 'Medallion', 'Gold', 'SmoothPlastic', 0.25, False, False, "the bolt's raised gold edge: a plate on the front (its tips past the rim) and a smaller one on the back"),
    ('FG_Bolt', 'Medallion', 'Bolt', 'Neon', 0.0, False, False, "the bolt's glowing core, inset 0.09 and 0.08 higher than its gold edge (both faces)"),
    ('FG_PadDisc', 'RingPad', 'PadDark', 'SmoothPlastic', 0.1, False, False, "the sign-up pad's dark disc with a rounded edge"),
    ('FG_PadRingCyan', 'RingPad', 'Cyan', 'Neon', 0.0, False, False, 'the outer and inner cyan rings'),
    ('FG_PadRingGold', 'RingPad', 'NeonGold', 'Neon', 0.0, False, False, 'the middle gold ring'),
]
ORDER = [p[0] for p in PIECES]


# ------------------------------------------------------------------------------------------------
# Mesh building: analytic positions and normals (custom split normals, so the smooth shading is
# exact and two pieces meeting on a ring, FG_LegR / FG_ArchRed, show no seam), triangles only.
# ------------------------------------------------------------------------------------------------
class MB:
    def __init__(self, name):
        self.name = name
        self.co, self.no, self.faces, self.uvs = [], [], [], []

    def v(self, co, no):
        self.co.append(Vector(co))
        n = Vector(no)
        self.no.append(n.normalized() if n.length > 1e-12 else Vector((0.0, 0.0, 1.0)))
        return len(self.co) - 1

    def tri(self, a, b, c, ta, tb, tc):
        if a == b or b == c or a == c:
            return
        pa, pb, pc = self.co[a], self.co[b], self.co[c]
        g = (pb - pa).cross(pc - pa)
        if g.length < 1e-9:
            return
        if g.dot(self.no[a] + self.no[b] + self.no[c]) < 0:  # outward winding from the analytic normals
            b, c, tb, tc = c, b, tc, tb
        self.faces.append((a, b, c))
        self.uvs.append((ta, tb, tc))

    def quad(self, a, b, c, d, ta, tb, tc, td):
        if (self.co[a] - self.co[c]).length <= (self.co[b] - self.co[d]).length:
            self.tri(a, b, c, ta, tb, tc)
            self.tri(a, c, d, ta, tc, td)
        else:
            self.tri(a, b, d, ta, tb, td)
            self.tri(b, c, d, tb, tc, td)

    def finish(self, mat, coll):
        used = sorted({i for f in self.faces for i in f})
        remap = {old: new for new, old in enumerate(used)}
        co = [tuple(self.co[i]) for i in used]
        no = [tuple(self.no[i]) for i in used]
        faces = [tuple(remap[i] for i in f) for f in self.faces]
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(co, [], faces)
        me.update()
        uvl = me.uv_layers.new(name='UVMap')
        for poly, t in zip(me.polygons, self.uvs):
            for li, uv in zip(poly.loop_indices, t):
                uvl.data[li].uv = uv
        for poly in me.polygons:
            poly.use_smooth = True
        me.normals_split_custom_set_from_vertices(no)
        me.materials.append(mat)
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        return ob


def rrect(a, b, rho, k, centres=False, dr=0.0):
    """A closed rounded rectangle, CCW in (r, d): half extents a (radial) x b (depth), corner radius
    rho, k segments a corner; centres adds (0, +-b) (the poles of a rounded end). dr shifts r."""
    assert rho < a and rho < b
    pts = []
    for i, (sr, sd, a0) in enumerate(((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270))):
        cr, cd = sr * (a - rho), sd * (b - rho)
        for j in range(k + 1):
            t = math.radians(a0 + 90.0 * j / k)
            pts.append((dr + cr + rho * math.cos(t), cd + rho * math.sin(t), math.cos(t), math.sin(t)))
        if centres and i == 0:
            pts.append((dr, b, 0.0, 1.0))
        if centres and i == 2:
            pts.append((dr, -b, 0.0, -1.0))
    return pts


# Stations along the arch plane (Blender XZ): (P, n radial, T tangent, s arc length).
def arc_station(R, theta):
    n = Vector((math.cos(theta), 0.0, math.sin(theta)))
    return (Vector((0.0, 0.0, LEG)) + n * R, n, Vector((-math.sin(theta), 0.0, math.cos(theta))))


def arc_stations(R, t0, t1):
    count = max(1, math.ceil(abs(t1 - t0) / ARC_STEP - 1e-9))
    return [arc_station(R, t0 + (t1 - t0) * i / count) for i in range(count + 1)]


def leg_stations(R, side, up):
    """The straight foot from the floor to LEG on side +1 (+x) / -1; up = the sweep runs upward."""
    n = Vector((float(side), 0.0, 0.0))
    pts = [(Vector((side * R, 0.0, z)), n, Vector((0.0, 0.0, 1.0 if up else -1.0))) for z in (0.0, LEG)]
    return pts if up else pts[::-1]


def join(*lists):
    out = []
    for lst in lists:
        for st in lst:
            if out and (out[-1][0] - st[0]).length < 1e-9:
                continue
            out.append(st)
    return out


def sweep(mb, stations, prof, start=None, end=None, uscale=0.1, cap_steps=12):
    """Sweeps the (r along n, d along YAX) profile; start / end = None, 'flat' or 'round'."""
    m = len(prof)
    rings, s = [], 0.0
    for k, (P, n, T) in enumerate(stations):
        if k:
            s += (P - stations[k - 1][0]).length
        rings.append(([mb.v(P + n * r + YAX * d, n * nr + YAX * nd) for (r, d, nr, nd) in prof], s))
    for k in range(len(rings) - 1):
        (ra, sa), (rb, sb) = rings[k], rings[k + 1]
        for j in range(m):
            j2 = (j + 1) % m
            va, vb = j / m, (j + 1) / m
            mb.quad(ra[j], ra[j2], rb[j2], rb[j], (sa * uscale, va), (sa * uscale, vb), (sb * uscale, vb), (sb * uscale, va))
    if start:
        cap(mb, stations[0], rings[0][0], prof, start, True, cap_steps)
    if end:
        cap(mb, stations[-1], rings[-1][0], prof, end, False, cap_steps)


def cap(mb, station, ring, prof, kind, backwards, steps):
    P, n, T = station
    out = -T if backwards else T
    m = len(prof)
    if kind == 'flat':
        c = mb.v(P, out)
        idx = [mb.v(mb.co[i], out) for i in ring]
        for j in range(m):
            a, b = idx[j], idx[(j + 1) % m]
            mb.tri(c, a, b, (0.5, 0.5), (0.5 + 0.5 * math.cos(2 * math.pi * j / m), 0.5 + 0.5 * math.sin(2 * math.pi * j / m)),
                   (0.5 + 0.5 * math.cos(2 * math.pi * (j + 1) / m), 0.5 + 0.5 * math.sin(2 * math.pi * (j + 1) / m)))
        return
    # 'round': the right half of the profile (r >= 0, from the bottom pole to the top pole) turned
    # half a turn about the depth axis through P, from +n through `out` to -n: a stadium end with
    # the profile's own bevel all round, exact normals.
    top = next(i for i, p in enumerate(prof) if p[2] == 0.0 and p[3] > 0)  # the poles rrect(centres=True) adds
    bot = next(i for i, p in enumerate(prof) if p[2] == 0.0 and p[3] < 0)
    half, i = [], bot
    while True:
        half.append(i)
        if i == top:
            break
        i = (i + 1) % m
    r0 = prof[top][0]  # the profile's centre line (dr)
    mirror = {}
    for i in half:
        r, d = prof[i][0] - r0, prof[i][1]
        mirror[i] = min(range(m), key=lambda q: ((prof[q][0] - r0) + r) ** 2 + (prof[q][1] - d) ** 2)
    grid = []
    for a in range(steps + 1):
        alpha = math.pi * a / steps
        u = n * math.cos(alpha) + out * math.sin(alpha)
        row = []
        for i in half:
            r, d, nr, nd = prof[i]
            r -= r0
            if abs(r) < 1e-9 or a == 0:
                row.append(ring[i])
            elif a == steps:
                row.append(ring[mirror[i]])
            else:
                row.append(mb.v(P + n * r0 + u * r + YAX * d, u * nr + YAX * nd))
        grid.append(row)
    for a in range(steps):
        for h in range(len(half) - 1):
            mb.quad(grid[a][h], grid[a][h + 1], grid[a + 1][h + 1], grid[a + 1][h],
                    (a / steps, h / len(half)), (a / steps, (h + 1) / len(half)),
                    ((a + 1) / steps, (h + 1) / len(half)), ((a + 1) / steps, h / len(half)))


def lathe(mb, centre, axis, e1, e2, prof, segs, closed):
    """Turns the (rho from the axis, d along it) profile about `axis`; rho = 0 points are poles."""
    centre, axis, e1, e2 = Vector(centre), Vector(axis), Vector(e1), Vector(e2)
    poles = {i: mb.v(centre + axis * p[1], axis * (1.0 if p[3] >= 0 else -1.0))
             for i, p in enumerate(prof) if p[0] < 1e-9}
    cols = []
    for s in range(segs):
        phi = 2 * math.pi * s / segs
        u = e1 * math.cos(phi) + e2 * math.sin(phi)
        cols.append([poles[i] if i in poles else mb.v(centre + u * p[0] + axis * p[1], u * p[2] + axis * p[3])
                     for i, p in enumerate(prof)])
    m = len(prof)
    rows = m if closed else m - 1
    for s in range(segs):
        s2 = (s + 1) % segs
        ua, ub = s / segs, (s + 1) / segs
        for i in range(rows):
            i2 = (i + 1) % m
            va, vb = i / m, (i + 1) / m
            mb.quad(cols[s][i], cols[s2][i], cols[s2][i2], cols[s][i2], (ua, va), (ub, va), (ub, vb), (ua, vb))


# ------------------------------------------------------------------------------------------------
# Pieces
# ------------------------------------------------------------------------------------------------
ARCH_PROF = rrect(OUTER - MID, DEPTH / 2, 0.62, 7)                     # 3.2 x 2.6, rounded 0.62
BAND_PROF = rrect((BAND_OUT - BAND_IN) / 2, 1.52, 0.32, 5, centres=True)  # 1.2 x 3.04: 0.22 proud of each face
LIP_R, LIP_A = 9.9, 0.38                                              # the red lip under the medallion
LIP_PROF = rrect(LIP_A, 1.5, 0.28, 4, centres=True)
LIP_FROM, LIP_TO = math.radians(55.0), math.radians(125.0)


def build_arch(mats, coll):
    obs = {}
    # FG_ArchRed: 20..160 degrees (+ the lip). FG_LegR / FG_LegL: the feet, floor to 20 degrees; they
    # share the split rings' positions and normals with FG_ArchRed, so the seam does not show.
    mb = MB('FG_ArchRed')
    sweep(mb, arc_stations(MID, LEG_SPLIT, math.pi - LEG_SPLIT), ARCH_PROF)
    sweep(mb, arc_stations(LIP_R, LIP_FROM, LIP_TO), LIP_PROF, start='round', end='round')
    obs['FG_ArchRed'] = mb.finish(mats['Red'], coll)
    mb = MB('FG_LegR')
    sweep(mb, join(leg_stations(MID, 1, True), arc_stations(MID, 0.0, LEG_SPLIT)), ARCH_PROF, start='flat')
    obs['FG_LegR'] = mb.finish(mats['Red'], coll)
    mb = MB('FG_LegL')
    sweep(mb, join(arc_stations(MID, math.pi - LEG_SPLIT, math.pi), leg_stations(MID, -1, False)), ARCH_PROF, end='flat')
    obs['FG_LegL'] = mb.finish(mats['Red'], coll)
    # The band: its rounded end's tip reaches BAND_TIP, so its straight part stops a half width short.
    tip_back = ((BAND_OUT - BAND_IN) / 2) / MID
    mb = MB('FG_BandGold')
    sweep(mb, join(leg_stations(MID, 1, True), arc_stations(MID, 0.0, BAND_TIP - tip_back)), BAND_PROF, start='flat', end='round')
    sweep(mb, join(arc_stations(MID, math.pi - BAND_TIP + tip_back, math.pi), leg_stations(MID, -1, False)), BAND_PROF,
          start='round', end='flat')
    obs['FG_BandGold'] = mb.finish(mats['Gold'], coll)
    return obs


# The bolt, in the viewer's frame (u = his right, v = up, from the medallion's centre): from the upper
# right to the lower left with the jog in the middle, as on The Flash's chest. CCW.
# The jog is 0.6 tall so the neck between the blades stays 0.78 wide (0.5 after the core's inset).
BOLT = [(0.9, 2.6), (-1.1, -0.3), (-0.25, -0.3), (-0.9, -2.6), (1.1, 0.3), (0.25, 0.3)]


def poly_area(poly):
    return 0.5 * sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))


def simple_poly(poly):
    """True when no two non-adjacent edges cross and the polygon keeps a positive area."""
    n = len(poly)

    def cross(a, b, c):
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        for j in range(i + 2, n):
            if (j + 1) % n == i:
                continue
            c, d = poly[j], poly[(j + 1) % n]
            if cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0:
                return False
    return poly_area([(p.x, p.y) for p in poly]) > 0


def offset_poly(poly, o):
    """The polygon (CCW, Vector 2D) offset inward by o (outward when o < 0), mitred."""
    n = len(poly)
    out = []
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        n0 = Vector((-e0.y, e0.x))
        n1 = Vector((-e1.y, e1.x))
        a = p1 + n0 * o
        b = p1 + n1 * o
        den = e0.x * e1.y - e0.y * e1.x
        if abs(den) < 1e-9:
            out.append(a)
            continue
        t = ((b - a).x * e1.y - (b - a).y * e1.x) / den
        out.append(a + e0 * t)
    return out


BOLT_BACK_SCALE = 0.62  # the back's bolt stays inside the rim


def bolt_piece(name, mat, coll, inset, d_in, d_out, bevel, k=4):
    """The bolt as two plates, each an extrusion from depth d_in (sunk into the face) to d_out with a
    quarter-round bevel of `bevel` on both rims (crisp mitred corners), the outline inset by `inset`:
    on the front BOLT itself, its tips past the rim as in the reference (a thin emblem, not a slab,
    from the side); on the back BOLT scaled by BOLT_BACK_SCALE, inside the rim, so no second tip
    shows behind the front one."""
    mb = MB(name)
    assert poly_area(BOLT) > 0
    plate(mb, [Vector(p) for p in BOLT], inset, d_in, d_out, bevel, k, 1.0)
    plate(mb, [Vector(p) * BOLT_BACK_SCALE for p in BOLT], inset * BOLT_BACK_SCALE, d_in, d_out, bevel, k, -1.0)
    return mb.finish(mat, coll)


def plate(mb, base, inset, d_in, d_out, bevel, k, sign):
    half_depth, mid = (d_out - d_in) / 2, sign * (d_out + d_in) / 2

    def at(p, d):  # viewer (u, v) + depth -> Blender
        return Vector((-p.x, mid + d, MED_Y + p.y))

    def dir3(e):  # an in-plane direction (u, v) -> Blender
        return Vector((-e.x, 0.0, e.y))
    outline = offset_poly(base, inset)
    for o in (0.0, bevel):
        poly = offset_poly(outline, o)
        assert simple_poly(poly), ('the bolt outline folds over at inset', inset + o)
        for i in range(len(poly)):  # no edge reversed (an inset past a thin part)
            assert (poly[(i + 1) % len(poly)] - poly[i]).dot(base[(i + 1) % len(base)] - base[i]) > 0, ('bolt edge collapsed', i)
    rings = []  # (offset polygon, depth, depth-normal weight, in-plane weight), front face to back face
    for j in range(k + 1):
        t = math.pi / 2 * j / k  # 0 on the face, 90 on the side wall
        rings.append((offset_poly(outline, bevel - bevel * math.sin(t)), half_depth - bevel + bevel * math.cos(t), math.cos(t), math.sin(t)))
    rings += [(poly, -d, -nd, nn) for (poly, d, nd, nn) in reversed(rings)]
    n = len(outline)
    for i in range(n):
        i2 = (i + 1) % n
        e = (outline[i2] - outline[i]).normalized()
        out_n = dir3(Vector((e.y, -e.x)))  # the edge's outward normal
        col = []
        for (poly, d, nd, nn) in rings:
            nrm = out_n * nn + YAX * nd
            col.append((mb.v(at(poly[i], d), nrm), mb.v(at(poly[i2], d), nrm)))
        for r in range(len(col) - 1):
            (a0, a1), (b0, b1) = col[r], col[r + 1]
            mb.quad(a0, a1, b1, b0, (0, r), (1, r), (1, r + 1), (0, r + 1))
    for poly, d, nd in ((rings[0][0], rings[0][1], 1.0), (rings[-1][0], rings[-1][1], -1.0)):
        idx = [mb.v(at(p, d), YAX * nd) for p in poly]
        for tri in geometry.tessellate_polygon([[Vector((p.x, p.y, 0.0)) for p in poly]]):
            a, b, c = (idx[t] for t in tri)
            mb.tri(a, b, c, *[((poly[t].x + 3) / 6, (poly[t].y + 3) / 6) for t in tri])


def build_medallion(mats, coll):
    obs = {}
    c, ax, e1, e2 = (0.0, 0.0, MED_Y), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)
    # The rim: a glossy, almost round-section ring RIM_IN..RIM from the centre, 3.3 thick (0.13 proud of the band).
    mb = MB('FG_MedallionRim')
    half = (RIM - RIM_IN) / 2
    lathe(mb, c, ax, e1, e2, rrect(half, 1.65, half - 0.03, 6, dr=RIM - half), 72, closed=True)
    obs['FG_MedallionRim'] = mb.finish(mats['Gold'], coll)
    # The face: cream, domed 0.08 on both sides (1.46 at its edge, 1.54 at the centre), its edge hidden in the rim.
    mb = MB('FG_MedallionFace')
    R, d0, d1, rows = RIM_IN + 0.06, 1.46, 1.54, 6
    prof = []
    for side in (1.0, -1.0):
        pts = []
        for j in range(rows + 1):
            rho = R * j / rows
            d = d1 - (d1 - d0) * (rho / R) ** 2
            slope = -2 * (d1 - d0) * rho / (R * R)
            pts.append((rho, side * d, -slope, side))
        if side > 0:
            prof += pts + [(R, d0, 1.0, 0.0)]
        else:
            prof += [(R, -d0, 1.0, 0.0)] + pts[::-1]
    lathe(mb, c, ax, e1, e2, prof, 72, closed=False)
    obs['FG_MedallionFace'] = mb.finish(mats['Cream'], coll)
    # The bolt: a gold edge (the outline) and a Neon core inset 0.09 and 0.08 higher: crisp and raised,
    # on both faces; on the front its tips reach past the rim as in the reference.
    obs['FG_BoltEdge'] = bolt_piece('FG_BoltEdge', mats['Gold'], coll, 0.0, 1.3, 1.72, 0.07)
    obs['FG_Bolt'] = bolt_piece('FG_Bolt', mats['Bolt'], coll, 0.09, 1.36, 1.80, 0.045)
    return obs


PAD_TOP = 0.22


def torus(mb, R, rh, rv, zc, segs, tube):
    prof = []
    for j in range(tube):
        t = 2 * math.pi * j / tube
        nrm = Vector((math.cos(t) / rh, math.sin(t) / rv)).normalized()
        prof.append((R + rh * math.cos(t), zc + rv * math.sin(t), nrm.x, nrm.y))
    lathe(mb, (0, 0, 0), (0, 0, 1), (1, 0, 0), (0, 1, 0), prof, segs, closed=True)


def build_pad(mats, coll):
    obs = {}
    mb = MB('FG_PadDisc')
    edge = 0.22
    prof = [(0.0, PAD_TOP, 0.0, 1.0), (3.3, PAD_TOP, 0.0, 1.0), (PAD_R - edge, PAD_TOP, 0.0, 1.0)]
    for j in range(1, 7):
        t = math.pi / 2 * j / 6
        prof.append((PAD_R - edge + edge * math.sin(t), edge * math.cos(t) + (PAD_TOP - edge), math.sin(t), math.cos(t)))
    prof += [(PAD_R, 0.0, 0.0, -1.0), (0.0, 0.0, 0.0, -1.0)]
    lathe(mb, (0, 0, 0), (0, 0, 1), (1, 0, 0), (0, 1, 0), prof, 96, closed=False)
    obs['FG_PadDisc'] = mb.finish(mats['PadDark'], coll)
    # The Neon rings (FlashGate.Pad.Rings: cyan 5.9..6.3, gold 4.3..4.8, cyan 2.5..2.9), half sunk.
    mb = MB('FG_PadRingCyan')
    torus(mb, 6.1, 0.2, 0.15, PAD_TOP + 0.06, 96, 10)
    torus(mb, 2.7, 0.2, 0.15, PAD_TOP + 0.06, 64, 10)
    obs['FG_PadRingCyan'] = mb.finish(mats['Cyan'], coll)
    mb = MB('FG_PadRingGold')
    torus(mb, 4.55, 0.25, 0.17, PAD_TOP + 0.07, 96, 10)
    obs['FG_PadRingGold'] = mb.finish(mats['GoldNeon'], coll)
    return obs


# ------------------------------------------------------------------------------------------------
# Materials (the preview's; Roblox gets Color / Material from the manifest)
# ------------------------------------------------------------------------------------------------
def lin(c):
    def f(x):
        x = x / 255.0
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


def principled(name, rgb, rough=0.35, metal=0.0, coat=0.0, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(rgb)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    for key in ('Coat Weight', 'Clearcoat'):
        if key in b.inputs:
            b.inputs[key].default_value = coat
            break
    if emit > 0:
        b.inputs['Emission Color'].default_value = lin(rgb)
        b.inputs['Emission Strength'].default_value = emit
    if alpha < 1.0:
        b.inputs['Alpha'].default_value = alpha
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    m.diffuse_color = lin(rgb)
    return m


def make_materials():
    return {
        'Red': principled('FG_Red', COLORS['Red'], rough=0.28, coat=0.35),
        'Gold': principled('FG_Gold', COLORS['Gold'], rough=0.22, metal=0.45, coat=0.35),
        'Cream': principled('FG_Cream', COLORS['Cream'], rough=0.45, coat=0.0),
        'Bolt': principled('FG_BoltNeon', COLORS['Bolt'], rough=0.4, emit=1.8),
        'Cyan': principled('FG_CyanNeon', COLORS['Cyan'], rough=0.4, emit=1.8),
        'GoldNeon': principled('FG_GoldNeon', COLORS['NeonGold'], rough=0.4, emit=1.8),
        'PadDark': principled('FG_PadDark', COLORS['PadDark'], rough=0.38, coat=0.15),
    }


# ------------------------------------------------------------------------------------------------
# Facts, Roblox limits, exports
# ------------------------------------------------------------------------------------------------
def facts(ob):
    me = ob.data
    co = np.array([v.co[:] for v in me.vertices])
    lo, hi = co.min(axis=0), co.max(axis=0)
    size_b, cen_b = hi - lo, (hi + lo) / 2
    keys = set()
    uvl = me.uv_layers.active.data
    cn = me.corner_normals
    for p in me.polygons:
        for li in p.loop_indices:
            n = cn[li].vector
            uv = uvl[li].uv
            keys.add((me.loops[li].vertex_index, round(n[0], 4), round(n[1], 4), round(n[2], 4), round(uv[0], 5), round(uv[1], 5)))
    areas = [p.area for p in me.polygons]
    bm = bmesh.new()
    bm.from_mesh(me)
    manifold = [e for e in bm.edges if len(e.link_faces) == 2]
    flipped = sum(1 for e in manifold if not e.is_contiguous)
    boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    bm.free()
    return {
        'tris': len(me.polygons), 'ngons': sum(1 for p in me.polygons if len(p.vertices) != 3), 'verts': len(me.vertices),
        'renderVerts': len(keys), 'minArea': min(areas), 'degenerate': sum(1 for a in areas if a < 1e-6),
        'flippedEdges': flipped, 'openEdges': boundary,
        # Roblox axes: (bx, bz, -by)
        'size': [round(float(size_b[0]), 3), round(float(size_b[2]), 3), round(float(size_b[1]), 3)],
        'bboxCenterOffset': [round(float(cen_b[0]), 3), round(float(cen_b[2]), 3), round(float(-cen_b[1]), 3) + 0.0],
        'minYB': float(lo[2]), 'maxAxis': float(size_b.max()),
    }


def check_limits(name, f):
    bad = []
    if f['ngons']:
        bad.append('ngons')
    if f['tris'] > ROBLOX_MAX_TRIS:
        bad.append('tris > %d' % ROBLOX_MAX_TRIS)
    if f['verts'] > ROBLOX_MAX_VERTS or f['renderVerts'] > ROBLOX_MAX_VERTS:
        bad.append('verts > %d' % ROBLOX_MAX_VERTS)
    if f['degenerate']:
        bad.append('degenerate faces')
    if f['flippedEdges']:
        bad.append('inconsistent winding')
    if f['maxAxis'] > 2048:
        bad.append('bbox > 2048')
    if f['minYB'] < -1e-6:
        bad.append('dips under the floor (%.4f)' % f['minYB'])
    assert not bad, (name, bad)


def fbx_facts(path):
    import struct
    b = Path(path).read_bytes()
    m = re.search(rb'UnitScaleFactorS\x06\x00\x00\x00doubleS\x06\x00\x00\x00NumberS\x00\x00\x00\x00D(.{8})', b, re.S)
    usf = struct.unpack('<d', m.group(1))[0] if m else None
    # No path of the user folder (non-ASCII: it broke Studio's Import Queue) anywhere in the file; the
    # binary FBX has no other text that could carry one (no textures, exported from an ASCII folder).
    home = str(Path.home()).encode('utf-8')
    return {'unitScaleFactor': usf, 'asciiOnly': b.find(home) < 0 and b.find(str(ROOT).encode('utf-8')) < 0}


def ascii_tempdir():
    for cand in (tempfile.gettempdir(), str(PUBLIC)):
        if cand.isascii():
            Path(cand).mkdir(parents=True, exist_ok=True)
            return Path(tempfile.mkdtemp(prefix='fg_kit_', dir=cand))
    raise RuntimeError('no ASCII temp folder')


def export_all(scene, obs):
    """FBX (the Green Hill kit's settings, the file Studio imported 1:1 with Scale Unit Stud: unit scale
    0.01, FBX Units Scale -> UnitScaleFactor 1, coordinates in studs), from an ASCII-only temp folder."""
    tmp = ascii_tempdir()
    (tmp / 'fbx').mkdir()
    (tmp / 'obj').mkdir()
    fbx_kw = dict(use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True, mesh_smooth_type='FACE',
                  use_tspace=False, add_leaf_bones=False, bake_anim=False, axis_forward='-Z', axis_up='Y',
                  apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0, apply_unit_scale=True, path_mode='STRIP',
                  embed_textures=False, use_custom_props=False, use_triangles=True, bake_space_transform=False)
    obj_kw = dict(export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y', global_scale=1.0,
                  apply_modifiers=True, export_triangulated_mesh=True, export_normals=True, export_uv=True,
                  export_materials=True, path_mode='STRIP', export_smooth_groups=False, export_vertex_groups=False,
                  export_animation=False, export_colors=False)
    old = (scene.unit_settings.system, scene.unit_settings.scale_length)
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.01
    try:
        for n in ORDER:
            bpy.ops.object.select_all(action='DESELECT')
            obs[n].select_set(True)
            bpy.context.view_layer.objects.active = obs[n]
            bpy.ops.export_scene.fbx(filepath=str(tmp / 'fbx' / (n + '.fbx')), **fbx_kw)
        bpy.ops.object.select_all(action='DESELECT')
        for n in ORDER:
            obs[n].select_set(True)
        bpy.context.view_layer.objects.active = obs[ORDER[0]]
        bpy.ops.export_scene.fbx(filepath=str(tmp / 'FlashGateKit.fbx'), **fbx_kw)
    finally:
        scene.unit_settings.system, scene.unit_settings.scale_length = old
    scene.unit_settings.scale_length = 1.0
    for n in ORDER:
        bpy.ops.object.select_all(action='DESELECT')
        obs[n].select_set(True)
        bpy.context.view_layer.objects.active = obs[n]
        bpy.ops.wm.obj_export(filepath=str(tmp / 'obj' / (n + '.obj')), **obj_kw)
    bpy.ops.object.select_all(action='DESELECT')
    ff = {p.name: fbx_facts(p) for p in [tmp / 'FlashGateKit.fbx'] + sorted((tmp / 'fbx').glob('*.fbx'))}
    for name, f in ff.items():
        assert f['asciiOnly'] and f['unitScaleFactor'] is not None and abs(f['unitScaleFactor'] - 1.0) < 1e-6, (name, f)
    # Deliver: design/race/flashgate and C:/Users/Public/FlashGateKit (ASCII, for Studio).
    for f in (OUT / 'fbx').glob('FG_*.fbx'):
        f.unlink()
    for f in (OUT / 'obj').glob('FG_*.*'):
        f.unlink()
    shutil.copy2(tmp / 'FlashGateKit.fbx', OUT / 'FlashGateKit.fbx')
    for f in sorted((tmp / 'fbx').glob('*.fbx')):
        shutil.copy2(f, OUT / 'fbx' / f.name)
    for f in sorted((tmp / 'obj').glob('*.*')):
        shutil.copy2(f, OUT / 'obj' / f.name)
    try:
        (PUBLIC / 'fbx').mkdir(parents=True, exist_ok=True)
        shutil.copy2(tmp / 'FlashGateKit.fbx', PUBLIC / 'FlashGateKit.fbx')
        for f in sorted((tmp / 'fbx').glob('*.fbx')):
            shutil.copy2(f, PUBLIC / 'fbx' / f.name)
        public_ok = True
    except Exception as err:  # the kit in design/ is the deliverable; the public copy is a convenience
        log('could not copy to', PUBLIC, err)
        public_ok = False
    shutil.rmtree(tmp, ignore_errors=True)
    return ff, public_ok


def verify_fbx(path, expect):
    """Re-imports the kit FBX in a clean scene (unit scale 0.01 like the export) and compares sizes."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(path))
    got = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
    assert sorted(got) == sorted(expect), (sorted(got), sorted(expect))
    worst = 0.0
    for n, ob in got.items():
        d = ob.dimensions  # Blender axes after the FBX's -Z forward / Y up conversion back
        e = expect[n]['size']  # Roblox (x, y, z) = Blender (x, z, y) in extent
        err = max(abs(d.x - e[0]), abs(d.z - e[1]), abs(d.y - e[2]))
        worst = max(worst, err)
        assert len(ob.data.polygons) == expect[n]['tris'], (n, len(ob.data.polygons), expect[n]['tris'])
    assert worst < 0.01, worst
    return {'objects': len(got), 'worstSizeErrorStuds': round(worst, 5), 'trianglesMatch': True}


# ------------------------------------------------------------------------------------------------
# The Luau block (FlashGate.Kit) and the manifest
# ------------------------------------------------------------------------------------------------
def num(x):
    s = ('%.3f' % x).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def vec(v):
    return '{ %s }' % ', '.join(num(x) for x in v)


def write_luau(manifest):
    with open(FLASHGATE_LUAU, 'r', encoding='utf-8', newline='') as f:
        text = f.read()
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    b = text.find(BLOCK_BEGIN)
    e = text.find(BLOCK_END, b)
    if b < 0 or e < 0:
        log('WARNING: no', BLOCK_BEGIN, 'block in', FLASHGATE_LUAU, '(FlashGate.Kit not written)')
        return False
    lines = [BLOCK_BEGIN + ' (audit/flash_gate_bpy.py; do not edit by hand)',
             '-- The Blender kit (design/race/flashgate/flashgate_manifest.json): per MeshPart its box (Size) and the',
             "-- box centre's offset from the gate origin (Offset, gate frame, studs), its look and flags.",
             'FlashGate.Kit = {',
             '\tTriangles = %d,' % manifest['totalTris'],
             '\tPieces = {']
    for p in manifest['pieces']:
        lines.append('\t\t{ Name = "%s", Group = "%s", Size = %s, Offset = %s, Color = %s, Material = "%s", Reflectance = %s, CastShadow = %s, CanCollide = %s, Triangles = %d },' % (
            p['name'], p['group'], vec(p['size']), vec(p['bboxCenterOffset']), vec(p['color']), p['material'], num(p['reflectance']),
            'true' if p['castShadow'] else 'false', 'true' if p['canCollide'] else 'false', p['tris']))
    glow = manifest['gate']['medallionGlow']
    lines += ['\t},',
              '\t-- MedallionGlow (a Neon cylinder Part the client breathes) around the mesh medallion.',
              '\tGlow = { Centre = %s, Radius = %s, Depth = %s },' % (vec(glow['centre']), num(glow['radius']), num(glow['depth'])),
              '}', BLOCK_END]
    text = text[:b] + '\n'.join(lines) + text[e + len(BLOCK_END):]
    if crlf:
        text = text.replace('\n', '\r\n')
    with open(FLASHGATE_LUAU, 'w', encoding='utf-8', newline='') as f:
        f.write(text)
    return True


# ------------------------------------------------------------------------------------------------
# Preview scene: bright sky, soft sun, a green baseplate, the client's dashes and MedallionGlow, and
# a stand-in R6 Flash (5 studs) for scale.
# ------------------------------------------------------------------------------------------------
def box_ob(name, size, loc, mat, coll, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=3, profile=0.5, affect='EDGES', clamp_overlap=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    coll.objects.link(ob)
    return ob


def cyl_ob(name, radius, depth, loc, rot, mat, coll, segs=48):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=depth)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    coll.objects.link(ob)
    return ob


def stand_in_flash(coll, loc, mats):
    """A blocky R6 (legs 2, torso 2, head ~1.25: 5.25 studs), red suit, yellow boots and emblem."""
    red = mats['SuitRed']
    yel = mats['SuitYellow']
    x, y = loc
    for side in (-0.5, 0.5):
        box_ob('R6_Leg', (1, 1, 2), (x + side, y, 1.0), red, coll, 0.06)
        box_ob('R6_Boot', (1.04, 1.04, 0.7), (x + side, y, 0.35), yel, coll, 0.06)
    box_ob('R6_Torso', (2, 1, 2), (x, y, 3.0), red, coll, 0.06)
    box_ob('R6_Belt', (2.04, 1.04, 0.22), (x, y, 2.2), yel, coll, 0.03)
    for side in (-1.5, 1.5):
        box_ob('R6_Arm', (1, 1, 2), (x + side, y, 3.0), red, coll, 0.06)
    cyl_ob('R6_Head', 0.62, 1.2, (x, y, 4.62), (0, 0, 0), red, coll, 32)
    # the emblem (a small gold disc with a bolt) and the ear wings
    cyl_ob('R6_Emblem', 0.42, 0.06, (x, y + 0.52, 3.35), (math.pi / 2, 0, 0), yel, coll, 24)
    for side in (-1, 1):
        w = box_ob('R6_Wing', (0.12, 0.35, 0.55), (x + side * 0.66, y, 4.75), yel, coll, 0.03)
        w.rotation_euler = (0, side * 0.35, 0)
    for side in (-0.2, 0.2):
        box_ob('R6_Eye', (0.26, 0.05, 0.16), (x + side, y + 0.61, 4.55), mats['White'], coll, 0.02)


def build_world(scene):
    w = bpy.data.worlds.new('Sky')
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    bg = nt.nodes.new('ShaderNodeBackground')
    outn = nt.nodes.new('ShaderNodeOutputWorld')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    nt.links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = lin((170, 222, 255))
    ramp.color_ramp.elements[1].position = 0.55
    ramp.color_ramp.elements[1].color = lin((38, 132, 238))
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = 1.0
    nt.links.new(bg.outputs[0], outn.inputs[0])


def build_ground(coll):
    m = bpy.data.materials.new('Baseplate')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    br = nt.nodes.new('ShaderNodeTexBrick')
    br.offset = 0.0
    br.squash = 1.0
    br.inputs['Color1'].default_value = lin((88, 190, 62))
    br.inputs['Color2'].default_value = lin((80, 180, 56))
    br.inputs['Mortar'].default_value = lin((62, 150, 44))
    br.inputs['Scale'].default_value = 0.5
    br.inputs['Mortar Size'].default_value = 0.03
    br.inputs['Brick Width'].default_value = 1.0
    br.inputs['Row Height'].default_value = 1.0
    nt.links.new(tc.outputs['Object'], br.inputs['Vector'])
    nt.links.new(br.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.8
    me = bpy.data.meshes.new('Ground')
    s = 1500.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(m)
    ob = bpy.data.objects.new('Ground', me)
    ob.location = (0, 0, -0.001)
    coll.objects.link(ob)
    # distant blocky green hills and a few clouds, as in the reference
    top = principled('HillTop', (84, 190, 64), rough=0.8)
    side = principled('HillSide', (176, 128, 84), rough=0.85)
    cloud = principled('Cloud', (255, 255, 255), rough=0.9)
    cloud.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (1, 1, 1, 1)
    cloud.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 0.45
    for (x, y, w, d, h) in ((-120, -160, 70, 50, 22), (-60, -230, 60, 60, 34), (95, -170, 80, 50, 26),
                            (160, -120, 50, 40, 18), (20, -300, 120, 60, 44), (-190, -90, 50, 60, 14)):
        box_ob('HillSide', (w, d, h), (x, y, h / 2), side, coll)
        box_ob('HillTop', (w + 0.6, d + 0.6, 3.0), (x, y, h + 1.2), top, coll)
    for (x, y, z, r) in ((-80, -260, 70, 16), (-60, -262, 76, 13), (-100, -258, 66, 11), (90, -300, 95, 20),
                         (115, -298, 100, 15), (65, -302, 90, 12), (200, -240, 60, 12), (-190, -220, 88, 14)):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=r)
        me = bpy.data.meshes.new('Cloud')
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(cloud)
        o = bpy.data.objects.new('Cloud', me)
        o.location = (x, y, z)
        o.scale = (1.6, 0.8, 0.7)
        coll.objects.link(o)


def add_client_parts(coll, mats):
    """What the game adds at run time: MedallionGlow (a Neon cylinder Part) and the turning dashes."""
    glow = principled('GlowPart', COLORS['GoldGlow'], emit=1.6, alpha=0.6)
    cyl_ob('MedallionGlow', GLOW, GLOW_DEPTH, (0, 0, MED_Y), (math.pi / 2, 0, 0), glow, coll, 64)
    for (color, radius, count, length) in (('GoldNeon', 5.35, 10, 1.55), ('Cyan', 3.6, 8, 1.2)):
        for i in range(count):
            th = 0.3 + 2 * math.pi * i / count
            o = box_ob('Dash', (0.22, length, 0.06), (radius * math.cos(th), radius * math.sin(th), 0.32), mats[color], coll)
            o.rotation_euler = (0, 0, th)


def add_sun(coll):
    ld = bpy.data.lights.new('Sun', 'SUN')
    ld.energy = 3.2
    ld.angle = math.radians(6.0)  # soft shadows
    ld.color = (1.0, 0.97, 0.9)
    ob = bpy.data.objects.new('Sun', ld)
    coll.objects.link(ob)
    d = Vector((-0.42, -0.55, -0.72)).normalized()  # from the upper left of the front view
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def add_camera(name, loc, target, lens, coll):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.2
    cd.clip_end = 4000
    ob = bpy.data.objects.new(name, cd)
    coll.objects.link(ob)
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob


def setup_render(scene, w, h):
    for engine in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
        try:
            scene.render.engine = engine
            break
        except Exception:
            continue
    ee = scene.eevee
    ee.taa_render_samples = 32 if QUICK else 128
    for key, value in (('use_shadows', True), ('shadow_ray_count', 3), ('shadow_step_count', 12), ('use_raytracing', True),
                       ('use_fast_gi', True), ('fast_gi_distance', 10.0)):
        try:
            setattr(ee, key, value)
        except Exception:
            pass
    try:
        ee.ray_tracing_method = 'SCREEN'
    except Exception:
        pass
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = 'PNG'
    try:
        scene.view_settings.view_transform = 'Standard'  # AgX washes the saturated cartoon colours out
        scene.view_settings.look = 'None'
    except Exception:
        pass
    scene.view_settings.exposure = -0.1
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new('CompositorNodeRLayers')
    comp = nt.nodes.new('CompositorNodeComposite')
    glare = nt.nodes.new('CompositorNodeGlare')
    for key, value in (('glare_type', 'BLOOM'), ('quality', 'HIGH'), ('threshold', 1.2), ('mix', -0.55), ('size', 7)):
        try:
            setattr(glare, key, value)
        except Exception:
            pass
    for key, value in (('Threshold', 1.2), ('Strength', 0.45), ('Size', 0.55)):
        if key in glare.inputs:
            try:
                glare.inputs[key].default_value = value
            except Exception:
                pass
    nt.links.new(rl.outputs['Image'], glare.inputs['Image'])
    nt.links.new(glare.outputs['Image'], comp.inputs['Image'])


def render(scene, cam, path):
    scene.camera = cam
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log('rendered', path.name)


def load_rgb(path):
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[:, :, :3].copy(), w, h


def side_by_side(left_path, right_path, out_path, gap=12):
    a, aw, ah = load_rgb(left_path)
    b, bw, bh = load_rgb(right_path)
    if (aw, ah) != (bw, bh):  # nearest-neighbour fit of the left image to the right's size
        ys = (np.arange(bh) * ah / bh).astype(int)
        xs = (np.arange(bw) * aw / bw).astype(int)
        a = a[ys][:, xs]
    h, w = bh, bw
    sheet = np.ones((h, w * 2 + gap, 3), np.float32)
    sheet[:, :w] = a
    sheet[:, w + gap:] = b
    im = bpy.data.images.new('compare', w * 2 + gap, h, alpha=False)
    rgba = np.ones((h, w * 2 + gap, 4), np.float32)
    rgba[:, :, :3] = sheet
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = str(out_path)
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)
    log('side by side', out_path.name)


# ------------------------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------------------------
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    mats = make_materials()
    kit = bpy.data.collections.new('FlashGateKit')
    scene.collection.children.link(kit)
    obs = {}
    obs.update(build_arch(mats, kit))
    obs.update(build_medallion(mats, kit))
    obs.update(build_pad(mats, kit))
    assert sorted(obs) == sorted(ORDER), sorted(obs)
    bpy.context.view_layer.update()

    info, total = {}, 0
    for spec in PIECES:
        name = spec[0]
        f = facts(obs[name])
        check_limits(name, f)
        info[name] = f
        total += f['tris']
        log('%-18s tris %5d verts %5d (render %5d, open edges %d)  size %s  centre %s' % (
            name, f['tris'], f['verts'], f['renderVerts'], f['openEdges'], f['size'], f['bboxCenterOffset']))
    log('TOTAL TRIS', total)
    assert total <= BUDGET_TOTAL, total

    # The footprint the part-built gate had (FlashGate.Arch): checked here and again by the Lune test.
    arch_parts = ['FG_ArchRed', 'FG_LegL', 'FG_LegR', 'FG_BandGold']
    xs = [info[n]['bboxCenterOffset'][0] + s * info[n]['size'][0] / 2 for n in arch_parts for s in (-1, 1)]
    ys = [info[n]['bboxCenterOffset'][1] + s * info[n]['size'][1] / 2 for n in arch_parts for s in (-1, 1)]
    width, height = max(xs) - min(xs), max(ys) - min(ys)
    assert abs(width - 2 * OUTER) < 0.01 and abs(height - (LEG + OUTER)) < 0.01, (width, height)
    med_top = info['FG_MedallionRim']['bboxCenterOffset'][1] + info['FG_MedallionRim']['size'][1] / 2
    depth = max(info[n]['size'][2] for n in ORDER if not n.startswith('FG_Pad'))  # the arch and its medallion

    ff, public_ok = export_all(scene, obs)
    log('FBX facts', ff['FlashGateKit.fbx'], 'public copy', public_ok)

    manifest = {
        'generator': 'audit/flash_gate_bpy.py', 'fbx': 'FlashGateKit.fbx', 'savedModel': 'FlashGateKit.rbxm',
        'units': '1 unit = 1 stud; FBX UnitScaleFactor 1.0 (the Green Hill kit settings: Studio Import 3D, Scale Unit Stud, gives 1:1)',
        'axes': 'Roblox gate frame: x = the gate\'s right, y up from the floor, -z toward the players (Blender +Y); FBX -Z forward, Y up',
        'pivot': 'every piece: the gate origin, the floor point under the arch centre (identity transforms); an imported MeshPart\'s PivotOffset.Position is -bboxCenterOffset turned by the import\'s turn',
        'placement': 'part.CFrame = gateCFrame * CFrame.new(bboxCenterOffset) * CFrame.Angles(0, -importTurn, 0); part.Size = size (RaceArenaBuilder.BuildGate, Shared/MeshKitImport)',
        'noTextures': 'no textures or UV-dependent look: the builder sets Color, Material, Reflectance from here',
        'totalTris': total, 'budgetTris': BUDGET_TOTAL,
        'gate': {'inner': INNER, 'outer': OUTER, 'leg': LEG, 'depth': DEPTH, 'bandInner': BAND_IN, 'bandOuter': BAND_OUT,
                 'medallionCentreY': MED_Y, 'rim': RIM, 'rimInner': RIM_IN, 'padRadius': PAD_R, 'padTop': PAD_TOP,
                 'medallionGlow': {'centre': [0.0, MED_Y, 0.0], 'radius': GLOW, 'depth': GLOW_DEPTH},
                 'legSplitDegrees': round(math.degrees(LEG_SPLIT), 3), 'bandTipDegrees': round(math.degrees(BAND_TIP), 3),
                 'width': round(width, 3), 'height': round(height, 3), 'medallionTop': round(med_top, 3), 'archDepth': round(depth, 3),
                 'opening': round(2 * INNER, 3)},
        'pieces': [],
    }
    for (name, group, color, material, refl, shadow, collide, note) in PIECES:
        f = info[name]
        manifest['pieces'].append({
            'name': name, 'group': group, 'size': f['size'], 'bboxCenterOffset': f['bboxCenterOffset'],
            'color': list(COLORS[color]), 'colorName': color, 'material': material, 'reflectance': refl,
            'castShadow': shadow, 'canCollide': collide, 'tris': f['tris'], 'verts': f['verts'], 'renderVerts': f['renderVerts'],
            'note': note,
        })
    manifest['fbxReimportCheck'] = verify_fbx(OUT / 'FlashGateKit.fbx', {p['name']: p for p in manifest['pieces']})
    log('FBX re-import', manifest['fbxReimportCheck'])
    with open(OUT / 'flashgate_manifest.json', 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(manifest, indent=1) + '\n')
    log('manifest written; FlashGate.Kit', 'written' if write_luau(manifest) else 'NOT written')

    if NO_RENDER:
        return
    # The scene again (verify_fbx reset the file), with the preview dressing.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    mats = make_materials()
    mats['SuitRed'] = principled('SuitRed', (196, 22, 30), rough=0.45)
    mats['SuitYellow'] = principled('SuitYellow', (255, 200, 30), rough=0.4)
    mats['White'] = principled('White', (250, 250, 250), rough=0.5)
    kit = bpy.data.collections.new('FlashGateKit')
    scene.collection.children.link(kit)
    build_arch(mats, kit)
    build_medallion(mats, kit)
    build_pad(mats, kit)
    dress = bpy.data.collections.new('Preview')
    scene.collection.children.link(dress)
    build_world(scene)
    build_ground(dress)
    add_client_parts(dress, mats)
    add_sun(dress)
    ref_w, ref_h = 1376, 768
    setup_render(scene, ref_w, ref_h)
    # 1. The reference's framing: front, slightly low, the stand-in where the reference draws Flash.
    stand = bpy.data.collections.new('StandInRef')
    scene.collection.children.link(stand)
    stand_in_flash(stand, (8.4, 3.6), mats)
    cam = add_camera('Cam_Front', (0.0, 28.5, 2.7), (0.0, 0.0, 7.3), 32.0, dress)
    render(scene, cam, PREV / '01_front.png')
    if REF.exists():
        side_by_side(REF, PREV / '01_front.png', PREV / '00_compare_front.png')
    cam = add_camera('Cam_Medallion', (-4.5, 17.0, 13.6), (0.0, 0.0, MED_Y - 0.3), 50.0, dress)
    render(scene, cam, PREV / '04_medallion.png')
    for ob in stand.objects:
        ob.hide_render = True
    # 2. In the game's layout: The Flash at FlashSpot (World 1: 18 studs to the gate's right, 3 forward).
    real = bpy.data.collections.new('StandInGame')
    scene.collection.children.link(real)
    stand_in_flash(real, (18.0, 3.0), mats)
    cam = add_camera('Cam_Lobby', (4.0, 52.0, 6.5), (6.0, 0.0, 5.5), 30.0, dress)
    render(scene, cam, PREV / '02_lobby_flashspot.png')
    cam = add_camera('Cam_ThreeQuarter', (-24.0, 27.0, 8.0), (0.5, 0.0, 6.2), 30.0, dress)
    render(scene, cam, PREV / '03_three_quarter.png')
    cam = add_camera('Cam_Back', (6.0, -30.0, 4.0), (0.0, 0.0, 6.6), 32.0, dress)
    render(scene, cam, PREV / '05_back.png')
    scene.camera = bpy.data.objects['Cam_Front']
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(PREV / 'FlashGate_preview.blend'), compress=True)
    log('preview blend saved')


main()
log('DONE')
