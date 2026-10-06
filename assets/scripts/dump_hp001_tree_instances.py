#!/usr/bin/env python3
"""Bake LOOK-001 tree transforms (seed 1001) as Godot-space HP trunk instances.

Mirrors gen_layout() in world_selva_look001.py without importing Blender.
Godot(x, y, z) = Blender(x, z, -y) — same as bl2gd() in that script.
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

SEED = 1001
CORRIDOR_HALF_DEPTH = 2.2
JUMP_CLEAR_Z = 7.5
TOTEM_ANCHOR = None  # set after Vector
FLOOR_SIZE = 18.0
PLATFORMS_ABC = [
    ("Selva_Platform_A", (4.0, 3.0, 0.25), (3.5, 2.5, 0.5)),
    ("Selva_Platform_B", (-5.0, -2.5, 0.35), (2.8, 3.0, 0.7)),
    ("Selva_Platform_C", (1.5, -6.0, 0.20), (4.0, 2.0, 0.4)),
]
ROOT_STUBS = [
    ((-3.5, 5.0, 0.35), 0.35, 0.70),
    ((6.0, -4.0, 0.25), 0.28, 0.50),
    ((-6.5, -5.5, 0.30), 0.32, 0.60),
    ((2.0, 6.5, 0.22), 0.25, 0.44),
]
SUN_AZ_DEG = -20.0
SUN_EL_DEG = 35.0
LIGHT_ZONES = None
SKY_OPENINGS = None
OPEN_LAGOON = None
CAM_LAGUNA_POS = None

# HP kit native heights (Blender Z-up max z of LOD0, metres above waterline z=0).
NATIVE_H = {"Thin": 8.1952, "Medium": 11.0834, "Thick": 14.3917}


class Vector:
    def __init__(self, v):
        vals = list(v)
        self.x = float(vals[0])
        self.y = float(vals[1]) if len(vals) > 1 else 0.0
        self.z = float(vals[2]) if len(vals) > 2 else 0.0

    @property
    def xy(self):
        return Vector((self.x, self.y))

    def __add__(self, o):
        return Vector((self.x + o.x, self.y + o.y, self.z + o.z))

    def __sub__(self, o):
        return Vector((self.x - o.x, self.y - o.y, self.z - o.z))

    def __mul__(self, k):
        if isinstance(k, Vector):
            return Vector((self.x * k.x, self.y * k.y, self.z * k.z))
        return Vector((self.x * k, self.y * k, self.z * k))

    __rmul__ = __mul__

    @property
    def length(self):
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def __iter__(self):
        yield self.x
        yield self.y
        yield self.z


TOTEM_ANCHOR = Vector((7.5, 0.0, 0.0))
LIGHT_ZONES = [
    ("zone_totem_maya", Vector((6.8, 0.0, 1.0)), 2.8),
    ("zone_platform_B", Vector((-4.8, -2.0, 0.4)), 2.4),
    ("zone_lagoon", Vector((-1.0, 17.0, 0.0)), 3.2),
]
SKY_OPENINGS = [
    (Vector((7.5, 0.0)), 2.6),
    (Vector((-2.5, -4.5)), 2.8),
    (Vector((1.5, 5.5)), 2.2),
    (Vector((-10.0, 7.0)), 2.6),
    (Vector((12.0, -9.0)), 3.0),
    (Vector((2.0, 25.0)), 3.6),
    (Vector((-14.0, 31.0)), 3.2),
    (Vector((15.0, 33.0)), 3.4),
    (Vector((-6.0, -15.0)), 3.0),
]
OPEN_LAGOON = (Vector((9.5, 13.5)), 8.0, 5.5)
CAM_LAGUNA_POS = Vector((13.8, 17.2, 1.75))


def sun_dir():
    az, el = math.radians(SUN_AZ_DEG), math.radians(SUN_EL_DEG)
    return Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))


def in_gap(c: Vector, rad: float) -> bool:
    sd = sun_dir()
    for _n, p, gr in LIGHT_ZONES:
        t = (c.z - p.z) / sd.z
        q = p + sd * t
        if (Vector((c.x, c.y)) - Vector((q.x, q.y))).length < gr + rad * 0.55:
            return True
    for p, gr in SKY_OPENINGS:
        if (Vector((c.x, c.y)) - p).length < gr + rad * 0.55:
            return True
    return False


def in_open_lagoon(x, y, margin=0.0):
    c, rx, ry = OPEN_LAGOON
    return ((x - c.x) / (rx + margin)) ** 2 + ((y - c.y) / (ry + margin)) ** 2 < 1.0


def over_corridor(c, rr):
    return (abs(c.y) - rr.y < CORRIDOR_HALF_DEPTH and c.z - rr.z < JUMP_CLEAR_Z and -12.5 < c.x < 12.5)


def gen_layout(rng: random.Random):
    L = {"trees": [], "snags": [], "logs": [], "canopy": [], "plants": [], "hangers": [],
         "vines": [], "backdrop": [], "fog": []}

    def try_tree(x, y, base_z, hmin, hmax, kind):
        H = rng.uniform(hmin, hmax)
        r = rng.uniform(0.26, 0.55) * (H / 13.0) ** 0.5
        lean = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 1.0))
        top = Vector((x, y, base_z)) + lean * H
        crowns = []
        n_cr = rng.choice([2, 3, 3])
        for k in range(n_cr):
            rr = rng.uniform(2.4, 4.2) * (1.0 if k == 0 else 0.75)
            off = Vector((rng.uniform(-1.6, 1.6), rng.uniform(-1.6, 1.6), rng.uniform(-0.8, 0.9))) * (0 if k == 0 else 1)
            c = top + off + Vector((0, 0, 0.6))
            crowns.append((c, Vector((rr, rr * rng.uniform(0.8, 1.15), rr * rng.uniform(0.42, 0.6)))))
        main_c, main_r = crowns[0]
        if in_gap(main_c, main_r.x):
            return False
        if any(over_corridor(c, rr) for c, rr in crowns):
            return False
        mid = []
        if H > 11.0 and rng.random() < 0.55:
            ang = rng.uniform(0, 2 * math.pi)
            mz = rng.uniform(5.5, 8.0)
            mc = Vector((x + math.cos(ang) * 1.6, y + math.sin(ang) * 1.6, base_z + mz))
            mr = Vector((rng.uniform(1.4, 2.2), rng.uniform(1.4, 2.2), rng.uniform(0.6, 0.9)))
            if not (abs(mc.y) - mr.y < CORRIDOR_HALF_DEPTH + 0.5 and -12.5 < mc.x < 12.5):
                mid.append((mc, mr))
        L["trees"].append({
            "pos": Vector((x, y, base_z)), "H": H, "r": r, "lean": lean, "crowns": crowns,
            "mid": mid, "kind": kind, "buttress": rng.randint(3, 4), "bangle": rng.uniform(0, 6.28),
            "stilt": kind == "flooded" and rng.random() < 0.55,
            "shade": rng.uniform(0.0, 1.0), "far": y > 27.0 or y < -15.0,
        })
        return True

    for x in (-10.4, -7.6, -4.6):
        for _ in range(6):
            if try_tree(x + rng.uniform(-0.6, 0.6), rng.uniform(10.0, 11.6), -0.35, 12.0, 15.5, "bank"):
                break
    for x in (-11.5, -7.5, -3.0, 1.5, 6.0, 10.5):
        for _ in range(6):
            if try_tree(x + rng.uniform(-1.2, 1.2), rng.uniform(-11.0, -16.5), -0.6, 12.0, 16.5, "front"):
                break
    placed, tries = 0, 0
    while placed < 15 and tries < 600:
        tries += 1
        x, y = rng.uniform(-26.0, 26.0), rng.uniform(12.5, 42.0)
        if in_open_lagoon(x, y, 1.5):
            continue
        if (Vector((x, y)) - CAM_LAGUNA_POS.xy).length < 6.0:
            continue
        if any((Vector((x, y)) - t["pos"].xy).length < 5.2 for t in L["trees"]):
            continue
        if try_tree(x, y, -0.6, 11.0, 17.0, "flooded"):
            placed += 1
    return L


def pick_variant(H: float) -> str:
    if H < 12.5:
        return "Thin"
    if H < 14.2:
        return "Medium"
    return "Thick"


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def rodrigues(axis, angle):
    x, y, z = axis
    c, s = math.cos(angle), math.sin(angle)
    C = 1.0 - c
    return [
        [c + x * x * C, x * y * C - z * s, x * z * C + y * s],
        [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
        [z * x * C - y * s, z * y * C + x * s, c + z * z * C],
    ]


def basis_from_lean_yaw(lean_godot, yaw: float):
    lx, ly, lz = lean_godot
    n = math.sqrt(lx * lx + ly * ly + lz * lz) or 1.0
    up = (lx / n, ly / n, lz / n)
    y_axis = (0.0, 1.0, 0.0)
    dot = max(-1.0, min(1.0, y_axis[0] * up[0] + y_axis[1] * up[1] + y_axis[2] * up[2]))
    if dot > 0.99999:
        align = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
    elif dot < -0.99999:
        align = [[-1.0, 0.0, 0.0], [0.0, -1.0, 0.0], [0.0, 0.0, 1.0]]
    else:
        ax = (
            y_axis[1] * up[2] - y_axis[2] * up[1],
            y_axis[2] * up[0] - y_axis[0] * up[2],
            y_axis[0] * up[1] - y_axis[1] * up[0],
        )
        al = math.sqrt(ax[0] ** 2 + ax[1] ** 2 + ax[2] ** 2) or 1.0
        axis = (ax[0] / al, ax[1] / al, ax[2] / al)
        align = rodrigues(axis, math.acos(dot))
    c, s = math.cos(yaw), math.sin(yaw)
    yaw_m = [[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]]
    return matmul(align, yaw_m)


def bl2gd(v):
    return [v[0], v[2], -v[1]]


def main():
    layout = gen_layout(random.Random(SEED))
    trees = []
    counts = {"Thin": 0, "Medium": 0, "Thick": 0}
    for t in layout["trees"]:
        variant = pick_variant(t["H"])
        native = NATIVE_H[variant]
        scale = t["H"] / native
        origin = bl2gd(list(t["pos"]))
        lean_bl = t["lean"]
        lean_gd = [lean_bl.x, lean_bl.z, -lean_bl.y]
        R = basis_from_lean_yaw(lean_gd, t["bangle"])
        x_axis = [R[0][0] * scale, R[1][0] * scale, R[2][0] * scale]
        y_axis = [R[0][1] * scale, R[1][1] * scale, R[2][1] * scale]
        z_axis = [R[0][2] * scale, R[1][2] * scale, R[2][2] * scale]
        trees.append({
            "variant": variant,
            "kind": t["kind"],
            "far": bool(t["far"]),
            "H": round(t["H"], 5),
            "r": round(t["r"], 5),
            "scale": round(scale, 5),
            "yaw": round(t["bangle"], 5),
            "origin": [round(c, 5) for c in origin],
            "x_axis": [round(c, 6) for c in x_axis],
            "y_axis": [round(c, 6) for c in y_axis],
            "z_axis": [round(c, 6) for c in z_axis],
        })
        counts[variant] += 1
    out = {
        "seed": SEED,
        "source": "assets/scripts/bpy/world_selva_look001.py gen_layout",
        "native_height": NATIVE_H,
        "counts": counts,
        "tree_count": len(trees),
        "trees": trees,
    }
    dest = Path(__file__).resolve().parents[2] / "runtime" / "data" / "hp001_tree_instances.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(f"wrote {dest} trees={len(trees)} {counts}")


if __name__ == "__main__":
    main()
