"""HP-001 E3 Cuyabeno platform skins (visual only, no collision).

Blender 5.2.1:  blender -b --python platform_skins_cuyabeno.py -- --out <dir> [--maya hero_grey.glb] [--pct 100] [--no-stills]

Source boxes: NadiaCoelloO/cacao-rush-3d @ 2191c381a7dda6ea18ea8ef265c86bcd5c0deb5e
  runtime/data/selva1_layout.json   (platforms[].center_m / size_m / top_m, pickups[].center_m)
  runtime/scripts/selva1_play.gd    (_add_box: BoxShape3D size=size_m, body at center_m;
                                     _add_lip: visual lip h=min(0.16, 0.4*size_y) on every box top)
All boxes: depth (Godot Z) 2.6667 m. Oneways 4.0 x 0.6667 (P16: 6.6667 x 0.75). Solids: widths 4..18.67, heights 2.67..28.

Piece frame (Blender, Z-up; glTF/Godot Y-up after export):
  X = level axis, Blender -Y = Godot +Z (toward the gameplay camera), Z = up.
  PIVOT = top face of the collision box: x = segment centre (modules) or the box end (caps),
          depth = box centre (Godot z=0 / Blender y=0), height = top_m.  Every vertex has z <= 0.
"""
from __future__ import annotations
import argparse, hashlib, json, math, struct, sys, time, zlib
from pathlib import Path
import bpy, bmesh
import numpy as np
from mathutils import Vector

SEED = 3101
D = 2.6667            # box depth (Godot z), all platforms
HD = D * 0.5
CW = 1.0 / 3.0        # end-cap width (m)
TOP_T = 1.3333        # Solid_Top band height
FILL_T = 2.0          # Solid_Fill tile height
ONE_H = 0.6667        # oneway box height (P01/P07/P10); P16 0.75 -> scale z 1.125
LIP_H = 0.16          # = selva1_play.gd min(0.16, 0.4*h)
LIP_DROP = 1.10      # lip moss strands hang to -0.40 (inside every box: min box h 0.6667)
LIP_W = 0.35          # lip strip depth on the top
BUDGET = (1500, 600, 200)
ATLAS = 1024
PAL = dict(earth="#3E2C20", earth_dk="#271C15", edge="#6B5846", litter="#3A3029", leaf1="#4E4034", leaf2="#352B23",
           leaf3="#43432F", moss="#34502F", moss_lt="#55704A", bark="#41332A", bark_dk="#2C231D", wood="#4A3F35",
           ring="#6E5B47", ring_dk="#4A3B2E")
# atlas regions (u0, v0, u1, v1), v up
R = dict(earth=(0, .5, .5, 1), litter=(.5, .5, 1, 1), bark=(0, .25, .5, .5), wood=(.5, .25, 1, .5),
         edge=(0, 0, .5, .125), lipmoss=(0, .125, .5, .25), grain=(.5, 0, .75, .25), mosscard=(.75, 0, 1, .25))


def log(*a):
    print("[skins]", *a, flush=True)


