"""Green Hill race kit generator (Blender 4.5, headless, deterministic).

Run:
  blender.exe -b --factory-startup --python audit/greenhill_kit_bpy.py -- [--quick] [--no-render] [--stage kit|all]

Writes (all under design/race/greenhill/):
  GreenHillKit.fbx            unique kit pieces, one object "Kit_<Name>" each, 1 material, 1 shared atlas texture
  textures/GreenHillAtlas.png 1024x1024 atlas (Astra's GPT Image tiles + painted swatches), embedded in the FBX
  layout.json                 every placement in track-local studs (Roblox axes)
  kit_manifest.json           per piece size / tris / offsets / fallback look + FBX re-import verification
  preview/*.png               Eevee previews of the layout (and a kit sheet)
  preview/GreenHill_preview.blend

Frames:
  Blender (x, y, z)  <->  Roblox track-local (x, y, z) = (bx, bz, -by)   (FBX export: -Z forward, Y up)
  Track: s = -Z (Roblox) = +Y (Blender). Start line s = 0, finish s = 2000, run-out to s = 2120, staging s = -64..0.
  Kit pieces: pivot = base centre (x = z = 0, y = 0 at the base / ground line). Roblox rotY == Blender rotZ (degrees).
"""
import bpy, bmesh, math, json, random, sys, time
from pathlib import Path
from mathutils import Vector, Matrix, noise as mnoise
import numpy as np

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
QUICK = '--quick' in ARGS
NO_RENDER = '--no-render' in ARGS
STAGE = 'all'
if '--stage' in ARGS:
    STAGE = ARGS[ARGS.index('--stage') + 1]
# --stage safe: rebuild the kit with the import-safe geometry fixes (monotonic palm trunk rings, stricter
# cleanup) and write ONLY the fallback files (fbx/, obj/, GreenHillKit_all.fbx). The frozen delivery
# (GreenHillKit.fbx, kit_manifest.json, layout.json) is never touched by that stage.
SAFE_GEOMETRY = STAGE == 'safe'
ONLY_VIEWS = None
if '--views' in ARGS:
    ONLY_VIEWS = ARGS[ARGS.index('--views') + 1].split(',')

SCRIPT = Path(__file__).resolve()
ROOT = SCRIPT.parents[1]
OUT = ROOT / 'design' / 'race' / 'greenhill'
PREV = OUT / 'preview'
TEXO = OUT / 'textures'
for p in (OUT, PREV, TEXO):
    p.mkdir(parents=True, exist_ok=True)
ASTRA_CANDIDATES = [ROOT / 'design' / 'race' / 'Astra_Recta',
                    Path.home() / 'Documents' / 'Codex' / '2026-09-25' / 'le-p' / 'outputs' / 'GreenHill_Recta']
ASTRA = next((p for p in ASTRA_CANDIDATES if (p / 'textures' / 'Cliff.png').exists()), None)
assert ASTRA is not None, 'Astra textures not found'

WATER_Y = -8.0
CLEAR_X = 38.1        # playable strip half-width (nothing above 0.5 stud inside, except the pad visuals)
DECOR_X = 40.0        # every decoration except fences starts at |x| >= 40
FENCE_X = 39.0
PAD_S = [60, 480, 990, 1450, 1850]
T0 = time.time()


def log(*a):
    print('[greenhill %6.1fs]' % (time.time() - T0), *a, flush=True)


# ----------------------------------------------------------------------------------------------
# Track profile (Astra's generator, verified against map_data.json)
# ----------------------------------------------------------------------------------------------
def track_h(s):
    h = 0.0
    for a, b, amp in [(120, 450, 4.5), (580, 930, 6), (1020, 1400, 4), (1510, 1820, 5)]:
        if a < s < b:
            h += amp * math.sin(math.pi * (s - a) / (b - a)) ** 2
    return h


def bank_w(s):
    return 69 + 7 * math.sin(s * .017) + 4 * math.sin(s * .031)


def verge_h(x, s):
    ax = abs(x)
    if ax < 36:
        return track_h(s)
    if ax <= 42:
        return track_h(s) + 0.3 * (ax - 36) / 6
    if ax <= bank_w(s):
        return track_h(s) + 0.3
    return None


md = ASTRA / 'map_data.json'
if md.exists():
    data = json.loads(md.read_text())
    err = max(abs(track_h(e['s']) - e['h']) for e in data['samples'])
    assert err < 1e-6, 'height profile mismatch %g' % err
    assert [b['s'] for b in data['boosts']] == PAD_S


# ----------------------------------------------------------------------------------------------
# Atlas (1024x1024): tiled regions with wrapped gutters + painted swatches
# ----------------------------------------------------------------------------------------------
AT = 1024
R_CLIFF = (16, 16, 480, 480)
R_GRASS = (528, 16, 480, 480)
R_BARK = (16, 528, 224, 480)
R_FROND = (264, 520, 240, 496)
SW = ['rock', 'broadleaf', 'bromeliad', 'petal', 'sunc', 'stem', 'padred', 'chevron',
      'steel', 'wood', 'rope', 'coconut', 'cloud', 'tuft', 'daisy', 'moss']


def sw_rect(name):
    i = SW.index(name)
    return (512 + (i % 4) * 128 + 10, 512 + (i // 4) * 128 + 10, 108, 108)


def ruv(rect, fu, fv):
    x, y, w, h = rect
    fu = min(1.0, max(0.0, fu))
    fv = min(1.0, max(0.0, fv))
    return ((x + fu * w) / AT, 1.0 - (y + (1.0 - fv) * h) / AT)


def tiled(rect, UV):
    cu = math.floor(sum(u for u, v in UV) / len(UV))
    cv = math.floor(sum(v for u, v in UV) / len(UV))
    return [ruv(rect, u - cu, v - cv) for u, v in UV]


def srgb(*c):
    return np.array(c, np.float32) / 255.0


def load_rgb(path, w, h):
    img = bpy.data.images.load(str(path), check_existing=False)
    img.scale(w, h)
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1, :, :3].copy()


def vnoise(h, w, cx, cy, rng, periodic=False):
    g = rng.random((cy + 1, cx + 1))
    if periodic:
        g[-1, :] = g[0, :]
        g[:, -1] = g[:, 0]
    X, Y = np.meshgrid(np.linspace(0, cx, w, endpoint=False), np.linspace(0, cy, h, endpoint=False))
    x0 = X.astype(int)
    y0 = Y.astype(int)
    fx = X - x0
    fy = Y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = g[y0, x0]; b = g[y0, x0 + 1]; c = g[y0 + 1, x0]; d = g[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, base, octaves, rng, periodic=False):
    acc = np.zeros((h, w), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        f = base * 2 ** o
        acc += amp * vnoise(h, w, f, f, rng, periodic)
        tot += amp
        amp *= 0.5
    return acc / tot


def grid(h, w):
    X, Y = np.meshgrid((np.arange(w) + 0.5) / w, (np.arange(h) + 0.5) / h)
    return X, 1.0 - Y  # U across, V up


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def build_atlas(path):
    rng = np.random.default_rng(20260926)
    A = np.zeros((AT, AT, 3), np.float32)

    def put_tile(tile, x0, y0, w, h, gut):
        th, tw = tile.shape[:2]
        iy = (np.arange(h) - gut) % th
        ix = (np.arange(w) - gut) % tw
        A[y0:y0 + h, x0:x0 + w] = tile[np.ix_(iy, ix)]

    # Checker cliff, graded to the reference's tan / mid-brown two-tone
    cl = load_rgb(ASTRA / 'textures' / 'Cliff.png', 480, 480)
    ii = np.arange(480) // 120
    par = (ii[:, None] + ii[None, :]) % 2  # 0 = light (top-left is light in Cliff.png)
    for p, tgt in ((0, srgb(232, 152, 64)), (1, srgb(156, 84, 38))):
        m = par == p
        mean = cl[m].mean(axis=0)
        cl[m] = cl[m] * (tgt / np.maximum(mean, 1e-3))
    # thin darker mortar line between squares for the "block" read
    edge = np.minimum(np.arange(480) % 120, 119 - np.arange(480) % 120)
    e2 = np.minimum(edge[:, None], edge[None, :])
    cl *= (0.82 + 0.18 * smoothstep(0, 4, e2))[..., None]
    put_tile(np.clip(cl, 0, 1), 0, 0, 512, 512, 16)

    gr = load_rgb(ASTRA / 'textures' / 'Grass.png', 480, 480)
    gr = gr * srgb(255, 255, 235) * 1.04
    put_tile(np.clip(gr, 0, 1), 512, 0, 512, 512, 16)

    bk = load_rgb(ASTRA / 'textures' / 'Bark.png', 224, 480)
    bk = np.clip(bk * srgb(262, 245, 225) * 1.45, 0, 1) ** 0.92
    put_tile(np.clip(bk, 0, 1), 0, 512, 256, 512, 16)

    # Palm / fern frond: U across (0 left edge, .5 rib, 1 right edge), V along (0 base -> 1 tip)
    H, W = 512, 256
    U, V = grid(H, W)
    d = np.abs(U - 0.5) * 2
    dark = srgb(28, 104, 22); light = srgb(122, 196, 44)
    col = mix(dark, light, 0.25 + 0.45 * V + 0.35 * d)
    phase = V * 16 - d * 2.2
    vein = smoothstep(0.80, 0.97, np.cos(2 * np.pi * phase))
    col = mix(col, col * 0.72, vein * smoothstep(0.08, 0.2, d))
    rib = np.exp(-(d / 0.05) ** 2)
    col = mix(col, srgb(196, 226, 96), rib * 0.85)
    col = mix(col, col * 1.12, smoothstep(0.82, 1.0, d))
    col *= (0.93 + 0.14 * fbm(H, W, 6, 3, rng))[..., None]
    A[512:1024, 256:512] = np.clip(col, 0, 1)

    # Swatches (128 px cells)
    def cell(name, fn):
        i = SW.index(name)
        x0 = 512 + (i % 4) * 128
        y0 = 512 + (i // 4) * 128
        U, V = grid(128, 128)
        A[y0:y0 + 128, x0:x0 + 128] = np.clip(fn(U, V), 0, 1)

    def n2(base=5, oct=3):
        return fbm(128, 128, base, oct, rng)

    cell('rock', lambda U, V: mix(srgb(104, 98, 98), srgb(174, 168, 160), 0.35 + 0.5 * V + 0.35 * (n2(6) - 0.5))
         * (0.9 + 0.2 * n2(14, 2))[..., None])
    cell('broadleaf', lambda U, V: mix(mix(srgb(30, 110, 34), srgb(104, 190, 58), 0.25 + 0.6 * V + 0.3 * np.abs(U - .5)),
                                       srgb(170, 214, 96), np.exp(-((U - 0.5) / 0.035) ** 2) * 0.8)
         * (0.92 + 0.16 * n2(8))[..., None])
    cell('bromeliad', lambda U, V: mix(mix(srgb(70, 140, 50), srgb(214, 36, 38), smoothstep(0.12, 0.38, V)),
                                       srgb(120, 12, 26), smoothstep(0.7, 1.0, V))
         * (0.9 + 0.1 * np.cos(U * 18))[..., None])
    cell('petal', lambda U, V: mix(srgb(236, 150, 16), srgb(255, 222, 40), 0.2 + 0.8 * V)
         * (0.94 + 0.08 * np.cos((U - .5) * 30))[..., None])

    def sunc(U, V):
        r = np.hypot(U - .5, V - .5) * 2
        ang = np.arctan2(V - .5, U - .5)
        dots = 0.5 + 0.5 * np.cos(r * 40) * np.cos(ang * 21 + r * 30)
        c = mix(srgb(96, 52, 18), srgb(40, 22, 10), smoothstep(0.1, 0.9, r))
        return mix(c, c * 1.6, dots * 0.5)
    cell('sunc', sunc)
    cell('stem', lambda U, V: mix(srgb(38, 118, 32), srgb(96, 170, 50), 0.3 + 0.5 * V) * (0.92 + 0.12 * n2(6))[..., None])

    def padred(U, V):
        x = U * 11; y = V * 11
        fx = x - np.floor(x) - .5; fy = y - np.floor(y) - .5
        dia = smoothstep(0.26, 0.2, np.abs(fx) + np.abs(fy) * 0.55)
        c = srgb(214, 26, 30) * (0.92 + 0.08 * n2(10))[..., None]
        return mix(c, srgb(240, 70, 58), dia * 0.6)
    cell('padred', padred)
    cell('chevron', lambda U, V: mix(srgb(255, 190, 0), srgb(255, 222, 30), V) * (0.96 + 0.04 * n2(10))[..., None])
    cell('steel', lambda U, V: mix(mix(srgb(206, 212, 220), srgb(118, 126, 138), U * 1.4), srgb(44, 48, 56),
                                   smoothstep(0.7, 0.74, U)) * (0.95 + 0.05 * np.cos(V * 60))[..., None])
    cell('wood', lambda U, V: mix(srgb(150, 84, 36), srgb(200, 126, 60), 0.4 + 0.4 * np.cos(U * 40 + n2(4) * 8) * 0.5 + 0.3 * V)
         * (0.92 + 0.1 * n2(12))[..., None])
    cell('rope', lambda U, V: mix(srgb(170, 124, 70), srgb(226, 186, 120), 0.5 + 0.5 * np.cos((U * 3 + V * 9) * 2 * np.pi)))
    cell('coconut', lambda U, V: mix(srgb(86, 66, 30), srgb(140, 108, 44), 0.3 + 0.5 * V + 0.3 * (n2(7) - .5)))
    cell('cloud', lambda U, V: mix(srgb(196, 214, 238), srgb(255, 255, 255), smoothstep(0.05, 0.6, V)))
    cell('tuft', lambda U, V: mix(srgb(34, 112, 28), srgb(150, 212, 64), V ** 0.8) * (0.94 + 0.1 * np.cos(U * 25))[..., None])
    cell('daisy', lambda U, V: mix(mix(srgb(255, 255, 255), srgb(255, 170, 205), smoothstep(0.45, 0.55, U)),
                                   srgb(255, 214, 60), smoothstep(0.82, 0.9, V)))
    cell('moss', lambda U, V: mix(srgb(40, 120, 30), srgb(110, 180, 50), n2(6)))

    img = bpy.data.images.new('GreenHillAtlas_tmp', AT, AT, alpha=False)
    rgba = np.ones((AT, AT, 4), np.float32)
    rgba[:, :, :3] = np.clip(A, 0, 1)
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.filepath_raw = str(path)
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(str(path), check_existing=False)
    img.name = 'GreenHillAtlas.png'
    return img


# ----------------------------------------------------------------------------------------------
# Mesh building helpers
# ----------------------------------------------------------------------------------------------
def newell(pts):
    n = Vector((0, 0, 0))
    m = len(pts)
    for i in range(m):
        a = pts[i]; b = pts[(i + 1) % m]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class MB:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.kind = self.bm.faces.layers.int.new('kind')

    def v(self, co):
        return self.bm.verts.new(Vector(co))

    def face(self, verts, uvs, want=None, smooth=True, kind=0):
        if want is not None:
            n = newell([v.co for v in verts])
            if n.dot(Vector(want)) < 0:
                verts = list(reversed(verts))
                uvs = list(reversed(uvs))
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        for lp, uv in zip(f.loops, uvs):
            lp[self.uv].uv = uv
        f.smooth = smooth
        f[self.kind] = kind
        return f

    def finish(self, mat, sharp_deg=None, collection=None):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if not v.link_faces], dist=0.0)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='BEAUTY')
        bad = [f for f in bm.faces if f.calc_area() < (1e-5 if SAFE_GEOMETRY else 1e-7)]
        if bad:
            bmesh.ops.delete(bm, geom=bad, context='FACES_ONLY')
        if SAFE_GEOMETRY:
            loose_e = [e for e in bm.edges if not e.link_faces]
            if loose_e:
                bmesh.ops.delete(bm, geom=loose_e, context='EDGES')
            loose_v = [v for v in bm.verts if not v.link_faces]
            if loose_v:
                bmesh.ops.delete(bm, geom=loose_v, context='VERTS')
        if sharp_deg is not None:
            lim = math.radians(sharp_deg)
            for e in bm.edges:
                if e.is_manifold and e.calc_face_angle(0) > lim:
                    e.smooth = False
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        return ob


def ring_frame(T):
    T = T.normalized()
    ref = Vector((0, 1, 0)) if abs(T.y) < 0.9 else Vector((1, 0, 0))
    e1 = ref.cross(T).normalized()
    e2 = T.cross(e1).normalized()
    return e1, e2


