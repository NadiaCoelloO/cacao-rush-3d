#!/usr/bin/env python3
"""Port rio-1 from Cacao.Game levels.ts (T=32) into Godot metres. 24 px = 1 m."""

import json
import math
from pathlib import Path

T = 32
H = T * 28  # 896
W = T * 156  # 4992
PX = 1.0 / 24.0
DEPTH = 64 * PX  # greybox thickness, not a 2D axis

# levels.ts rio-1. sand-vivid-dawn-sail@5fd45031 404s; this is Cacao.Game@77e55b5278.
PLATFORMS = [
    ("solid", 0, T * 20, T * 10, T * 8, None),
    ("moving", T * 12, T * 20, T * 5, 22, {"ax": T * 7, "ay": 0, "period": 3.4, "phase": 0}),
    ("moving", T * 28, T * 16, T * 5, 22, {"ax": 0, "ay": T * 5, "period": 3.8, "phase": 0.4}),
    ("solid", T * 40, T * 18, T * 8, T * 10, None),
    ("oneway", T * 44, T * 14, T * 3, 18, None),
    ("crate", T * 50, T * 22, T * 3, 22, None),
    ("moving", T * 54, T * 14, T * 4, 22, {"ax": T * 8, "ay": 0, "period": 2.9, "phase": 0}),
    ("solid", T * 70, T * 12, T * 8, T * 16, None),
    ("oneway", T * 78, T * 18, T * 4, 22, None),
    ("moving", T * 86, T * 16, T * 5, 22, {"ax": 0, "ay": -T * 6, "period": 3.2, "phase": 0}),
    ("solid", T * 98, T * 20, T * 10, T * 8, None),
    ("oneway", T * 108, T * 17, T * 5, 20, None),
    ("moving", T * 116, T * 15, T * 5, 22, {"ax": T * 5, "ay": T * 2, "period": 3.6, "phase": 0}),
    ("solid", T * 124, T * 14, T * 8, T * 14, None),
    ("oneway", T * 133, T * 12, T * 4, 20, None),
    ("solid", T * 138, T * 12, T * 18, T * 16, None),
]

HAZARDS = [
    ("lava", 0, T * 25, T * 156, T * 4, {}),
    ("spikes", T * 44, T * 18 - 18, T * 3, 18, {}),
    ("spikes", T * 104, T * 20 - 18, T * 2, 18, {}),
    ("wind", T * 20, T * 8, T * 50, T * 14, {"vx": 160, "ay": 0}),
    ("wind", T * 80, T * 6, T * 40, T * 12, {"vx": -140, "ay": 0}),
]

CHECKS = [
    {"x": T * 41, "y": T * 18 - 72, "warpRandom": False},
    {"x": T * 73, "y": T * 12 - 72, "warpRandom": True},
    {"x": T * 99, "y": T * 20 - 72, "warpRandom": False},
]


def r(n):
    return round(float(n), 6)


def box(x, y, w, h):
    return {
        "center_m": [r((x + w / 2) * PX), r((H - y - h / 2) * PX), 0.0],
        "size_m": [r(w * PX), r(h * PX), r(DEPTH)],
        "top_m": r((H - y) * PX),
        "px": {"x": r(x), "y": r(y), "w": r(w), "h": r(h)},
    }


def arc(x, y, n, dx, lift):
    out = []
    for i in range(n):
        t = 0.0 if n == 1 else i / (n - 1)
        out.append((x + i * dx, y - math.sin(t * math.pi) * lift))
    return out


def t0(move, x, y):
    phase = move["phase"]
    nx = x + math.sin(phase) * move["ax"]
    ny = y + math.cos(phase) * move["ay"]
    return nx, ny


