#!/usr/bin/env python3
"""Resolve ruinas-1 (2D) into Godot metres and write the greybox layout JSON.

The pinned repo NadiaCoelloO/sand-vivid-dawn-sail@5fd45031 is not readable from
this environment (GitHub 404). The level block below is the public sibling
NadiaCoelloO/Cacao.Game@77e55b5278 src/game/levels.ts `ruinas-1`, whose selva-1
oneways match the tip-verified table in docs/ONEWAY_DELTA_selva.md exactly.
sitSpikes / freeCoins / the jardin fall are the same functions as that file.
Scale is player_maya.gd PX_TO_M (24 px = 1 m). 2D y grows downward.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

T = 32
PX = 1.0 / 24.0
LEVEL_W = T * 150
LEVEL_H = T * 36
DEPTH_PX = 64.0  # greybox thickness, not a 2D route
PH = 42
PW = 26

ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "runtime" / "data" / "ruinas1_layout.json"


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


def laser(x, y, w, h, period=2.4, phase=0):
    return {"kind": "laser", "x": x, "y": y, "w": w, "h": h, "period": period, "phase": phase}


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
    cy = (LEVEL_H - y - h / 2.0) * PX
    sx = w * PX
    sy = h * PX
    sz = DEPTH_PX * PX
    top = (LEVEL_H - y) * PX
    return [round(cx, 4), round(cy, 4), 0.0], [round(sx, 4), round(sy, 4), round(sz, 4)], round(top, 4)


def point_m(x, y):
    return [round(x * PX, 4), round((LEVEL_H - y) * PX, 4), 0.0]


def feet_m(px, py):
    """2D player top-left → Godot feet (capsule origin)."""
    return [round((px + PW / 2.0) * PX, 4), round((LEVEL_H - (py + PH)) * PX, 4), 0.0]


def mover_at_zero(p):
    m = p["move"]
    # sim.ts updateMovers: nx = ox + sin(t)*ax, ny = oy + cos(t)*ay, t includes phase.
    t = m["phase"]
    return m["ox"] + math.sin(t) * m["ax"], m["oy"] + math.cos(t) * m["ay"]


def build():
    platforms = [
        plat(0, T * 27, T * 10, T * 9, "solid", "suelo de entrada"),
        plat(T * 10, T * 6, T * 2, T * 30, "solid", "muro de escalada izquierdo del pozo"),
        plat(T * 14, T * 6, T * 2, T * 30, "solid", "muro de escalada derecho del pozo"),
        plat(T * 16, T * 27, T * 8, T * 9, "solid", "suelo tras el pozo"),
        crawl_cover(T * 18, T * 27, T * 6, "techo de arrastre (crawlCover, gap 30 px)"),
        plat(T * 24, T * 20, T * 6, T * 16, "solid", "bloque medio"),
        plat(T * 26, T * 8, T * 2, T * 8, "solid", "columna"),
        plat(T * 32, T * 17, T * 8, T * 19, "solid", "bloque grande"),
        plat(T * 30, T * 13, T * 3, 18, "oneway", "one-way"),
        plat(T * 38, T * 22, T * 5, 22, "crate", "caja"),
        mover(T * 40, T * 12, T * 3, 22, 0, T * 7, 4, 0, "plataforma móvil vertical"),
        plat(T * 48, T * 8, T * 10, T * 4, "solid", "repisa alta"),
        plat(T * 48, T * 24, T * 10, T * 8, "solid", "suelo bajo la repisa"),
        crumble(T * 60, T * 18, T * 4, T * 14, "piedra que cede (alta)"),
        plat(T * 66, T * 14, T * 5, 22, "oneway", "one-way"),
        plat(T * 74, T * 20, T * 6, T * 12, "solid", "suelo del poste secreto pichincha"),
        crumble(T * 82, T * 17, T * 4, 22, "piedra que cede"),
        mover(T * 90, T * 14, T * 4, 22, T * 7, 0, 3.1, 0, "plataforma móvil horizontal"),
        plat(T * 104, T * 18, T * 10, T * 14, "solid", "bloque ancho"),
        plat(T * 108, T * 12, T * 3, 18, "oneway", "one-way"),
        plat(T * 118, T * 22, T * 6, T * 10, "solid", "suelo del paso bajo"),
        squeeze_cover(T * 118, T * 22, T * 5, "techo de arrastre estrecho (squeezeCover, gap 18 px)"),
        plat(T * 126, T * 16, T * 4, T * 16, "solid", "bloque"),
        plat(T * 126, T * 6, T * 2, T * 6, "solid", "columna alta"),
        plat(T * 134, T * 12, T * 16, T * 20, "solid", "suelo de meta"),
    ]
    hazards = [
        spikes(T * 32, T * 17 - 18, T * 4),
        spikes(T * 50, T * 24 - 18, T * 6),
        spikes(T * 76, T * 20 - 18, T * 4),
        spikes(T * 106, T * 18 - 18, T * 4),
        laser(T * 42, T * 12, 10, T * 8, 2.4, 0),
        laser(T * 86, T * 16, 10, T * 8, 2.8, 0.5),
        laser(T * 118, T * 8, 10, T * 10, 2.2, 0.3),
    ]
    coin_list = coins(
        [
            *arc(T * 6, T * 24, 3, T * 2, 16),
            [T * 12.4, T * 16],
            [T * 18, T * 27 - 12],
            [T * 20, T * 27 - 12],
            [T * 28, T * 17],
            [T * 27, T * 6],
            [T * 34, T * 11],
            [T * 42, T * 8],
            *arc(T * 50, T * 5, 4, T * 2, 10),
            [T * 68, T * 11],
            [T * 78, T * 17],
            [T * 92, T * 11],
            [T * 110, T * 9],
            [T * 120, T * 19],
            [T * 128, T * 4],
            [T * 140, T * 9],
        ]
    )
    checks = [
        {"x": T * 74, "y": T * 20 - 72, "secret": "pichincha"},
        {"x": T * 111, "y": T * 18 - 72, "secret": None},
    ]
    goal = {"x": T * 144, "y": T * 12 - 56, "w": 48, "h": 56, "kind": "cacao"}
    falls = [{"x": T * 11.5, "y": T * 31, "w": T * 5, "h": T * 6, "secret": "jardin"}]
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

    out_falls = []
    for i, f in enumerate(falls):
        center, size, top = box_m(f["x"], f["y"], f["w"], f["h"])
        out_falls.append(
            {
                "id": f"F{i:02d}",
                "secret": f["secret"],
                "px": {"x": f["x"], "y": f["y"], "w": f["w"], "h": f["h"]},
                "center_m": center,
                "size_m": size,
                "top_m": top,
            }
        )

    shots = [
        {
            "id": "patio",
            "label": "Patio inicial, techo de arrastre y pozo",
            "player_px": {"x": 291, "y": T * 27 - PH},
        },
        {
            "id": "jardin",
            "label": "Secreto jardín: caída entre los muros",
            "player_px": {"x": 403, "y": 1095},
        },
        {
            "id": "mantle",
            "label": "Borde de mantle en la corona del muro de escalada",
            "player_px": {"x": 356, "y": T * 6 - PH},
        },
    ]
    for s in shots:
        s["feet_m"] = feet_m(s["player_px"]["x"], s["player_px"]["y"])

    spawn_px = {"x": T * 3, "y": T * 24}
    doc = {
        "meta": {
            "level_id": "ruinas-1",
            "world_id": "ruinas",
            "display": "Ruinas de Kakaw",
            "subtitle": "El patio de las lanzas",
            "source_requested": "NadiaCoelloO/sand-vivid-dawn-sail@5fd450312c8e6ad0a214f35b68fd81ec2857fec3",
            "source_read": "NadiaCoelloO/Cacao.Game@77e55b5278 src/game/levels.ts ruinas-1",
            "px_to_m": PX,
            "level_w_px": LEVEL_W,
            "level_h_px": LEVEL_H,
            "depth_px": DEPTH_PX,
            "spawn_px": spawn_px,
            "spawn_feet_m": feet_m(spawn_px["x"], spawn_px["y"]),
        },
        "platforms": out_plats,
        "hazards": out_haz,
        "pickups": out_coins,
        "checkpoints": out_checks,
        "goal": out_goal,
        "falls": out_falls,
        "shots": shots,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"wrote {OUT_JSON}")
    print(f"platforms {len(out_plats)} hazards {len(out_haz)} pickups {len(out_coins)} checks {len(out_checks)} falls {len(out_falls)}")
    for s in shots:
        print(s["id"], s["player_px"], s["feet_m"])


if __name__ == "__main__":
    build()