def add_tube(mb, pts, radii, sides, uvfn, cap_end=False, want_out=True, v_of=None):
    """pts: list of Vector along the tube; radii list; uvfn(fu, fv)->uv."""
    rings = []
    n = len(pts)
    for k in range(n):
        T = (pts[min(n - 1, k + 1)] - pts[max(0, k - 1)])
        e1, e2 = ring_frame(T)
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            ring.append(mb.v(pts[k] + (e1 * math.cos(a) + e2 * math.sin(a)) * radii[k]))
        rings.append(ring)
    for k in range(n - 1):
        fv0 = v_of(k) if v_of else k / (n - 1)
        fv1 = v_of(k + 1) if v_of else (k + 1) / (n - 1)
        for j in range(sides):
            j2 = (j + 1) % sides
            quad = [rings[k][j], rings[k][j2], rings[k + 1][j2], rings[k + 1][j]]
            c = (pts[k] + pts[k + 1]) * 0.5
            mid = sum((q.co for q in quad), Vector()) / 4
            u0 = j / sides; u1 = (j + 1) / sides
            mb.face(quad, [uvfn(u0, fv0), uvfn(u1, fv0), uvfn(u1, fv1), uvfn(u0, fv1)],
                    want=(mid - c) if want_out else (c - mid))
    if cap_end:
        tip = mb.v(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.6)
        for j in range(sides):
            j2 = (j + 1) % sides
            mb.face([rings[-1][j], rings[-1][j2], tip], [uvfn(j / sides, 1), uvfn((j + 1) / sides, 1), uvfn(0.5, 1)],
                    want=pts[-1] - pts[-2])
    return rings


def add_sphere(mb, c, r, seg, rings, uvfn, deform=None):
    c = Vector(c)
    verts = []
    for k in range(1, rings):
        th = math.pi * k / rings
        row = []
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            p = Vector((math.sin(th) * math.cos(ph) * r[0], math.sin(th) * math.sin(ph) * r[1], math.cos(th) * r[2]))
            if deform:
                p = deform(p)
            row.append((mb.v(c + p), 1 - k / rings))
        verts.append(row)
    top = mb.v(c + (deform(Vector((0, 0, r[2]))) if deform else Vector((0, 0, r[2]))))
    bot = mb.v(c + (deform(Vector((0, 0, -r[2]))) if deform else Vector((0, 0, -r[2]))))

    def U(j):
        return abs(((j % seg) / seg) * 2 - 1)
    for j in range(seg):
        j2 = (j + 1) % seg
        a, fa = verts[0][j]; b, fb = verts[0][j2]
        mb.face([top, a, b], [uvfn(0.5, 1), uvfn(U(j), fa), uvfn(U(j + 1), fb)], want=a.co - c)
        a, fa = verts[-1][j]; b, fb = verts[-1][j2]
        mb.face([bot, b, a], [uvfn(0.5, 0), uvfn(U(j + 1), fb), uvfn(U(j), fa)], want=a.co - c)
        for k in range(len(verts) - 1):
            p0, f0 = verts[k][j]; p1, _ = verts[k][j2]; p2, f2 = verts[k + 1][j2]; p3, _ = verts[k + 1][j]
            mid = (p0.co + p1.co + p2.co + p3.co) / 4
            mb.face([p0, p1, p2, p3], [uvfn(U(j), f0), uvfn(U(j + 1), f0), uvfn(U(j + 1), f2), uvfn(U(j), f2)],
                    want=mid - c)


def add_icorock(mb, c, scale, subdiv, seed, uvrect, cuts=5, flatten=-0.35):
    bm = mb.bm
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=Matrix(), calc_uvs=False)
    vs = res['verts']
    rnd = random.Random(seed)
    planes = []
    for i in range(cuts):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1.0))).normalized()
        planes.append((d, rnd.uniform(0.72, 0.86)))
    off = Vector((seed * 1.7, seed * 0.3, 3.1))
    for v in vs:
        p = v.co.copy()
        p *= 1 + 0.16 * mnoise.noise(p * 1.3 + off) + 0.06 * mnoise.noise(p * 3.1 + off)
        for d, k in planes:
            dd = p.dot(d)
            if dd > k:
                p -= d * (dd - k) * 0.85
        if p.z < flatten:
            p.z = flatten + (p.z - flatten) * 0.25
        v.co = Vector((c[0] + p.x * scale[0], c[1] + p.y * scale[1], c[2] + p.z * scale[2]))
    faces = {f for v in vs for f in v.link_faces}
    zs = [v.co.z for v in vs]
    z0, z1 = min(zs), max(zs)
    for f in faces:
        for lp in f.loops:
            p = lp.vert.co
            ang = math.atan2(p.y - c[1], p.x - c[0])
            lp[mb.uv].uv = ruv(uvrect, abs(ang) / math.pi, (p.z - z0) / max(1e-3, z1 - z0))
        f.smooth = True
    return z0


# ----------------------------------------------------------------------------------------------
# Outline + plateau (checker terraces / mesas with overhanging grass caps)
# ----------------------------------------------------------------------------------------------
def rounded_poly(pts, r, arc_seg=6):
    pts = [Vector(p) for p in pts]
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        d1 = (p1 - p0).normalized(); d2 = (p2 - p1).normalized()
        cross = d1.x * d2.y - d1.y * d2.x
        ang = math.acos(max(-1.0, min(1.0, d1.dot(d2))))
        if ang < 1e-3:
            out.append(p1); continue
        t = r * math.tan(ang / 2)
        a = p1 - d1 * t
        left = Vector((-d1.y, d1.x))
        c = a + left * r if cross > 0 else a - left * r
        b = p1 + d2 * t
        a0 = math.atan2(a.y - c.y, a.x - c.x); a1 = math.atan2(b.y - c.y, b.x - c.x)
        da = a1 - a0
        if cross > 0:
            while da <= 0: da += 2 * math.pi
        else:
            while da >= 0: da -= 2 * math.pi
        for k in range(arc_seg + 1):
            aa = a0 + da * k / arc_seg
            out.append(c + Vector((math.cos(aa), math.sin(aa))) * r)
    # drop near-duplicates
    clean = []
    for p in out:
        if not clean or (p - clean[-1]).length > 1e-4:
            clean.append(p)
    if (clean[0] - clean[-1]).length < 1e-4:
        clean.pop()
    return clean


def blob_poly(rx, ry, n, amp, seed, offset=(0, 0)):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + amp * (0.6 * math.sin(3 * a + seed) + 0.4 * math.sin(5 * a + seed * 2.3) + 0.3 * math.cos(2 * a + seed * .7))
        out.append(Vector((offset[0] + rx * k * math.cos(a), offset[1] + ry * k * math.sin(a))))
    return out


def poly_area(poly):
    return 0.5 * sum(poly[i - 1].x * poly[i].y - poly[i].x * poly[i - 1].y for i in range(len(poly)))


def resample(poly, sub, tile=16.0, keep=True):
    m = len(poly)
    seg = [(poly[(i + 1) % m] - poly[i]) for i in range(m)]
    sl = [s.length for s in seg]
    L = sum(sl)
    ntile = max(1, round(L / tile))
    tileLen = L / ntile
    k = max(1, round(tileLen / sub))
    step = tileLen / k
    sn = [Vector((s.y, -s.x)).normalized() for s in seg]
    vn = [(sn[i - 1] + sn[i]).normalized() for i in range(m)]
    cum = [0.0]
    for l in sl:
        cum.append(cum[-1] + l)
    ts = [j * step for j in range(int(round(L / step)))]
    for i in range(m if keep else 0):
        t = cum[i]
        j = round(t / step)
        if abs(t - j * step) > 0.3 * step:
            ts.append(t)
    ts = sorted(set(round(t, 7) for t in ts if t < L - 1e-6))
    out = []
    i = 0
    for t in ts:
        while i < m - 1 and cum[i + 1] <= t:
            i += 1
        f = (t - cum[i]) / sl[i]
        p = poly[i].lerp(poly[(i + 1) % m], f)
        n = vn[i].lerp(vn[(i + 1) % m], f).normalized()
        out.append((p, n, t))
    return out, L, tileLen


def plateau(mb, poly, z0, z1, seed, noise_amp=0.28, taper=0.018, inset=2.3, lip=1.25, droop_amp=1.0,
            wall_sub=4.0, cap_sub=2.0, detail_rows=(4, 8), keep=True):
    """Checker wall from z0 to z1 + thick overhanging grass cap. poly CCW (local XY). Returns top ring polygon (2D) and top z."""
    assert poly_area(poly) > 0
    # ---- wall
    S, L, tl = resample(poly, wall_sub, keep=keep)
    rows = {z0, z1}
    for d in detail_rows:
        if z1 - d > z0: rows.add(z1 - d)
    k = 1
    while z1 - 16 * k > z0:
        rows.add(z1 - 16 * k); k += 1
    zs = sorted(rows)
    rings = []
    for z in zs:
        ring = []
        for (p, n, t) in S:
            off = taper * (z1 - z)
            if z0 < z < z1:
                off += noise_amp * mnoise.noise(Vector((p.x * 0.23 + seed, p.y * 0.23 - seed, z * 0.19)))
            ring.append(mb.v((p.x + n.x * off, p.y + n.y * off, z)))
        rings.append(ring)
    m = len(S)
    for a in range(len(zs) - 1):
        Va = (zs[a] - z1) / 16.0; Vb = (zs[a + 1] - z1) / 16.0
        for i in range(m):
            j = (i + 1) % m
            Ui = S[i][2] / tl; Uj = (S[j][2] if j else L) / tl
            quad = [rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]]
            out = Vector((S[i][1].x + S[j][1].x, S[i][1].y + S[j][1].y, 0))
            mb.face(quad, tiled(R_CLIFF, [(Ui, Va), (Uj, Va), (Uj, Vb), (Ui, Vb)]), want=out, kind=0)
    # ---- cap
    C, Lc, tlc = resample(poly, cap_sub, keep=keep)
    R = Lc / (2 * math.pi) * 0.33

    def droop(t):
        a = 2 * math.pi * t / Lc
        n1 = mnoise.noise(Vector((math.cos(a) * R, math.sin(a) * R, seed * 3.7)))
        p1 = Lc / max(1, round(Lc / 3.3)); p2 = Lc / max(1, round(Lc / 8.5))
        s1 = 0.5 + 0.5 * math.sin(2 * math.pi * t / p1 + seed)
        s2 = 0.5 + 0.5 * math.sin(2 * math.pi * t / p2 + seed * 1.9)
        return droop_amp * max(0.05, 0.3 + 0.55 * s1 ** 2 + 0.3 * s2 + 0.35 * n1)
    # insert samples so ring A crosses the 16-stud grid on vertices
    Cx = []
    for i in range(len(C)):
        p, n, t = C[i]
        p2, n2, t2 = C[(i + 1) % len(C)]
        if i == len(C) - 1: t2 = Lc
        Cx.append((p, n, t))
        A1 = p - n * inset; A2 = p2 - n2 * inset
        fs = []
        for ax in (0, 1):
            lo, hi = sorted((A1[ax], A2[ax]))
            for g in range(math.floor(lo / 16) + 1, math.ceil(hi / 16)):
                gv = g * 16.0
                if lo + 1e-4 < gv < hi - 1e-4:
                    fs.append((gv - A1[ax]) / (A2[ax] - A1[ax]))
        for f in sorted(fs):
            Cx.append((p.lerp(p2, f), n.lerp(n2, f), t + (t2 - t) * f))
    C = Cx
    ringsC = {k: [] for k in 'ABCDE'}
    VB = (inset + 0.45) / 16
    Vs = {'A': 0.0, 'B': VB, 'C': VB + 1.0 / 16, 'D': VB + 2.4 / 16, 'E': VB + 3.3 / 16}
    for (p, n, t) in C:
        d = droop(t)
        bump = 0.12 * mnoise.noise(Vector((p.x * 0.3, p.y * 0.3, seed)))
        ringsC['A'].append(mb.v((p.x - n.x * inset, p.y - n.y * inset, z1 + 0.95 + bump)))
        ringsC['B'].append(mb.v((p.x + n.x * 0.45, p.y + n.y * 0.45, z1 + 0.78 + bump * 0.5)))
        o = lip + 0.12 * d
        ringsC['C'].append(mb.v((p.x + n.x * o, p.y + n.y * o, z1 - 0.12 - 0.25 * d)))
        o = lip - 0.18 + 0.12 * d
        ringsC['D'].append(mb.v((p.x + n.x * o, p.y + n.y * o, z1 - 1.0 - d)))
        ringsC['E'].append(mb.v((p.x - n.x * 0.4, p.y - n.y * 0.4, z1 - 0.7 - 0.5 * d)))
    mc = len(C)
    order = 'ABCDE'
    for q in range(4):
        X, Y = ringsC[order[q]], ringsC[order[q + 1]]
        vx, vy = Vs[order[q]], Vs[order[q + 1]]
        for i in range(mc):
            j = (i + 1) % mc
            Ui = C[i][2] / tlc; Uj = (C[j][2] if j else Lc) / tlc
            quad = [X[i], Y[i], Y[j], X[j]]
            nrm = newell([v.co for v in quad])
            mb.face(quad, tiled(R_GRASS, [(Ui, vx), (Ui, vy), (Uj, vy), (Uj, vx)]), kind=1)
    # ---- top fill, split on the 16-stud grid so the atlas tile never wraps inside a face
    ringA = ringsC['A']
    top = mb.bm.faces.new(ringA)
    top.smooth = True
    top[mb.kind] = 2
    top.normal_update()
    if top.normal.z < 0:
        top.normal_flip()
    xs = [v.co.x for v in ringA]; ys = [v.co.y for v in ringA]
    for ax, lo, hi in ((0, min(xs), max(xs)), (1, min(ys), max(ys))):
        for g in range(math.floor(lo / 16) + 1, math.ceil(hi / 16)):
            faces = [f for f in mb.bm.faces if f[mb.kind] == 2]
            geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
            co = Vector((g * 16.0, 0, 0)) if ax == 0 else Vector((0, g * 16.0, 0))
            no = Vector((1, 0, 0)) if ax == 0 else Vector((0, 1, 0))
            bmesh.ops.bisect_plane(mb.bm, geom=geom, dist=1e-4, plane_co=co, plane_no=no)
    for f in mb.bm.faces:
        if f[mb.kind] == 2:
            f.smooth = True
            UV = [(lp.vert.co.x / 16.0, lp.vert.co.y / 16.0) for lp in f.loops]
            for lp, uv in zip(f.loops, tiled(R_GRASS, UV)):
                lp[mb.uv].uv = uv
            f[mb.kind] = 3
    top_poly = [Vector((v.co.x, v.co.y)) for v in ringA]
    return top_poly, z1 + 0.95


# ----------------------------------------------------------------------------------------------
# Plants
# ----------------------------------------------------------------------------------------------
def frond(mb, base, dirh, L, W, rise, droop, N, uvf, thick=0.09, notch=0.6, tipw=1.0, fold=0.3, curl=0.12,
          petiole=0.1, tipf=0.85):
    dirh = Vector((dirh.x, dirh.y, 0)).normalized()
    pts = []
    for k in range(N + 1):
        u = k / N
        pts.append(base + dirh * (L * (u - curl * u * u)) + Vector((0, 0, L * (rise * u - droop * u * u))))

    def width(u):
        if u <= petiole:
            return W * 0.05
        x = (u - petiole) / (1 - petiole)
        return W * max(0.05, math.sin(math.pi * min(1.0, 0.07 + x * 0.93)) ** 0.5 * (1 - 0.3 * x))
    st = []
    for k in range(N + 1):
        T = (pts[min(N, k + 1)] - pts[max(0, k - 1)]).normalized()
        S = T.cross(Vector((0, 0, 1)))
        if S.length < 1e-4:
            S = Vector((0, 1, 0))
        S.normalize()
        Nn = S.cross(T).normalized()
        st.append((pts[k], T, S, Nn, width(k / N)))
    for sheet in (0, 1):
        rows = []
        for (P, T, S, Nn, w) in st:
            Pc = P - Nn * (thick if sheet else 0)
            rows.append((mb.v(Pc + Nn * (0.1 * w)), mb.v(Pc + S * (notch * w) - Nn * (fold * w)),
                         mb.v(Pc - S * (notch * w) - Nn * (fold * w))))
        tips = []
        for k in range(N):
            P = st[k][0].lerp(st[k + 1][0], tipf)
            S = st[k][2].lerp(st[k + 1][2], tipf).normalized()
            Nn = st[k][3].lerp(st[k + 1][3], tipf).normalized()
            w = (st[k][4] * (1 - tipf) + st[k + 1][4] * tipf) * tipw
            Pc = P - Nn * (thick if sheet else 0)
            tips.append((mb.v(Pc + S * w - Nn * (fold * 1.6 * w)), mb.v(Pc - S * w - Nn * (fold * 1.6 * w))))
        for k in range(N):
            r0, rn0, ln0 = rows[k]; r1, rn1, ln1 = rows[k + 1]; rt, lt = tips[k]
            u0 = k / N; u1 = (k + 1) / N; ut = (k + tipf) / N
            want = st[k][3] * (-1 if sheet else 1)
            mb.face([r0, rn0, rt, rn1, r1], [uvf(0.5, u0), uvf(0.5 + 0.31, u0), uvf(0.99, ut), uvf(0.81, u1), uvf(0.5, u1)], want=want)
            mb.face([r0, r1, ln1, lt, ln0], [uvf(0.5, u0), uvf(0.5, u1), uvf(0.19, u1), uvf(0.01, ut), uvf(0.19, u0)], want=want)