def hexrgb(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def uvr(reg, u, v):
    u0, v0, u1, v1 = R[reg]
    pad = 2.0 / ATLAS
    u = min(max(u, 0.0), 1.0); v = min(max(v, 0.0), 1.0)
    return (u0 + pad + (u1 - u0 - 2 * pad) * u, v0 + pad + (v1 - v0 - 2 * pad) * v)


def hn(*a):
    """deterministic hash noise in [0,1)"""
    x = math.sin(sum((i + 1) * 12.9898 * float(v) for i, v in enumerate(a)) + SEED * 0.618) * 43758.5453
    return x - math.floor(x)


def pnoise(x, z, k=1.0):
    """smooth noise periodic in x over 2 m (so modules tile)"""
    t = x * math.pi
    return (0.5 * math.sin(t * 2 + 1.3 * z * k + 0.7) + 0.3 * math.sin(t * 5 - 2.1 * z * k + 2.0) + 0.2 * math.sin(t * 9 + 3.7 * z * k)) * 0.5 + 0.5


# ---------------------------------------------------------------- mesh builder
class MB:
    def __init__(s): s.v, s.f, s.uv = [], [], []

    def V(s, p): s.v.append(tuple(float(c) for c in p)); return len(s.v) - 1

    def F(s, idx, uvs): s.f.append(tuple(idx)); s.uv.append(tuple(uvs))

    def grid(s, P, nu, nv, reg, uvf=None):
        """P(a,b)->xyz for a,b in [0,1]; quads wound by (a,b) order; uvf(a,b)->(u,v) in region space"""
        uvf = uvf or (lambda a, b: (a, b))
        ids = [[s.V(P(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
        for i in range(nu):
            for j in range(nv):
                q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                s.F([ids[a][b] for a, b in q], [uvr(reg, *uvf(a / nu, b / nv)) for a, b in q])
        return ids

    def quad(s, pts, reg, uvs):
        s.F([s.V(p) for p in pts], [uvr(reg, *u) for u in uvs])

    def to_object(s, name, coll, mat):
        me = bpy.data.meshes.new(name)
        me.from_pydata(s.v, [], s.f)
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", [c for f in s.uv for uv in f for c in uv])
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=[]) if False else None
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.to_mesh(me); bm.free()
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me); coll.objects.link(ob)
        return ob


SUB = dict(clump=(0, 0, .5, 1), tuft=(.5, .5, 1, 1), leaf=(.5, 0, 1, .5))   # sub-rects of the "mosscard" region


def card(mb, xa, xb, ztop, zbot, sub, y=None, skew=0.0):
    """alpha-scissor card in the front plane (3 mm inside the box front); skew shifts the bottom edge in x"""
    y = -HD + 0.003 if y is None else y
    u0, v0, u1, v1 = SUB[sub]
    mb.quad([(xa + skew, y, zbot), (xb + skew, y, zbot), (xb, y, ztop), (xa, y, ztop)], "mosscard", [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])


def moss_groups(mb, x0, x1, ztop, q, seed, ngroups):
    """v2: grouped clumps of very different lengths with gaps between the groups"""
    w = x1 - x0
    per = [3, 2, 0][q]
    for g in range(ngroups):
        gc = x0 + w * (g + 0.25 + 0.5 * hn(seed, g, 1)) / ngroups
        for k in range(per):
            cw = 0.07 + 0.10 * hn(seed, g, k, 2)
            xc = min(max(gc + (k - (per - 1) / 2) * 0.07 + 0.03 * (hn(seed, g, k, 3) - .5), x0 + cw / 2), x1 - cw / 2)
            L = [0.14, 0.75, 0.32, 0.55, 0.22][(g * 3 + k + seed) % 5] * (0.8 + 0.4 * hn(seed, g, k, 4))
            zt = ztop - 0.01 * hn(seed, g, k, 5)
            card(mb, xc - cw / 2, xc + cw / 2, zt, zt - L, "clump", y=-HD + 0.003 + 0.002 * k, skew=0.05 * (hn(seed, g, k, 6) - .5))


def root(mb, xs, ztop, L, r0, q, seed, dfun, x0, x1, fork=True, dx=None):
    """v2 root: smooth cubic curve down, radius tapers thick->tip, half-buried in the face, optional fork"""
    seg = [10, 5, 0][q]
    if seg == 0: return
    sides = [5, 4, 0][q]
    dx = (0.25 * (hn(seed, 1) - .5)) if dx is None else dx
    bow = 0.12 * (hn(seed, 2) - .5)
    def P(t):
        x = xs + dx * t * t + bow * math.sin(math.pi * t)
        return min(x1 - 0.03, max(x0 + 0.03, x)), ztop - L * (0.15 * t + 0.85 * t ** 1.15)
    pts = [P(i / seg) for i in range(seg + 1)]
    rings = []
    for i, (x, z) in enumerate(pts):
        t = i / seg; r = max(0.004, r0 * (1 - t) ** 0.9 + 0.004 * t)
        a_ = pts[min(i + 1, seg)]; b_ = pts[max(i - 1, 0)]
        tx, tz = a_[0] - b_[0], a_[1] - b_[1]; Ln = math.hypot(tx, tz) or 1; sx, sz = -tz / Ln, tx / Ln
        front = max(-HD + 0.0005, -HD + dfun(x, z) - 0.55 * r)          # partly buried: ~55 % of the radius shows
        cy = front + r
        rings.append([mb.V((x + sx * r * math.sin(a), cy + r * math.cos(a), z + sz * r * math.sin(a)))
                      for a in [math.pi * (0.5 + k / (sides - 1)) for k in range(sides)]])
    for i in range(seg):
        for k in range(sides - 1):
            mb.F([rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]],
                 [uvr("bark", i / seg, .12 * k / (sides - 1)), uvr("bark", i / seg, .12 * (k + 1) / (sides - 1)),
                  uvr("bark", (i + 1) / seg, .12 * (k + 1) / (sides - 1)), uvr("bark", (i + 1) / seg, .12 * k / (sides - 1))])
    if fork and q == 0 and hn(seed, 9) > 0.45:
        t = 0.4 + 0.15 * hn(seed, 10); fx, fz = P(t)
        root(mb, fx, fz, L * 0.45, r0 * (1 - t) * 0.6, q, seed + 101, dfun, x0, x1, fork=False,
             dx=(0.18 if hn(seed, 11) > .5 else -0.18))


def _clamp01(v): return min(1.0, max(0.0, v))


def make_top_d(nz):
    """v2 seam fix: the last grid row above the Top/Fill join is flat (d = 0.012), so the join vertices get exactly
    the same normal (0, -1, 0) on both pieces -> no shading step at -1.333 m"""
    def f(x, z):
        b = _clamp01(-z / TOP_T)
        return 0.012 + 0.05 * pnoise(x, z * 2.0) * smooth(_clamp01(b * 4)) * smooth(_clamp01((1 - b) * nz - 1.0))
    return f


def make_fill_d(nz):
    def f(x, z):
        b = _clamp01(-z / FILL_T)
        return 0.012 + 0.05 * pnoise(x, z * 2.0 + 5.0) * smooth(_clamp01(b * nz - 1.0)) * smooth(_clamp01((1 - b) * nz - 1.0))
    return f


def xspan(end, w):
    """returns x0,x1 of the piece and the outward end face x (None for modules)"""
    if end is None: return -w / 2, w / 2, None
    if end == "L": return 0.0, CW, 0.0
    return -CW, 0.0, 0.0


def end_face(mb, prof, xe, outward, reg, uvf):
    """ngon end face from a closed YZ profile at x=xe"""
    idx = [mb.V((xe, y, z)) for y, z in prof]
    uvs = [uvr(reg, *uvf(y, z)) for y, z in prof]
    if outward < 0: mb.F(idx, uvs)
    else: mb.F(idx[::-1], uvs[::-1])


# ---------------------------------------------------------------- pieces
EDGE_Y = 0.40     # v2.1: Solid_Top's flat top stops 0.40 m behind the front; Lip_* is the crumbly edge (required on solids)
EDGE_Z = 0.30     # ...and its earth face starts 0.30 m below the top


def nx_shift(x, end):
    """noise coordinate continuous across cap|module joins (L cap x=CW meets module x=-1, R cap x=-CW meets x=+1)"""
    if end == "L": return x - CW - 1.0
    if end == "R": return x + CW + 1.0
    return x


def solid_top(q, end=None):
    mb = MB(); x0, x1, xe = xspan(end, 2.0); w = x1 - x0
    nx = max(1, round([10, 4, 1][q] * w / 2.0))
    ny = [5, 2, 1][q]
    yb = -HD + EDGE_Y
    mb.grid(lambda a, b: (x0 + w * a, yb + (HD - yb) * b, 0.0), nx, ny, "litter",
            lambda a, b: ((x0 + w * a + 1) / 2 % 1.0001, 0.15 + 0.85 * b))
    nz = [7, 3, 1][q]
    top_d = make_top_d(nz)
    ztop = -EDGE_Z
    def frontP(a, b):
        x = x0 + w * a; z = ztop + (-TOP_T - ztop) * b
        d = 0.0 if (b == 0 or q == 2) else top_d(x, z)
        if b > 0 and q < 2 and b * nz < 0.999: d = d * smooth(_clamp01(b * nz))
        if b == 0 and q < 2: d = 0.03                                   # v2.3: face top edge tucked behind the Lip crumble (no crease)
        return (x, -HD + d, z)
    mb.grid(frontP, nx, nz, "earth", lambda a, b: ((x0 + w * a + 1) / 2 % 1.0001, 1 - (0.11 + 0.89 * b) * 0.5))
    if q < 2:
        mb.quad([(x1, HD, 0), (x0, HD, 0), (x0, HD, -TOP_T), (x1, HD, -TOP_T)], "earth", [(1, 1), (0, 1), (0, .3), (1, .3)])
    nroots = [4, 2, 0][q] if end is None else [1, 0, 0][q]
    for k in range(nroots):
        xs = x0 + w * (0.1 + 0.8 * (k + hn(k, 1)) / max(1, nroots))
        root(mb, xs, ztop - 0.005, 0.5 + 0.5 * hn(k, 2), 0.05 - 0.012 * hn(k, 3), q, k * 7 + 3, top_d, x0, x1)
    if xe is not None:
        prof = [(HD, 0.0), (yb, 0.0), (-HD, ztop), (-HD, -TOP_T), (HD, -TOP_T)]
        end_face(mb, prof, xe, -1 if end == "L" else 1, "earth", lambda y, z: ((y + HD) / D, 1 + z / 2.0))
    return mb


def moss_beards(mb, x0, x1, q, under):
    """v2.2: 3 hanging-moss bundles per module (0.15 m / 0.4 m / 0.9 m beard) draping from the lip undercut.
    Each bundle = a clustered fan of alpha-scissor strand cards, 2 segments each with a sideways sway."""
    # v2.3: beard goes where no root crosses it (max distance from the Solid_Top / Lip root x positions)
    roots_f = [0.1 + 0.8 * (k + hn(k, 1)) / 4 for k in range(4)] + [0.3 + 0.1 * hn(0, 71), 0.75 + 0.1 * hn(1, 71)]
    cand = [0.12 + 0.02 * i for i in range(39)]
    fb = max(cand, key=lambda f: min(abs(f - r) for r in roots_f))
    others = sorted([f for f in (0.16, 0.50, 0.84) if abs(f - fb) > 0.22], key=lambda f: -min(abs(f - r) for r in roots_f))[:2]
    spec = [(fb, 0.92, 0.34)] + [(f, L_, cw_) for f, (L_, cw_) in zip(others, ((0.40, 0.26), (0.16, 0.20)))]
    if q == 1: spec = spec[:2]
    ncard = [6, 3][q]; nseg = [3, 1][q]
    w = x1 - x0
    u0, v0, u1, v1 = SUB["clump"]
    for g, (fx, L, cw) in enumerate(spec):
        gx = x0 + w * fx
        uy, uz = under(gx)
        ztop = min(uz, -0.05)
        mb.beard_x = getattr(mb, "beard_x", []) + [gx]
        for c in range(ncard):
            t = (c + 0.5) / ncard - 0.5
            Lc = L * (0.55 + 0.45 * hn(g, c, 1)) if c else L                 # one full-length card per bundle
            zt = ztop + 0.03 - 0.06 * hn(g, c, 7)                             # staggered tops
            wc = cw * (0.45 + 0.4 * hn(g, c, 2))
            xc = min(max(gx + t * cw * 0.7, x0 + wc / 2 + 0.01), x1 - wc / 2 - 0.01)
            sway = (0.05 + 0.08 * L) * (hn(g, c, 3) - 0.5) * 2
            y = -HD + 0.0025 + 0.0035 * c                                    # in front of the crumble, inside the box
            mir = c % 2
            ua, ub = (u1, u0) if mir else (u0, u1)
            prev = None
            for sgi in range(nseg + 1):
                f = sgi / nseg
                z = zt - Lc * f
                dx = sway * f * f + 0.5 * wc * t * f                        # sway + slight fan-out
                ww = wc * (1 - 0.25 * f)
                yy = y + (0.025 if sgi == 0 else 0.0)                             # top tucked back toward the earth (bend)
                a = mb.V((xc - ww / 2 + dx, yy, z)); b = mb.V((xc + ww / 2 + dx, yy, z))
                vv = v1 - (v1 - v0) * f
                if prev:
                    pa, pb, pv = prev
                    mb.F([a, b, pb, pa], [uvr("mosscard", ua, vv), uvr("mosscard", ub, vv), uvr("mosscard", ub, pv), uvr("mosscard", ua, pv)])
                prev = (a, b, vv)


def moss_clumps(mb, x0, x1, ztop, q):
    """v2.1: 2-3 organic clumps per module (short tuft / long beard / mid), bare gaps between them"""
    spec = [(0.18, 0.30, 0.22, 0), (0.52, 0.42, 0.85, 1), (0.84, 0.30, 0.38, 0)][: [3, 2][q]]
    w = x1 - x0
    for k, (fx, cw, L, mir) in enumerate(spec):
        xc = min(max(x0 + w * fx, x0 + cw / 2), x1 - cw / 2)
        zt = ztop - 0.02 * hn(k, 81)
        u0, v0, u1, v1 = SUB["clump"]
        if mir: u0, u1 = u1, u0
        y = -HD + 0.004 + 0.002 * k
        mb.quad([(xc - cw / 2 + 0.03, y, zt - L), (xc + cw / 2 + 0.03, y, zt - L), (xc + cw / 2, y, zt), (xc - cw / 2, y, zt)], "mosscard",
                [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])


def smooth(t): return t * t * (3 - 2 * t)


def solid_fill(q, end=None):
    mb = MB(); x0, x1, xe = xspan(end, 2.0); w = x1 - x0
    nx = max(1, round([8, 4, 1][q] * w / 2.0)); nz = [8, 4, 1][q]
    fill_d = make_fill_d(nz)
    def P(a, b):
        x = x0 + w * a; z = -FILL_T * b
        d = 0.0 if q == 2 else fill_d(x, z)
        return (x, -HD + d, z)
    mb.grid(P, nx, nz, "earth", lambda a, b: ((x0 + w * a + 1) / 2 % 1.0001, 0.5 - 0.5 * b))
    if q < 2:
        mb.quad([(x1, HD, 0), (x0, HD, 0), (x0, HD, -FILL_T), (x1, HD, -FILL_T)], "earth", [(1, 1), (0, 1), (0, 0), (1, 0)])
    for k in range([2, 1, 0][q] if end is None else 0):
        xs = x0 + w * (0.25 + 0.5 * hn(k, 21))
        root(mb, xs, -0.02, 1.2 + 0.5 * hn(k, 22), 0.032, q, k * 13 + 50, fill_d, x0, x1)
    if xe is not None:
        end_face(mb, [(HD, 0.0), (-HD, 0.0), (-HD, -FILL_T), (HD, -FILL_T)], xe, -1 if end == "L" else 1, "earth",
                 lambda y, z: ((y + HD) / D, 1 + z / 2.0))
    return mb


LOG_R = 0.335
LOG_ZC = -0.315


def log_ring(n, x, rough):
    """v2.1 round log: centre on the box depth centre (grains sit at y=0), r ~0.335, bow in y, flat adzed top at z=0"""
    r = LOG_R * (1.0 - 0.035 * pnoise(x * 0.5 + 0.2, 0.3))            # slow taper / swelling (periodic over 2 m)
    yc = 0.05 * math.sin(math.pi * x) + 0.02 * math.sin(2 * math.pi * x + 1)
    pts = []
    for k in range(n):
        th = 2 * math.pi * k / n + math.pi / 2
        rr = r * (1 - (0.045 * pnoise(x * 1.3 + k * 0.37, k * 1.9) if rough else 0))
        y = yc + rr * math.cos(th); z = LOG_ZC + rr * math.sin(th)
        pts.append((y, min(z, 0.0), z >= 0.0))
    return pts


def oneway(q, end=None):
    mb = MB(); x0, x1, xe = xspan(end, 2.0); w = x1 - x0
    n = [16, 10, 6][q]; nx = max(1, round([10, 4, 1][q] * w / 2.0))
    rings = []
    for i in range(nx + 1):
        x = x0 + w * i / nx; xs = nx_shift(x, end)
        rings.append([(mb.V((x, y, z)), flat) for y, z, flat in log_ring(n, xs, q < 2)])
    for i in range(nx):
        uo = 1.0 if end == "L" else (-1.0 if end == "R" else 0.0)       # v2.2: caps continue the module's bark u
        ua = (nx_shift(x0 + w * i / nx, end) + 1) / 2 + uo
        ub = (nx_shift(x0 + w * (i + 1) / nx, end) + 1) / 2 + uo
        for k in range(n):
            k2 = (k + 1) % n
            flat = rings[i][k][1] and rings[i][k2][1]
            reg = "wood" if flat else "bark"
            va, vb = k / n, (k + 1) / n
            mb.F([rings[i][k][0], rings[i + 1][k][0], rings[i + 1][k2][0], rings[i][k2][0]],
                 [uvr(reg, ua, va), uvr(reg, ub, va), uvr(reg, ub, vb), uvr(reg, ua, vb)])
    if end is None and q < 2:
        # broken branch stub on the front-lower side, pointing out/down (stays inside the box)
        sx = x0 + w * 0.62; seg = [5, 3][q]; sides = [7, 5][q]
        base = (sx, -LOG_R * 0.80, LOG_ZC - LOG_R * 0.45)
        dirv = Vector((0.25, -0.75, -0.45)).normalized()
        L = 0.28; ringsS = []
        for t in range(seg + 1):
            tt = t / seg; c = Vector(base) + dirv * (L * tt); rr = 0.075 * (1 - 0.55 * tt)
            a = dirv.orthogonal().normalized(); b = dirv.cross(a)
            ringsS.append([mb.V(c + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * rr) for k in range(sides)])
        for t in range(seg):
            for k in range(sides):
                k2 = (k + 1) % sides
                mb.F([ringsS[t][k], ringsS[t][k2], ringsS[t + 1][k2], ringsS[t + 1][k]],
                     [uvr("bark", t / seg, k / sides * .2), uvr("bark", t / seg, (k + 1) / sides * .2), uvr("bark", (t + 1) / seg, (k + 1) / sides * .2), uvr("bark", (t + 1) / seg, k / sides * .2)])
        tip = ringsS[-1]
        mb.F(tip[::-1], [uvr("grain", .5 + .4 * math.cos(2 * math.pi * k / sides), .5 + .4 * math.sin(2 * math.pi * k / sides)) for k in range(sides)][::-1])
        # a short moss clump hanging off the belly
        u0, v0, u1, v1 = SUB["clump"]
        cx = x0 + w * 0.28; yv = -LOG_R * 0.55
        mb.quad([(cx - 0.12, yv, -0.62), (cx + 0.14, yv, -0.62), (cx + 0.12, yv, -0.42), (cx - 0.12, yv, -0.42)], "mosscard", [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    if xe is not None:
        ring = log_ring(n, nx_shift(xe, end), q < 2)
        prof = [(y, z) for y, z, _f in ring]
        end_face(mb, prof, xe, -1 if end == "L" else 1, "grain", lambda y, z: (0.5 + 0.5 * y / (LOG_R * 1.1), 0.5 + 0.5 * (z - LOG_ZC) / (LOG_R * 1.1)))
    return mb


def lip_edge(x, end):
    """edge outline: how far the brink sits behind the box front (3-15 cm), scallops + bites; varies along X"""
    xs = nx_shift(x, end)
    f = 0.5 * pnoise(xs * 1.0 + 0.4, 0.2) + 0.5 * abs(math.sin(math.pi * (2.5 * xs + 0.7 * math.sin(math.pi * xs))))
    return 0.03 + 0.12 * f


def lip(q, end=None):
    """v2.1: the earth top itself breaking down into the face. No tube, no constant cross-section."""
    mb = MB(); x0, x1, xe = xspan(end, 2.0); w = x1 - x0
    nx = max(2, round([28, 10, 3][q] * w / 2.0))
    def rows(x):
        xs = nx_shift(x, end)
        e = lip_edge(x, end); n1 = pnoise(xs * 1.7 + 2.0, 1.1); n2 = pnoise(xs * 2.9 + 0.5, 2.3); n3 = pnoise(xs * 4.1 + 1.3, 0.4)
        if q == 2:
            return [(-HD + EDGE_Y, 0.0), (-HD + e, -0.02), (-HD, -EDGE_Z)]
        over = 0.035 * n3                                          # small overhang: brink sticks out over an undercut
        return [(-HD + EDGE_Y, 0.0),
                (-HD + e + 0.08 + 0.06 * n1, -0.002 - 0.006 * n2),      # crumbly top approaching the brink
                (-HD + e, -0.012 - 0.035 * n2),                          # brink (outline varies 3-15 cm)
                (-HD + e + over + 0.01, -0.07 - 0.05 * n1),              # undercut / bite
                (-HD + 0.004 + 0.03 * n3 * (1 - n2), -0.15 - 0.05 * n3),  # crumbled earth breaking into the face
                (-HD + 0.0008, -EDGE_Z - 0.10 * pnoise(xs * 2.2 + 0.9, 3.3) - 0.03 * n2)]   # v2.3: ragged bottom, overlaps the face
    R = [rows(x0 + w * i / nx) for i in range(nx + 1)]
    m = len(R[0])
    ids = [[mb.V((x0 + w * i / nx, y, z)) for (y, z) in R[i]] for i in range(nx + 1)]
    for i in range(nx):
        ua, ub = ((x0 + w * i / nx) + 1) / 2, ((x0 + w * (i + 1) / nx) + 1) / 2
        for k in range(m - 1):
            reg = "litter" if k == 0 else "lipmoss"
            va, vb = 1 - k / (m - 1), 1 - (k + 1) / (m - 1)
            if reg == "litter": va, vb = 0.15, 0.02
            mb.F([ids[i][k], ids[i + 1][k], ids[i + 1][k + 1], ids[i][k + 1]],
                 [uvr(reg, ua % 1.0001, va), uvr(reg, ub % 1.0001, va), uvr(reg, ub % 1.0001, vb), uvr(reg, ua % 1.0001, vb)])
    if end is None and q < 2:
        def brink(x):
            r = rows(x); return r[2]
        for k in range([6, 3][q]):                                       # tufts of different heights on the brink
            xc = x0 + w * (0.06 + 0.88 * hn(k, 51)); cw = 0.06 + 0.09 * hn(k, 52)
            xc = min(max(xc, x0 + cw / 2), x1 - cw / 2)
            by, bz = brink(xc)
            tip = min(-0.004, bz + 0.005 - 0.0) if hn(k, 53) > 0.5 else bz - 0.03 * hn(k, 55)
            card(mb, xc - cw / 2, xc + cw / 2, tip, bz - 0.10 - 0.10 * hn(k, 54), "tuft", y=by - 0.004 if by - 0.004 > -HD else -HD + 0.001)
        for k in range([3, 1][q]):                                       # leaves drooping over the brink
            xc = x0 + w * (0.2 + 0.6 * (k + hn(k, 61)) / 3); lw = 0.07 + 0.04 * hn(k, 62)
            r_ = rows(xc); (y1, z1), (y2, z2) = r_[1], r_[2]
            zt = z2 - 0.12 - 0.08 * hn(k, 64); yd = max(-HD + 0.002, y2 - 0.02)
            a = mb.V((xc - lw / 2, y1 + 0.02, z1 - 0.0)); b = mb.V((xc + lw / 2, y1 + 0.02, z1 - 0.0))
            c = mb.V((xc + lw / 2, y2 - 0.003, z2 + 0.004)); d = mb.V((xc - lw / 2, y2 - 0.003, z2 + 0.004))
            e = mb.V((xc + lw / 2 + 0.02, yd, zt)); f = mb.V((xc - lw / 2 + 0.03, yd, zt))
            u0, v0, u1, v1 = SUB["leaf"]; vm = v0 + .55 * (v1 - v0)
            mb.F([a, b, c, d], [uvr("mosscard", u0, v1), uvr("mosscard", u1, v1), uvr("mosscard", u1, vm), uvr("mosscard", u0, vm)])
            mb.F([d, c, e, f], [uvr("mosscard", u0, vm), uvr("mosscard", u1, vm), uvr("mosscard", u1, v0), uvr("mosscard", u0, v0)])
        moss_beards(mb, x0, x1, q, lambda x: rows(x)[3])
        for k in range([2, 1][q]):                                       # a root curling out of the crumble
            xr = x0 + w * (0.3 + 0.45 * k + 0.1 * hn(k, 71))
            root(mb, xr, -0.06, 0.26 + 0.1 * hn(k, 72), 0.032, q, 300 + k, lambda x, z: 0.0, x0, x1, fork=False, dx=0.18 * (1 if k else -1))
    if xe is not None:
        prof = rows(xe)[::-1] + [(-HD + EDGE_Y, -EDGE_Z)]
        prof = [(-HD + EDGE_Y, 0.0)] + rows(xe)[1:] + [(-HD + EDGE_Y, -EDGE_Z)]
        end_face(mb, prof, xe, -1 if end == "L" else 1, "lipmoss", lambda y, z: ((y + HD) / EDGE_Y, 1 + z / EDGE_Z))
    return mb


PIECES = {  # name: (builder, box height covered below the pivot)
    "Solid_Top_2m": (solid_top, None, TOP_T), "Solid_Top_CapL": (solid_top, "L", TOP_T), "Solid_Top_CapR": (solid_top, "R", TOP_T),
    "Solid_Fill_2m": (solid_fill, None, FILL_T), "Solid_Fill_CapL": (solid_fill, "L", FILL_T), "Solid_Fill_CapR": (solid_fill, "R", FILL_T),
    "Oneway_2m": (oneway, None, ONE_H), "Oneway_CapL": (oneway, "L", ONE_H), "Oneway_CapR": (oneway, "R", ONE_H),
    "Lip_2m": (lip, None, LIP_DROP), "Lip_CapL": (lip, "L", LIP_DROP), "Lip_CapR": (lip, "R", LIP_DROP),
}


# ---------------------------------------------------------------- atlas
def periodic_noise(rs, h, w, beta=2.0, lo=2):
    f = rs.standard_normal((h, w)) + 1j * rs.standard_normal((h, w))
    ky = np.fft.fftfreq(h)[:, None] * h; kx = np.fft.fftfreq(w)[None, :] * w
    k = np.sqrt(kx ** 2 + ky ** 2); k[0, 0] = 1
    f *= 1 / k ** (beta / 2); f[k < lo] *= 0.3; f[0, 0] = 0
    n = np.real(np.fft.ifft2(f)); n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    return n.astype(np.float32)


def paint_atlas(path):
    rs = np.random.default_rng(SEED)
    S = ATLAS
    img = np.zeros((S, S, 4), np.float32); img[..., 3] = 1
    C = {k: hexrgb(v) for k, v in PAL.items()}

    def region(reg):
        u0, v0, u1, v1 = R[reg]
        r0, r1 = int((1 - v1) * S), int((1 - v0) * S); c0, c1 = int(u0 * S), int(u1 * S)
        return r0, r1, c0, c1

    def put(reg, rgb, a=None):
        r0, r1, c0, c1 = region(reg)
        img[r0:r1, c0:c1, :3] = np.clip(rgb, 0, 1)
        if a is not None: img[r0:r1, c0:c1, 3] = a

    # earth front (512x512, top of region = top of the face)
    h, w = 512, 512
    n1 = periodic_noise(rs, h, w, 2.2); n2 = periodic_noise(rs, h, w, 1.4, 8)
    # v2 seam fix: the lower half (v 0..0.5, used by Solid_Fill and the bottom of Solid_Top) repeats every 256 rows,
    # so Top->Fill and Fill->Fill joins land on identical texel rows.
    rs2 = np.random.default_rng(SEED + 7)
    n1 = np.tile(periodic_noise(rs2, 256, w, 2.2), (2, 1)); n2 = np.tile(periodic_noise(rs2, 256, w, 1.4, 8), (2, 1))
    yy = np.linspace(0, 1, h)[:, None]
    drip = periodic_noise(rs, h, w // 8 * 8, 2.0)[:, :]
    streak = np.repeat(periodic_noise(rs, 8, w, 2.0, 1)[:1], h, 0)
    base = C["earth"][None, None] * (0.78 + 0.45 * n1[..., None]) * (0.85 + 0.25 * streak[..., None])
    base = base * (1 - 0.25 * (n2[..., None] > 0.72)) + C["earth_dk"] * 0.2 * (n2[..., None] > 0.72)
    peb = (n2 > 0.8) & (n1 > 0.55)
    base[peb] = base[peb] * 0.6 + C["edge"] * 0.4
    _ = periodic_noise(rs, h, w, 2.4)
    moss = (np.tile(periodic_noise(rs2, 256, w, 2.4), (2, 1)) * (1.2 - yy * 1.6)) > 0.55
    base[moss] = base[moss] * 0.25 + (C["moss"] * (0.8 + 0.4 * n2[moss][:, None])) * 0.75
    put("earth", base)
    # leaf-litter top
    n1 = periodic_noise(rs, h, w, 2.0)
    lit = C["litter"][None, None] * (0.75 + 0.45 * n1[..., None])
    Y, X = np.mgrid[0:h, 0:w]
    leafcols = [C["leaf1"], C["leaf2"], C["leaf3"], C["leaf1"] * 0.8, C["moss"]]
    for i in range(260):
        cx, cy = rs.uniform(0, w), rs.uniform(0, h); L = rs.uniform(16, 34); Wd = L * rs.uniform(0.3, 0.45); a = rs.uniform(0, math.pi)
        col = leafcols[i % 5] * rs.uniform(0.8, 1.15)
        for ox in (-w, 0, w):
            dx = (X - cx - ox); dy = (Y - cy)
            if abs(cx + ox - w / 2) > w / 2 + L: continue
            u = dx * math.cos(a) + dy * math.sin(a); v = -dx * math.sin(a) + dy * math.cos(a)
            m = (u / L) ** 2 + (v / Wd) ** 2 < 1
            lit[m] = col * (0.85 + 0.25 * (u[m] / L))[:, None] * (1 - 0.35 * (np.abs(v[m]) < 1.2)[:, None])
    mt = periodic_noise(rs, h, w, 2.6) > 0.66
    lit[mt] = lit[mt] * 0.3 + C["moss"] * 0.7
    put("litter", lit)
    # bark v2.1 (u = along the log, v = around): broken lens-shaped fissures following the length, plates, 2 knots,
    # moss on the upper sides (v near 0/1 = top of the log). No continuous stripes.
    h2 = 256
    nb = periodic_noise(rs, h2, w, 1.8, 3); _ = periodic_noise(rs, h2, 8, 2.0); _ = periodic_noise(rs, h2, w, 2.4)
    rs5 = np.random.default_rng(SEED + 31)
    plate = periodic_noise(rs5, h2, w, 2.2)
    bark = C["bark"] * (0.78 + 0.4 * plate[..., None]) * (0.9 + 0.2 * nb[..., None])
    Yb, Xb = np.mgrid[0:h2, 0:w]
    for k in range(150):
        cx, cy = rs5.uniform(0, w), rs5.uniform(0, h2); L = rs5.uniform(30, 110); wd = rs5.uniform(1.2, 3.2); ang = rs5.normal(0, 0.08)
        for ox in (-w, 0, w):
            dx = Xb - cx - ox; dy = Yb - cy
            u = dx * math.cos(ang) + dy * math.sin(ang); v = -dx * math.sin(ang) + dy * math.cos(ang)
            m = (np.abs(u) < L / 2) & (np.abs(v) < wd * (1 - (2 * u / L) ** 2).clip(0))
            bark[m] = C["bark_dk"] * 0.85
    for kx, ky in ((150, 150), (380, 95)):                                    # knots
        r2 = ((Xb - kx) / 16.0) ** 2 + ((Yb - ky) / 11.0) ** 2
        bark[r2 < 1] = C["bark_dk"] * 0.7; ring = (r2 > 1) & (r2 < 2.2); bark[ring] = bark[ring] * 1.2
        bark[(r2 < 0.35)] = C["ring"] * 0.8
    vv = Yb / (h2 - 1); topness = np.maximum(1 - vv / 0.22, 0) + np.maximum((vv - 0.78) / 0.22, 0)
    mm = (periodic_noise(rs5, h2, w, 2.4) * (0.4 + topness)) > 0.62
    bark[mm] = bark[mm] * 0.25 + C["moss"] * (0.8 + 0.3 * plate[mm][:, None]) * 0.75
    put("bark", bark)
    # hewn wood top
    g = periodic_noise(rs, h2, w, 1.6, 2)
    gl = 0.5 + 0.5 * np.sin(np.linspace(0, 1, h2)[:, None] * 2 * math.pi * 30 + 9 * g)
    wood = C["wood"] * (0.78 + 0.25 * gl[..., None]) * (0.85 + 0.3 * periodic_noise(rs, h2, w, 2.4)[..., None])
    adz = np.repeat(periodic_noise(rs, 8, w, 1.2, 6)[:1], h2, 0) > 0.6; wood[adz] *= 0.85
    wm = periodic_noise(rs, h2, w, 2.4) > 0.7; wood[wm] = wood[wm] * 0.4 + C["moss"] * 0.6
    edge_rows = np.r_[0:10, h2 - 10:h2]; wood[edge_rows] *= 0.75
    put("wood", wood)
    # light top edge (128 rows)
    h3 = 128
    ne = periodic_noise(rs, h3, w, 2.0)
    yy = np.linspace(0, 1, h3)[:, None, None]
    edge = C["edge"] * (1 - 0.35 * yy) * (0.85 + 0.3 * ne[..., None]) + C["earth"] * 0.35 * yy
    em = periodic_noise(rs, h3, w, 2.5) > 0.7; edge[em] = edge[em] * 0.4 + C["moss"] * 0.6
    put("edge", edge)
    # v2 lip: irregular earth edge with PATCHY moss (no continuous band, no bright rim line)
    rs3 = np.random.default_rng(SEED + 11)
    nm = periodic_noise(rs3, h3, w, 2.0); np_ = periodic_noise(rs3, h3, w, 2.6, 4); nc = periodic_noise(rs3, h3, w, 1.0, 20)
    lm = (C["edge"] * 0.25 + C["earth"] * 0.75) * (0.7 + 0.5 * nm[..., None]) * np.ones((h3, w, 1))
    patch = np_ > 0.64
    lm[patch] = lm[patch] * 0.3 + C["moss"] * (0.75 + 0.4 * nm[patch][:, None]) * 0.7
    crumb = nc > 0.78; lm[crumb] *= 0.65
    # v2.3 bleed: the bottom 40 % of the lip texture fades into the face's dark wet earth with moss blotches
    fy = np.clip((np.arange(h3)[:, None] / (h3 - 1) - 0.6) / 0.4, 0, 1)[..., None]
    face = C["earth"] * (0.8 + 0.35 * nm[..., None])
    fm = (np_ > 0.5)[..., None]
    face = np.where(fm, face * 0.35 + C["moss"] * 0.65, face)
    lm = lm * (1 - fy) + face * fy
    put("lipmoss", lm)
    # end grain rings
    gs = 256
    yy, xx = np.mgrid[0:gs, 0:gs] / gs
    rr = np.sqrt(((xx - .5) * 1.0) ** 2 + ((yy - 0.15) * 2.2) ** 2)
    ng = periodic_noise(rs, gs, gs, 2.0)
    ring = 0.5 + 0.5 * np.sin(rr * 90 + ng * 6)
    eg = C["ring"] * (0.75 + 0.3 * ring[..., None]) * (1 - 0.25 * (ring[..., None] < 0.2))
    eg = eg * (1 - 0.35 * np.clip((rr[..., None] - 0.55) * 4, 0, 1)) + C["ring_dk"] * 0.0
    put("grain", eg)
    # v2 cards: [clump 128x256 | tuft 128x128 (top) / leaf 128x128 (bottom)]
    hc, wc = 256, 256
    a = np.zeros((hc, wc), np.float32); col = np.zeros((hc, wc, 3), np.float32) + C["moss"]
    rs4 = np.random.default_rng(SEED + 23)
    def strand(x, y0, L, wd, sway, colf, up=False, xlo=0, xhi=127):
        for i in range(int(L)):
            t = i / max(1, L); xx_ = x + sway * t * t
            ww = max(0.45, wd * (1 - t) ** 1.3)
            yy_ = int(y0 - i) if up else int(y0 + i)
            if not (0 <= yy_ < hc): continue
            c0 = int(max(xlo, round(xx_ - ww))); c1 = int(min(xhi, round(xx_ + ww))) + 1
            if c1 <= c0: continue
            a[yy_, c0:c1] = 1.0; col[yy_, c0:c1] = colf(t)
    # clump v2.1: ONE organic clump per card - strands splay from a small root mass, curve, taper to fine tips,
    # very different lengths; olive / brown tones mixed with light-brown rootlets. Card edges stay empty.
    def splay(x0_, y0_, ang, L, wd, curl, colf):
        x_, y_ = x0_, y0_; n = int(L)
        for i in range(n):
            t = i / max(1, n); th = ang + curl * t * t
            x_ += math.sin(th); y_ += math.cos(th)
            rr = max(0.5, wd * (1 - t) ** 1.4)
            yi, xi = int(y_), int(x_)
            if not (0 <= yi < hc and 0 <= xi < 128): break
            r_ = int(math.ceil(rr))
            ya, yb_ = max(0, yi - r_), min(hc, yi + r_ + 1); xa, xb = max(1, xi - r_), min(127, xi + r_ + 1)
            if xb <= xa or yb_ <= ya: continue
            YY, XX = np.mgrid[ya:yb_, xa:xb]; m = (YY - y_) ** 2 + (XX - x_) ** 2 <= rr * rr
            a[ya:yb_, xa:xb][m] = 1.0; col[ya:yb_, xa:xb][m] = colf(t)
    olive, brown, root_c = hexrgb("#3C4027"), hexrgb("#4C3E2E"), hexrgb("#8A735A")
    mossg = C["moss"]
    a[:] = 0
    # v2.2 strand bundle: dense mass at the top, strands thin out and split into tapered wisps toward the bottom
    for k in range(150):
        L = hc * min(0.99, max(0.15, rs4.beta(2.2, 1.6)))
        x0_ = 64 + rs4.normal(0, 20)
        ang = rs4.normal(0, 0.10) + (x0_ - 64) / 64 * 0.12
        tone = (olive, mossg, brown)[k % 3] * rs4.uniform(0.75, 1.15)
        splay(x0_, rs4.uniform(10, 26), ang, L, rs4.uniform(1.4, 3.0), rs4.normal(0, 0.35),
              lambda t, tone=tone: tone * (0.9 - 0.25 * t) + C["moss_lt"] * 0.1 * t)
    for k in range(14):
        splay(64 + rs4.normal(0, 22), 1, rs4.normal(0, 0.15), hc * rs4.uniform(0.5, 0.98), 0.75, rs4.normal(0, 0.5),
              lambda t: root_c * (1 - 0.2 * t))
    # v2.3: no straight top - a ragged moss cushion of overlapping blobs, outline varies per column, rows 0-2 always empty
    a[0:3, 0:128] = 0.0
    for k in range(26):
        cx_, cy_ = 64 + rs4.normal(0, 20), rs4.uniform(8, 26); rx, ry = rs4.uniform(6, 15), rs4.uniform(4, 9)
        YY, XX = np.mgrid[0:40, 0:128]; m = ((XX - cx_) / rx) ** 2 + ((YY - cy_) / ry) ** 2 < 1
        m &= rs4.random((40, 128)) > 0.12
        a[0:40, 0:128][m] = 1.0; col[0:40, 0:128][m] = (mossg * 0.9 if k % 2 else olive) * rs4.uniform(0.7, 1.1)
    for k in range(30):                                                         # short tufts poking up out of the cushion
        splay(64 + rs4.normal(0, 22), rs4.uniform(12, 22), math.pi + rs4.normal(0, 0.4), rs4.uniform(5, 13), 1.4, 0.0, lambda t: mossg * (1.0 - 0.3 * t))
    a[0:3, 0:128] = 0.0; a[:, :2] = 0.0; a[:, 126:128] = 0.0
    # tuft (anchored at the bottom of its 128x128 tile, blades up)
    for k in range(22):
        x = 128 + 64 + rs4.normal(0, 14); L = rs4.uniform(0.35, 0.95) * 120
        sh = rs4.uniform(0.8, 1.15)
        strand(x, 127, L, rs4.uniform(1.5, 2.8), rs4.uniform(-26, 26), lambda t, sh=sh: (C["moss"] * 0.8 + C["leaf3"] * 0.2) * sh * (0.85 + 0.35 * t), up=True, xlo=129, xhi=254)
    # leaf (128x128 tile at rows 128..255): elongated, base at the top, tip at the bottom
    yy_, xx_ = np.mgrid[0:128, 0:128]
    t = yy_ / 127.0; half = 26 * np.sin(np.pi * np.clip(t, 0, 1)) ** 0.8 * (1 - 0.25 * t)
    m = np.abs(xx_ - 64) < half
    lc = (C["leaf1"] * 0.6 + C["leaf3"] * 0.4) * (0.9 + 0.2 * periodic_noise(rs4, 128, 128, 2.0))[..., None]
    lc[np.abs(xx_ - 64) < 1.2] *= 0.75
    a[128:, 128:][m] = 1.0; col[128:, 128:][m] = lc[m]
    r0, r1, c0, c1 = region("mosscard")
    img[r0:r1, c0:c1, :3] = col; img[r0:r1, c0:c1, 3] = a
    # alpha only on the card region; everything else opaque
    out = (np.clip(img, 0, 1) ** (1.0) * 255 + 0.5).astype(np.uint8)
    raw = b"".join(b"\x00" + out[y].tobytes() for y in range(S))
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    return out


def magenta_count(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(r == mx, 60 * (((g - b) / d) % 6), np.where(b == mx, 60 * ((r - g) / d + 4), 60 * ((b - r) / d + 2)))
    return int(((g == mn) & (mx > 0.35) & (sat > 0.45) & (hue >= 285) & (hue <= 335)).sum())


def make_material(tex_path):
    mat = bpy.data.materials.new("M_PlatformSkins_Cuyabeno")
    mat.use_nodes = True; nt = mat.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = bpy.data.images.load(str(tex_path)); ti.image.colorspace_settings.name = "sRGB"
    nt.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
    rnd = nt.nodes.new("ShaderNodeMath"); rnd.operation = "ROUND"          # glTF alphaMode MASK (cutoff 0.5)
    nt.links.new(ti.outputs["Alpha"], rnd.inputs[0]); nt.links.new(rnd.outputs["Value"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.62                           # wet earth / damp wood
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    mat.use_backface_culling = False
    return mat


def export_glb(path, objs):
    for o in bpy.context.view_layer.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    kw = dict(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
              export_texcoords=True, export_normals=True, export_materials="EXPORT", export_image_format="AUTO",
              export_cameras=False, export_lights=False, export_animations=False, export_extras=False)
    valid = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in valid})
    for o in objs: o.select_set(False)


def read_glb(path):
    data = Path(path).read_bytes(); off = 12; js = None
    while off < len(data):
        cl, ct = struct.unpack("<II", data[off:off + 8])
        if ct == 0x4E4F534A: js = json.loads(data[off + 8:off + 8 + cl])
        off += 8 + cl
    acc = js["accessors"]; res = {}
    for n in js["nodes"]:
        if "mesh" not in n: continue
        m = js["meshes"][n["mesh"]]
        t = sum(acc[p["indices"]]["count"] // 3 for p in m["primitives"])
        a = acc[m["primitives"][0]["attributes"]["POSITION"]]
        res[n["name"]] = dict(tris=t, min=a["min"], max=a["max"], t=n.get("translation", [0, 0, 0]))
    return res, [dict(alphaMode=m.get("alphaMode", "OPAQUE"), cutoff=m.get("alphaCutoff"), doubleSided=m.get("doubleSided", False)) for m in js["materials"]]


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


# ---------------------------------------------------------------- stills
def look_at(ob, t): ob.rotation_euler = (Vector(t) - ob.location).to_track_quat("-Z", "Y").to_euler()


def cam(coll, name, loc, tgt, lens):
    cd = bpy.data.cameras.new(name); cd.lens = lens; cd.clip_start = 0.05; cd.clip_end = 300
    ob = bpy.data.objects.new(name, cd); coll.objects.link(ob); ob.location = loc; look_at(ob, tgt); return ob


def light(coll, name, kind, loc, tgt, energy, color, size=1.0):
    ld = bpy.data.lights.new(name, kind); ld.energy = energy; ld.color = color
    if kind == "SUN": ld.angle = math.radians(size)
    else: ld.size = size
    ob = bpy.data.objects.new(name, ld); coll.objects.link(ob); ob.location = loc; look_at(ob, tgt); return ob


def flat_mat(name, hexc, alpha=1.0, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]; c = hexrgb(hexc)
    b.inputs["Base Color"].default_value = (*(c ** 2.2), 1); b.inputs["Roughness"].default_value = 0.8
    if emit:
        b.inputs["Emission Color"].default_value = (*(c ** 2.2), 1); b.inputs["Emission Strength"].default_value = emit
    return m


def place(coll, src, name, loc, scale=(1, 1, 1)):
    ob = bpy.data.objects.new(name, src.data); coll.objects.link(ob); ob.location = loc; ob.scale = scale; return ob


def tile_plan(W):
    """modules between two caps: N = round((W-2CW)/2), uniform X scale s = (W-2CW)/(2N)"""
    inner = W - 2 * CW; N = max(1, round(inner / 2.0)); return N, inner / (2.0 * N)


def skin_box(coll, objs, kind, cx, top, W, H, lod=0):
    """place skins on a Godot box (center x, top, width W, height H). Blender y=0 is the box depth centre."""
    x0 = cx - W / 2
    N, s = tile_plan(W)
    rows = []
    if kind == "solid":
        rows.append(("Solid_Top", 0.0, TOP_T))
        z = TOP_T
        while z < H - 1e-4:
            hh = min(FILL_T, H - z); rows.append(("Solid_Fill", z, hh)); z += hh
        rows.append(("Lip", 0.0, LIP_H))
    else:
        rows.append(("Oneway", 0.0, H))
    for base, zoff, hh in rows:
        sz = hh / {"Solid_Top": TOP_T, "Solid_Fill": FILL_T, "Lip": LIP_H, "Oneway": ONE_H}[base]
        if base == "Solid_Top": sz = 1.0
        place(coll, objs[f"{base}_CapL_LOD{lod}"], f"{base}_L", (x0, 0, top - zoff), (1, 1, sz))
        place(coll, objs[f"{base}_CapR_LOD{lod}"], f"{base}_R", (x0 + W, 0, top - zoff), (1, 1, sz))
        for i in range(N):
            place(coll, objs[f"{base}_2m_LOD{lod}"], f"{base}_{i}", (x0 + CW + (2 * i + 1) * s, 0, top - zoff), (s, 1, sz))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(); ap.add_argument("--out", required=True); ap.add_argument("--maya", default="")
    ap.add_argument("--pct", type=int, default=100); ap.add_argument("--no-stills", action="store_true")
    a = ap.parse_args(argv)
    out = Path(a.out); (out / "textures").mkdir(parents=True, exist_ok=True)
    rep = dict(blender=bpy.app.version_string, seed=SEED, tris={}, fit={}, fails=[], magenta={}, glb={})
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tex = out / "textures" / "T_PlatformSkins_Cuyabeno_A.png"
    atlas = paint_atlas(tex)
    rep["atlas"] = dict(path=str(tex.relative_to(out)), size=[ATLAS, ATLAS], magenta_texels=magenta_count(atlas[..., :3] / 255.0))
    mat = make_material(tex)
    lod_colls = []
    objs = {}
    for q in range(3):
        coll = bpy.data.collections.new(f"PlatformSkins_LOD{q}"); bpy.context.scene.collection.children.link(coll); lod_colls.append(coll)
        for name, (fn, end, hgt) in PIECES.items():
            mb = fn(q, end)
            ob = mb.to_object(f"{name}_LOD{q}", coll, mat)
            objs[ob.name] = ob
            # box-fit check (local frame = collision box, pivot on top)
            vs = np.array([v.co[:] for v in ob.data.vertices])
            lo, hi = vs.min(0), vs.max(0)
            xlo, xhi = (-1.0, 1.0) if end is None else ((0.0, CW) if end == "L" else (-CW, 0.0))
            eps = 1e-5
            ok = (lo[0] >= xlo - eps and hi[0] <= xhi + eps and lo[1] >= -HD - eps and hi[1] <= HD + eps and hi[2] <= eps and lo[2] >= -hgt - eps)
            tris = len(ob.data.polygons)
            rep["tris"][ob.name] = tris
            rep["fit"][ob.name] = dict(min=[round(float(x), 4) for x in lo], max=[round(float(x), 4) for x in hi], ok=bool(ok))
            if not ok: rep["fails"].append(f"{ob.name} leaves its box: {lo} {hi}")
            if tris > BUDGET[q]: rep["fails"].append(f"{ob.name} {tris} tris > {BUDGET[q]}")
        # place pieces apart for the blend overview (GLB export applies transforms -> keep at origin, offset after export)
    for q, coll in enumerate(lod_colls):
        p = out / f"platform_skins_cuyabeno_LOD{q}.glb"
        export_glb(p, list(coll.objects))
        nodes, mats = read_glb(p)
        rep["glb"][p.name] = dict(nodes=nodes, materials=mats)
        for n, d in nodes.items():
            if d["max"][1] > 1e-4: rep["fails"].append(f"GLB {p.name}:{n} top {d['max'][1]} above pivot")
        if any(m["alphaMode"] == "BLEND" for m in mats): rep["fails"].append("alpha BLEND found")
        log("exported", p.name, sum(d["tris"] for d in nodes.values()), "tris")
    # overview layout in the blend
    for q, coll in enumerate(lod_colls):
        for i, ob in enumerate(sorted(coll.objects, key=lambda o: o.name)):
            ob.location = (i % 6 * 3.0, q * 8.0 + (i // 6) * 4.0, 0)
        coll.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "platform_skins_cuyabeno.blend"))
    for q, coll in enumerate(lod_colls):
        for ob in coll.objects: ob.location = (0, 0, 0)
    (out / "platform_skins_report.json").write_text(json.dumps(rep, indent=1))
    if not a.no_stills:
        stills(out, objs, rep, a)
    (out / "platform_skins_report.json").write_text(json.dumps(rep, indent=1))
    if rep["fails"]:
        log("FAIL", rep["fails"]); sys.exit(1)
    log("OK")


def stills(out, objs, rep, a):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.render.resolution_percentage = a.pct
    sc.view_settings.view_transform = "AgX"
    try: sc.view_settings.look = "AgX - Punchy"
    except Exception: pass
    try: sc.eevee.taa_render_samples = 32
    except Exception: pass
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.13, 0.12, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    st = bpy.data.collections.new("Stage"); sc.collection.children.link(st)
    light(st, "Sun", "SUN", (0, -10, 20), (6, 2, 0), 3.2, (1.0, 0.93, 0.80), 3)
    light(st, "Fill", "AREA", (-6, -14, 6), (4, 0, -1), 2500, (0.70, 0.84, 1.0), 12)
    light(st, "Rim", "AREA", (14, 12, 8), (4, 0, -1), 1800, (0.75, 0.88, 1.0), 10)
    # ground backdrop (dark water) + back wall
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -6)); bpy.context.object.data.materials.append(flat_mat("Water", "#14201C"))
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 30, 0), rotation=(math.radians(90), 0, 0)); bpy.context.object.data.materials.append(flat_mat("Back", "#1E2E26"))
    lay = bpy.data.collections.new("Layout"); sc.collection.children.link(lay)
    # demo: solid 6.6667 x 4.0 (3 modules, s=1.0), oneway 4.0 (2 modules s=0.833) at top +2.5 m
    skin_box(lay, objs, "solid", 3.3333, 0.0, 6.6667, 4.0)
    skin_box(lay, objs, "oneway", 10.0, 2.0, 4.0, ONE_H)
    wire = flat_mat("BoxWire", "#B8B8B0", emit=0.6)
    def ghost(cx, top, W, H):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, 0, top - H / 2)); g = bpy.context.object
        g.scale = (W, D, H); mod = g.modifiers.new("w", "WIREFRAME"); mod.thickness = 0.015; g.data.materials.append(wire); return g
    gh = [ghost(3.3333, 0.0, 6.6667, 4.0), ghost(10.0, 2.0, 4.0, ONE_H)]
    bean_m = flat_mat("Bean", "#8B4A2B")
    def bean(x, z):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(x, 0, z)); b = bpy.context.object
        b.scale = (1.18, 0.32, 2.28); b.data.materials.append(bean_m); return b
    beans = [bean(2.0, 0.0 + 0.502 + 0.02), bean(10.0, 2.0 + 0.502 + 0.02)]
    cams = {
        "HP001_platform_skins_front.png": cam(st, "C_front", (7.0, -22.0, 1.0), (7.0, 0, 0.0), 50),
        "HP001_platform_skins_34.png": cam(st, "C_34", (-4.5, -11.0, 5.5), (5.0, 0, -0.4), 35),
        "HP001_platform_skins_closeup.png": cam(st, "C_close", (1.2, -3.6, 0.9), (2.4, -HD, -0.35), 40),
        "HP001_platform_skins_oneway_front.png": cam(st, "C_ow_front", (10.0, -7.5, 2.1), (10.0, 0, 1.75), 40),
        "HP001_platform_skins_oneway_34.png": cam(st, "C_ow_34", (13.8, -5.6, 3.4), (10.0, 0, 1.7), 38),
    }
    # v2: soft bounce from below (water/ground bounce) so the log belly is never black
    ub = light(st, "Bounce_Under", "AREA", (10.0, -3.5, -0.2), (10.0, 0, 1.7), 900, (0.80, 0.86, 0.82), 6)
    ub.data.specular_factor = 0.0
    ow_key = light(st, "OW_Key", "AREA", (7.0, -6.0, 5.0), (10.0, 0, 1.8), 700, (1.0, 0.95, 0.86), 4)
    for fn, c in cams.items():
        for g in gh: g.hide_render = fn != "HP001_platform_skins_front.png"
        sc.camera = c; sc.render.filepath = str(out / fn); bpy.ops.render.render(write_still=True)
        rep["magenta"][fn] = mag(out / fn); log("still", fn, rep["magenta"][fn])
    # scale still: game camera of the 'entrance' shot (player feet 4.5417; camera offset (0,1,24.13), fov 50)
    for ob in list(lay.objects): bpy.data.objects.remove(ob)
    for g in gh + beans: bpy.data.objects.remove(g)
    skin_box(lay, objs, "solid", 6.6667, 0.0, 13.3333, 6.0)          # P00 (13.33 wide; 13.33 tall, upper 6 m skinned here)
    skin_box(lay, objs, "oneway", 10.0, 6.6667, 4.0, 0.6667)          # P01
    gh = [ghost(6.6667, 0.0, 13.3333, 6.0), ghost(10.0, 6.6667, 4.0, 0.6667)]
    for g in gh: g.hide_render = True
    beans = [bean(6.6667, 4.0), bean(9.0667, 4.5), bean(11.4667, 4.0), bean(10.6667, 10.6667),
             bean(12.0, 0.0 + 0.52)]                                    # last one: grain marker resting on the solid top
    if a.maya and Path(a.maya).exists():
        bpy.ops.import_scene.gltf(filepath=a.maya)
        for o in list(bpy.context.selected_objects):
            if o.type == "MESH" and not o.name.startswith("Maya_LOD0"): o.hide_render = True
            if o.parent is None: o.location = (4.5417, 0, 0)
    else:
        rep["fails"].append("hero_grey.glb missing for the scale still")
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    c = cam(st, "C_game", (4.5417, -24.1256, 1.0), (4.5417, 0, 1.0), 1)
    c.data.sensor_fit = "VERTICAL"; c.data.lens_unit = "FOV"; c.data.angle = math.radians(50)
    c.rotation_euler = (math.radians(90), 0, 0)
    fn = "HP001_platform_skins_scale_maya.png"
    sc.camera = c; sc.render.filepath = str(out / fn); bpy.ops.render.render(write_still=True)
    rep["magenta"][fn] = mag(out / fn); log("still", fn, rep["magenta"][fn])
    c2 = cam(st, "C_scale_close", (6.8, -9.0, 3.4), (7.0, 0, 1.6), 35)
    for g in gh: g.hide_render = False
    fn = "HP001_platform_skins_scale_maya_close.png"
    sc.camera = c2; sc.render.filepath = str(out / fn); bpy.ops.render.render(write_still=True)
    rep["magenta"][fn] = mag(out / fn); log("still", fn, rep["magenta"][fn])
    if any(rep["magenta"].values()): rep["fails"].append("magenta pixels in stills")


def mag(p):
    im = bpy.data.images.load(str(p)); px = np.array(im.pixels[:], np.float32).reshape(im.size[1], im.size[0], 4)[..., :3]
    bpy.data.images.remove(im); return magenta_count(px)


if __name__ == "__main__":
    main()
