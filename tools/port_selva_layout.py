#!/usr/bin/env python3
"""Resolve selva-1 (2D) into Godot metres and write the greybox layout JSON.

The pinned repo NadiaCoelloO/sand-vivid-dawn-sail@5fd45031 is not readable from
this environment (GitHub 404). The level block below is the public sibling
NadiaCoelloO/Cacao.Game src/game/levels.ts `selva-1` (QA-verified same geometry).
sitSpikes / freeCoins are the same functions as that file.
Scale is player_maya.gd PX_TO_M (24 px = 1 m). 2D y grows downward.

Y is shifted so the first solid top sits at Godot y = 0 (feel harness: spawn
lands at y≈0, CSGPlatform ledge stays at y=1). First oneway top is then 6.67 m.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

T = 32
PX = 1.0 / 24.0
LEVEL_W = T * 152
LEVEL_H = T * 32
DEPTH_PX = 64.0
PH = 42
PW = 26
# First solid: plat(0, T*22, T*10, T*10). top_m_raw = (LEVEL_H - T*22)*PX = 13.3333
Y_SHIFT = (LEVEL_H - T * 22) * PX

ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "runtime" / "data" / "selva1_layout.json"


def plat(x, y, w, h, kind="solid", tag=""):
    return {"x": x, "y": y, "w": w, "h": h, "kind": kind, "tag": tag, "move": None}


def crumble(x, y, w, h, tag=""):
    return plat(x, y, w, h, "crumble", tag)


def mover(x, y, w, h, ax, ay, period, phase=0, tag=""):
    p = plat(x, y, w, h, "moving", tag)
    p["move"] = {"ox": x, "oy": y, "ax": ax, "ay": ay, "period": period, "phase": phase}
    return p


def crawl_cover(x, floor_top, w, tag=""):
    gap, h = 30, T * 2
    return plat(x, floor_top - gap - h, w, h, "solid", tag)


def squeeze_cover(x, floor_top, w, tag=""):
    gap, h = 18, T * 2
    return plat(x, floor_top - gap - h, w, h, "solid", tag)


def spikes(x, y, w):
    return {"kind": "spikes", "x": x, "y": y, "w": w, "h": 18}


def frog(x, y, rng=T * 3, period=1.6, phase=0, venom=False):
    return {
        "kind": "frog",
        "x": x,
        "y": y,
        "w": 18,
        "h": 16,
        "ox": x,
        "oy": y,
        "ax": rng,
        "ay": 36,
        "period": period,
        "phase": phase,
        "venom": venom,
        "chase": venom,
    }


def wind(x, y, w, h, vx, vy=0):
    return {"kind": "wind", "x": x, "y": y, "w": w, "h": h, "vx": vx, "ay": vy}


def rock(x, y, rng, speed=260, phase=0, drift=0):
    return {
        "kind": "rock",
        "x": x,
        "y": y,
        "w": 22,
        "h": 20,
        "ox": x,
        "oy": y,
        "range": rng,
        "vx": speed,
        "phase": phase,
        "ax": drift,
    }


def arc(x, y, n, dx, lift):
    out = []
    for i in range(n):
        t = 0 if n == 1 else i / (n - 1)
        out.append([x + i * dx, y - math.sin(t * math.pi) * lift])
    return out


def coins(pairs):
    return [{"x": x, "y": y, "r": 12, "kind": "bean"} for x, y in pairs]


def sit_spikes(level):
    tooth = 16
    plats = [p for p in level["platforms"] if p["kind"] not in ("oneway", "moving")]
    for h in level["hazards"]:
        if h["kind"] != "spikes":
            continue
        best, best_score = None, -1
        for p in plats:
            overlap = min(h["x"] + h["w"], p["x"] + p["w"]) - max(h["x"], p["x"])
            if overlap <= 12:
                continue
            yerr = abs(p["y"] - h["h"] - h["y"])
            if yerr > 24:
                continue
            score = overlap * 2 - yerr
            if score > best_score:
                best_score = score
                best = p
        if not best:
            continue
        h["y"] = best["y"] - h["h"] + 1
        left = max(h["x"], best["x"])
        right = min(h["x"] + h["w"], best["x"] + best["w"])
        w = math.floor((right - left) / tooth) * tooth
        if w < tooth * 2:
            w = min(best["w"], tooth * 2)
        slack = right - left - w
        h["x"] = left + max(0, slack) / 2
        h["w"] = w


def free_coins(level):
    plats = level["platforms"]
    death = [h for h in level["hazards"] if h["kind"] in ("lava", "crack", "spikes")]
    for c in level["coins"]:
        for p in plats:
            if p["kind"] == "oneway":
                continue
            if p["x"] + 2 <= c["x"] <= p["x"] + p["w"] - 2 and p["y"] + 6 <= c["y"] <= p["y"] + p["h"] - 2:
                c["y"] = p["y"] - 14
        on_floor = any(
            p["x"] - 10 <= c["x"] <= p["x"] + p["w"] + 10 and p["y"] - 6 <= c["y"] + 16 <= p["y"] + 26
            for p in plats
        )
        over_death = any(h["x"] <= c["x"] <= h["x"] + h["w"] and c["y"] < h["y"] and c["y"] > h["y"] - 160 for h in death)
        if not on_floor and over_death:
            best, bd = None, math.inf
            for p in plats:
                px = max(p["x"] + 12, min(c["x"], p["x"] + p["w"] - 12))
                py = p["y"] - 14
                d = math.hypot(px - c["x"], py - c["y"])
                if d < bd:
                    bd, best = d, p
            if best:
                c["x"] = max(best["x"] + 12, min(best["x"] + best["w"] - 12, c["x"]))
                c["y"] = best["y"] - 14


def box_m(x, y, w, h):
    cx = (x + w / 2.0) * PX
    cy = (LEVEL_H - y - h / 2.0) * PX - Y_SHIFT
    sx = w * PX
    sy = h * PX
    sz = DEPTH_PX * PX
    top = (LEVEL_H - y) * PX - Y_SHIFT
    return [round(cx, 4), round(cy, 4), 0.0], [round(sx, 4), round(sy, 4), round(sz, 4)], round(top, 4)


def point_m(x, y):
    return [round(x * PX, 4), round((LEVEL_H - y) * PX - Y_SHIFT, 4), 0.0]


def feet_m(px, py):
    """2D player top-left → Godot feet (capsule origin)."""
    return [round((px + PW / 2.0) * PX, 4), round((LEVEL_H - (py + PH)) * PX - Y_SHIFT, 4), 0.0]


def mover_at_zero(p):
    m = p["move"]
    t = m["phase"]
    return m["ox"] + math.sin(t) * m["ax"], m["oy"] + math.cos(t) * m["ay"]


def build():
    platforms = [
        plat(0, T * 22, T * 10, T * 10, "solid", "suelo de entrada"),
        plat(T * 6, T * 17, T * 3, 16, "oneway", "one-way #0 (top 6.67 m)"),
        plat(T * 14, T * 21, T * 8, T * 11, "solid", "suelo tras el primer hueco"),
        plat(T * 17, T * 17, T * 3, 20, "crate", "caja"),
        mover(T * 25, T * 19, T * 4, 22, T * 5, 0, 2.7, 0, "plataforma móvil horizontal"),
        plat(T * 38, T * 20, T * 14, T * 12, "solid", "suelo ancho del primer poste"),
        crawl_cover(T * 40, T * 20, T * 7, "techo de arrastre (crawlCover, gap 30 px)"),
        plat(T * 48, T * 16, T * 3, 16, "oneway", "one-way"),
        crumble(T * 54, T * 18, T * 5, 20, "tronco que cede"),
        plat(T * 62, T * 16, T * 6, T * 16, "solid", "suelo de la rana"),
        plat(T * 66, T * 11, T * 3, 16, "oneway", "one-way"),
        plat(T * 70, T * 11, T * 3, T * 21, "solid", "columna"),
        plat(T * 76, T * 20, T * 10, T * 12, "solid", "suelo del paso estrecho"),
        squeeze_cover(T * 78, T * 20, T * 6, "techo de arrastre estrecho (squeezeCover, gap 18 px)"),
        mover(T * 88, T * 16, T * 4, 22, 0, -T * 7, 3.2, 0, "plataforma móvil vertical"),
        plat(T * 96, T * 10, T * 8, T * 6, "solid", "repisa del viento"),
        plat(T * 106, T * 14, T * 5, 18, "oneway", "one-way"),
        plat(T * 112, T * 12, T * 6, T * 6, "solid", "suelo de la segunda rana"),
        crumble(T * 120, T * 14, T * 4, 18, "tronco que cede"),
        mover(T * 126, T * 13, T * 4, 22, T * 4, 0, 2.5, 0, "plataforma móvil horizontal"),
        plat(T * 138, T * 15, T * 14, T * 17, "solid", "suelo de meta"),
    ]
    hazards = [
        spikes(T * 49, T * 20 - 18, T * 3),
        frog(T * 63, T * 16 - 16, T * 3, 1.6, 0.2, False),
        frog(T * 113, T * 12 - 16, T * 3, 1.5, 0.8, False),
        wind(T * 96, T * 3, T * 22, T * 10, 150),
        rock(T * 100, T * 0, T * 16, 210, 0.2),
        rock(T * 112, T * 0, T * 14, 190, 1.4, 12),
    ]
    coin_list = coins(
        [
            *arc(T * 5, T * 19, 3, T * 1.8, 12),
            [T * 8, T * 14],
            [T * 18, T * 14],
            *arc(T * 26, T * 16, 3, T * 2, 22),
            [T * 42, T * 20 - 12],
            [T * 45.5, T * 20 - 12],
            [T * 50, T * 13],
            [T * 56, T * 15],
            [T * 64, T * 13],
            [T * 68, T * 8],
            [T * 72, T * 8],
            [T * 80, T * 20 - 10],
            [T * 83, T * 20 - 10],
            [T * 90, T * 8],
            [T * 98, T * 7],
            [T * 108, T * 11],
            [T * 114, T * 9],
            [T * 122, T * 11],
            [T * 130, T * 10],
            [T * 144, T * 12],
        ]
    )
    checks = [
        {"x": T * 39, "y": T * 20 - 72, "secret": None},
        {"x": T * 97, "y": T * 10 - 72, "secret": None},
    ]
    goal = {"x": T * 146, "y": T * 15 - 56, "w": 48, "h": 56, "kind": "cacao"}
    level = {"platforms": platforms, "hazards": hazards, "coins": coin_list}
    sit_spikes(level)
    free_coins(level)

    out_plats = []
    for i, p in enumerate(platforms):
        x, y = p["x"], p["y"]
        if p["move"]:
            x, y = mover_at_zero(p)
        center, size, top = box_m(x, y, p["w"], p["h"])
        entry = {
            "id": f"P{i:02d}",
            "kind": p["kind"],
            "tag": p["tag"],
            "px": {"x": round(x, 4), "y": round(y, 4), "w": p["w"], "h": p["h"]},
            "rest_px": {"x": p["x"], "y": p["y"], "w": p["w"], "h": p["h"]},
            "center_m": center,
            "size_m": size,
            "top_m": top,
            "move": p["move"],
        }
        out_plats.append(entry)

    out_haz = []
    for i, h in enumerate(hazards):
        center, size, top = box_m(h["x"], h["y"], h["w"], h["h"])
        out_haz.append(
            {
                "id": f"H{i:02d}",
                "kind": h["kind"],
                "px": {"x": h["x"], "y": h["y"], "w": h["w"], "h": h["h"]},
                "center_m": center,
                "size_m": size,
                "top_m": top,
                "period": h.get("period"),
                "phase": h.get("phase"),
                "ox": h.get("ox"),
                "oy": h.get("oy"),
                "ax": h.get("ax"),
                "ay": h.get("ay"),
                "vx": h.get("vx"),
                "range": h.get("range"),
                "venom": h.get("venom"),
                "chase": h.get("chase"),
            }
        )

    out_coins = []
    for i, c in enumerate(coin_list):
        out_coins.append(
            {
                "id": f"C{i:02d}",
                "kind": c["kind"],
                "px": {"x": round(c["x"], 4), "y": round(c["y"], 4), "r": c["r"]},
                "center_m": point_m(c["x"], c["y"]),
                "radius_m": round(c["r"] * PX, 4),
            }
        )

    out_checks = []
    for i, c in enumerate(checks):
        w, h = 36, 72
        center, size, top = box_m(c["x"], c["y"], w, h)
        out_checks.append(
            {
                "id": f"K{i:02d}",
                "px": {"x": c["x"], "y": c["y"], "w": w, "h": h},
                "center_m": center,
                "size_m": size,
                "top_m": top,
                "secret": c["secret"],
            }
        )

    gcenter, gsize, gtop = box_m(goal["x"], goal["y"], goal["w"], goal["h"])
    out_goal = {
        "id": "G00",
        "kind": goal["kind"],
        "px": goal,
        "center_m": gcenter,
        "size_m": gsize,
        "top_m": gtop,
    }

    shots = [
        {
            "id": "entrance",
            "label": "Tramo de entrada: suelo, oneway #0 a 6.67 m, tótem",
            "player_px": {"x": 96, "y": T * 22 - PH},
        },
        {
            "id": "hazard",
            "label": "Pinchos H00 sobre el suelo ancho",
            "player_px": {"x": T * 47, "y": T * 20 - PH},
        },
        {
            "id": "cacao",
            "label": "Cacaos sobre el oneway y el tronco que cede",
            "player_px": {"x": T * 49, "y": T * 16 - PH},
        },
    ]
    for s in shots:
        s["feet_m"] = feet_m(s["player_px"]["x"], s["player_px"]["y"])

    spawn_px = {"x": T * 3, "y": T * 20}
    doc = {
        "meta": {
            "level_id": "selva-1",
            "world_id": "selva",
            "display": "Cuyabeno",
            "subtitle": "Las primeras semillas",
            "source_requested": "NadiaCoelloO/sand-vivid-dawn-sail@5fd450312c8e6ad0a214f35b68fd81ec2857fec3",
            "source_read": "NadiaCoelloO/Cacao.Game src/game/levels.ts selva-1 (QA-verified same geometry)",
            "px_to_m": PX,
            "y_shift_m": round(Y_SHIFT, 6),
            "level_w_px": LEVEL_W,
            "level_h_px": LEVEL_H,
            "depth_px": DEPTH_PX,
            "spawn_px": spawn_px,
            "spawn_feet_m": feet_m(spawn_px["x"], spawn_px["y"]),
            "camera": {
                "fov": 50,
                "offset_m": [0.0, 1.0, 24.1256],
                "view_m": [40.0, 22.5],
                "maya_px_at_720p": 56,
            },
        },
        "platforms": out_plats,
        "hazards": out_haz,
        "pickups": out_coins,
        "checkpoints": out_checks,
        "goal": out_goal,
        "falls": [],
        "shots": shots,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"wrote {OUT_JSON}")
    print(
        f"platforms {len(out_plats)} hazards {len(out_haz)} pickups {len(out_coins)} "
        f"checks {len(out_checks)} y_shift {Y_SHIFT:.4f}"
    )
    print("P00 top", out_plats[0]["top_m"], "P01 oneway top", out_plats[1]["top_m"])
    print("spawn feet", doc["meta"]["spawn_feet_m"])
    for s in shots:
        print(s["id"], s["player_px"], s["feet_m"])


if __name__ == "__main__":
    build()