def leaf(mb, base, axis, up, L, W, uvf, droop=0.25, fold=0.18, thick=0.05, stations=4, shape='oval'):
    """Generic broad leaf along axis (unit), 'up' = leaf surface normal-ish."""
    axis = axis.normalized()
    side = axis.cross(up).normalized()
    up = side.cross(axis).normalized()
    for sheet in (0, 1):
        o = -up * (thick if sheet else 0)
        rows = []
        for k in range(stations + 1):
            u = k / stations
            if shape == 'heart':
                w = W * (math.sin(math.pi * min(1, u * 0.9 + 0.1)) ** 0.7) * (1.0 - 0.25 * u)
            elif shape == 'strap':
                w = W * (1 - u ** 1.6)
            else:
                w = W * math.sin(math.pi * u) ** 0.8
            c = base + axis * (L * u) - up * (droop * L * u * u) + o
            rows.append((mb.v(c + up * 0.03 * L), mb.v(c + side * w - up * fold * w), mb.v(c - side * w - up * fold * w), u))
        want = -up if sheet else up
        for k in range(stations):
            a, b = rows[k], rows[k + 1]
            mb.face([a[0], a[1], b[1], b[0]], [uvf(0.5, a[3]), uvf(1.0, a[3]), uvf(1.0, b[3]), uvf(0.5, b[3])], want=want)
            mb.face([a[0], b[0], b[2], a[2]], [uvf(0.5, a[3]), uvf(0.5, b[3]), uvf(0.0, b[3]), uvf(0.0, a[3])], want=want)


def palm_piece(name, mat, height, lean, sway, nseg, r0, r1, nf, flen, fw, seed, coll):
    rnd = random.Random(seed)
    mb = MB(name)
    P0 = Vector((0, 0, 0)); P3 = Vector((lean, 0, height))
    P1 = Vector((-sway * lean, 0, height * 0.36)); P2 = Vector((lean * 0.55, 0, height * 0.72))

    def spine(t):
        return (P0 * (1 - t) ** 3 + P1 * 3 * t * (1 - t) ** 2 + P2 * 3 * t * t * (1 - t) + P3 * t ** 3)

    def tangent(t):
        return (spine(min(1, t + 1e-3)) - spine(max(0, t - 1e-3))).normalized()

    def rad(t):
        return r0 + (r1 - r0) * t
    bands = [(0.092, 0.258), (0.258, 0.419), (0.419, 0.577), (0.577, 0.746), (0.746, 0.92)]
    # Frozen kit (imported in Studio): original rings. Import-safe fallback: ring heights increase
    # monotonically (the frozen flare ring sits above the first segment ring, folding 8 faces back).
    ts = 0.035 if SAFE_GEOMETRY else 0.0
    flare_z = 0.1 if SAFE_GEOMETRY else 0.35
    ringspec = [(spine(0) - Vector((0, 0, 1.0)), Vector((0, 0, 1)), r0 * 1.55, None),
                (spine(0) + Vector((0, 0, flare_z)), Vector((0, 0, 1)), r0 * 1.28, None)]
    for k in range(nseg):
        dt = (1 - ts) / nseg; t0 = ts + k * dt
        for f, mult in ((0.0, 0.9), (0.55, 1.0), (0.9, 1.13)):
            t = t0 + f * dt
            ringspec.append((spine(t), tangent(t), rad(t) * mult, (k, f)))
    ringspec.append((spine(1), tangent(1), rad(1) * 0.9, (nseg, 0.0)))
    sides = 8
    uvb = lambda fu, fv: ruv(R_BARK, fu, fv)
    rings = []
    for (P, T, r, tag) in ringspec:
        e1, e2 = ring_frame(T)
        rings.append([mb.v(P + (e1 * math.cos(2 * math.pi * j / sides) + e2 * math.sin(2 * math.pi * j / sides)) * r)
                      for j in range(sides)])

    def fv_of(idx, as_top):
        tag = ringspec[idx][3]
        if tag is None:
            return (0.1, 0.2)[idx] if idx < 2 else 0.2
        k, f = tag
        if as_top and f == 0.0:
            lo, hi = bands[(k - 1) % 5]
            return hi
        lo, hi = bands[k % 5]
        return lo + f * (hi - lo)
    for a in range(len(rings) - 1):
        va = fv_of(a, False)
        vb = fv_of(a + 1, True)
        if a == 0:
            va, vb = 0.02, 0.09
        elif a == 1:
            va, vb = 0.09, bands[0][0]
        c = (ringspec[a][0] + ringspec[a + 1][0]) / 2
        for j in range(sides):
            j2 = (j + 1) % sides
            quad = [rings[a][j], rings[a][j2], rings[a + 1][j2], rings[a + 1][j]]
            mid = sum((q.co for q in quad), Vector()) / 4
            mb.face(quad, [uvb(j / sides, va), uvb((j + 1) / sides, va), uvb((j + 1) / sides, vb), uvb(j / sides, vb)],
                    want=mid - c)
    # crown knob (fibre) + coconuts
    top = spine(1); T = tangent(1)
    uvc = lambda fu, fv: ruv(sw_rect('coconut'), fu, fv)
    kp = [top, top + T * 0.8, top + T * 1.6, top + T * 2.3]
    kr = [r1 * 0.9, r1 * 1.3, r1 * 1.05, r1 * 0.35]
    last = rings[-1]
    add_tube(mb, kp, kr, sides, uvc, cap_end=True)
    e1, e2 = ring_frame(T)
    ncoco = 3 + (seed % 2)
    for i in range(ncoco):
        a = 2 * math.pi * i / ncoco + rnd.uniform(-.3, .3)
        cpos = top + T * 0.5 + (e1 * math.cos(a) + e2 * math.sin(a)) * (r1 * 1.25) - Vector((0, 0, 0.5))
        add_sphere(mb, cpos, (0.85, 0.85, 0.95), 8, 5, uvc)
    # fronds
    base = top + T * 1.5
    uvf = lambda fu, fv: ruv(R_FROND, fu, fv)
    for i in range(nf):
        a = 2 * math.pi * i / nf + rnd.uniform(-0.18, 0.18)
        upper = i % 2 == 0
        L = flen * rnd.uniform(0.9, 1.08) * (0.92 if upper else 1.0)
        rise = rnd.uniform(0.55, 0.75) if upper else rnd.uniform(0.2, 0.38)
        dro = rnd.uniform(0.95, 1.15) if upper else rnd.uniform(0.85, 1.05)
        frond(mb, base, Vector((math.cos(a), math.sin(a), 0)), L, fw * rnd.uniform(0.92, 1.08), rise, dro, 11, uvf)
    return mb.finish(mat, sharp_deg=75, collection=coll)


def fern_piece(name, mat, coll, seed=11):
    rnd = random.Random(seed)
    mb = MB(name)
    uvf = lambda fu, fv: ruv(R_FROND, fu, fv)
    n = 11
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-.2, .2)
        inner = i % 2 == 0
        L = rnd.uniform(4.4, 5.2) if inner else rnd.uniform(5.4, 6.2)
        rise = rnd.uniform(1.7, 2.0) if inner else rnd.uniform(1.3, 1.55)
        dro = rise - 0.35 if inner else rise + 0.02
        frond(mb, Vector((0, 0, 0.15)), Vector((math.cos(a), math.sin(a), 0)), L, 1.15, rise, dro, 10, uvf,
              thick=0.05, notch=0.32, tipw=1.05, fold=0.18, curl=0.18, petiole=0.08, tipf=0.8)
    return mb.finish(mat, sharp_deg=80, collection=coll)


def bush_a_piece(name, mat, coll, seed=21):
    """Round dense leafy bush (3 lobes of leaves around leafy cores)."""
    rnd = random.Random(seed)
    mb = MB(name)
    uvl = lambda fu, fv: ruv(sw_rect('broadleaf'), fu, fv)
    uvm = lambda fu, fv: ruv(sw_rect('moss'), fu, fv)
    lobes = [((0, 0, 1.9), (2.6, 2.4, 2.0)), ((1.9, 1.1, 1.3), (1.8, 1.7, 1.4)), ((-1.6, 1.4, 1.2), (1.7, 1.6, 1.3))]
    for (c, r) in lobes:
        add_sphere(mb, c, r, 10, 6, uvm, deform=lambda p: p * (1 + 0.1 * mnoise.noise(p * 1.4 + Vector((seed, 0, 0)))))
    for (c, r) in lobes:
        c = Vector(c)
        nl = int(26 * r[0] / 2.6)
        for i in range(nl):
            z = rnd.uniform(-0.25, 1.0)
            a = rnd.uniform(0, 2 * math.pi)
            q = math.sqrt(max(0, 1 - z * z))
            nrm = Vector((q * math.cos(a), q * math.sin(a), z)).normalized()
            p = c + Vector((nrm.x * r[0], nrm.y * r[1], nrm.z * r[2])) * 0.82
            axis = (nrm + Vector((rnd.uniform(-.4, .4), rnd.uniform(-.4, .4), -0.15))).normalized()
            up = (Vector((0, 0, 1)) - axis * axis.z).normalized() if abs(axis.z) < 0.95 else Vector((1, 0, 0))
            leaf(mb, p, axis, up, rnd.uniform(1.5, 2.1), rnd.uniform(0.5, 0.65), uvl, droop=0.15, fold=0.2, stations=2)
    return mb.finish(mat, sharp_deg=80, collection=coll)


def bush_b_piece(name, mat, coll, seed=31):
    """Broad-leaf tropical plant (elephant-ear style) on petioles."""
    rnd = random.Random(seed)
    mb = MB(name)
    uvl = lambda fu, fv: ruv(sw_rect('broadleaf'), fu, fv)
    uvs = lambda fu, fv: ruv(sw_rect('stem'), fu, fv)
    n = 8
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-.25, .25)
        d = Vector((math.cos(a), math.sin(a), 0))
        hgt = rnd.uniform(2.2, 3.8)
        out = rnd.uniform(1.0, 2.0)
        p0 = Vector((0, 0, 0)); p1 = d * (out * 0.4) + Vector((0, 0, hgt * 0.6)); p2 = d * out + Vector((0, 0, hgt))
        add_tube(mb, [p0, p1, p2], [0.14, 0.11, 0.08], 4, uvs)
        axis = (d * 1.0 + Vector((0, 0, rnd.uniform(0.1, 0.5)))).normalized()
        up = (Vector((0, 0, 1)) - axis * axis.z).normalized()
        leaf(mb, p2, axis, up, rnd.uniform(3.0, 3.8), rnd.uniform(1.2, 1.5), uvl, droop=0.3, fold=0.15, stations=6,
             shape='heart')
    return mb.finish(mat, sharp_deg=80, collection=coll)


def bromeliad_piece(name, mat, coll, seed=41):
    rnd = random.Random(seed)
    mb = MB(name)
    uvb = lambda fu, fv: ruv(sw_rect('bromeliad'), fu, fv)
    specs = [(9, 2.9, 0.45, 0.6, 0.62 + 0.4), (7, 2.3, 0.38, 1.1, 1.2), (5, 1.5, 0.3, 1.7, 1.3)]
    for (n, L, W, rise, dro) in specs:
        off = rnd.uniform(0, 1)
        for i in range(n):
            a = 2 * math.pi * (i + off) / n
            d = Vector((math.cos(a), math.sin(a), 0))
            N = 6
            pts = [Vector((0, 0, 0.1)) + d * (L * u * (1 - 0.1 * u)) + Vector((0, 0, L * (rise * u - (dro - 0.4) * u * u)))
                   for u in [k / N for k in range(N + 1)]]
            for sheet in (0, 1):
                rows = []
                for k in range(N + 1):
                    u = k / N
                    T = (pts[min(N, k + 1)] - pts[max(0, k - 1)]).normalized()
                    S = T.cross(Vector((0, 0, 1))).normalized()
                    Nn = S.cross(T).normalized()
                    w = W * (1 - u ** 1.8) + 0.02
                    P = pts[k] - Nn * (0.04 if sheet else 0)
                    rows.append((mb.v(P - Nn * 0.12 * w), mb.v(P + S * w + Nn * 0.3 * w), mb.v(P - S * w + Nn * 0.3 * w), u, Nn))
                for k in range(N):
                    A, B = rows[k], rows[k + 1]
                    want = A[4] * (-1 if sheet else 1)
                    mb.face([A[0], A[1], B[1], B[0]], [uvb(0.5, A[3]), uvb(1, A[3]), uvb(1, B[3]), uvb(0.5, B[3])], want=want)
                    mb.face([A[0], B[0], B[2], A[2]], [uvb(0.5, A[3]), uvb(0.5, B[3]), uvb(0, B[3]), uvb(0, A[3])], want=want)
    # central bloom spike
    uvp = lambda fu, fv: ruv(sw_rect('petal'), fu, fv)
    add_tube(mb, [Vector((0, 0, 0.3)), Vector((0, 0, 1.2)), Vector((0, 0, 1.8))], [0.32, 0.26, 0.12], 6, uvp, cap_end=True)
    return mb.finish(mat, sharp_deg=80, collection=coll)


def sunflower_piece(name, mat, coll, seed=51):
    rnd = random.Random(seed)
    mb = MB(name)
    uvs = lambda fu, fv: ruv(sw_rect('stem'), fu, fv)
    uvl = lambda fu, fv: ruv(sw_rect('broadleaf'), fu, fv)
    uvp = lambda fu, fv: ruv(sw_rect('petal'), fu, fv)
    uvc = lambda fu, fv: ruv(sw_rect('sunc'), fu, fv)
    for (bx, by, h, hs) in ((0.0, 0.0, 4.4, 0.8), (0.8, 1.1, 3.3, 0.68), (-0.7, -0.9, 2.5, 0.58)):
        base = Vector((bx, by, -0.2))
        lean = Vector((rnd.uniform(0.1, 0.4), rnd.uniform(-.2, .2), 0))
        pts = [base + lean * (u * u) + Vector((0, 0, (h + 0.2) * u)) for u in (0, .25, .5, .75, 1.0)]
        add_tube(mb, pts, [0.16, 0.15, 0.14, 0.12, 0.1], 6, uvs)
        for k, (u, a) in enumerate(((0.3, rnd.uniform(0, 6.28)), (0.52, rnd.uniform(0, 6.28)), (0.7, rnd.uniform(0, 6.28)))):
            p = base + lean * (u * u) + Vector((0, 0, (h + 0.2) * u))
            ax = Vector((math.cos(a), math.sin(a), 0.35)).normalized()
            leaf(mb, p, ax, Vector((0, 0, 1)), 1.6 * hs, 0.75 * hs, uvl, droop=0.35, stations=4, shape='heart')
        C = pts[-1] + Vector((0.15, 0, 0.1))
        F = Vector((1.0, rnd.uniform(-0.25, 0.25), 0.35)).normalized()  # faces local +X (towards the track)
        e1, e2 = ring_frame(F)
        R = 1.0 * hs
        # centre disc (dome) and green back
        cen = mb.v(C + F * 0.35 * hs)
        ring1 = [mb.v(C + F * 0.26 * hs + (e1 * math.cos(2 * math.pi * j / 12) + e2 * math.sin(2 * math.pi * j / 12)) * 0.6 * R) for j in range(12)]
        ring2 = [mb.v(C + F * 0.05 * hs + (e1 * math.cos(2 * math.pi * j / 12) + e2 * math.sin(2 * math.pi * j / 12)) * 1.0 * R) for j in range(12)]
        ring3 = [mb.v(C - F * 0.12 * hs + (e1 * math.cos(2 * math.pi * j / 12) + e2 * math.sin(2 * math.pi * j / 12)) * 0.95 * R) for j in range(12)]
        back = mb.v(C - F * 0.45 * hs)

        def cuv(j, r):
            a = 2 * math.pi * j / 12
            return uvc(0.5 + 0.5 * r * math.cos(a), 0.5 + 0.5 * r * math.sin(a))
        for j in range(12):
            j2 = (j + 1) % 12
            mb.face([cen, ring1[j], ring1[j2]], [uvc(.5, .5), cuv(j, .6), cuv(j + 1, .6)], want=F)
            mb.face([ring1[j], ring2[j], ring2[j2], ring1[j2]], [cuv(j, .6), cuv(j, .98), cuv(j + 1, .98), cuv(j + 1, .6)], want=F)
            mb.face([ring2[j], ring3[j], ring3[j2], ring2[j2]], [uvs(0, .4), uvs(0, .6), uvs(1, .6), uvs(1, .4)],
                    want=(ring2[j].co - C))
            mb.face([ring3[j], back, ring3[j2]], [uvs(0, .6), uvs(.5, .9), uvs(1, .6)], want=-F)
        # petals: two layers
        for layer, (npet, rot, zoff, ln) in enumerate(((14, 0.0, 0.02, 1.25), (14, 0.5, -0.06, 1.1))):
            for j in range(npet):
                a = 2 * math.pi * (j + rot) / npet
                rd = e1 * math.cos(a) + e2 * math.sin(a)
                sd = F.cross(rd).normalized()
                b0 = C + rd * 0.9 * R + F * zoff * hs
                tip = C + rd * (0.9 + ln) * R + F * (zoff + 0.12 - 0.08 * layer) * hs
                mid = C + rd * (0.9 + ln * 0.45) * R + F * (zoff + 0.06) * hs
                for sheet in (0, 1):
                    o = -F * (0.03 if sheet else 0)
                    vb = mb.v(b0 + o); vt = mb.v(tip + o); vl = mb.v(mid + sd * 0.26 * R + o); vr = mb.v(mid - sd * 0.26 * R + o)
                    want = -F if sheet else F
                    mb.face([vb, vr, vt, vl], [uvp(.5, 0), uvp(1, .45), uvp(.5, 1), uvp(0, .45)], want=want)
    return mb.finish(mat, sharp_deg=80, collection=coll)