def main():
    platforms = []
    for i, (kind, x, y, w, h, move) in enumerate(PLATFORMS):
        px, py = (x, y)
        entry = {"id": "P%02d" % i, "kind": kind}
        if move:
            nx, ny = t0(move, x, y)
            entry.update(box(nx, ny, w, h))
            entry["move"] = {
                "ox": r(x),
                "oy": r(y),
                "ax": r(move["ax"]),
                "ay": r(move["ay"]),
                "period": move["period"],
                "phase": move["phase"],
            }
            entry["rest_px"] = {"x": r(x), "y": r(y)}
            entry["t0_px"] = {"x": r(nx), "y": r(ny)}
        else:
            entry.update(box(px, py, w, h))
        platforms.append(entry)

    hazards = []
    for i, (kind, x, y, w, h, extra) in enumerate(HAZARDS):
        prefix = {"lava": "L", "spikes": "S", "wind": "W"}[kind]
        # count per kind
        n = sum(1 for hzd in hazards if hzd["kind"] == kind)
        entry = {"id": "%s%02d" % (prefix, n), "kind": kind}
        entry.update(box(x, y, w, h))
        entry["vx"] = extra.get("vx", 0)
        entry["ay"] = extra.get("ay", 0)
        hazards.append(entry)

    coins_px = []
    coins_px += arc(T * 12, T * 16, 4, T * 2.4, 36)
    coins_px += [(T * 30, T * 12), (T * 42, T * 15), (T * 46, T * 11)]
    coins_px += arc(T * 56, T * 10, 4, T * 2.5, 28)
    coins_px += [
        (T * 72, T * 9),
        (T * 80, T * 15),
        (T * 88, T * 10),
        (T * 100, T * 17),
        (T * 112, T * 11),
        (T * 122, T * 8),
        (T * 136, T * 13),
        (T * 146, T * 9),
    ]
    pickups = []
    for i, (x, y) in enumerate(coins_px):
        pickups.append({
            "id": "C%02d" % i,
            "kind": "bean",
            "r_px": 12,
            "center_m": [r(x * PX), r((H - y) * PX), 0.0],
            "px": {"x": r(x), "y": r(y)},
        })

    checks = []
    for i, c in enumerate(CHECKS):
        x, y, w, h = c["x"], c["y"], 36, 72
        entry = {"id": "K%02d" % i, "warp_random": c["warpRandom"]}
        entry.update(box(x, y, w, h))
        entry["spawn_feet_m"] = [
            r((x + 4 + 13) * PX),
            r((H - (y + h)) * PX),
            0.0,
        ]
        checks.append(entry)

    gx, gy, gw, gh = T * 148, T * 12 - 56, 48, 56
    goal = {"id": "G00", "kind": "cacao"}
    goal.update(box(gx, gy, gw, gh))

    # Standing feet for the stills. 2D top-left = (feet_x*24 - 13, 896 - (feet_y+1.75)*24).
    shots = [
        ("embarque", 4.541667, 10.666667, "Orilla, cacao del arco y la primera balsa"),
        ("pinchos", 57.0, 13.333333, "Pinchos S00 sobre la orilla, one-way arriba"),
        ("secreto", 96.2, 21.333333, "Tótem K01 warpRandom, el secreto del río"),
        ("viento", 136.5, 10.666667, "Pinchos S01 y el viento que empuja a la izquierda"),
        ("meta", 194.5, 21.333333, "Orilla final y el grano de la meta"),
    ]
    shot_rows = []
    for sid, fx, fy, note in shots:
        top_x = fx * 24 - 13
        top_y = H - (fy + 42 * PX) * 24
        shot_rows.append({
            "id": sid,
            "feet_m": [r(fx), r(fy), 0.0],
            "px": {"x": r(top_x), "y": r(top_y)},
            "note": note,
        })

    spawn_x, spawn_y = T * 3, T * 16
    doc = {
        "meta": {
            "source_repo": "NadiaCoelloO/Cacao.Game",
            "source_sha": "77e55b5278",
            "requested_pin": "NadiaCoelloO/sand-vivid-dawn-sail@5fd45031",
            "requested_pin_status": "404 from this environment",
            "level_id": "rio-1",
            "world_id": "rio",
            "display": "Río de Chocolate",
            "subtitle": "Balsas de caramelo",
            "tag": "Balsas sobre el río. El último tramo sí se alcanza.",
            "width_px": W,
            "height_px": H,
            "waterline_px": T * 25,
            "waterline_m": r((H - T * 25) * PX),
            "can_swim": False,
            "fog": "#1a100c",
            "sky": "cocoa",
            "tile": "cocoa",
            "spawn_px": {"x": spawn_x, "y": spawn_y},
            "spawn_feet_m": [r((spawn_x + 13) * PX), r((H - spawn_y - 42) * PX), 0.0],
            "goal_kind": "cacao",
            "only_level": "rio-1 is the only rio-* level in createLevels()",
        },
        "platforms": platforms,
        "hazards": hazards,
        "pickups": pickups,
        "checkpoints": checks,
        "goal": goal,
        "falls": [],
        "shots": shot_rows,
    }
    out = Path(__file__).resolve().parents[1] / "runtime" / "data" / "rio1_layout.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=2) + "\n")
    print("wrote", out)
    print("platforms", len(platforms), "hazards", len(hazards), "coins", len(pickups), "checks", len(checks))
    for p in platforms:
        if p["kind"] == "moving":
            print(p["id"], "t0", p["t0_px"], "top", p["top_m"])


if __name__ == "__main__":
    main()