def rock_a_piece(name, mat, coll):
    mb = MB(name)
    z0 = add_icorock(mb, (0, 0, 0), (3.3, 2.7, 2.5), 4, 7, sw_rect('rock'), cuts=6)
    ob = mb.finish(mat, sharp_deg=None, collection=coll)
    ground(ob, 0.45)
    return ob


def rock_b_piece(name, mat, coll):
    mb = MB(name)
    for (c, s, seed) in (((0, 0, 0), (2.2, 1.9, 1.7), 3), ((2.6, 1.3, 0), (1.4, 1.2, 1.1), 5), ((-1.9, 1.8, 0), (1.1, 1.0, 0.9), 9)):
        add_icorock(mb, c, s, 3, seed, sw_rect('rock'), cuts=4, flatten=-0.3)
    ob = mb.finish(mat, collection=coll)
    ground(ob, 0.35)
    return ob


def ground(ob, sink):
    """Shift mesh so its lowest point sits 'sink' below z=0 (pivot = ground line)."""
    zs = [v.co.z for v in ob.data.vertices]
    dz = -min(zs) - sink
    for v in ob.data.vertices:
        v.co.z += dz


def grass_tuft_piece(name, mat, coll, seed=61):
    rnd = random.Random(seed)
    mb = MB(name)
    uvt = lambda fu, fv: ruv(sw_rect('tuft'), fu, fv)
    for i in range(44):
        y = rnd.uniform(-3.6, 3.6); x = rnd.uniform(-1.1, 1.1) * (1 - (y / 4.2) ** 2)
        h = rnd.uniform(1.0, 2.3) * (1 - 0.35 * (abs(y) / 3.6))
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0))
        bend = rnd.uniform(0.3, 0.8) * h
        base = Vector((x, y, -0.1))
        w = rnd.uniform(0.16, 0.24)
        mid = base + Vector((0, 0, h * 0.55)) + d * bend * 0.3
        tip = base + Vector((0, 0, h)) + d * bend
        for sheet in (0, 1):
            o = d * (0.02 if sheet else 0)
            b0 = mb.v(base + s * w + o); b1 = mb.v(base - s * w + o); m0 = mb.v(mid + s * w * 0.6 + o); m1 = mb.v(mid - s * w * 0.6 + o)
            t = mb.v(tip + o)
            want = -d if sheet else d
            mb.face([b0, b1, m1, m0], [uvt(0, 0), uvt(1, 0), uvt(1, .55), uvt(0, .55)], want=want)
            mb.face([m0, m1, t], [uvt(0, .55), uvt(1, .55), uvt(.5, 1)], want=want)
    return mb.finish(mat, collection=coll)


def flower_patch_piece(name, mat, coll, seed=71):
    rnd = random.Random(seed)
    mb = MB(name)
    uvd = lambda fu, fv: ruv(sw_rect('daisy'), fu, fv)
    uvs = lambda fu, fv: ruv(sw_rect('stem'), fu, fv)
    uvt = lambda fu, fv: ruv(sw_rect('tuft'), fu, fv)
    for i in range(9):
        p = Vector((rnd.uniform(-2.2, 2.2), rnd.uniform(-2.2, 2.2), -0.1))
        h = rnd.uniform(0.7, 1.4)
        pink = rnd.random() < 0.35
        c = p + Vector((rnd.uniform(-.15, .15), rnd.uniform(-.15, .15), h))
        add_tube(mb, [p, c], [0.06, 0.05], 3, uvs)
        F = Vector((rnd.uniform(-.3, .3), rnd.uniform(-.3, .3), 1)).normalized()
        e1, e2 = ring_frame(F)
        cu = 0.75 if pink else 0.25
        cen = mb.v(c + F * 0.12)
        rr = [mb.v(c + (e1 * math.cos(2 * math.pi * j / 6) + e2 * math.sin(2 * math.pi * j / 6)) * 0.14) for j in range(6)]
        for j in range(6):
            mb.face([cen, rr[j], rr[(j + 1) % 6]], [uvd(cu, .95), uvd(cu, .9), uvd(cu, .92)], want=F)
        for j in range(8):
            a = 2 * math.pi * j / 8
            rd = e1 * math.cos(a) + e2 * math.sin(a)
            sd = F.cross(rd)
            for sheet in (0, 1):
                o = -F * (0.02 if sheet else 0)
                vb = mb.v(c + rd * 0.1 + o); vt = mb.v(c + rd * 0.62 + F * 0.05 + o)
                vl = mb.v(c + rd * 0.36 + sd * 0.12 + o); vr = mb.v(c + rd * 0.36 - sd * 0.12 + o)
                mb.face([vb, vr, vt, vl], [uvd(cu, .1), uvd(cu + .1, .4), uvd(cu, .7), uvd(cu - .1, .4)], want=(-F if sheet else F))
    for i in range(14):
        base = Vector((rnd.uniform(-2.4, 2.4), rnd.uniform(-2.4, 2.4), -0.1))
        a = rnd.uniform(0, 6.28); d = Vector((math.cos(a), math.sin(a), 0)); s = Vector((-d.y, d.x, 0))
        h = rnd.uniform(0.6, 1.1)
        for sheet in (0, 1):
            o = d * (0.02 if sheet else 0)
            b0 = mb.v(base + s * 0.14 + o); b1 = mb.v(base - s * 0.14 + o); t = mb.v(base + Vector((0, 0, h)) + d * 0.35 + o)
            mb.face([b0, b1, t], [uvt(0, 0), uvt(1, 0), uvt(.5, 1)], want=(-d if sheet else d))
    return mb.finish(mat, collection=coll)


# ----------------------------------------------------------------------------------------------
# Terrain pieces
# ----------------------------------------------------------------------------------------------
TERRACE_H = 48.0
PLATEAUS = {}  # kit name -> list of (top_poly local 2D, top z local, wall poly)


def terrace_rect(name, mat, coll, dx, dy, seed, r=4.0):
    mb = MB(name)
    poly = rounded_poly([(-dx / 2, -dy / 2), (dx / 2, -dy / 2), (dx / 2, dy / 2), (-dx / 2, dy / 2)], r)
    tp, tz = plateau(mb, poly, 0.0, TERRACE_H, seed)
    PLATEAUS[name] = [(tp, tz, poly)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


def terrace_corner(name, mat, coll, seed=5):
    mb = MB(name)
    a, d = 36.0, 20.0
    pts = [(0, 0), (a, 0), (a, d), (d, d), (d, a), (0, a)]
    pts = [(x - a / 2, y - a / 2) for x, y in pts]
    poly = rounded_poly(pts, 4.0)
    tp, tz = plateau(mb, poly, 0.0, TERRACE_H, seed)
    PLATEAUS[name] = [(tp, tz, poly)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


def terrace_round(name, mat, coll, seed=9):
    mb = MB(name)
    poly = blob_poly(14.0, 13.0, 48, 0.035, seed)
    tp, tz = plateau(mb, poly, 0.0, TERRACE_H, seed, wall_sub=3.0, cap_sub=1.6, keep=False)
    PLATEAUS[name] = [(tp, tz, poly)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


def mesa_tall(name, mat, coll, seed=13):
    mb = MB(name)
    lo = blob_poly(22.0, 21.0, 64, 0.05, seed)
    hi = blob_poly(13.5, 13.0, 48, 0.05, seed + 4, offset=(2.5, -1.5))
    t1, z1 = plateau(mb, lo, 0.0, 64.0, seed, lip=1.5, wall_sub=3.2, cap_sub=2.4, keep=False)
    t2, z2 = plateau(mb, hi, 62.0, 96.0, seed + 1, lip=1.4, wall_sub=3.0, cap_sub=2.2, keep=False)
    PLATEAUS[name] = [(t1, z1, lo), (t2, z2, hi)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


def mesa_wide(name, mat, coll, seed=17):
    mb = MB(name)
    lo = blob_poly(40.0, 29.0, 80, 0.06, seed)
    hi = blob_poly(17.0, 14.0, 48, 0.06, seed + 3, offset=(12.0, 5.0))
    t1, z1 = plateau(mb, lo, 0.0, 44.0, seed, lip=1.5, wall_sub=4.0, cap_sub=2.6, keep=False)
    t2, z2 = plateau(mb, hi, 42.0, 62.0, seed + 1, lip=1.4, wall_sub=3.0, cap_sub=2.2, keep=False)
    PLATEAUS[name] = [(t1, z1, lo), (t2, z2, hi)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


def mesa_spire(name, mat, coll, seed=23):
    mb = MB(name)
    poly = blob_poly(12.5, 11.5, 48, 0.06, seed)
    tp, tz = plateau(mb, poly, 0.0, 88.0, seed, lip=1.3, taper=0.03, wall_sub=3.0, cap_sub=2.0, keep=False)
    PLATEAUS[name] = [(tp, tz, poly)]
    return mb.finish(mat, sharp_deg=70, collection=coll)


# ----------------------------------------------------------------------------------------------
# Props
# ----------------------------------------------------------------------------------------------
def fence_piece(name, mat, coll):
    mb = MB(name)
    uvw = lambda fu, fv: ruv(sw_rect('wood'), fu, fv)
    uvr = lambda fu, fv: ruv(sw_rect('rope'), fu, fv)
    for py in (-8.0, 8.0):
        c = Vector((0, py, 0))
        pts = [c + Vector((0, 0, -1.0)), c + Vector((0, 0, 3.0)), c + Vector((0, 0, 3.3))]
        add_tube(mb, pts, [0.5, 0.5, 0.44], 8, uvw, cap_end=True)
        for zr in (1.55, 2.65):
            k = [c + Vector((0, 0, zr - 0.16)), c + Vector((0, 0, zr)), c + Vector((0, 0, zr + 0.16))]
            add_tube(mb, k, [0.51, 0.56, 0.51], 8, uvr)
    for zr in (1.55, 2.65):
        pts = []
        n = 8
        for k in range(n + 1):
            u = k / n
            y = -7.5 + 15.0 * u
            pts.append(Vector((0, y, zr - 0.38 * math.sin(math.pi * u))))
        add_tube(mb, pts, [0.15] * (n + 1), 6, uvr)
    return mb.finish(mat, sharp_deg=60, collection=coll)


def box_bevel(mb, x0, x1, y0, y1, z0, z1, bev, uvtop, uvside):
    lo = [Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)), Vector((x0, y1, z0))]
    mid = [Vector((p.x, p.y, z1 - bev)) for p in lo]
    top = [Vector((x0 + bev, y0 + bev, z1)), Vector((x1 - bev, y0 + bev, z1)), Vector((x1 - bev, y1 - bev, z1)), Vector((x0 + bev, y1 - bev, z1))]
    L = [mb.v(p) for p in lo]; M = [mb.v(p) for p in mid]; T = [mb.v(p) for p in top]
    c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    for i in range(4):
        j = (i + 1) % 4
        for A, B, v0, v1 in ((L, M, 0.0, 0.7), (M, T, 0.7, 1.0)):
            quad = [A[i], A[j], B[j], B[i]]
            mid_ = sum((q.co for q in quad), Vector()) / 4
            out = mid_ - c; out.z *= 0.3
            mb.face(quad, [uvside(0, v0), uvside(1, v0), uvside(1, v1), uvside(0, v1)], want=out)
    mb.face(T, [uvtop((p.x - x0) / (x1 - x0), (p.y - y0) / (y1 - y0)) for p in top], want=(0, 0, 1))


def speedpad_piece(name, mat, coll):
    mb = MB(name)
    uvr = lambda fu, fv: ruv(sw_rect('padred'), fu, fv)
    uvy = lambda fu, fv: ruv(sw_rect('chevron'), fu, fv)
    uvs = lambda fu, fv: ruv(sw_rect('steel'), fu, fv)
    box_bevel(mb, -7.6, 7.6, -8.0, 8.0, 0.0, 0.3, 0.12, uvr, lambda fu, fv: uvr(fu, 0.1 + 0.3 * fv))
    # three chevrons pointing forward (+Y Blender = -Z Roblox = race direction)
    for a in (-7.0, -2.6, 1.8):
        hw, ih, th = 5.1, 3.0, 1.75
        P = [(-hw, a), (0, a + ih), (hw, a), (hw, a + th), (0, a + ih + th * 1.35), (-hw, a + th)]
        z0, z1 = 0.29, 0.37
        bot = [mb.v((x, y, z0)) for x, y in P]
        top = [mb.v((x, y, z1)) for x, y in P]
        mb.face([top[0], top[1], top[4], top[5]], [uvy(0, 0), uvy(.5, .3), uvy(.5, 1), uvy(0, .7)], want=(0, 0, 1))
        mb.face([top[1], top[2], top[3], top[4]], [uvy(.5, .3), uvy(1, 0), uvy(1, .7), uvy(.5, 1)], want=(0, 0, 1))
        cc = Vector((0, a + ih * 0.6, 0.33))
        for i in range(6):
            j = (i + 1) % 6
            quad = [bot[i], bot[j], top[j], top[i]]
            e = top[j].co - top[i].co
            out = Vector((e.y, -e.x, 0))
            mb.face(quad, [uvy(0, 0), uvy(1, 0), uvy(1, .2), uvy(0, .2)], want=out)
    # rails with a dark centre channel
    prof = [(0.0, 0.0), (0.0, 0.35), (0.15, 0.44), (0.5, 0.44), (0.55, 0.38), (0.85, 0.38), (0.9, 0.44), (1.25, 0.44), (1.4, 0.35), (1.4, 0.0)]
    fus = [0.0, 0.15, 0.3, 0.45, 0.8, 0.85, 0.9, 0.5, 0.35, 0.2]
    for sgn in (-1, 1):
        x0 = 7.6 if sgn > 0 else -7.6
        pts = [(x0 + sgn * px, pz) for px, pz in prof]
        rows = []
        for y in (-8.0, 8.0):
            rows.append([mb.v((x, y, z)) for x, z in pts])
        cx = x0 + sgn * 0.7
        for i in range(len(pts) - 1):
            quad = [rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]]
            mid_ = sum((q.co for q in quad), Vector()) / 4
            out = Vector((mid_.x - cx, 0, mid_.z - 0.1))
            if 3 <= i <= 5:
                out = Vector((0, 0, 1))
            fu0 = 0.8 if 3 <= i <= 5 else fus[i] * 0.6
            fu1 = 0.8 if 3 <= i <= 5 else fus[i + 1] * 0.6
            mb.face(quad, [uvs(fu0, 0), uvs(fu1, 0), uvs(fu1, 1), uvs(fu0, 1)], want=out)
        for r, yy in ((rows[0], -1), (rows[1], 1)):
            mb.face(list(r), [uvs(0.3, 0.5)] * len(r), want=(0, yy, 0))
        for by in (-7.2, 7.2):
            for bx in (x0 + sgn * 0.33, x0 + sgn * 1.07):
                c = Vector((bx, by, 0.44))
                ring = [mb.v(c + Vector((math.cos(2 * math.pi * j / 6) * 0.13, math.sin(2 * math.pi * j / 6) * 0.13, 0.0))) for j in range(6)]
                tip = mb.v(c + Vector((0, 0, 0.055)))
                for j in range(6):
                    mb.face([ring[j], ring[(j + 1) % 6], tip], [uvs(.1, 0), uvs(.15, 0), uvs(.12, 1)], want=(0, 0, 1))
    return mb.finish(mat, sharp_deg=35, collection=coll)


def cloud_piece(name, mat, coll, seed=81):
    rnd = random.Random(seed)
    mb = MB(name)
    uvc = lambda fu, fv: ruv(sw_rect('cloud'), fu, fv)
    puffs = [((0, 0, 10), (22, 16, 15)), ((-20, 3, 6), (16, 12, 11)), ((19, -2, 6), (17, 13, 12)), ((-8, -6, 16), (13, 11, 12)),
             ((9, 6, 15), (14, 11, 12)), ((-34, 0, 3), (10, 8, 7)), ((33, 2, 3), (11, 9, 7)), ((2, 9, 5), (14, 9, 8))]
    for (c, r) in puffs:
        def deform(p):
            q = p.copy()
            if q.z < 0:
                q.z *= 0.3
            return q
        add_sphere(mb, c, r, 14, 7, lambda fu, fv: uvc(fu, fv), deform=deform)
    return mb.finish(mat, collection=coll)


# ----------------------------------------------------------------------------------------------
# Kit assembly
# ----------------------------------------------------------------------------------------------
KIT_ORDER = ['PalmA', 'PalmB', 'PalmC', 'Fern', 'Sunflower', 'Bromeliad', 'BushA', 'BushB', 'RockA', 'RockB',
             'GrassTuft', 'FlowerPatch', 'TerraceS', 'TerraceM', 'TerraceL', 'TerraceCorner', 'TerraceRound',
             'MesaTall', 'MesaWide', 'MesaSpire', 'FenceSection', 'SpeedPad', 'Cloud']

FALLBACK = {
    'PalmA': ('Wood', [124, 92, 52], 'trunk colour; fronds need the texture'),
    'PalmB': ('Wood', [124, 92, 52], ''), 'PalmC': ('Wood', [124, 92, 52], ''),
    'Fern': ('Grass', [62, 150, 40], ''), 'Sunflower': ('SmoothPlastic', [250, 200, 30], ''),
    'Bromeliad': ('SmoothPlastic', [200, 40, 40], ''), 'BushA': ('Grass', [58, 140, 44], ''),
    'BushB': ('Grass', [64, 150, 50], ''), 'RockA': ('Slate', [132, 128, 132], ''), 'RockB': ('Slate', [132, 128, 132], ''),
    'GrassTuft': ('Grass', [80, 170, 50], ''), 'FlowerPatch': ('Grass', [90, 170, 60], ''),
    'TerraceS': ('Sandstone', [196, 132, 70], 'checker + grass need the texture'),
    'TerraceM': ('Sandstone', [196, 132, 70], ''), 'TerraceL': ('Sandstone', [196, 132, 70], ''),
    'TerraceCorner': ('Sandstone', [196, 132, 70], ''), 'TerraceRound': ('Sandstone', [196, 132, 70], ''),
    'MesaTall': ('Sandstone', [190, 128, 68], ''), 'MesaWide': ('Sandstone', [190, 128, 68], ''), 'MesaSpire': ('Sandstone', [190, 128, 68], ''),
    'FenceSection': ('Wood', [170, 104, 50], ''), 'SpeedPad': ('SmoothPlastic', [214, 30, 34], ''),
    'Cloud': ('SmoothPlastic', [255, 255, 255], ''),
}
TRI_BUDGET = {'PalmA': 3000, 'PalmB': 3000, 'PalmC': 3000}


def budget_of(name):
    if name in TRI_BUDGET:
        return TRI_BUDGET[name]
    if name.startswith(('Terrace', 'Mesa')):
        return 2500
    if name in ('FenceSection', 'SpeedPad', 'Cloud'):
        return 2500
    return 1500


def build_kit(mat, coll):
    K = {}
    K['PalmA'] = palm_piece('Kit_PalmA', mat, 31.0, 5.0, 0.05, 11, 1.7, 1.1, 14, 16.0, 2.9, 101, coll)
    K['PalmB'] = palm_piece('Kit_PalmB', mat, 25.0, 11.0, 0.22, 10, 1.5, 1.05, 13, 14.0, 2.7, 202, coll)
    K['PalmC'] = palm_piece('Kit_PalmC', mat, 15.0, 2.2, 0.0, 7, 1.4, 1.05, 12, 11.0, 2.45, 303, coll)
    K['Fern'] = fern_piece('Kit_Fern', mat, coll)
    K['Sunflower'] = sunflower_piece('Kit_Sunflower', mat, coll)
    K['Bromeliad'] = bromeliad_piece('Kit_Bromeliad', mat, coll)
    K['BushA'] = bush_a_piece('Kit_BushA', mat, coll)
    K['BushB'] = bush_b_piece('Kit_BushB', mat, coll)
    K['RockA'] = rock_a_piece('Kit_RockA', mat, coll)
    K['RockB'] = rock_b_piece('Kit_RockB', mat, coll)
    K['GrassTuft'] = grass_tuft_piece('Kit_GrassTuft', mat, coll)
    K['FlowerPatch'] = flower_patch_piece('Kit_FlowerPatch', mat, coll)
    K['TerraceS'] = terrace_rect('Kit_TerraceS', mat, coll, 20.0, 24.0, 1)
    K['TerraceM'] = terrace_rect('Kit_TerraceM', mat, coll, 24.0, 40.0, 2)
    K['TerraceL'] = terrace_rect('Kit_TerraceL', mat, coll, 28.0, 56.0, 3)
    K['TerraceCorner'] = terrace_corner('Kit_TerraceCorner', mat, coll)
    K['TerraceRound'] = terrace_round('Kit_TerraceRound', mat, coll)
    K['MesaTall'] = mesa_tall('Kit_MesaTall', mat, coll)
    K['MesaWide'] = mesa_wide('Kit_MesaWide', mat, coll)
    K['MesaSpire'] = mesa_spire('Kit_MesaSpire', mat, coll)
    K['FenceSection'] = fence_piece('Kit_FenceSection', mat, coll)
    K['SpeedPad'] = speedpad_piece('Kit_SpeedPad', mat, coll)
    K['Cloud'] = cloud_piece('Kit_Cloud', mat, coll)
    for n in KIT_ORDER:
        K[n].data.name = 'Kit_' + n
    return K


def hull2d(pts):
    pts = sorted(set((round(p[0], 4), round(p[1], 4)) for p in pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def kit_info(K):
    info = {}
    for n in KIT_ORDER:
        ob = K[n]
        me = ob.data
        co = [v.co for v in me.vertices]
        mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
        mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)
        hull = hull2d([(c.x, c.y) for c in co])
        rad = max(math.hypot(x, y) for x, y in hull)
        ctr = (mn + mx) / 2
        info[n] = dict(min=mn, max=mx, tris=tris, hull=hull, radius=rad, center=ctr, obj=ob,
                       plateaus=[(tp, tz, wp) for (tp, tz, wp) in PLATEAUS.get('Kit_' + n, [])])
    return info


# ----------------------------------------------------------------------------------------------
# Layout
# ----------------------------------------------------------------------------------------------
def pip(x, y, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i][0], poly[i][1]
        xj, yj = poly[j][0], poly[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            inside = not inside
        j = i
    return inside


def xform2(pts, x, y, rot_deg, sc):
    c = math.cos(math.radians(rot_deg)); s = math.sin(math.radians(rot_deg))
    return [(x + sc * (px * c - py * s), y + sc * (px * s + py * c)) for px, py in pts]


class Layout:
    def __init__(self, info, seed=20260926):
        self.info = info
        self.rng = random.Random(seed)
        self.items = []
        self.plats = []  # dict(top=poly, z=top, wall=poly, bbox, idx)
        self.veg = []    # (x, y, r)

    def add(self, kit, x, y, z, rot, sc=1.0, low=True, role=''):
        it = dict(kit=kit, x=x, y=y, z=z, rot=rot % 360.0, sc=sc, low=low, role=role)
        self.items.append(it)
        inf = self.info[kit]
        for (tp, tz, wp) in inf['plateaus']:
            top = xform2([(p.x, p.y) for p in tp], x, y, rot, sc)
            wall = xform2([(p.x, p.y) for p in wp], x, y, rot, sc)
            xs = [p[0] for p in wall]; ys = [p[1] for p in wall]
            self.plats.append(dict(top=top, z=z + tz * sc, wall=wall, bbox=(min(xs), max(xs), min(ys), max(ys)), item=it))
        return it

    def footprint(self, kit, x, y, rot, sc):
        return xform2(self.info[kit]['hull'], x, y, rot, sc)

    def clear_ok(self, kit, x, y, rot, sc):
        fp = self.footprint(kit, x, y, rot, sc)
        side = 1 if x > 0 else -1
        lim = CLEAR_X + 0.25 if kit == 'FenceSection' else DECOR_X
        return all(p[0] * side >= lim for p in fp)

    def support(self, x, y):
        best = None
        for P in self.plats:
            b = P['bbox']
            if b[0] <= x <= b[1] and b[2] <= y <= b[3] and pip(x, y, P['top']):
                if best is None or P['z'] > best:
                    best = P['z']
        return best

    def in_wall(self, x, y, margin=0.0):
        for P in self.plats:
            b = P['bbox']
            if b[0] - margin <= x <= b[1] + margin and b[2] - margin <= y <= b[3] + margin and pip(x, y, P['wall']):
                return True
        return False

    def ground_at(self, x, y):
        s = self.support(x, y)
        if s is not None:
            return s, 'plateau'
        if self.in_wall(x, y):
            return None, 'wall'
        g = verge_h(x, y)
        if g is not None and abs(x) <= bank_w(y) - 1.0 and -64 <= y <= 2120:
            return g, 'verge'
        return None, 'water'

    def free(self, x, y, r, k=0.6):
        for (a, b, rr) in self.veg:
            if (a - x) ** 2 + (b - y) ** 2 < (k * (r + rr)) ** 2:
                return False
        return True


def build_layout(info):
    L = Layout(info)
    rng = L.rng
    DX = {'TerraceS': 20, 'TerraceM': 24, 'TerraceL': 28, 'TerraceCorner': 36, 'TerraceRound': 28}
    DY = {'TerraceS': 24, 'TerraceM': 40, 'TerraceL': 56, 'TerraceCorner': 36, 'TerraceRound': 26}
    topY = {k: info[k]['plateaus'][0][1] for k in DX}

    def hmax(a, b):
        return max(track_h(s) for s in np.linspace(a, b, 9))

    # --- speed pads (visual overlay, exact gameplay positions)
    for s in PAD_S:
        L.add('SpeedPad', 0.0, float(s), track_h(s), 0.0, 1.0, low=False, role='pad')

    # --- fences, full length both sides (posts every 16 studs, sections overlap on the shared post)
    for side in (-1, 1):
        for k in range(137):
            sc = -56.0 + 16.0 * k
            L.add('FenceSection', side * FENCE_X, sc, track_h(sc) + 0.15, 0.0, 1.0, low=True, role='fence')

    # --- tier 1 terraces
    tier1 = {-1: [], 1: []}
    openings = {-1: [], 1: []}
    for side in (-1, 1):
        s = -190.0
        since_open = 0.0
        while s < 2280:
            if since_open > 220 and rng.random() < 0.16 and 80 < s < 2050:
                w = rng.uniform(30, 46)
                openings[side].append((s, s + w))
                s += w; since_open = 0.0
                continue
            kind = rng.choices(['TerraceS', 'TerraceM', 'TerraceL'], [3, 4, 3])[0]
            gap = rng.choice([-2, 0, 0, 1, 2, 3, 5])
            sc_ = s + gap + DY[kind] / 2
            inner = rng.uniform(49.5, 57.0)
            rot = rng.uniform(-3.5, 3.5) + (180 if rng.random() < 0.5 else 0)
            x = side * (inner + DX[kind] / 2)
            top = hmax(sc_ - DY[kind] / 2, sc_ + DY[kind] / 2) + rng.choice([6.5, 7.5, 8.5, 9.5, 10.5, 11.5])
            base = top - topY[kind]
            if L.clear_ok(kind, x, sc_, rot, 1.0):
                it = L.add(kind, x, sc_, base, rot, 1.0, low=False, role='tier1')
                tier1[side].append((sc_ - DY[kind] / 2, sc_ + DY[kind] / 2, inner, top, it))
            s = sc_ + DY[kind] / 2
            since_open += DY[kind] + gap

    def tier1_at(side, s):
        for (a, b, inner, top, it) in tier1[side]:
            if a - 1 <= s <= b + 1:
                return inner, top
        return None, None

    # --- tier 2 terraces (behind tier 1, higher)
    tier2 = {-1: [], 1: []}
    for side in (-1, 1):
        s = -200.0
        while s < 2300:
            kind = rng.choices(['TerraceM', 'TerraceL', 'TerraceCorner', 'TerraceRound'], [3, 5, 1.4, 1.6])[0]
            gap = rng.choice([4, 8, 12, 18, 26, 34])
            sc_ = s + gap + DY[kind] / 2
            inner = rng.uniform(66.0, 78.0)
            rot = rng.uniform(-6, 6)
            if kind == 'TerraceCorner':
                rot = (0 if side > 0 else 90) + rng.choice([0, -90]) * 0 + rng.uniform(-4, 4)
                if side < 0:
                    rot = rng.choice([90, 180]) + rng.uniform(-4, 4)
                else:
                    rot = rng.choice([0, 270]) + rng.uniform(-4, 4)
            elif rng.random() < 0.5:
                rot += 180
            x = side * (inner + DX[kind] / 2)
            t1 = max([t for (a, b, i_, t, it) in tier1[side] if a < sc_ + DY[kind] / 2 and b > sc_ - DY[kind] / 2] or [track_h(sc_) + 8])
            top = max(t1 + rng.uniform(5.5, 9.5), hmax(sc_ - 20, sc_ + 20) + rng.uniform(15, 21))
            base = top - topY[kind]
            if base <= WATER_Y - 1 and L.clear_ok(kind, x, sc_, rot, 1.0):
                it = L.add(kind, x, sc_, base, rot, 1.0, low=False, role='tier2')
                tier2[side].append((sc_ - DY[kind] / 2, sc_ + DY[kind] / 2, inner, top, it))
            s = sc_ + DY[kind] / 2

    # --- tier 3 (sparse tall steps) + back frame behind the start
    for side in (-1, 1):
        s = -150.0 + rng.uniform(0, 60)
        while s < 2350:
            kind = rng.choices(['TerraceL', 'TerraceRound', 'TerraceM', 'MesaWide'], [3, 3, 2, 1.2])[0]
            sc = 1.0
            if kind == 'MesaWide':
                sc = rng.uniform(0.5, 0.62)
            inner = rng.uniform(92, 118)
            half = (DX.get(kind, 80) / 2) * sc
            x = side * (inner + half)
            top = track_h(s) + rng.uniform(27, 38)
            tz = info[kind]['plateaus'][-1][1] if kind != 'MesaWide' else info[kind]['plateaus'][0][1]
            base = top - tz * sc
            base = min(base, WATER_Y - 1.5)
            rot = rng.uniform(0, 360) if kind in ('TerraceRound', 'MesaWide') else rng.uniform(-8, 8) + rng.choice([0, 180])
            if L.clear_ok(kind, x, s, rot, sc):
                L.add(kind, x, s, base, rot, sc, low=False, role='tier3')
            s += rng.uniform(120, 240)
    for x, y, kind, rot in ((-72, -228, 'TerraceL', 90), (72, -228, 'TerraceL', 90), (-116, -250, 'TerraceM', 90),
                            (116, -250, 'TerraceM', 90)):
        top = rng.uniform(12, 20)
        if L.clear_ok(kind, x, y, rot, 1.0):
            L.add(kind, float(x), float(y), top - topY[kind], rot + rng.uniform(-3, 3), 1.0, low=False, role='back')

    # --- background mesas in the water + vista at the far end
    mesas = []

    def mesa_ok(x, y, r):
        for (a, b, rr) in mesas:
            if (a - x) ** 2 + (b - y) ** 2 < (0.85 * (r + rr)) ** 2:
                return False
        return True
    for side in (-1, 1):
        s = -460.0 + rng.uniform(0, 80)
        while s < 2700:
            kind = rng.choices(['MesaTall', 'MesaWide', 'MesaSpire'], [4.5, 3, 3])[0]
            dist = rng.uniform(150, 430)
            sc = rng.uniform(0.7, 1.05) + (dist - 150) / 280 * 0.45
            r = info[kind]['radius'] * sc
            x = side * dist
            rot = rng.uniform(0, 360)
            base = WATER_Y - rng.uniform(2, 7)
            for attempt in range(6):
                if mesa_ok(x, s, r) and L.clear_ok(kind, x, s, rot, sc):
                    L.add(kind, x, s, base, rot, sc, low=False, role='mesa')
                    mesas.append((x, s, r))
                    break
                x = side * rng.uniform(150, 430)
            s += rng.uniform(110, 190)
    for i in range(9):
        side = -1 if i % 2 == 0 else 1
        s = 2260 + i * 60 + rng.uniform(0, 40)
        kind = ('MesaWide', 'MesaTall', 'MesaSpire')[i % 3]
        sc = rng.uniform(0.75, 1.2)
        r = info[kind]['radius'] * sc
        x = side * (40 + r + rng.uniform(10, 140))
        rot = rng.uniform(0, 360)
        if mesa_ok(x, s, r) and L.clear_ok(kind, x, s, rot, sc):
            L.add(kind, x, s, WATER_Y - rng.uniform(2, 6), rot, sc, low=False, role='vista')
            mesas.append((x, s, r))

    # --- islets (low round terraces rising from the water)
    islets = []
    tries = 0
    while len(islets) < 20 and tries < 600:
        tries += 1
        side = rng.choice([-1, 1])
        x = side * rng.uniform(112, 330)
        s = rng.uniform(-300, 2550)
        sc = rng.uniform(0.34, 0.78)
        r = info['TerraceRound']['radius'] * sc
        if not mesa_ok(x, s, r + 6) or L.in_wall(x, s, r + 4):
            continue
        top = WATER_Y + rng.uniform(1.5, 5.0)
        base = top - info['TerraceRound']['plateaus'][0][1] * sc
        rot = rng.uniform(0, 360)
        if L.clear_ok('TerraceRound', x, s, rot, sc):
            L.add('TerraceRound', x, s, base, rot, sc, low=False, role='islet')
            islets.append((x, s, r, top))
            mesas.append((x, s, r))

    # --- clouds
    for i in range(16):
        side = rng.choice([-1, 1])
        x = side * rng.uniform(260, 850)
        s = -300 + i * 220 + rng.uniform(0, 160)
        L.add('Cloud', x, s, rng.uniform(190, 300), rng.uniform(0, 360), rng.uniform(1.5, 3.2), low=True, role='cloud')

    # --- palms
    def try_palm(kind, x, y, rot, sc, low, role, need='any'):
        z, where = L.ground_at(x, y)
        if z is None or (need == 'plateau' and where != 'plateau'):
            return False
        if not L.clear_ok(kind, x, y, rot, sc):
            return False
        # trunk base well inside its support
        for dx, dy in ((2.2, 0), (-2.2, 0), (0, 2.2), (0, -2.2)):
            z2, w2 = L.ground_at(x + dx, y + dy)
            if z2 is None or abs(z2 - z) > 0.6:
                return False
        if not L.free(x, y, 3.0, 1.0):
            return False
        L.add(kind, x, y, z, rot, sc, low=low, role=role)
        L.veg.append((x, y, 3.0))
        return True

    def palm_rot(kind, side):
        if kind == 'PalmB':
            return (0 if side > 0 else 180) + rng.uniform(-50, 50)
        return rng.uniform(0, 360)
    # hero vignettes next to every pad (both sides) + palms on tier-1 tops
    for s0 in PAD_S:
        for side in (-1, 1):
            placed = 0
            for attempt in range(60):
                if placed >= (3 if side < 0 else 2):
                    break
                kind = rng.choice(['PalmA', 'PalmB', 'PalmA', 'PalmC'])
                y = s0 + rng.uniform(15, 70)
                x = side * rng.uniform(44, 64)
                sc = rng.uniform(0.95, 1.15)
                if try_palm(kind, x, y, palm_rot(kind, side), sc, False, 'palm_hero'):
                    placed += 1
    for side in (-1, 1):
        for (a, b, inner, top, it) in tier1[side]:
            if rng.random() < 0.5:
                for k in range(rng.choice([1, 1, 2])):
                    kind = rng.choices(['PalmA', 'PalmB', 'PalmC'], [4, 3, 3])[0]
                    y = rng.uniform(a + 5, b - 5)
                    x = side * (inner + rng.uniform(3.5, 9.0))
                    try_palm(kind, x, y, palm_rot(kind, side), rng.uniform(0.85, 1.15), rng.random() < 0.45, 'palm_t1', need='plateau')
        for (a, b, inner, top, it) in tier2[side]:
            if rng.random() < 0.3:
                kind = rng.choices(['PalmA', 'PalmC'], [5, 5])[0]
                try_palm(kind, side * (inner + rng.uniform(4, 10)), rng.uniform(a + 5, b - 5), rng.uniform(0, 360),
                         rng.uniform(0.85, 1.1), True, 'palm_t2', need='plateau')
        for (o0, o1) in openings[side]:
            for k in range(2):
                kind = rng.choice(['PalmB', 'PalmA', 'PalmC'])
                try_palm(kind, side * rng.uniform(44, 58), rng.uniform(o0 + 4, o1 - 4), palm_rot(kind, side),
                         rng.uniform(0.9, 1.15), False, 'palm_open')
    for it in [i for i in L.items if i['role'] in ('mesa', 'islet', 'vista', 'tier3')]:
        if rng.random() < (0.6 if it['role'] == 'islet' else 0.4):
            P = [p for p in L.plats if p['item'] is it]
            P = P[-1]
            xs = [q[0] for q in P['top']]; ys = [q[1] for q in P['top']]
            for k in range(rng.choice([1, 1, 2]) if it['role'] != 'islet' else 1):
                for attempt in range(12):
                    x = rng.uniform(min(xs), max(xs)); y = rng.uniform(min(ys), max(ys))
                    kind = rng.choice(['PalmA', 'PalmC', 'PalmB'])
                    if try_palm(kind, x, y, rng.uniform(0, 360), rng.uniform(0.9, 1.2), True, 'palm_far', need='plateau'):
                        break

    # --- vegetation clusters on the verge (between the fence and the tier-1 walls)
    VEG_W = [('Fern', 30), ('GrassTuft', 12), ('Sunflower', 13), ('Bromeliad', 11), ('BushA', 14), ('BushB', 10),
             ('RockA', 4), ('RockB', 3), ('FlowerPatch', 10)]

    def try_veg(kind, x, y, rot, sc, low, role, allow=('verge', 'plateau')):
        z, where = L.ground_at(x, y)
        if z is None or where not in allow:
            return False
        r = info[kind]['radius'] * sc
        if not L.clear_ok(kind, x, y, rot, sc):
            return False
        if not L.free(x, y, r * 0.8):
            return False
        # all of the base must be supported at (nearly) the same height
        for dx, dy in ((r * 0.35, 0), (-r * 0.35, 0), (0, r * 0.35), (0, -r * 0.35)):
            z2, w2 = L.ground_at(x + dx, y + dy)
            if z2 is None or abs(z2 - z) > 0.5:
                return False
        L.add(kind, x, y, z, rot, sc, low=low, role=role)
        L.veg.append((x, y, r * 0.8))
        return True

    def face_track(side):
        return (0.0 if side < 0 else 180.0) + rng.uniform(-40, 40)
    for side in (-1, 1):
        s = -58.0
        while s < 2118:
            near_pad = any(abs(s - p) < 60 for p in PAD_S)
            s += rng.uniform(7, 13) if near_pad else rng.uniform(12, 26)
            n = rng.choice([2, 2, 2, 3, 3, 4]) + (1 if near_pad else 0)
            inner, _ = tier1_at(side, s)
            lim = min((inner if inner else 60.0) - 2.0, bank_w(s) - 2.5)
            cx = side * rng.uniform(44.5, max(45.0, min(51.0, lim)))
            for k in range(n):
                kind = rng.choices([k_ for k_, w in VEG_W], [w for k_, w in VEG_W])[0]
                for attempt in range(5):
                    x = cx + rng.uniform(-3.5, 3.5)
                    y = s + rng.uniform(-6, 6)
                    sc = rng.uniform(0.95, 1.4)
                    if try_veg(kind, x, y, face_track(side), sc, True, 'verge'):
                        break
        # grass tufts along the fence line
        s = -60.0
        while s < 2120:
            s += rng.uniform(30, 60)
            try_veg('GrassTuft', side * rng.uniform(42.2, 43.2), s, rng.uniform(-12, 12), rng.uniform(0.9, 1.2), True, 'fence_tuft')

    # --- vegetation on terrace tops (near the inner edge, visible from the track)
    TOP_W = [('Fern', 30), ('BushA', 22), ('Sunflower', 12), ('Bromeliad', 12), ('BushB', 12), ('FlowerPatch', 8), ('RockA', 4)]
    for side in (-1, 1):
        for (a, b, inner, top, it) in tier1[side]:
            for k in range(rng.choice([1, 2, 2])):
                kind = rng.choices([k_ for k_, w in TOP_W], [w for k_, w in TOP_W])[0]
                for attempt in range(6):
                    x = side * (inner + rng.uniform(3.0, 7.5)); y = rng.uniform(a + 3, b - 3)
                    if try_veg(kind, x, y, face_track(side), rng.uniform(0.9, 1.3), True, 'top1', allow=('plateau',)):
                        break
        for (a, b, inner, top, it) in tier2[side]:
            if rng.random() < 0.3:
                kind = rng.choice(['BushA', 'Fern', 'BushB'])
                for attempt in range(6):
                    x = side * (inner + rng.uniform(3.0, 8.0)); y = rng.uniform(a + 3, b - 3)
                    if try_veg(kind, x, y, face_track(side), rng.uniform(1.0, 1.4), True, 'top2', allow=('plateau',)):
                        break
    for (x, s, r, top) in islets:
        if rng.random() < 0.6:
            for attempt in range(6):
                if try_veg(rng.choice(['BushA', 'Fern', 'RockB']), x + rng.uniform(-r * .4, r * .4), s + rng.uniform(-r * .4, r * .4),
                           rng.uniform(0, 360), rng.uniform(0.9, 1.3), True, 'islet_veg', allow=('plateau',)):
                    break
    # --- hard budget: trim lowest-priority phone-hidden items if still over
    MAX_TOTAL = 1390
    for pool in (('top2', 'islet_veg'), ('fence_tuft',), ('verge', 'top1', 'palm_far')):
        cands = [i for i in L.items if i['role'] in pool and i['low']]
        rng.shuffle(cands)
        while len(L.items) > MAX_TOTAL and cands:
            L.items.remove(cands.pop())
    return L, tier1, tier2, openings


def validate_layout(L, info):
    items = L.items
    low = sum(1 for i in items if i['low'])
    hi = len(items) - low
    problems = []
    for it in items:
        k = it['kit']
        if k != 'SpeedPad' and not L.clear_ok(k, it['x'], it['y'], it['rot'], it['sc']):
            problems.append(('strip', k, it['x'], it['y']))
        if k.startswith(('Terrace', 'Mesa')) and it['z'] > WATER_Y - 0.5:
            problems.append(('base_above_water', k, it['x'], it['y'], it['z']))
    # floating check for plants / palms / rocks / fences
    for it in items:
        k = it['kit']
        if k.startswith(('Terrace', 'Mesa')) or k in ('Cloud', 'SpeedPad'):
            continue
        if k == 'FenceSection':
            if abs(it['z'] - (track_h(it['y']) + 0.15)) > 1e-6:
                problems.append(('fence_z', it['y']))
            continue
        g = None
        best = None
        for P in L.plats:
            if P['item'] is it:
                continue
            b = P['bbox']
            if b[0] <= it['x'] <= b[1] and b[2] <= it['y'] <= b[3] and pip(it['x'], it['y'], P['top']):
                best = P['z'] if best is None else max(best, P['z'])
        if best is not None:
            g = best
        else:
            g = verge_h(it['x'], it['y']) if abs(it['x']) <= bank_w(it['y']) - 0.9 else None
        if g is None or abs(g - it['z']) > 0.05:
            problems.append(('floating', k, round(it['x'], 1), round(it['y'], 1), round(it['z'], 2), g))
    pads = [i for i in items if i['kit'] == 'SpeedPad']
    assert [round(p['y']) for p in pads] == PAD_S and all(abs(p['x']) < 1e-9 for p in pads)
    return dict(total=len(items), lowPower=low, alwaysOn=hi, problems=problems)


# ----------------------------------------------------------------------------------------------
# Scene helpers (materials, preview world)
# ----------------------------------------------------------------------------------------------
def make_atlas_material(img):
    m = bpy.data.materials.new('GH_Atlas')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Linear'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.78
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.25
    m.use_backface_culling = True
    return m


def image_material(name, path, rough=0.85, tint=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(path), check_existing=True)
    if tint:
        mixn = nt.nodes.new('ShaderNodeMix'); mixn.data_type = 'RGBA'; mixn.blend_type = 'MULTIPLY'
        mixn.inputs['Factor'].default_value = 1.0
        nt.links.new(tex.outputs['Color'], mixn.inputs['A'])
        mixn.inputs['B'].default_value = (*tint, 1)
        nt.links.new(mixn.outputs['Result'], bsdf.inputs['Base Color'])
    else:
        nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = rough
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.2
    return m


def build_track_bank(coll):
    """Preview-only copy of Astra's Road / Verge / Embankment (stays in RaceArena, not part of the kit)."""
    mats = {n: image_material('Astra_' + n, ASTRA / 'textures' / (n + '.png')) for n in ('Dirt', 'Grass', 'Cliff')}
    obs = []
    for nm, mat in (('Road', mats['Dirt']), ('Verge', mats['Grass']), ('Embankment', mats['Cliff'])):
        bm = bmesh.new(); uv = bm.loops.layers.uv.new('UVMap')
        s = -64.0
        prev = None
        def face(pts, uvs):
            vs = [bm.verts.new(p) for p in pts]
            f = bm.faces.new(vs)
            for lp, u in zip(f.loops, uvs): lp[uv].uv = u
            f.smooth = True
        while s < 2120:
            n = min(2120.0, s + 8)
            hs, hn = track_h(s), track_h(n)
            if nm == 'Road':
                for a, b in ((-36, -18), (-18, 0), (0, 18), (18, 36)):
                    face([(a, s, hs), (b, s, hs), (b, n, hn), (a, n, hn)], [(a / 22, s / 22), (b / 22, s / 22), (b / 22, n / 22), (a / 22, n / 22)])
            elif nm == 'Verge':
                for sg in (-1, 1):
                    bands = [36, 42, bank_w(s)]; bn = [36, 42, bank_w(n)]
                    for k in range(2):
                        pts = [(sg * bands[k], s, hs + (.3 if k else 0)), (sg * bands[k + 1], s, hs + .3), (sg * bn[k + 1], n, hn + .3), (sg * bn[k], n, hn + (.3 if k else 0))]
                        if sg < 0: pts.reverse()
                        face(pts, [(p[0] / 18, p[1] / 18) for p in pts])
            else:
                for sg in (-1, 1):
                    pts = [(sg * bank_w(s), s, hs + .3), (sg * bank_w(n), n, hn + .3), (sg * (bank_w(n) + 3), n, -14), (sg * (bank_w(s) + 3), s, -14)]
                    uvs = [(s / 16, (hs + .3) / 16), (n / 16, (hn + .3) / 16), (n / 16, -14 / 16), (s / 16, -14 / 16)]
                    if sg > 0: pts.reverse(); uvs.reverse()
                    face(pts, uvs)
            s = n
        if nm == 'Embankment':
            for sv in (-64.0, 2120.0):
                hs = track_h(sv)
                w = bank_w(sv)
                pts = [(-w - 3, sv, -14), (w + 3, sv, -14), (w, sv, hs + .3), (-w, sv, hs + .3)]
                if sv > 0: pts.reverse()
                face(pts, [(p[0] / 16, p[2] / 16) for p in pts])
        me = bpy.data.meshes.new('Preview_' + nm)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]) if nm == 'Embankment' and False else None
        bm.to_mesh(me); bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new('Preview_' + nm, me)
        coll.objects.link(ob)
        obs.append(ob)
    return obs


def build_world(scene):
    w = bpy.data.worlds.new('GH_Sky')
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
    cr.elements[0].position = 0.0
    cr.elements[0].color = (0.33, 0.62, 0.95, 1)
    cr.elements[1].position = 0.5
    cr.elements[1].color = (0.006, 0.10, 0.62, 1)
    e = cr.elements.new(0.1)
    e.color = (0.10, 0.36, 0.92, 1)
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = 1.0
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])
    w.mist_settings.start = 180
    w.mist_settings.depth = 2600
    w.mist_settings.falloff = 'QUADRATIC'


def build_water(coll):
    m = bpy.data.materials.new('GH_Water')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (0.012, 0.22, 0.42, 1)
    bsdf.inputs['Roughness'].default_value = 0.06
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.6
    noi = nt.nodes.new('ShaderNodeTexNoise')
    noi.inputs['Scale'].default_value = 0.08
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = 0.12
    nt.links.new(noi.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    me = bpy.data.meshes.new('Water')
    me.from_pydata([(-3000, -2000, WATER_Y), (3000, -2000, WATER_Y), (3000, 5000, WATER_Y), (-3000, 5000, WATER_Y)], [], [(0, 1, 2, 3)])
    me.materials.append(m)
    ob = bpy.data.objects.new('Water', me)
    coll.objects.link(ob)
    return ob


def add_sun(scene, coll):
    ld = bpy.data.lights.new('Sun', 'SUN')
    ld.energy = 4.2
    ld.angle = math.radians(2.2)
    ld.color = (1.0, 0.96, 0.88)
    ob = bpy.data.objects.new('Sun', ld)
    coll.objects.link(ob)
    d = Vector((-0.55, -0.62, -0.75)).normalized()  # light travel direction
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return ob


def add_camera(name, loc, target, lens, coll):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.3
    cd.clip_end = 9000
    ob = bpy.data.objects.new(name, cd)
    coll.objects.link(ob)
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob


def setup_render(scene, quick):
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    ee = scene.eevee
    ee.taa_render_samples = 24 if quick else 96
    ee.use_shadows = True
    ee.shadow_ray_count = 2
    ee.shadow_step_count = 8
    ee.use_raytracing = True
    ee.ray_tracing_method = 'SCREEN'
    ee.use_fast_gi = True
    ee.fast_gi_distance = 12
    scene.render.resolution_x = 960 if quick else 1920
    scene.render.resolution_y = 540 if quick else 1080
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = 'AgX'
        scene.view_settings.look = 'AgX - Punchy'
    except Exception:
        pass
    scene.view_settings.exposure = 0.35
    scene.render.film_transparent = True
    vl = scene.view_layers[0]
    vl.use_pass_mist = True
    vl.use_pass_environment = True
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new('CompositorNodeRLayers')
    comp = nt.nodes.new('CompositorNodeComposite')
    mixn = nt.nodes.new('CompositorNodeMixRGB')
    mixn.blend_type = 'MIX'
    mixn.use_alpha = False
    mul = nt.nodes.new('CompositorNodeMath')
    mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = 0.42
    haze = (0.42, 0.62, 0.92, 1)
    nt.links.new(rl.outputs['Mist'], mul.inputs[0])
    nt.links.new(mul.outputs[0], mixn.inputs[0])
    nt.links.new(rl.outputs['Image'], mixn.inputs[1])
    mixn.inputs[2].default_value = haze
    seta = nt.nodes.new('CompositorNodeSetAlpha')
    seta.mode = 'APPLY'
    nt.links.new(mixn.outputs[0], seta.inputs['Image'])
    nt.links.new(rl.outputs['Alpha'], seta.inputs['Alpha'])
    over = nt.nodes.new('CompositorNodeAlphaOver')
    nt.links.new(rl.outputs['Env'], over.inputs[1])
    nt.links.new(seta.outputs[0], over.inputs[2])
    sat = nt.nodes.new('CompositorNodeHueSat')
    sat.inputs['Saturation'].default_value = 1.05
    nt.links.new(over.outputs[0], sat.inputs['Image'])
    nt.links.new(sat.outputs[0], comp.inputs['Image'])


# ----------------------------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------------------------
def water_region(L):
    xs = [i['x'] for i in L.items if i['kit'] != 'Cloud']
    ys = [i['y'] for i in L.items if i['kit'] != 'Cloud']
    x0, x1 = min(xs) - 120, max(xs) + 120
    y0, y1 = min(ys) - 120, max(ys) + 120
    return {'note': 'Terrain water surface at y=-8 (thin layer, e.g. Sand floor at y=-14 and Water from -14 to -8), track-local studs, Roblox axes',
            'min': [round(x0), -14, round(-y1)], 'max': [round(x1), WATER_Y, round(-y0)]}


def to_roblox(x, y, z):
    return [round(x, 3), round(z, 3), round(-y, 3)]


def safe_main():
    """Fallback delivery only: fbx/Kit_<Name>.fbx, obj/Kit_<Name>.obj, GreenHillKit_all.fbx + report."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    img = build_atlas(TEXO / 'GreenHillAtlas.png')
    mat = make_atlas_material(img)
    coll = bpy.data.collections.new('GreenHillKit')
    scene.collection.children.link(coll)
    K = build_kit(mat, coll)
    info = kit_info(K)
    table, facts = export_import_safe(scene, K, info, img)
    rows, worst = finish_import_safe(info)
    report = {'note': 'Fallback files only. Same 23 names, sizes, pivots and texture as GreenHillKit.fbx; the three palms differ '
                      'slightly at the trunk base (flare ring order fixed so no faces fold back); other pieces only lose '
                      'loose vertices. kit_manifest.json and layout.json apply unchanged.',
              'fbxSettings': 'METRIC unit scale 1.0, apply_unit_scale, Apply Scalings = FBX All -> UnitScaleFactor 100; raw coordinates = studs; '
                             '-Z forward, Y up; identity transforms; triangles; PNG embedded; ASCII-only paths',
              'fbxFacts': facts, 'robloxLimitValidation': table,
              'reimportCheck': {'worstSizeErrorStuds': worst, 'rows': [[r[0], r[1], r[2]] for r in rows]}}
    (OUT / 'fbx' / 'import_safe_report.json').write_text(json.dumps(report, indent=1))
    log('import-safe fallback written; frozen files untouched')


def main():
    if STAGE == 'safe':
        return safe_main()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    atlas_path = TEXO / 'GreenHillAtlas.png'
    img = build_atlas(atlas_path)
    log('atlas written', atlas_path)
    mat = make_atlas_material(img)
    kit_coll = bpy.data.collections.new('GreenHillKit')
    scene.collection.children.link(kit_coll)
    K = build_kit(mat, kit_coll)
    info = kit_info(K)
    total = 0
    for n in KIT_ORDER:
        t = info[n]['tris']; total += t
        assert t <= budget_of(n), (n, t, budget_of(n))
        log('%-14s tris %5d  size %s' % (n, t, tuple(round(v, 2) for v in (info[n]['max'] - info[n]['min']))))
    log('KIT TOTAL TRIS', total)
    assert total <= 35000, total
    assert 18 <= len(KIT_ORDER) <= 24
    sp = info['SpeedPad']
    assert abs((sp['max'].x - sp['min'].x) - 18.0) < 1e-3 and abs((sp['max'].y - sp['min'].y) - 16.0) < 1e-3
    assert sp['max'].z <= 0.5 + 1e-6

    # Kit sheet arrangement (FBX node positions; pivots stay at the base centre of each piece)
    rows = [['TerraceS', 'TerraceM', 'TerraceL', 'TerraceCorner', 'TerraceRound', 'MesaTall', 'MesaWide', 'MesaSpire'],
            ['PalmA', 'PalmB', 'PalmC', 'Cloud'],
            ['Fern', 'Sunflower', 'Bromeliad', 'BushA', 'BushB', 'RockA', 'RockB', 'GrassTuft', 'FlowerPatch', 'FenceSection', 'SpeedPad']]
    y = 0.0
    for row in rows:
        x = 0.0
        depth = max(info[n]['max'].y - info[n]['min'].y for n in row)
        for n in row:
            w = info[n]['max'].x - info[n]['min'].x
            K[n].location = (x - info[n]['min'].x, y - info[n]['min'].y, 0)
            x += w + 6
        y -= depth + 12

    # ---- FBX export (FBX Units Scale, -Z forward, Y up; unit scale 0.01 -> UnitScaleFactor 1 so 1 BU = 1 stud)
    fbx = OUT / 'GreenHillKit.fbx'
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 0.01
    bpy.ops.object.select_all(action='DESELECT')
    for n in KIT_ORDER:
        K[n].select_set(True)
    bpy.context.view_layer.objects.active = K['PalmA']
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True,
                             mesh_smooth_type='FACE', use_tspace=False, add_leaf_bones=False, bake_anim=False,
                             axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0,
                             apply_unit_scale=True, path_mode='COPY', embed_textures=True, use_custom_props=False,
                             use_triangles=True)
    scene.unit_settings.scale_length = 1.0
    log('FBX written', fbx, '%.1f KB' % (fbx.stat().st_size / 1024))

    manifest = {'generator': 'audit/greenhill_kit_bpy.py', 'fbx': 'GreenHillKit.fbx', 'texture': 'textures/GreenHillAtlas.png',
                'units': '1 unit = 1 stud; FBX UnitScaleFactor 1.0 (cm); axes: -Z forward, Y up (Roblox axes)',
                'pivot': 'base centre: x=z=0, y=0 at the base / ground line',
                'placement': 'part.CFrame = ORIGIN * CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY), 0) * CFrame.new(bboxCenterOffset * scale); part.Size = size * scale',
                'totalTris': total, 'pieces': []}
    for n in KIT_ORDER:
        I = info[n]
        mn, mx = I['min'], I['max']
        c = (mn + mx) / 2
        e = {'name': 'Kit_' + n, 'kit': n,
             'size': [round(mx.x - mn.x, 3), round(mx.z - mn.z, 3), round(mx.y - mn.y, 3)],
             'bboxCenterOffset': [round(c.x, 3), round(c.z, 3), round(-c.y, 3)],
             'minY': round(mn.z, 3), 'tris': I['tris'], 'triBudget': budget_of(n), 'texture': 'textures/GreenHillAtlas.png',
             'footprintRadius': round(I['radius'], 2),
             'footprintHullXZ': [[round(x, 2), round(-y, 2)] for x, y in I['hull']],
             'fallback': {'Material': FALLBACK[n][0], 'Color': FALLBACK[n][1]},
             'canCollide': False, 'canQuery': False, 'castShadow': n not in ('GrassTuft', 'FlowerPatch', 'Cloud')}
        if I['plateaus']:
            e['topY'] = [round(tz, 3) for (tp, tz, wp) in I['plateaus']]
        if n == 'FenceSection':
            e['note'] = 'tiles every 16 studs along Z; posts at z=+-8 overlap the neighbour (identical geometry); posts buried 1 stud below y=0'
        if n == 'SpeedPad':
            e['note'] = '18 wide (X) x 16 long (Z), top 0.48; chevrons point to -Z (race direction). Visual only.'
        if n.startswith(('Terrace', 'Mesa')):
            e['note'] = 'walls reach far below y=topY-%d; place base <= -9 so it is always under the water (y=-8)' % 9
        manifest['pieces'].append(e)
    (OUT / 'kit_manifest.json').write_text(json.dumps(manifest, indent=1))
    log('kit_manifest.json written')

    # ---- kit sheet render
    prev_coll = bpy.data.collections.new('Preview')
    scene.collection.children.link(prev_coll)
    build_world(scene)
    sun = add_sun(scene, prev_coll)
    setup_render(scene, QUICK)
    if not NO_RENDER and (ONLY_VIEWS is None or 'kit' in ONLY_VIEWS):
        contact_sheet(scene, K, info, prev_coll)
    if STAGE == 'kit':
        verify_fbx(fbx, info)
        return

    # ---- layout
    L, tier1, tier2, openings = build_layout(info)
    val = validate_layout(L, info)
    log('layout', {k: v for k, v in val.items() if k != 'problems'}, 'problems', len(val['problems']))
    from collections import Counter as _C
    log('roles', dict(_C(i['role'] for i in L.items)))
    log('kits', dict(_C(i['kit'] for i in L.items)))
    for p in val['problems'][:30]:
        log('  PROBLEM', p)
    assert not val['problems'], 'layout problems'
    assert val['total'] <= 1400 and val['alwaysOn'] <= 500, val
    from collections import Counter
    cnt = Counter(i['kit'] for i in L.items)
    roles = Counter(i['role'] for i in L.items)
    layout = {'generator': 'audit/greenhill_kit_bpy.py', 'frame': 'track-local studs, Roblox axes: origin = centre of the start line on the floor (RaceArena origin 6000,12000,0); race runs to -Z; x in [-36,36] is the dirt road',
              'waterLevelY': WATER_Y, 'playableClearX': CLEAR_X, 'decorClearX': DECOR_X,
              'rules': 'inside |x|<38.1 only the 5 SpeedPad visuals; fences between 38.25 and 39.6; everything else has its whole footprint at |x|>=40; terraces/mesas/islets have their base below y=-8.5; plants/palms/rocks sit on the track verge (Astra Verge_*, y=h(s)+0.3 for 42<=|x|<=bank width) or exactly on a terrace/mesa top',
              'waterRegionSuggestion': water_region(L),
              'placementFormula': 'CFrame.new(ORIGIN + Vector3.new(pos[1],pos[2],pos[3])) * CFrame.Angles(0, math.rad(rotY), 0) * CFrame.new(bboxCenterOffset * scale), Size = kitSize * scale',
              'counts': {'total': val['total'], 'alwaysOn': val['alwaysOn'], 'lowPower': val['lowPower'], 'byKit': dict(sorted(cnt.items())), 'byRole': dict(sorted(roles.items()))},
              'placements': [{'kit': i['kit'], 'pos': to_roblox(i['x'], i['y'], i['z']), 'rotY': round(i['rot'], 2),
                              'scale': round(i['sc'], 3), 'lowPower': bool(i['low'])} for i in L.items]}
    (OUT / 'layout.json').write_text(json.dumps(layout, indent=None, separators=(',', ':')).replace('{"kit"', '\n{"kit"'))
    log('layout.json written', val['total'], 'placements;', val['alwaysOn'], 'always-on')

    # ---- preview scene
    for n in KIT_ORDER:
        K[n].hide_render = True
        K[n].hide_viewport = True
    lay_coll = bpy.data.collections.new('Layout')
    scene.collection.children.link(lay_coll)
    build_track_bank(prev_coll)
    build_water(prev_coll)
    for idx, it in enumerate(L.items):
        ob = bpy.data.objects.new('%s_%04d' % (it['kit'], idx), K[it['kit']].data)
        ob.location = (it['x'], it['y'], it['z'])
        ob.rotation_euler = (0, 0, math.radians(it['rot']))
        ob.scale = (it['sc'],) * 3
        lay_coll.objects.link(ob)
    log('instanced', len(L.items), 'objects')
    views = [
        ('01_racer_eye', (0.0, 446.0, 5.0), (0.0, 713.0, -26.0), 23.0),
        ('02_recorrido', (0.0, -30.0, 24.0), (0.0, 700.0, -2.0), 22.0),
        ('03_palms_pad', (-20.0, 431.0, 4.4), (-11.0, 540.0, 9.0), 21.0),
        ('04_overview', (230.0, -260.0, 175.0), (-10.0, 560.0, -30.0), 24.0),
    ]
    for name, loc, tgt, lens in views:
        cam = add_camera('Cam_' + name, loc, tgt, lens, prev_coll)
        if NO_RENDER or (ONLY_VIEWS is not None and name not in ONLY_VIEWS):
            continue
        scene.camera = cam
        scene.render.filepath = str(PREV / (name + '.png'))
        bpy.ops.render.render(write_still=True)
        log('rendered', name)
    scene.camera = bpy.data.objects['Cam_01_racer_eye']
    img.pack()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(PREV / 'GreenHill_preview.blend'), compress=True)
    log('preview blend saved')
    verify_fbx(fbx, info)


# ----------------------------------------------------------------------------------------------
# Import-safe delivery (per-piece FBX + OBJ, Roblox mesh limits, ASCII-only paths)
# ----------------------------------------------------------------------------------------------
ROBLOX_MAX_TRIS = 20000
ROBLOX_MAX_VERTS = 10000
ROBLOX_MAX_AXIS = 2048.0


def validate_roblox(ob):
    me = ob.data
    r = {'name': ob.name}
    bad = []
    r['tris'] = len(me.polygons)
    r['ngons'] = sum(1 for p in me.polygons if len(p.vertices) != 3)
    r['verts'] = len(me.vertices)
    corner_n = me.corner_normals if hasattr(me, 'corner_normals') else None
    uvl = me.uv_layers.active.data if me.uv_layers.active else None
    keys = set()
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            n = corner_n[li].vector if corner_n is not None else me.loops[li].normal
            uv = uvl[li].uv if uvl is not None else (0, 0)
            keys.add((vi, round(n[0], 4), round(n[1], 4), round(n[2], 4), round(uv[0], 5), round(uv[1], 5)))
    r['renderVerts'] = len(keys)
    areas = [p.area for p in me.polygons]
    r['minArea'] = min(areas) if areas else 0.0
    r['degenerate'] = sum(1 for a in areas if a < 1e-6)
    used = set()
    for p in me.polygons:
        used.update(p.vertices)
    r['looseVerts'] = len(me.vertices) - len(used)
    edge_used = set()
    for p in me.polygons:
        edge_used.update(p.edge_keys)
    r['looseEdges'] = sum(1 for e in me.edges if e.key not in edge_used)
    co = [v.co for v in me.vertices]
    dims = [max(c[i] for c in co) - min(c[i] for c in co) for i in range(3)]
    r['sizeStuds'] = [round(dims[0], 3), round(dims[2], 3), round(dims[1], 3)]
    r['uvMaps'] = len(me.uv_layers)
    r['materials'] = len([m for m in me.materials if m])
    bm = bmesh.new()
    bm.from_mesh(me)
    manifold = [e for e in bm.edges if len(e.link_faces) == 2]
    r['flippedEdges'] = sum(1 for e in manifold if not e.is_contiguous)
    r['nanNormals'] = sum(1 for f in bm.faces if f.normal.length < 0.5)
    bm.free()
    r['shapeKeys'] = 0 if me.shape_keys is None else len(me.shape_keys.key_blocks)
    r['modifiers'] = len(ob.modifiers)
    names = [ob.name, me.name] + [m.name for m in me.materials if m]
    r['asciiNames'] = all(n.isascii() and ' ' not in n for n in names)
    r['identityXform'] = (ob.location.length < 1e-9 and Vector(ob.rotation_euler).length < 1e-9 and
                          (ob.scale - Vector((1, 1, 1))).length < 1e-9)
    if r['ngons']: bad.append('ngons')
    if r['tris'] > ROBLOX_MAX_TRIS: bad.append('tris>%d' % ROBLOX_MAX_TRIS)
    if r['renderVerts'] > ROBLOX_MAX_VERTS or r['verts'] > ROBLOX_MAX_VERTS: bad.append('verts>%d' % ROBLOX_MAX_VERTS)
    if r['degenerate']: bad.append('degenerate faces')
    if r['looseVerts'] or r['looseEdges']: bad.append('loose geometry')
    if max(dims) > ROBLOX_MAX_AXIS: bad.append('bbox>2048')
    if r['uvMaps'] != 1: bad.append('uv maps != 1')
    if r['materials'] != 1 or len(me.materials) != 1: bad.append('materials != 1')
    if r['flippedEdges'] or r['nanNormals']: bad.append('inconsistent normals')
    if r['shapeKeys'] or r['modifiers']: bad.append('shape keys/modifiers')
    if not r['asciiNames']: bad.append('non-ascii/space names')
    if not r['identityXform']: bad.append('transform not applied')
    r['ok'] = not bad
    r['errors'] = bad
    return r


def fbx_facts(path):
    import re, struct
    b = Path(path).read_bytes()
    m = re.search(rb'UnitScaleFactorS\x06\x00\x00\x00doubleS\x06\x00\x00\x00NumberS\x00\x00\x00\x00D(.{8})', b, re.S)
    usf = struct.unpack('<d', m.group(1))[0] if m else None
    content = b.find(b'Content') >= 0 and b.find(b'\x89PNG') >= 0
    strs = []
    for mm in re.finditer(rb'(?:FileName|Filename|RelativeFilename)S(.{4})', b, re.S):
        n = struct.unpack('<I', mm.group(1))[0]
        strs.append(b[mm.end():mm.end() + n])
    # path strings must be pure ASCII and the (non-ASCII) user folder must not appear anywhere in the file
    home = str(Path.home()).encode('utf-8')
    ascii_ok = all(all(c < 128 for c in s_) for s_ in strs) and (home.isascii() or b.find(home) < 0)
    return {'unitScaleFactor': usf, 'embeddedPng': content, 'asciiPaths': ascii_ok,
            'texturePaths': sorted({s_.decode('ascii', 'replace') for s_ in strs})}


def export_import_safe(scene, K, info, img):
    import tempfile, shutil
    tmp = Path(tempfile.mkdtemp(prefix='gh_kit_'))
    assert str(tmp).isascii(), 'temp dir must be ASCII so no non-ASCII path ends up inside the FBX: %s' % tmp
    (tmp / 'fbx').mkdir()
    (tmp / 'obj').mkdir()
    atlas_tmp = tmp / 'GreenHillAtlas.png'
    shutil.copy2(TEXO / 'GreenHillAtlas.png', atlas_tmp)
    old_fp = img.filepath
    img.filepath = str(atlas_tmp)
    img.reload()
    old_units = (scene.unit_settings.system, scene.unit_settings.scale_length)
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    saved = {n: K[n].location.copy() for n in KIT_ORDER}
    for n in KIT_ORDER:
        K[n].location = (0, 0, 0)
    bpy.context.view_layer.update()
    table = [validate_roblox(K[n]) for n in KIT_ORDER]
    log('Roblox mesh-limit validation (limits: %d tris, %d verts, %d studs per axis)' % (ROBLOX_MAX_TRIS, ROBLOX_MAX_VERTS, ROBLOX_MAX_AXIS))
    print('%-18s %6s %6s %7s %5s %5s %5s %3s %3s %5s %-22s %s' % ('piece', 'tris', 'verts', 'rVerts', 'ngon', 'degen', 'loose', 'uv', 'mat', 'flip', 'size studs X x Y x Z', 'result'))
    for r in table:
        print('%-18s %6d %6d %7d %5d %5d %5d %3d %3d %5d %-22s %s' % (
            r['name'], r['tris'], r['verts'], r['renderVerts'], r['ngons'], r['degenerate'], r['looseVerts'] + r['looseEdges'],
            r['uvMaps'], r['materials'], r['flippedEdges'], 'x'.join('%g' % v for v in r['sizeStuds']),
            'OK' if r['ok'] else 'FAIL ' + ','.join(r['errors'])), flush=True)
    failed = [(r['name'], r['errors']) for r in table if not r['ok']]
    assert not failed, 'Roblox limit validation failed: %s' % failed
    fbx_kw = dict(use_selection=True, object_types={'MESH'}, use_mesh_modifiers=True, mesh_smooth_type='FACE',
                  use_tspace=False, add_leaf_bones=False, bake_anim=False, axis_forward='-Z', axis_up='Y',
                  apply_scale_options='FBX_SCALE_ALL', global_scale=1.0, apply_unit_scale=True, path_mode='COPY',
                  embed_textures=True, use_custom_props=False, use_triangles=True, bake_space_transform=False)
    obj_kw = dict(export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y', global_scale=1.0,
                  apply_modifiers=True, export_triangulated_mesh=True, export_normals=True, export_uv=True,
                  export_materials=True, path_mode='STRIP', export_smooth_groups=False, export_vertex_groups=False,
                  export_animation=False, export_colors=False)
    for n in KIT_ORDER:
        bpy.ops.object.select_all(action='DESELECT')
        K[n].select_set(True)
        bpy.context.view_layer.objects.active = K[n]
        bpy.ops.export_scene.fbx(filepath=str(tmp / 'fbx' / ('Kit_%s.fbx' % n)), **fbx_kw)
        bpy.ops.wm.obj_export(filepath=str(tmp / 'obj' / ('Kit_%s.obj' % n)), **obj_kw)
    bpy.ops.object.select_all(action='DESELECT')
    for n in KIT_ORDER:
        K[n].select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(tmp / 'GreenHillKit_all.fbx'), **fbx_kw)
    dst_fbx = OUT / 'fbx'
    dst_obj = OUT / 'obj'
    dst_fbx.mkdir(exist_ok=True)
    dst_obj.mkdir(exist_ok=True)
    facts = {}
    for f in sorted((tmp / 'fbx').glob('*.fbx')) + [tmp / 'GreenHillKit_all.fbx']:
        facts[f.name] = fbx_facts(f)
        shutil.copy2(f, (dst_fbx / f.name) if f.parent.name == 'fbx' else (OUT / f.name))
    for f in sorted((tmp / 'obj').glob('Kit_*.*')):
        shutil.copy2(f, dst_obj / f.name)
    for d in (dst_fbx, dst_obj, OUT):
        shutil.copy2(TEXO / 'GreenHillAtlas.png', d / 'GreenHillAtlas.png')
    bad = {k: v for k, v in facts.items() if not (v['unitScaleFactor'] and abs(v['unitScaleFactor'] - 100.0) < 1e-6
                                                   and v['embeddedPng'] and v['asciiPaths'])}
    log('FBX facts: UnitScaleFactor', sorted({round(v['unitScaleFactor'], 6) for v in facts.values()}),
        '| embedded PNG in all:', all(v['embeddedPng'] for v in facts.values()),
        '| ASCII-only paths in all:', all(v['asciiPaths'] for v in facts.values()))
    assert not bad, bad
    for n in KIT_ORDER:
        K[n].location = saved[n]
    scene.unit_settings.system, scene.unit_settings.scale_length = old_units
    img.filepath = old_fp
    img.reload()
    shutil.rmtree(tmp, ignore_errors=True)
    return table, facts


def verify_import_safe(expect_studs):
    """Re-import every new FBX / OBJ in a default metric scene and compare sizes in studs (Roblox X, Y, Z)."""
    rows = []
    files = [(OUT / 'fbx' / ('Kit_%s.fbx' % n), 'fbx', ['Kit_' + n]) for n in KIT_ORDER]
    files.append((OUT / 'GreenHillKit_all.fbx', 'fbx', ['Kit_' + n for n in KIT_ORDER]))
    worst = 0.0
    # OBJ: read the file coordinates directly (OBJ has no axis metadata; Roblox reads them as X, Y-up, Z)
    for n in KIT_ORDER:
        path = OUT / 'obj' / ('Kit_%s.obj' % n)
        vs = [tuple(map(float, ln.split()[1:4])) for ln in path.read_text().splitlines() if ln.startswith('v ')]
        got = [max(v[i] for v in vs) - min(v[i] for v in vs) for i in range(3)]
        err = max(abs(a - b) for a, b in zip(got, expect_studs[n]))
        worst = max(worst, err)
        mtl = (OUT / 'obj' / ('Kit_%s.mtl' % n)).read_text()
        assert 'map_Kd GreenHillAtlas.png' in mtl, path.name
        rows.append((path.name, 'Kit_' + n, [round(v, 3) for v in got], err, ['GreenHillAtlas.png (mtl)']))
        if n == 'SpeedPad':
            # chevrons (top at y ~0.37 around x=0) must point to -Z: the apex (x~0) is further toward -Z than the wings
            top = [v for v in vs if 0.36 < v[1] < 0.38]
            apex = min(v[2] for v in top if abs(v[0]) < 0.05)
            wing = min(v[2] for v in top if 5.0 < abs(v[0]) < 5.2)
            assert apex < wing, ('chevrons do not point to -Z in the OBJ', apex, wing)
    for path, kind, names in files:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(path))
        bpy.context.view_layer.update()
        obs = {o.name.split('.')[0]: o for o in bpy.data.objects if o.type == 'MESH'}
        for nm in names:
            ob = obs.get(nm)
            assert ob is not None, (path.name, nm, list(obs))
            d = ob.dimensions
            got = [d.x, d.z, d.y]
            exp = expect_studs[nm[4:]]
            err = max(abs(a - b) for a, b in zip(got, exp))
            worst = max(worst, err)
            imgs = sorted({i.name for i in bpy.data.images})
            if len(names) == 1 or nm in ('Kit_SpeedPad', 'Kit_TerraceL', 'Kit_MesaTall'):
                rows.append((path.name, nm, [round(v, 3) for v in got], err, imgs))
    # chevron direction after an FBX round trip: apex toward Blender +Y (= Roblox -Z, race direction)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT / 'fbx' / 'Kit_SpeedPad.fbx'))
    ob = bpy.data.objects['Kit_SpeedPad']
    top = [ob.matrix_world @ v.co for v in ob.data.vertices]
    top = [v for v in top if 0.36 < v.z < 0.38]
    assert max(v.y for v in top if abs(v.x) < 0.05) > max(v.y for v in top if 5.0 < abs(v.x) < 5.2), 'FBX chevrons not toward -Z'
    for r in rows:
        print('  re-import %-24s %-18s studs %-28s err %.4f images %s' % (r[0], r[1], r[2], r[3], r[4]))
    log('import-safe re-import check: %d files, worst size error %.5f studs' % (len(files), worst))
    assert worst < 0.01, worst
    return rows, worst


def finish_import_safe(info):
    expect = {n: [info[n]['max'].x - info[n]['min'].x, info[n]['max'].z - info[n]['min'].z, info[n]['max'].y - info[n]['min'].y]
              for n in KIT_ORDER}
    rows, worst = verify_import_safe(expect)
    return rows, worst


def contact_sheet(scene, K, info, coll):
    """Render every kit piece alone in a small studio and tile them into preview/kit_sheet.png."""
    S0 = Vector((5000.0, 5000.0, 0.0))
    gm = bpy.data.materials.new('StudioGround'); gm.use_nodes = True
    gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.42, 0.55, 0.36, 1)
    gme = bpy.data.meshes.new('StudioGround')
    gme.from_pydata([(S0.x - 400, S0.y - 400, 0), (S0.x + 400, S0.y - 400, 0), (S0.x + 400, S0.y + 400, 0), (S0.x - 400, S0.y + 400, 0)], [], [(0, 1, 2, 3)])
    gme.materials.append(gm)
    g = bpy.data.objects.new('StudioGround', gme); coll.objects.link(g)
    cam = add_camera('Cam_Studio', (0, 0, 0), (0, 1, 0), 40, coll)
    scene.camera = cam
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    scene.render.resolution_x, scene.render.resolution_y = 480, 360
    tiles = []
    for n in KIT_ORDER:
        ob = K[n]
        old = ob.location.copy()
        ob.location = S0
        mn, mx = info[n]['min'], info[n]['max']
        c = S0 + (mn + mx) / 2
        diag = (mx - mn).length
        d = Vector((0.75, -1.0, 0.55)).normalized()
        if n == 'SpeedPad':
            d = Vector((0.35, -1.0, 0.75)).normalized()
        if n == 'FenceSection':
            d = Vector((1.0, -0.55, 0.35)).normalized()
        cam.location = c + d * max(diag * 1.25, (mx.z - mn.z) * 1.75)
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        fp = PREV / ('_tile_%s.png' % n)
        scene.render.filepath = str(fp)
        bpy.ops.render.render(write_still=True)
        ob.location = old
        im = bpy.data.images.load(str(fp), check_existing=False)
        px = np.empty(480 * 360 * 4, np.float32); im.pixels.foreach_get(px)
        tiles.append((n, px.reshape(360, 480, 4)[::-1, :, :3].copy()))
        bpy.data.images.remove(im)
        fp.unlink()
    cols = 6
    rows_n = (len(tiles) + cols - 1) // cols
    sheet = np.ones((rows_n * 360, cols * 480, 3), np.float32)
    for i, (n, t) in enumerate(tiles):
        r, c_ = divmod(i, cols)
        sheet[r * 360:(r + 1) * 360, c_ * 480:(c_ + 1) * 480] = t
    im = bpy.data.images.new('kit_sheet', cols * 480, rows_n * 360, alpha=False)
    rgba = np.ones((rows_n * 360, cols * 480, 4), np.float32); rgba[:, :, :3] = sheet
    im.pixels.foreach_set(rgba[::-1].ravel())
    im.filepath_raw = str(PREV / 'kit_sheet.png'); im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)
    scene.render.resolution_x, scene.render.resolution_y = rx, ry
    bpy.data.objects.remove(g)
    log('kit sheet rendered', [n for n, t in tiles])


def verify_fbx(fbx, info):
    expect = {('Kit_' + n): info[n]['max'] - info[n]['min'] for n in KIT_ORDER}
    tris = {('Kit_' + n): info[n]['tris'] for n in KIT_ORDER}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 0.01
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    got = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
    rep = {'objects': len(got), 'missing': sorted(set(expect) - set(got)), 'extra': sorted(set(got) - set(expect)), 'sizes': {}}
    worst = 0.0
    for n, ob in got.items():
        if n not in expect:
            continue
        d = ob.dimensions
        e = expect[n]
        err = max(abs(d.x - e.x), abs(d.y - e.y), abs(d.z - e.z))
        worst = max(worst, err)
        mats = [m.name for m in ob.data.materials]
        imgs = sorted({nd.image.name for m in ob.data.materials if m and m.use_nodes for nd in m.node_tree.nodes if nd.type == 'TEX_IMAGE' and nd.image})
        ob.data.calc_loop_triangles()
        rep['sizes'][n] = dict(dims=[round(d.x, 3), round(d.y, 3), round(d.z, 3)], materials=mats, images=imgs,
                               tris=len(ob.data.loop_triangles), trisOk=len(ob.data.loop_triangles) == tris[n])
    rep['worstSizeError'] = worst
    pad = rep['sizes'].get('Kit_SpeedPad', {}).get('dims')
    rep['speedPadDims'] = pad
    rep['embeddedImages'] = sorted({i.name for i in bpy.data.images})
    rep['packed'] = [i.name for i in bpy.data.images if i.packed_file]
    ok = (not rep['missing'] and not rep['extra'] and worst < 0.01 and pad and abs(pad[0] - 18) < 0.01 and abs(pad[1] - 16) < 0.01)
    rep['ok'] = bool(ok)
    log('FBX re-import check', 'OK' if ok else 'FAILED', 'worst size error %.4f' % worst, 'pad', pad, 'images', rep['embeddedImages'])
    mpath = OUT / 'kit_manifest.json'
    man = json.loads(mpath.read_text())
    man['fbxReimportCheck'] = {k: v for k, v in rep.items() if k != 'sizes'}
    man['fbxReimportCheck']['perPiece'] = {k: {'dims_BlenderXYZ': v['dims'], 'images': v['images'], 'trisOk': v['trisOk']} for k, v in rep['sizes'].items()}
    mpath.write_text(json.dumps(man, indent=1))
    assert ok, rep


main()
log('DONE')
