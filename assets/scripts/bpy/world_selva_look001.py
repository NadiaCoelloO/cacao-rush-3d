#!/usr/bin/env python3
"""WORLD-001 / LOOK-001 — Cuyabeno (world id `selva`) greybox look pass.

Blender 5.2.1 LTS, EEVEE. Reproducible, fixed seed, idempotent.

What it does
  * Gameplay base (SELVA_GAMEPLAY_BASE): approved greybox footprint rebuilt from the repo
    bpy patterns at ref f9a879d (chunk_selva_floor / chunk_selva_platform_solid /
    chunk_selva_oneway). Kept intact if the collection already exists in the open .blend.
  * LOOK-001 decor in per-LOD collections (LOOK001_DECOR_LOD0/1/2): trees, roots, canopy,
    understory, bank, blackwater plane, non-figurative wood/cacao/liana totem, backdrop.
  * Atmosphere (LOOK001_ATMOS): low discontinuous fog volumes  -> never exported.
  * VFX preview (warp beam), review helpers (Maya grey stand-in, light probes),
    lights and cameras in their own collections -> never exported.
  * Exports selva_look001_LOD0/1/2.glb independently (gameplay + markers + that LOD only),
    transforms applied, triangulated, Y-up via the glTF exporter (no manual rotation).
  * Renders LOOK-001_laguna.png / LOOK-001_dosel.png (EEVEE 1920x1080, same grade/exposure).
  * Writes LOOK-001_manifest.json and SHA256SUMS.txt.

Display name is **Cuyabeno** (never the superseded names). High-poly HOLD respected.
1u = 1m. Ref 2D tip 5fd45031 (read only).

Usage
  blender --background --python world_selva_look001.py -- [--out DIR] [--samples N]
          [--res 1920x1080] [--no-render] [--no-export] [--only laguna|dosel]
Exit codes: 0 ok · 3 LOD0 over 80k tris · 1 any other failure.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import shutil
import struct
import sys
import time
import traceback
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

# --------------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------------
SCRIPT_ID = "world_selva_look001.py"
LOOK_ID = "LOOK-001"
WORLD_ID = "selva"
DISPLAY_NAME = "Cuyabeno"
DEFAULT_OUT = Path("/home/box/workspace/world-001/assets-out")
SEED = 1001
REF_2D_TIP = "5fd45031"
REF_2D_TIP_FULL = "5fd450312c8e6ad0a214f35b68fd81ec2857fec3"
GREYBOX_REF = "f9a879d"
GREYBOX_REPO = "NadiaCoelloO/cacao-rush-3d"
REQUIRED_BLENDER = (5, 2, 1)
PAINT_V03 = {
    "CIN-001_warp_sting_paint_v03.png": {
        "path": "/home/box/workspace/cine/CIN-001/CIN-001_warp_sting_paint_v03.png",
        "sha256": "31cfd39af3076707c72ae9dfe00adf72ae8505bb9c6b956e41c8ccd2639826a9",
    },
    "CIN-003_intro_cuyabeno_paint_v03.png": {
        "path": "/home/box/workspace/cine/CIN-003/CIN-003_intro_cuyabeno_paint_v03.png",
        "sha256": "da799083d8ee44960130b3cf239af7c35b98b22381f10d671470db165e4d536c",
    },
}

BUDGET_CONTRACT_LOD0 = 80000
BUDGET_SUGGESTED = {0: 15000, 1: 6000, 2: 2000}

# Gameplay anchors (from runtime/scenes/pilot_cuyabeno.tscn @ f9a879d, Godot -> Blender
# conversion: Blender(x, y, z) = Godot(x, -z, y)). Movement axis = Blender X at y = 0.
TOTEM_ANCHOR = Vector((7.5, 0.0, 0.0))
VFX_SPAWN_Z = 3.03
SOLID_MODULE_POS = Vector((6.0, 0.0, 0.0))       # matches pilot CSGPlatform x=6, top y=1.0
ONEWAY_MODULE_POS = Vector((1.0, 0.0, 1.80))     # review placement (see manifest)
CORRIDOR_HALF_DEPTH = 2.2                        # |y| < this stays clear of decor
JUMP_CLEAR_Z = 7.5                               # no decor over the corridor below this

MAYA_POS = Vector((5.55, 0.0, 1.0))              # review stand-in on the solid platform
MAYA_YAW_DEG = -45.0

# Palette (sRGB hex) — brief section 7
PAL_HEX = {
    "water": "#10191A",
    "veg_deep": "#20372C",
    "veg_lit": "#52654A",
    "wood_wet": "#654B34",
    "maya": "#808080",
    "cacao_y": "#D6AB3D",
    "cacao_o": "#CE722E",
    "cacao_r": "#A64B36",
    "warp_gold": "#FFD16A",
    "warp_cyan": "#83D5D9",
    # derived working tones (documented in manifest)
    "earth": "#3B342A",
    "earth_wet": "#2B2620",
    "litter": "#55462F",
    "rock": "#56534A",
    "plat_body": "#4E4234",
    "plat_top": "#7E7058",
    "solid_body": "#5B5446",
    "solid_top": "#8E8670",
    "oneway_top": "#A88E62",
    "oneway_cue": "#4A3A2A",
    "wood_dark": "#3E2E21",
    "vine": "#3C5634",
    "veg_near": "#16261E",
    "backdrop_lo": "#16221C",
    "backdrop_hi": "#26362D",
    "mud": "#2A241C",
    "mud_dark": "#1A1713",
}


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexlin(h: str):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PAL = {k: hexlin(v) for k, v in PAL_HEX.items()}


def cmix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] * (1.0 - t) + b[i] * t for i in range(3))


def cmul(a, k):
    return tuple(max(0.0, a[i] * k) for i in range(3))


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------------------
# Args
# --------------------------------------------------------------------------------------
def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(description="WORLD-001 LOOK-001 Cuyabeno look build")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output dir (default assets-out)")
    p.add_argument("--res", default="1920x1080")
    p.add_argument("--samples", type=int, default=64)
    p.add_argument("--no-render", action="store_true")
    p.add_argument("--no-export", action="store_true")
    p.add_argument("--only", choices=["laguna", "dosel"], default=None)
    p.add_argument("--percent", type=int, default=100, help="render resolution percentage (QA only)")
    return p.parse_args(argv)


# --------------------------------------------------------------------------------------
# Mesh builder (bmesh, float corner colours "Col", per-face material slot)
# --------------------------------------------------------------------------------------
class MB:
    def __init__(self, name: str, slots):
        self.name = name
        self.slots = list(slots)
        self.bm = bmesh.new()
        self.cl = self.bm.loops.layers.float_color.new("Col")

    def _finish(self, verts, color, slot=None, top=None, smooth=False):
        slot = slot or self.slots[0]
        idx = self.slots.index(slot)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = idx
            f.smooth = smooth
            f.normal_update()
            for lp in f.loops:
                if callable(color):
                    c = color(lp.vert.co, f)
                elif top is not None and f.normal.z > 0.7:
                    c = top
                else:
                    c = color
                lp[self.cl] = (c[0], c[1], c[2], 1.0)
        return faces

    @staticmethod
    def _m(center, rot=(0, 0, 0), scale=(1, 1, 1)):
        return (Matrix.Translation(Vector(center)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
                @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))

    def box(self, center, size, color, slot=None, rot=(0, 0, 0), top=None):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._m(center, rot, size))
        return self._finish(r["verts"], color, slot, top)

    def bevel_box(self, center, size, color, slot=None, offset=0.06, segments=2, top=None):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self._m(center, (0, 0, 0), size))
        verts = r["verts"]
        edges = list({e for v in verts for e in v.link_edges})
        res = bmesh.ops.bevel(self.bm, geom=edges, offset=offset, segments=segments,
                              profile=0.5, affect="EDGES")
        allv = {v for v in verts if v.is_valid} | {v for f in res.get("faces", []) for v in f.verts}
        return self._finish(list(allv), color, slot, top)

    def seg(self, a, b, r1, r2, segs, color, slot=None, cap=False):
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
        r = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segs,
                                  radius1=r1, radius2=r2, depth=L, matrix=M)
        return self._finish(r["verts"], color, slot)

    def cyl(self, center, r1, r2, depth, segs, color, slot=None, cap=True, rot=(0, 0, 0), top=None):
        r = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segs,
                                  radius1=r1, radius2=r2, depth=depth,
                                  matrix=self._m(center, rot))
        return self._finish(r["verts"], color, slot, top)

    def blob(self, center, radii, subdiv, color, slot=None, rng=None, jitter=0.0, rot_z=0.0):
        c = Vector(center)
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0,
                                       matrix=self._m(center, (0, 0, rot_z), radii))
        if rng is not None and jitter > 0:
            for v in r["verts"]:
                k = 1.0 + rng.uniform(-jitter, jitter)
                v.co = c + (v.co - c) * k
        return self._finish(r["verts"], color, slot)

    def octa(self, center, radii, color, slot=None, rot_z=0.0):
        """8-tri octahedral mass for distant LODs."""
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=4, v_segments=2, radius=1.0,
                                      matrix=self._m(center, (0, 0, rot_z), radii))
        return self._finish(r["verts"], color, slot)

    def pod(self, center, radii, axis_rot, u, v, color, slot=None, groove=0.78):
        c = Vector(center)
        R = Euler(axis_rot, "XYZ").to_matrix()
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=1.0,
                                      matrix=self._m(center, axis_rot, radii))
        b1, b2 = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0))
        dark = cmul(color, groove)

        def cf(co, f):
            w = f.calc_center_median() - c
            ang = math.atan2(w.dot(b2), w.dot(b1))
            band = int((ang + math.pi) / (2 * math.pi) * u) % 2
            return dark if band else color
        return self._finish(r["verts"], cf, slot)

    def quad(self, pts, color, slot=None):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        self.bm.faces.new(vs)
        return self._finish(vs, color, slot)

    def leaf(self, base, direction, length, width, droop, color, slot=None, fold=True):
        """Broad leaf: 4–5 verts, 2–4 tris."""
        b = Vector(base)
        d = Vector(direction).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        mid = b + d * (length * 0.45) + Vector((0, 0, droop * 0.25))
        tip = b + d * length + Vector((0, 0, -droop))
        pts = [b, mid + side * width * 0.5, tip, mid - side * width * 0.5]
        vs = [self.bm.verts.new(p) for p in pts]
        if fold:
            midc = self.bm.verts.new(mid + Vector((0, 0, 0.06 * width)))
            for a, bb in ((0, 1), (1, 2), (2, 3), (3, 0)):
                self.bm.faces.new([vs[a], vs[bb], midc])
            vs.append(midc)
        else:
            self.bm.faces.new(vs)
        return self._finish(vs, color, slot)

    def grid(self, x0, x1, y0, y1, z, nx, ny, colorfn, slot=None):
        rows = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx
                y = y0 + (y1 - y0) * j / ny
                row.append(self.bm.verts.new((x, y, z)))
            rows.append(row)
        for j in range(ny):
            for i in range(nx):
                self.bm.faces.new([rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]])
        return self._finish([v for r in rows for v in r], colorfn, slot)

    def to_object(self, coll, mats, props=None):
        if len(self.bm.faces) == 0:
            self.bm.free()
            return None
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:], quad_method="BEAUTY",
                              ngon_method="BEAUTY")
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for s in self.slots:
            me.materials.append(mats[s])
        if not any(s in VC_MATERIALS for s in self.slots):
            attr = me.color_attributes.get("Col")
            if attr is not None:
                me.color_attributes.remove(attr)
        else:
            try:
                me.color_attributes.active_color_name = "Col"
                me.color_attributes.render_color_index = 0
            except Exception:
                pass
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        for k, v in (props or {}).items():
            ob[k] = v
        return ob


# --------------------------------------------------------------------------------------
# Scene / collections (idempotent)
# --------------------------------------------------------------------------------------
GAMEPLAY_COLL = "SELVA_GAMEPLAY_BASE"
LOOK_COLLS = [
    "LOOK001_MARKERS", "LOOK001_DECOR", "LOOK001_DECOR_LOD0", "LOOK001_DECOR_LOD1",
    "LOOK001_DECOR_LOD2", "LOOK001_ATMOS", "LOOK001_VFX_PREVIEW", "LOOK001_LIGHTS",
    "LOOK001_CAMERAS", "LOOK001_REVIEW_HELPERS",
]


def find_layer_collection(lc, name):
    if lc.collection.name == name:
        return lc
    for ch in lc.children:
        r = find_layer_collection(ch, name)
        if r:
            return r
    return None


def clear_look_collections():
    removed = 0
    names = list(LOOK_COLLS) + [c.name for c in bpy.data.collections if c.name.startswith("LOOK001_")]
    for name in names:
        col = bpy.data.collections.get(name)
        if col is None:
            continue
        for ob in list(col.all_objects):
            bpy.data.objects.remove(ob, do_unlink=True)
            removed += 1
        bpy.data.collections.remove(col)
    for block in (bpy.data.meshes, bpy.data.lights, bpy.data.cameras, bpy.data.lightprobes):
        for item in list(block):
            if item.users == 0:
                block.remove(item)
    return removed


def new_coll(name, parent=None):
    col = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(col)
    return col


def prepare_scene():
    fresh = not bpy.data.filepath
    if fresh:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "SELVA_LOOK001"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "METERS"
    removed = clear_look_collections()
    return scene, fresh, removed


# --------------------------------------------------------------------------------------
# Materials (six shared slots + look-only helpers)
# --------------------------------------------------------------------------------------
def _nt(mat):
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    return nt


def _get_mat(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def _set(node, key, val):
    if key in node.inputs:
        node.inputs[key].default_value = val


def make_materials():
    mats = {}
    # M_SELVA_OPAQUE — simple lit, colour from vertex colour "Col"
    m = _get_mat("M_SELVA_OPAQUE")
    nt = _nt(m)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    _set(bsdf, "Roughness", 0.78)
    _set(bsdf, "Metallic", 0.0)
    _set(bsdf, "Specular IOR Level", 0.35)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m.use_backface_culling = False
    m.diffuse_color = (*PAL["veg_deep"], 1.0)
    mats["M_SELVA_OPAQUE"] = m

    # M_SELVA_BACKDROP — unlit (Background shader -> KHR_materials_unlit in glTF)
    m = _get_mat("M_SELVA_BACKDROP")
    nt = _nt(m)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bg = nt.nodes.new("ShaderNodeBackground")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    m.diffuse_color = (*PAL["backdrop_lo"], 1.0)
    mats["M_SELVA_BACKDROP"] = m

    # M_BLACKWATER — Principled, metallic 0, roughness 0.15, broad slow ripples (bump only)
    m = _get_mat("M_BLACKWATER")
    nt = _nt(m)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*PAL["water"], 1.0)
    _set(bsdf, "Roughness", WATER_ROUGHNESS)
    _set(bsdf, "Metallic", 0.0)
    _set(bsdf, "IOR", 1.333)
    _set(bsdf, "Specular IOR Level", 0.5)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 0.22
    n1.inputs["Detail"].default_value = 1.0
    n1.inputs["Roughness"].default_value = 0.35
    n2 = nt.nodes.new("ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = 0.9
    n2.inputs["Detail"].default_value = 0.0
    mixh = nt.nodes.new("ShaderNodeMath")
    mixh.operation = "MULTIPLY_ADD"
    mixh.inputs[1].default_value = 0.25
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = WATER_BUMP
    bump.inputs["Distance"].default_value = 0.06
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    nt.links.new(n2.outputs["Fac"], mixh.inputs[0])
    nt.links.new(n1.outputs["Fac"], mixh.inputs[2])
    nt.links.new(mixh.outputs["Value"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m.diffuse_color = (*PAL["water"], 1.0)
    mats["M_BLACKWATER"] = m

    # M_MAYA_GREY — #808080 neutral mid grey
    m = _get_mat("M_MAYA_GREY")
    nt = _nt(m)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*PAL["maya"], 1.0)
    _set(bsdf, "Roughness", 0.72)
    _set(bsdf, "Metallic", 0.0)
    _set(bsdf, "Specular IOR Level", 0.4)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m.diffuse_color = (*PAL["maya"], 1.0)
    mats["M_MAYA_GREY"] = m

    # M_WARP_GOLD / M_WARP_CYAN — simple emissive (Principled emission -> glTF emissive)
    for name, key in (("M_WARP_GOLD", "warp_gold"), ("M_WARP_CYAN", "warp_cyan")):
        m = _get_mat(name)
        nt = _nt(m)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = (*PAL[key], 1.0)
        _set(bsdf, "Roughness", 0.45)
        _set(bsdf, "Metallic", 0.0)
        _set(bsdf, "Emission Color", (*PAL[key], 1.0))
        _set(bsdf, "Emission Strength", WARP_STRENGTH["active"][name])
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        m.diffuse_color = (*PAL[key], 1.0)
        mats[name] = m

    # Look-only (not slots, never exported): beam preview with soft fade, fog volume.
    for name, key, strength in (("LOOKONLY_VFX_BeamGold", "warp_gold", BEAM_STRENGTH["gold"]),
                                ("LOOKONLY_VFX_BeamCyan", "warp_cyan", BEAM_STRENGTH["cyan"])):
        m = _get_mat(name)
        nt = _nt(m)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*PAL[key], 1.0)
        em.inputs["Strength"].default_value = strength
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        inv = nt.nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        pw = nt.nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        pw.inputs[1].default_value = 1.6
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.55
        face = nt.nodes.new("ShaderNodeMath")
        face.operation = "SUBTRACT"
        face.inputs[0].default_value = 1.0
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        gain = nt.nodes.new("ShaderNodeMath")
        gain.operation = "MULTIPLY"
        gain.inputs[1].default_value = 0.85
        gain.use_clamp = True
        nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
        nt.links.new(sep.outputs["Z"], inv.inputs[1])
        nt.links.new(inv.outputs["Value"], pw.inputs[0])
        nt.links.new(lw.outputs["Facing"], face.inputs[1])
        nt.links.new(pw.outputs["Value"], mul.inputs[0])
        nt.links.new(face.outputs["Value"], mul.inputs[1])
        nt.links.new(mul.outputs["Value"], gain.inputs[0])
        nt.links.new(gain.outputs["Value"], mix.inputs["Fac"])
        nt.links.new(tr.outputs["BSDF"], mix.inputs[1])
        nt.links.new(em.outputs["Emission"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
        m.use_backface_culling = False
        mats[name] = m

    m = _get_mat("LOOKONLY_FogBank")
    nt = _nt(m)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.78, 0.82, 0.86, 1.0)
    _set(vol, "Anisotropy", 0.35)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    edge = nt.nodes.new("ShaderNodeMapRange")
    edge.interpolation_type = "SMOOTHSTEP"
    edge.inputs["From Min"].default_value = 1.0
    edge.inputs["From Max"].default_value = 0.35
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.6
    noise.inputs["Detail"].default_value = 2.0
    noise.inputs["Roughness"].default_value = 0.5
    nmr = nt.nodes.new("ShaderNodeMapRange")
    nmr.interpolation_type = "SMOOTHSTEP"
    nmr.inputs["From Min"].default_value = 0.42
    nmr.inputs["From Max"].default_value = 0.68
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    hz = nt.nodes.new("ShaderNodeMapRange")       # denser at the bottom of the bank
    hz.inputs["From Min"].default_value = 1.0
    hz.inputs["From Max"].default_value = -0.6
    hz.inputs["To Min"].default_value = 0.25
    hz.inputs["To Max"].default_value = 1.0
    m1 = nt.nodes.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    m2 = nt.nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    dens = nt.nodes.new("ShaderNodeMath")
    dens.operation = "MULTIPLY"
    dens.name = "FOG_DENSITY"
    dens.inputs[1].default_value = FOG_BANK_DENSITY
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    nt.links.new(ln.outputs["Value"], edge.inputs["Value"])
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], nmr.inputs["Value"])
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], hz.inputs["Value"])
    nt.links.new(edge.outputs["Result"], m1.inputs[0])
    nt.links.new(nmr.outputs["Result"], m1.inputs[1])
    nt.links.new(m1.outputs["Value"], m2.inputs[0])
    nt.links.new(hz.outputs["Result"], m2.inputs[1])
    nt.links.new(m2.outputs["Value"], dens.inputs[0])
    nt.links.new(dens.outputs["Value"], vol.inputs["Density"])
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    mats["LOOKONLY_FogBank"] = m
    return mats


VC_MATERIALS = {"M_SELVA_OPAQUE", "M_SELVA_BACKDROP"}
SLOT_MATERIALS = ["M_SELVA_OPAQUE", "M_SELVA_BACKDROP", "M_BLACKWATER",
                  "M_MAYA_GREY", "M_WARP_GOLD", "M_WARP_CYAN"]
WATER_ROUGHNESS = 0.15
WATER_BUMP = 0.05
FOG_BANK_DENSITY = 0.18
WORLD_HAZE_DENSITY = 0.0025
CANOPY_STEP = 4.8
BACKDROP_CEILING = False
WARP_STRENGTH = {"active": {"M_WARP_GOLD": 3.0, "M_WARP_CYAN": 2.4},
                 "dim": {"M_WARP_GOLD": 0.35, "M_WARP_CYAN": 0.25}}
BEAM_STRENGTH = {"gold": 3.2, "cyan": 2.6}


# --------------------------------------------------------------------------------------
# Gameplay base — approved greybox footprint (repo f9a879d patterns, positions unchanged)
# --------------------------------------------------------------------------------------
FLOOR_SIZE = 18.0
PLATFORMS_ABC = [  # chunk_selva_floor.py — name, center, size
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
LITTER = [(-2.0, 2.0, 0.04), (3.5, -1.5, 0.03), (-4.0, -3.0, 0.05), (5.5, 4.5, 0.04),
          (0.5, 1.0, 0.03), (-7.0, 1.5, 0.04), (7.0, -6.0, 0.03), (-1.0, -7.0, 0.04)]
ROCKS = [((7.5, 2.0, 0.25), (0.7, 0.5, 0.5)), ((-7.0, 6.0, 0.20), (0.5, 0.6, 0.4))]
SOLID_W, SOLID_D, SOLID_H = 3.0, 2.0, 1.0
ONEWAY_W, ONEWAY_D, ONEWAY_H = 4.0, 2.0, 0.18


def floor_color(co, f=None):
    x, y = co.x, co.y
    t = 0.5 + 0.5 * math.sin(x * 0.61 + 1.3) * math.cos(y * 0.47 - 0.4)
    c = cmix(PAL["earth_wet"], PAL["earth"], 0.35 + 0.5 * t)
    edge = max(abs(x), abs(y)) / (FLOOR_SIZE * 0.5)
    return cmix(c, PAL["earth_wet"], smoothstep(0.82, 1.0, edge) * 0.6)


def build_gameplay(coll, mats):
    objs = []
    src = lambda f: f"{f}@{GREYBOX_REF}"  # noqa: E731
    h = FLOOR_SIZE * 0.5
    mb = MB("SELVA_GP_Floor", ["M_SELVA_OPAQUE"])
    mb.grid(-h, h, -h, h, 0.0, 4, 4, floor_color)   # plane 18 m, 3 cuts == 4x4 quads
    objs.append(mb.to_object(coll, mats, {"cr_role": "gameplay_floor", "cr_src": src("chunk_selva_floor.py")}))

    mb = MB("SELVA_GP_Platforms", ["M_SELVA_OPAQUE"])
    for _n, c, s in PLATFORMS_ABC:
        mb.box(c, s, PAL["plat_body"], top=PAL["plat_top"])
    objs.append(mb.to_object(coll, mats, {"cr_role": "gameplay_platform_solid", "cr_src": src("chunk_selva_floor.py")}))

    mb = MB("SELVA_GP_FloorClutter", ["M_SELVA_OPAQUE"])
    for loc, r, d in ROOT_STUBS:
        mb.cyl(loc, r, r, d, 10, PAL["wood_dark"], top=PAL["wood_wet"])
        mb.box((loc[0] + r * 0.9, loc[1], 0.08), (r * 1.6, r * 0.5, 0.12), PAL["wood_dark"])
    for i, (x, y, z) in enumerate(LITTER, start=1):
        mb.box((x, y, z), (0.8 + (i % 3) * 0.15, 0.5 + (i % 2) * 0.2, 0.06),
               cmix(PAL["litter"], PAL["earth"], 0.3 * (i % 2)))
    for c, s in ROCKS:
        mb.box(c, s, PAL["rock"], top=cmul(PAL["rock"], 1.25))
    objs.append(mb.to_object(coll, mats, {"cr_role": "gameplay_floor_clutter", "cr_src": src("chunk_selva_floor.py")}))

    # chunk_selva_platform_solid.py module (3x2x1, bevel 0.06/2, top plate) at pilot CSG x=6
    mb = MB("SELVA_GP_PlatformSolid_01", ["M_SELVA_OPAQUE"])
    p = SOLID_MODULE_POS
    mb.bevel_box((p.x, p.y, p.z + SOLID_H * 0.5), (SOLID_W, SOLID_D, SOLID_H), PAL["solid_body"],
                 offset=0.06, segments=2, top=PAL["solid_top"])
    mb.box((p.x, p.y, p.z + SOLID_H - 0.03 + 0.005), (SOLID_W * 0.92, SOLID_D * 0.92, 0.06),
           PAL["solid_body"], top=PAL["solid_top"])
    objs.append(mb.to_object(coll, mats, {"cr_role": "gameplay_platform_solid", "cr_src": src("chunk_selva_platform_solid.py")}))

    # chunk_selva_oneway.py module (4x2x0.18 slab + top strip + underside chevron cue)
    mb = MB("SELVA_GP_Oneway_01", ["M_SELVA_OPAQUE"])
    o = ONEWAY_MODULE_POS
    mb.box((o.x, o.y, o.z + ONEWAY_H * 0.5), (ONEWAY_W, ONEWAY_D, ONEWAY_H), PAL["wood_wet"])
    mb.box((o.x, o.y, o.z + ONEWAY_H + 0.015), (ONEWAY_W * 0.94, ONEWAY_D * 0.70, 0.03),
           PAL["oneway_cue"], top=PAL["oneway_top"])
    mb.box((o.x - 0.45, o.y, o.z - 0.06), (1.1, 0.12, 0.10), PAL["oneway_cue"], rot=(0, 0.45, 0))
    mb.box((o.x + 0.45, o.y, o.z - 0.06), (1.1, 0.12, 0.10), PAL["oneway_cue"], rot=(0, -0.45, 0))
    mb.box((o.x, o.y, o.z - 0.08), (0.35, 0.35, 0.12), PAL["oneway_cue"])
    objs.append(mb.to_object(coll, mats, {"cr_role": "gameplay_platform_oneway", "cr_oneway": True,
                                          "cr_src": src("chunk_selva_oneway.py")}))
    return [o for o in objs if o]


# --------------------------------------------------------------------------------------
# Decor layout (generated once with fixed seed; meshes rebuilt per LOD from same params)
# --------------------------------------------------------------------------------------
SUN_AZ_DEG = -20.0     # from +X toward -Y
SUN_EL_DEG = 35.0


def sun_dir():
    az, el = math.radians(SUN_AZ_DEG), math.radians(SUN_EL_DEG)
    return Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))


# Light zones on the ground: gaps are carved in the canopy along the sun ray above them.
LIGHT_ZONES = [
    ("zone_totem_maya", Vector((6.8, 0.0, 1.0)), 2.8),
    ("zone_platform_B", Vector((-4.8, -2.0, 0.4)), 2.4),
    ("zone_lagoon", Vector((-1.0, 17.0, 0.0)), 3.2),
]
# Vertical sky openings (irregular, explain the light + give reflections in the water).
SKY_OPENINGS = [
    (Vector((7.5, 0.0)), 2.6),     # above the totem: room for the warp beam
    (Vector((-2.5, -4.5)), 2.8),
    (Vector((1.5, 5.5)), 2.2),
    (Vector((-10.0, 7.0)), 2.6),
    (Vector((12.0, -9.0)), 3.0),
    (Vector((2.0, 25.0)), 3.6),
    (Vector((-14.0, 31.0)), 3.2),
    (Vector((15.0, 33.0)), 3.4),
    (Vector((-6.0, -15.0)), 3.0),
]
OPEN_LAGOON = (Vector((9.5, 13.5)), 8.0, 5.5)   # ellipse kept free of trunks
CAM_LAGUNA_POS = Vector((13.8, 17.2, 1.75))
CAM_DOSEL_POS = Vector((-7.2, -9.4, 0.95))


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


def in_gameplay_keepout(x, y, margin=0.6):
    if abs(y) < CORRIDOR_HALF_DEPTH and -12.5 < x < 12.5:
        return True
    for _n, c, s in PLATFORMS_ABC:
        if abs(x - c[0]) < s[0] * 0.5 + margin and abs(y - c[1]) < s[1] * 0.5 + margin:
            return True
    for loc, r, _d in ROOT_STUBS:
        if math.hypot(x - loc[0], y - loc[1]) < r + margin + 0.3:
            return True
    if abs(x - TOTEM_ANCHOR.x) < 1.2 + margin and abs(y) < 1.2 + margin:
        return True
    return False


def over_corridor(c, rr):
    """True if a mass (center c, radii rr) would hang over the play corridor below jump clearance."""
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

    # 1) back bank row (behind corridor, left side only so the corridor stays visible)
    for x in (-10.4, -7.6, -4.6):
        for _ in range(6):
            if try_tree(x + rng.uniform(-0.6, 0.6), rng.uniform(10.0, 11.6), -0.35, 12.0, 15.5, "bank"):
                break
    # 2) front row (y < -10.5: behind the gameplay camera; frames the lagoon still)
    for x in (-11.5, -7.5, -3.0, 1.5, 6.0, 10.5):
        for _ in range(6):
            if try_tree(x + rng.uniform(-1.2, 1.2), rng.uniform(-11.0, -16.5), -0.6, 12.0, 16.5, "front"):
                break
    # 3) flooded forest in the lagoon (behind corridor), avoiding the open lagoon ellipse
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
    # 4) snags (dead emergent trunks) and floating logs
    tries = 0
    while len(L["snags"]) < 7 and tries < 400:
        tries += 1
        x, y = rng.uniform(-18.0, 20.0), rng.uniform(10.5, 30.0)
        if in_open_lagoon(x, y, -2.5) and rng.random() < 0.6:
            continue
        if (Vector((x, y)) - CAM_LAGUNA_POS.xy).length < 4.0:
            continue
        if any((Vector((x, y)) - t["pos"].xy).length < 2.5 for t in L["trees"]):
            continue
        L["snags"].append({"pos": Vector((x, y, -0.6)), "H": rng.uniform(1.6, 4.8),
                           "r": rng.uniform(0.14, 0.3),
                           "tilt": (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25))})
    for _ in range(5):
        x, y = rng.uniform(-14.0, 16.0), rng.uniform(10.5, 26.0)
        if (Vector((x, y)) - CAM_LAGUNA_POS.xy).length < 9.0:
            continue
        L["logs"].append({"pos": Vector((x, y, -0.1)), "len": rng.uniform(2.5, 5.0),
                          "r": rng.uniform(0.15, 0.26), "yaw": rng.uniform(0, math.pi)})
    # 5) overhead canopy (lit, chunk area) — near dark layer lower at the frame edges
    for gx in range(-6, 7):
        for gy in range(-5, 9):
            x = gx * CANOPY_STEP + rng.uniform(-1.8, 1.8)
            y = gy * CANOPY_STEP + 4.0 + rng.uniform(-1.8, 1.8)
            dist = math.hypot(x - 3.0, y - 6.0)
            if dist > 30.0:
                continue
            near = (y < -5.0) or abs(x) > 15.0
            z = rng.uniform(7.8, 10.2) if near else rng.uniform(10.0, 15.5)
            rr = rng.uniform(3.6, 6.0)
            c = Vector((x, y, z))
            radii = Vector((rr, rr * rng.uniform(0.75, 1.2), rng.uniform(1.2, 2.2)))
            if in_gap(c, rr) or over_corridor(c, radii):
                continue
            L["canopy"].append({"c": c, "r": radii, "near": near, "rot": rng.uniform(0, 3.14), "far": dist > 20.0})
    # 5b) framing canopy over the lagoon review camera (dark near layer; closes the upper frame)
    for _ in range(40):
        if sum(1 for k in L["canopy"] if k.get("frame")) >= 9:
            break
        x, y = rng.uniform(4.0, 26.0), rng.uniform(-8.0, 26.0)
        if abs(y) < 9.0 and x < 13.0:
            continue
        c = Vector((x, y, rng.uniform(8.5, 11.0)))
        rr = rng.uniform(3.6, 5.4)
        radii = Vector((rr, rr * rng.uniform(0.8, 1.2), rng.uniform(1.2, 1.9)))
        if over_corridor(c, radii) or any((c - k["c"]).length < rr * 0.9 for k in L["canopy"]):
            continue
        L["canopy"].append({"c": c, "r": radii, "near": True, "rot": rng.uniform(0, 3.14), "far": False, "frame": True})
    # 6) understory plants (low on the front half; taller only behind the corridor)
    tries = 0
    while len(L["plants"]) < 34 and tries < 2000:
        tries += 1
        x, y = rng.uniform(-10.0, 10.0), rng.uniform(-10.2, 10.6)
        if in_gameplay_keepout(x, y, 0.5):
            continue
        if abs(x - ONEWAY_MODULE_POS.x) < 2.6 and abs(y) < 2.6:
            continue
        front = y < 0
        if front and abs(x) < 7.5 and y > -8.0 and rng.random() < 0.65:
            continue  # keep the near floor mostly readable
        height = rng.uniform(0.35, 0.75) if front else rng.uniform(0.6, 1.5)
        on_floor = abs(x) <= 9 and abs(y) <= 9
        L["plants"].append({"pos": Vector((x, y, 0.0 if on_floor else -0.25)),
                            "h": height, "n": rng.randint(4, 6), "rot": rng.uniform(0, 6.28),
                            "tone": rng.random()})
    # 7) hanging broad-leaf clusters near canopy edges (front zone, above play camera view)
    for _ in range(12):
        x, y = rng.uniform(-13.0, 4.0), rng.uniform(-11.0, -4.0)
        z = rng.uniform(6.2, 8.4)
        L["hangers"].append({"pos": Vector((x, y, z)), "n": rng.randint(5, 7), "rot": rng.uniform(0, 6.28),
                             "size": rng.uniform(0.9, 1.5)})
    # 8) lianas hanging from canopy (never over corridor / platforms)
    tries = 0
    while len(L["vines"]) < 14 and tries < 600:
        tries += 1
        x, y = rng.uniform(-14.0, 16.0), rng.uniform(-12.0, 22.0)
        if abs(y) < CORRIDOR_HALF_DEPTH + 1.2:
            continue
        if in_gameplay_keepout(x, y, 1.0) or in_open_lagoon(x, y, -1.0):
            continue
        top = rng.uniform(10.5, 13.0)
        bottom = rng.uniform(3.0, 6.0)
        L["vines"].append({"top": Vector((x, y, top)),
                           "bottom": Vector((x + rng.uniform(-0.6, 0.6), y + rng.uniform(-0.6, 0.6), bottom)),
                           "sway": Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0))})

    # 9) backdrop: far canopy walls + far ceiling (unlit, separate object)
    def wall(x0, x1, y0, y1, n):
        for i in range(n):
            t = (i + rng.uniform(-0.3, 0.3)) / max(1, n - 1)
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t + rng.uniform(-3.0, 3.0)
            for lvl in range(2):
                z = rng.uniform(6.0, 9.0) if lvl == 0 else rng.uniform(12.5, 16.0)
                rr = rng.uniform(5.0, 8.5)
                L["backdrop"].append({"c": Vector((x, y, z)), "r": Vector((rr, rr * 0.8, rr * rng.uniform(0.4, 0.6))),
                                      "trunk": lvl == 0 and rng.random() < 0.6, "big": lvl == 1 or rr > 7.0, "lvl": lvl,
                                      "rot": rng.uniform(0, 3.14)})
    wall(-58, 58, 52, 52, 13)       # back wall (seen behind lagoon / gameplay camera)
    wall(-50, 50, -30, -30, 11)     # front wall (seen only by the review lagoon camera)
    wall(-46, -46, -28, 50, 8)      # left wall
    wall(46, 46, -28, 50, 8)        # right wall
    for gx in ([] if not BACKDROP_CEILING else range(-4, 5)):  # far ceiling ring (off: keeps sky openings)
        for gy in range(-3, 7):
            x, y = gx * 11.0 + rng.uniform(-3, 3), gy * 11.0 + 6.0 + rng.uniform(-3, 3)
            d = math.hypot(x - 3.0, y - 6.0)
            if d < 27.0 or d > 52.0:
                continue
            c = Vector((x, y, rng.uniform(15.0, 21.0)))
            rr = rng.uniform(6.0, 9.0)
            if in_gap(c, rr):
                continue
            L["backdrop"].append({"c": c, "r": Vector((rr, rr, rr * 0.35)), "trunk": False, "big": True,
                                  "rot": rng.uniform(0, 3.14)})
    # 10) fog banks (look-only) — over water / depressions, never on landing zones
    banks = [
        ((5.5, 12.2), (4.5, 2.2), 0.10), ((3.0, 11.5), (4.5, 1.8), 0.05), ((-6.5, 11.2), (5.0, 1.6), 0.05),
        ((16.5, 6.5), (3.5, 2.2), 0.10), ((-2.0, 19.0), (6.0, 3.0), 0.15), ((12.0, 24.0), (6.5, 3.5), 0.15),
        ((-12.0, 23.0), (6.0, 3.5), 0.15), ((2.0, 31.0), (8.0, 4.0), 0.2), ((-4.0, -12.5), (6.0, 2.2), 0.05),
        ((9.0, -13.0), (5.0, 2.0), 0.05), ((-15.0, 14.0), (4.5, 3.0), 0.1), ((20.0, 15.0), (5.0, 3.0), 0.1),
    ]
    for (x, y), (rx, ry), zc in banks:
        th = rng.uniform(0.55, 0.95)          # half-thickness -> visual 0.3–1.2 m above water
        L["fog"].append({"c": Vector((x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.5, 0.5), zc)),
                         "r": Vector((rx, ry, th)), "rot": rng.uniform(0, 3.14)})
    return L


# --------------------------------------------------------------------------------------
# Decor builders per LOD (same params -> same origins/placements; less detail per LOD)
# --------------------------------------------------------------------------------------
LOD_SPEC = {
    0: {"trunk": 8, "trunk_rings": 2, "crown": 2, "crown_far": 1, "crowns": 3, "butt": True, "stilt": 5,
        "canopy": 2, "canopy_far": 1, "canopy_min_r": 0.0, "plants": 1.0, "hangers": True, "vines": 4,
        "back_trunks": True, "back_small": True, "totem": 12, "pod_u": 8, "pod_v": 5, "liana": 8, "snag": 6, "logs": 6},
    1: {"trunk": 6, "trunk_rings": 1, "crown": 1, "crown_far": 1, "crowns": 2, "butt": False, "stilt": 4,
        "canopy": 1, "canopy_far": 0, "canopy_min_r": 0.0, "plants": 0.5, "hangers": True, "vines": 3,
        "back_trunks": False, "back_small": False, "totem": 8, "pod_u": 6, "pod_v": 3, "liana": 3, "snag": 4, "logs": 4},
    2: {"trunk": 4, "trunk_rings": 1, "crown": 1, "crown_far": 0, "crowns": 1, "butt": False, "stilt": 0,
        "canopy": 1, "canopy_far": 0, "canopy_min_r": 4.8, "canopy_skip_far": True, "plants": 0.0, "hangers": False, "vines": 0,
        "back_trunks": False, "back_small": False, "back_top_only": True, "totem": 6, "pod_u": 4, "pod_v": 3, "liana": 0, "snag": 0, "logs": 0},
}


def trunk_color(t, shade):
    def f(co, face):
        z = co.z - t["pos"].z
        k = z / max(t["H"], 1.0)
        base = cmix(PAL["wood_dark"], PAL["wood_wet"], 0.35 + 0.4 * shade)
        c = cmix(cmul(PAL["mud_dark"], 1.2), base, smoothstep(0.0, 1.4, z))   # wet waterline
        return cmix(c, cmix(PAL["wood_wet"], PAL["veg_deep"], 0.45), smoothstep(0.55, 1.0, k) * 0.6)
    return f


def crown_color(center, radii, shade, lit_bias=0.0):
    def f(co, face):
        dz = (co.z - center.z) / max(radii.z, 0.1)
        k = smoothstep(-0.7, 0.9, dz) * (0.75 + 0.25 * shade) + lit_bias
        c = cmix(PAL["veg_near"], PAL["veg_deep"], 0.6 + 0.4 * shade)
        return cmix(c, PAL["veg_lit"], max(0.0, min(1.0, k * 0.85)))
    return f


def build_trees(L, lod, coll, mats):
    S = LOD_SPEC[lod]
    rng = random.Random(SEED + 100)
    mb = MB(f"LOOK001_Trees_LOD{lod}", ["M_SELVA_OPAQUE"])
    for t in L["trees"]:
        p, H, r = t["pos"], t["H"], t["r"]
        top = p + t["lean"] * H
        rings = S["trunk_rings"]
        cf = trunk_color(t, t["shade"])
        prev = p
        for k in range(rings):
            nxt = p + (top - p) * ((k + 1) / rings)
            mb.seg(prev, nxt, r * (1.0 - 0.35 * k / rings), r * (1.0 - 0.35 * (k + 1) / rings), S["trunk"], cf)
            prev = nxt
        if S["butt"] and t["kind"] != "flooded":
            for b in range(t["buttress"]):
                ang = t["bangle"] + b * (2 * math.pi / t["buttress"])
                d = Vector((math.cos(ang), math.sin(ang), 0))
                ln = r * 3.2
                mb.box(p + d * (r + ln * 0.35) + Vector((0, 0, 0.9)), (ln, 0.12, 1.8), cf, rot=(0, 0, ang))
        if t["stilt"] and S["stilt"]:
            for b in range(4):
                ang = t["bangle"] + b * (math.pi / 2) + 0.3
                d = Vector((math.cos(ang), math.sin(ang), 0))
                a = p + Vector((0, 0, 2.0 + 0.3 * b))
                bb = p + d * (r * 4.0 + 0.6)
                mb.seg(a, bb, r * 0.22, r * 0.3, S["stilt"], cf)
        for i, (c, rr) in enumerate(t["crowns"][:S["crowns"]]):
            if lod == 2:
                rr = rr * 1.12
            sub = S["crown_far"] if t["far"] else S["crown"]
            if sub == 0:
                mb.octa(c, rr, crown_color(c, rr, t["shade"]), rot_z=t["bangle"] + i)
            else:
                mb.blob(c, rr, sub, crown_color(c, rr, t["shade"]), rng=rng, jitter=0.18 if sub > 1 else 0.10,
                        rot_z=t["bangle"] + i)
        if lod < 2:
            for c, rr in t["mid"]:
                mb.blob(c, rr, 1, crown_color(c, rr, t["shade"], -0.1), rng=rng, jitter=0.12)
    return mb.to_object(coll, mats, {"cr_role": "decor_trees", "cr_lod": lod})


def build_snags(L, lod, coll, mats):
    S = LOD_SPEC[lod]
    mb = MB(f"LOOK001_Snags_LOD{lod}", ["M_SELVA_OPAQUE"])
    for s in (L["snags"] if S["snag"] else []):
        p = s["pos"]
        tip = p + Vector((s["tilt"][0] * s["H"], s["tilt"][1] * s["H"], s["H"]))
        mb.seg(p, tip, s["r"], s["r"] * 0.55, S["snag"], trunk_color({"pos": p, "H": s["H"]}, 0.2), cap=True)
    if S["logs"]:
        for g in L["logs"]:
            d = Vector((math.cos(g["yaw"]), math.sin(g["yaw"]), 0.04))
            mb.seg(g["pos"] - d * g["len"] * 0.5, g["pos"] + d * g["len"] * 0.5, g["r"], g["r"] * 0.8, S["logs"],
                   cmix(PAL["wood_dark"], PAL["mud_dark"], 0.3), cap=True)
    return mb.to_object(coll, mats, {"cr_role": "decor_snags_logs", "cr_lod": lod})


def build_canopy(L, lod, coll, mats):
    S = LOD_SPEC[lod]
    rng = random.Random(SEED + 200)
    mb = MB(f"LOOK001_Canopy_LOD{lod}", ["M_SELVA_OPAQUE"])
    for k in L["canopy"]:
        if k["r"].x < S["canopy_min_r"] and not k.get("frame"):
            continue
        if S.get("canopy_skip_far") and k["far"]:
            continue
        rr = k["r"] * (1.15 if lod == 2 else 1.0)
        sub = S["canopy_far"] if k["far"] else S["canopy"]
        cc = crown_color(k["c"], rr, 0.0 if k["near"] else 0.7, -0.15 if k["near"] else 0.0)
        if sub == 0:
            mb.octa(k["c"], rr, cc, rot_z=k["rot"])
        else:
            mb.blob(k["c"], rr, sub, cc, rng=rng, jitter=0.2 if sub > 1 else 0.12, rot_z=k["rot"])
    return mb.to_object(coll, mats, {"cr_role": "decor_canopy", "cr_lod": lod})


def build_understory(L, lod, coll, mats):
    S = LOD_SPEC[lod]
    mb = MB(f"LOOK001_Understory_LOD{lod}", ["M_SELVA_OPAQUE"])
    for pl in L["plants"][:int(round(len(L["plants"]) * S["plants"]))]:
        n = pl["n"] if lod == 0 else max(3, pl["n"] - 2)
        col = cmix(PAL["veg_deep"], PAL["veg_lit"], 0.25 + 0.55 * pl["tone"])
        for i in range(n):
            ang = pl["rot"] + i * 2 * math.pi / n
            d = Vector((math.cos(ang), math.sin(ang), 0.55))
            mb.leaf(pl["pos"] + Vector((0, 0, 0.02)), d, pl["h"] * 1.1, pl["h"] * 0.55, pl["h"] * 0.25,
                    col, fold=(lod == 0))
    if S["hangers"]:
        for hg in L["hangers"]:
            n = hg["n"] if lod == 0 else 3
            for i in range(n):
                ang = hg["rot"] + i * 2 * math.pi / n
                d = Vector((math.cos(ang), math.sin(ang), -0.35))
                mb.leaf(hg["pos"], d, hg["size"] * 1.6, hg["size"] * 0.8, hg["size"] * 0.7,
                        cmix(PAL["veg_near"], PAL["veg_deep"], 0.6), fold=(lod == 0))
    if S["vines"]:
        for v in L["vines"]:
            mid = (v["top"] + v["bottom"]) * 0.5 + v["sway"]
            mb.seg(v["top"], mid, 0.035, 0.03, S["vines"], PAL["vine"])
            mb.seg(mid, v["bottom"], 0.03, 0.025, S["vines"], PAL["vine"])
    return mb.to_object(coll, mats, {"cr_role": "decor_understory", "cr_lod": lod})


def build_bank(lod, coll, mats):
    """Wet mud bank skirt on the front/back edges of the floor (X edges left open for tiling)."""
    mb = MB(f"LOOK001_Bank_LOD{lod}", ["M_SELVA_OPAQUE"])
    rng = random.Random(SEED + 300)
    h = FLOOR_SIZE * 0.5
    n = 9

    def cf(co, f):
        return cmix(PAL["mud"], PAL["mud_dark"], smoothstep(-0.05, -0.5, co.z))
    for side in (-1, 1):
        outer = [rng.uniform(1.1, 2.0) for _ in range(n + 1)]
        for i in range(n):
            x0 = -h + FLOOR_SIZE * i / n
            x1 = -h + FLOOR_SIZE * (i + 1) / n
            y_in = side * h
            p = [(x0, y_in, 0.0), (x1, y_in, 0.0),
                 (x1, y_in + side * outer[i + 1], -0.55), (x0, y_in + side * outer[i], -0.55)]
            if side < 0:
                p = [p[1], p[0], p[3], p[2]]
            mb.quad(p, cf)
    return mb.to_object(coll, mats, {"cr_role": "decor_bank", "cr_lod": lod})


def build_water(lod, coll, mats):
    mb = MB(f"LOOK001_Blackwater_LOD{lod}", ["M_BLACKWATER"])
    z = -0.12
    mb.quad([(-62, -34, z), (62, -34, z), (62, 62, z), (-62, 62, z)], PAL["water"])
    return mb.to_object(coll, mats, {"cr_role": "decor_water_visual_only", "cr_walkable": False, "cr_lod": lod})


def build_backdrop(L, lod, coll, mats):
    S = LOD_SPEC[lod]
    rng = random.Random(SEED + 400)
    mb = MB(f"LOOK001_Backdrop_LOD{lod}", ["M_SELVA_BACKDROP"])
    for b in L["backdrop"]:
        if not S["back_small"] and not b["big"]:
            continue
        if S.get("back_top_only") and b.get("lvl", 1) != 1:
            continue
        c, rr = b["c"], b["r"] * (1.12 if lod == 2 else 1.0)

        def cf(co, f, c=c, rr=rr):
            dz = (co.z - c.z) / max(rr.z, 0.1)
            hgt = smoothstep(4.0, 22.0, co.z)
            return cmix(PAL["backdrop_lo"], PAL["backdrop_hi"], 0.25 + 0.45 * smoothstep(-0.8, 0.9, dz) + 0.3 * hgt)
        if lod == 2:
            mb.octa(c, rr, cf, rot_z=b["rot"])
        else:
            mb.blob(c, rr, 1, cf, rng=rng, jitter=0.15, rot_z=b["rot"])
        if b["trunk"] and S["back_trunks"]:
            mb.seg(Vector((c.x, c.y, -0.5)), Vector((c.x, c.y, c.z - rr.z * 0.5)), 0.7, 0.5, 4,
                   cmix(PAL["backdrop_lo"], PAL["wood_dark"], 0.35))
    return mb.to_object(coll, mats, {"cr_role": "decor_backdrop_unlit", "cr_lod": lod})


def build_totem(lod, coll, mats):
    """Non-figurative wood post + cacao Y/O/R + lianas + gold bands + cyan tip.
    Heights follow totem_warp_cuyabeno.py (tip 2.95, spawn 3.03); NO crown spikes,
    NO faces/eyes/masks, NO stone battlements."""
    S = LOD_SPEC[lod]
    seg = S["totem"]
    P = TOTEM_ANCHOR
    post = MB(f"LOOK001_Totem_Post_LOD{lod}", ["M_SELVA_OPAQUE"])
    warp = MB(f"LOOK001_Totem_Warp_LOD{lod}", ["M_WARP_GOLD", "M_WARP_CYAN"])

    def at(x, y, z):
        return Vector((P.x + x, P.y + y, P.z + z))

    wood, dark = PAL["wood_wet"], PAL["wood_dark"]
    post.seg(at(0, 0, 0), at(0, 0, 0.36), 0.48, 0.29, seg, dark, cap=True)        # root flare
    post.seg(at(0, 0, 0.36), at(0, 0, 1.50), 0.26, 0.23, seg, wood, cap=False)     # lower shaft
    post.cyl(at(0, 0, 1.55), 0.31, 0.31, 0.10, seg, dark)                           # ledge
    post.seg(at(0, 0, 1.60), at(0, 0, 2.50), 0.21, 0.185, seg, wood, cap=False)    # upper shaft
    post.cyl(at(0, 0, 2.55), 0.27, 0.25, 0.10, seg, dark)                           # crown plate
    if lod < 2:
        for i in range(4):  # organic root fins (not stepped / not battlements)
            ang = i * math.pi / 2 + 0.4
            d = Vector((math.cos(ang), math.sin(ang), 0))
            post.box(at(0, 0, 0) + d * 0.5 + Vector((0, 0, 0.12)), (0.55, 0.09, 0.24), dark, rot=(0, 0, ang))
    if S["liana"]:
        for z0, z1, a0, turns in ((0.3, 2.4, 0.3, 1.1), (0.7, 2.2, 2.6, -0.9), (1.2, 2.5, 4.4, 0.6)):
            n = S["liana"]
            prev = None
            for k in range(n + 1):
                t = k / n
                ang = a0 + turns * 2 * math.pi * t
                z = z0 + (z1 - z0) * t
                rad = 0.27 if z < 1.55 else 0.225
                q = at(math.cos(ang) * rad, math.sin(ang) * rad, z)
                if prev is not None:
                    post.seg(prev, q, 0.03, 0.028, 4 if lod == 0 else 3, PAL["vine"])
                prev = q
    Y, O, R = PAL["cacao_y"], PAL["cacao_o"], PAL["cacao_r"]
    crown = [((0.14, 0.04, 2.72), Y, (0.35, 0.2, 0.3)), ((-0.12, 0.09, 2.70), O, (-0.3, 0.25, 1.2)),
             ((0.02, -0.15, 2.69), R, (0.3, -0.35, 2.1)), ((-0.08, -0.08, 2.80), Y, (-0.2, -0.2, 0.7)),
             ((0.07, 0.15, 2.79), O, (0.25, 0.1, 2.8))]
    shaft = [((0.27, 0.06, 2.05), R, (0.15, 0.25, 0.0)), ((-0.25, 0.10, 1.80), Y, (-0.2, -0.15, 0.0)),
             ((0.05, 0.30, 1.25), O, (0.25, 0.0, 0.0)), ((0.18, -0.25, 0.95), R, (-0.15, 0.2, 0.0))]
    for (x, y, z), c, rot in crown + (shaft if lod < 2 else []):
        if lod == 2:
            post.octa(at(x, y, z), (0.09, 0.08, 0.15), c, rot_z=rot[2])
        else:
            post.pod(at(x, y, z), (0.085, 0.08, 0.155), rot, S["pod_u"], S["pod_v"], c)
    if lod < 2:
        for (x, y, z), _c, _r in shaft:  # short stems
            post.seg(at(x * 0.8, y * 0.8, z + 0.12), at(x * 0.95, y * 0.95, z + 0.2), 0.012, 0.012, 3, PAL["vine"])
    warp.cyl(at(0, 0, 0.55), 0.268, 0.268, 0.06, seg, PAL["warp_gold"], slot="M_WARP_GOLD")
    warp.cyl(at(0, 0, 2.20), 0.228, 0.228, 0.05, seg, PAL["warp_gold"], slot="M_WARP_GOLD")
    warp.blob(at(0.01, 0.0, 2.80), (0.055, 0.055, 0.055), 1, PAL["warp_gold"], slot="M_WARP_GOLD")
    warp.cyl(at(0, 0, 2.95), 0.07, 0.0, 0.16, max(4, seg // 2 + 2), PAL["warp_cyan"], slot="M_WARP_CYAN", cap=True)
    o1 = post.to_object(coll, mats, {"cr_role": "decor_totem_post", "cr_lod": lod})
    o2 = warp.to_object(coll, mats, {"cr_role": "decor_totem_warp_emissive", "cr_lod": lod})
    return [o1, o2]


def build_markers(coll):
    out = []
    for name, loc in (("TotemWarpAnchor", TOTEM_ANCHOR),
                      ("VFX_WarpBeam_Spawn", TOTEM_ANCHOR + Vector((0, 0, VFX_SPAWN_Z)))):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.4
        e.location = loc
        coll.objects.link(e)
        e["cr_role"] = "marker"
        out.append(e)
    return out


# --------------------------------------------------------------------------------------
# Look-only: fog, beam preview, Maya stand-in, probes, lights, cameras, world, compositor
# --------------------------------------------------------------------------------------
def build_fog(L, coll, mats):
    objs = []
    for i, f in enumerate(L["fog"]):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        me = bpy.data.meshes.new(f"LOOK001_FogBank_{i:02d}")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mats["LOOKONLY_FogBank"])
        ob = bpy.data.objects.new(f"LOOK001_FogBank_{i:02d}", me)
        ob.location = f["c"]
        ob.scale = f["r"]
        ob.rotation_euler = (0, 0, f["rot"])
        ob.display_type = "WIRE"
        ob.visible_shadow = False
        ob["cr_role"] = "look_only_fog_volume"
        ob["cr_export"] = False
        coll.objects.link(ob)
        objs.append(ob)
    # Bounded aerial haze (look-only): replaces a world volume so canopy openings still show sky.
    hm = bpy.data.materials.get("LOOKONLY_Haze") or bpy.data.materials.new("LOOKONLY_Haze")
    try:
        hm.use_nodes = True
    except Exception:
        pass
    nt = hm.node_tree
    nt.nodes.clear()
    hout = nt.nodes.new("ShaderNodeOutputMaterial")
    hvs = nt.nodes.new("ShaderNodeVolumeScatter")
    hvs.inputs["Color"].default_value = (0.80, 0.84, 0.88, 1.0)
    hvs.inputs["Density"].default_value = WORLD_HAZE_DENSITY
    _set(hvs, "Anisotropy", 0.3)
    nt.links.new(hvs.outputs["Volume"], hout.inputs["Volume"])
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new("LOOK001_AerialHaze")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(hm)
    ob = bpy.data.objects.new("LOOK001_AerialHaze", me)
    x0, x1, y0, y1, z0, z1 = HAZE_BOX
    ob.location = ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
    ob.scale = (x1 - x0, y1 - y0, z1 - z0)
    ob.display_type = "WIRE"
    ob.visible_shadow = False
    ob["cr_role"] = "look_only_aerial_haze"
    ob["cr_export"] = False
    coll.objects.link(ob)
    objs.append(ob)
    return objs


HAZE_BOX = (-62.0, 62.0, -34.0, 60.0, -0.3, 24.0)
BEAM_GEOM = {"gold": (0.07, 0.30, 6.2), "cyan": (0.025, 0.085, 5.0)}


def build_beam_preview(coll, mats):
    base = TOTEM_ANCHOR + Vector((0, 0, VFX_SPAWN_Z - 0.05))
    objs = []
    for name, key, mat, off in (("LOOK001_VFX_BeamGold", "gold", "LOOKONLY_VFX_BeamGold", (0, 0)),
                                ("LOOK001_VFX_BeamCyanCore", "cyan", "LOOKONLY_VFX_BeamCyan", (0.02, -0.02))):
        r1, r2, h = BEAM_GEOM[key]
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=16, radius1=r1, radius2=r2,
                              depth=h, matrix=Matrix.Translation((0, 0, h * 0.5)))
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mats[mat])
        ob = bpy.data.objects.new(name, me)
        ob.location = base + Vector((off[0], off[1], 0))
        ob.visible_shadow = False
        ob["cr_role"] = "look_only_vfx_preview"
        coll.objects.link(ob)
        objs.append(ob)
    return objs


def build_maya_standin(coll, mats):
    """hero_maya_grey.py proportions (~1.9 m) in M_MAYA_GREY #808080. Review only, not exported.
    No face features, no costume colours."""
    mb = MB("LOOK001_Maya_GreyStandIn", ["M_MAYA_GREY"])
    g = PAL["maya"]
    mb.box((0, 0, 1.02), (0.36, 0.22, 0.20), g)
    mb.box((0, 0, 1.36), (0.38, 0.24, 0.46), g)
    mb.box((0, 0, 1.58), (0.44, 0.26, 0.18), g)
    mb.cyl((0, 0, 1.74), 0.075, 0.075, 0.11, 12, g)
    r = bmesh.ops.create_uvsphere(mb.bm, u_segments=16, v_segments=10, radius=0.14,
                                  matrix=Matrix.Translation((0, 0, 1.90)))
    mb._finish(r["verts"], g)
    r = bmesh.ops.create_uvsphere(mb.bm, u_segments=12, v_segments=8, radius=1.0,
                                  matrix=MB._m((0, -0.02, 1.94), (0, 0, 0), (0.157, 0.165, 0.128)))
    mb._finish(r["verts"], g)
    for sx in (1.0, -1.0):
        mb.seg((sx * 0.25, 0, 1.60), (sx * 0.36, 0, 1.24), 0.075, 0.07, 10, g, cap=True)
        mb.seg((sx * 0.38, 0, 1.25), (sx * 0.45, 0, 0.92), 0.065, 0.06, 10, g, cap=True)
        mb.box((sx * 0.46, 0, 0.86), (0.09, 0.07, 0.11), g)
        mb.cyl((sx * 0.13, 0, 0.68), 0.095, 0.095, 0.48, 10, g)
        mb.cyl((sx * 0.13, 0, 0.30), 0.075, 0.075, 0.40, 10, g)
        mb.box((sx * 0.13, 0.07, 0.065), (0.13, 0.24, 0.11), g)
    mb.box((0, -0.20, 1.34), (0.30, 0.13, 0.34), g)
    mb.box((0.19, -0.06, 1.50), (0.045, 0.17, 0.045), g)
    ob = mb.to_object(coll, mats, {"cr_role": "review_maya_standin", "cr_export": False})
    ob.location = MAYA_POS
    ob.rotation_euler = (0, 0, math.radians(MAYA_YAW_DEG))
    return ob


def build_probes(coll):
    objs = []
    try:
        pl = bpy.data.lightprobes.new("LP_Blackwater_Planar", "PLANE")
        ob = bpy.data.objects.new("LOOK001_LP_Blackwater_Planar", pl)
        ob.location = (0.0, 14.0, -0.12)
        ob.scale = (62.0, 48.0, 1.0)
        try:
            pl.influence_distance = 0.3
        except Exception:
            pass
        coll.objects.link(ob)
        objs.append(ob)
    except Exception as e:
        print(f"[WARN] planar probe unavailable: {e}")
    try:
        sp = bpy.data.lightprobes.new("LP_Selva_Sphere", "SPHERE")
        ob = bpy.data.objects.new("LOOK001_LP_Selva_Sphere", sp)
        ob.location = (4.0, 6.0, 3.0)
        try:
            sp.influence_distance = 45.0
        except Exception:
            pass
        coll.objects.link(ob)
        objs.append(ob)
    except Exception as e:
        print(f"[WARN] sphere probe unavailable: {e}")
    return objs


LIGHT_RIG = {
    "key": {"type": "SUN", "color": (1.0, 0.78, 0.56), "strength": 4.2, "angle_deg": 4.0},
    "totem": {"type": "POINT", "color": (1.0, 0.74, 0.40), "power_active": 90.0, "power_dim": 6.0,
              "radius": 0.30, "loc": (TOTEM_ANCHOR.x, TOTEM_ANCHOR.y, 3.15)},
    "fill_world": {"strength": 0.6},
    # Soft lateral dawn key under the canopy (light entering from the open lagoon side, +X/-Y)
    "key_soft": {"type": "AREA", "color": (1.0, 0.80, 0.58), "power": 3600.0, "size": 14.0,
                 "loc": (22.0, -4.0, 6.0), "aim": (4.0, 2.0, 1.5), "volume_factor": 0.4, "specular_factor": 0.0},
    # Cool humid fill from the opposite side (no specular so the blackwater only mirrors canopy/sky)
    "fill_soft": {"type": "AREA", "color": (0.62, 0.80, 0.84), "power": 1200.0, "size": 16.0,
                  "loc": (-8.0, -6.0, 8.5), "aim": (4.0, 6.0, 0.0), "volume_factor": 0.15, "specular_factor": 0.0},
}


def build_lights(coll):
    objs = {}
    k = LIGHT_RIG["key"]
    ld = bpy.data.lights.new("KEY_SunDawn_Filtered", "SUN")
    ld.color = k["color"]
    ld.energy = k["strength"]
    ld.angle = math.radians(k["angle_deg"])
    ld.use_shadow = True
    ob = bpy.data.objects.new("LOOK001_KEY_SunDawn_Filtered", ld)
    d = sun_dir()
    ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    ob.location = TOTEM_ANCHOR + d * 30.0
    coll.objects.link(ob)
    objs["key"] = ob
    t = LIGHT_RIG["totem"]
    lt = bpy.data.lights.new("TOTEM_Local_Gold", "POINT")
    lt.color = t["color"]
    lt.energy = t["power_active"]
    lt.shadow_soft_size = t["radius"]
    lt.use_shadow = True
    ob = bpy.data.objects.new("LOOK001_TOTEM_Local_Gold", lt)
    ob.location = t["loc"]
    coll.objects.link(ob)
    objs["totem"] = ob
    for key, oname in (("key_soft", "LOOK001_KEY_Soft_Lateral"), ("fill_soft", "LOOK001_FILL_Cool")):
        a = LIGHT_RIG[key]
        la = bpy.data.lights.new(oname, "AREA")
        la.shape = "SQUARE"
        la.size = a["size"]
        la.energy = a["power"]
        la.color = a["color"]
        la.use_shadow = True
        for attr in ("volume_factor", "specular_factor"):
            if hasattr(la, attr):
                setattr(la, attr, a[attr])
        ob = bpy.data.objects.new(oname, la)
        ob.location = a["loc"]
        ob.rotation_euler = (Vector(a["aim"]) - Vector(a["loc"])).to_track_quat("-Z", "Y").to_euler()
        coll.objects.link(ob)
        objs[key] = ob
    return objs


SKY_CAMERA_FACTOR = 0.7
SKY = {"horizon": (0.20, 0.25, 0.22), "zenith": (0.27, 0.34, 0.33), "dawn": (0.92, 0.66, 0.42), "dawn_mix": 0.6}


def setup_world():
    w = bpy.data.worlds.get("W_SELVA_LOOK001") or bpy.data.worlds.new("W_SELVA_LOOK001")
    bpy.context.scene.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (*SKY["horizon"], 1.0)
    cr.elements[1].position = 0.6
    cr.elements[1].color = (*SKY["zenith"], 1.0)
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    sd = sun_dir()
    dot.inputs[1].default_value = (sd.x, sd.y, 0.0)
    band = nt.nodes.new("ShaderNodeMapRange")
    band.interpolation_type = "SMOOTHSTEP"
    band.inputs["From Min"].default_value = 0.2
    band.inputs["From Max"].default_value = 0.95
    low = nt.nodes.new("ShaderNodeMapRange")
    low.interpolation_type = "SMOOTHSTEP"
    low.inputs["From Min"].default_value = 0.45
    low.inputs["From Max"].default_value = 0.0
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = "MULTIPLY"
    m2 = nt.nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    m2.inputs[1].default_value = SKY["dawn_mix"]
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    mix.inputs[7].default_value = (*SKY["dawn"], 1.0)
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(tc.outputs["Generated"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], band.inputs["Value"])
    nt.links.new(sep.outputs["Z"], low.inputs["Value"])
    nt.links.new(band.outputs["Result"], m.inputs[0])
    nt.links.new(low.outputs["Result"], m.inputs[1])
    nt.links.new(m.outputs["Value"], m2.inputs[0])
    nt.links.new(m2.outputs["Value"], mix.inputs[0])
    nt.links.new(ramp.outputs["Color"], mix.inputs[6])
    nt.links.new(mix.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = LIGHT_RIG["fill_world"]["strength"]
    # Camera-visible sky slightly darker than the sky used for lighting (openings stay readable
    # without turning the frame into an overcast grey sky).
    lp = nt.nodes.new("ShaderNodeLightPath")
    cam_k = nt.nodes.new("ShaderNodeMath")
    cam_k.operation = "MULTIPLY_ADD"
    cam_k.inputs[1].default_value = -(1.0 - SKY_CAMERA_FACTOR)
    cam_k.inputs[2].default_value = 1.0
    cam_s = nt.nodes.new("ShaderNodeMath")
    cam_s.operation = "MULTIPLY"
    cam_s.inputs[1].default_value = LIGHT_RIG["fill_world"]["strength"]
    nt.links.new(lp.outputs["Is Camera Ray"], cam_k.inputs[0])
    nt.links.new(cam_k.outputs["Value"], cam_s.inputs[0])
    nt.links.new(cam_s.outputs["Value"], bg.inputs["Strength"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    vs = nt.nodes.new("ShaderNodeVolumeScatter")
    vs.inputs["Color"].default_value = (0.80, 0.84, 0.88, 1.0)
    vs.inputs["Density"].default_value = WORLD_HAZE_DENSITY
    _set(vs, "Anisotropy", 0.3)
    # Blender 5 EEVEE treats a world volume as infinite and it swallows the sky background,
    # so the aerial haze lives in a bounded look-only box (LOOK001_ATMOS) instead.
    nt.nodes.remove(vs)
    return w


CAMERAS = {
    "Cam_Laguna": {"pos": CAM_LAGUNA_POS, "aim": Vector((6.2, -0.5, 2.55)), "lens": 22.0},
    "Cam_Dosel": {"pos": CAM_DOSEL_POS, "aim": Vector((0.2, 4.2, 6.6)), "lens": 16.0},
    # Reference only (not rendered): pilot_cuyabeno.tscn Camera3D child of PlayerMaya @ x=0.
    "Cam_Gameplay_Ref": {"pos": Vector((0.0, -6.5, 4.4)), "aim": Vector((0.0, 8.5, -1.9)), "lens": 38.6},
}


def build_cameras(coll):
    objs = {}
    for name, c in CAMERAS.items():
        cd = bpy.data.cameras.new(name)
        cd.lens = c["lens"]
        cd.sensor_fit = "HORIZONTAL"
        cd.sensor_width = 36.0
        cd.clip_start = 0.1
        cd.clip_end = 250.0
        cd.dof.use_dof = False
        ob = bpy.data.objects.new(name, cd)
        ob.location = c["pos"]
        ob.rotation_euler = (c["aim"] - c["pos"]).to_track_quat("-Z", "Y").to_euler()
        coll.objects.link(ob)
        objs[name] = ob
    return objs


GLARE = {"type": "Fog Glow", "quality": "High", "threshold": 1.6, "smoothness": 0.3,
         "strength": 0.22, "size": 0.45, "saturation": 0.9}
GRADE = {"lift": (1.0, 1.0, 1.0, 1.0), "gamma": (1.0, 1.0, 1.0, 1.0), "gain": (1.03, 1.0, 0.96, 1.0)}  # Blender 5: lift colour stays neutral (1,1,1) with Base Lift 0


def setup_compositor(scene):
    """Blender 5: CompositorNodeTree + scene.compositing_node_group + NodeGroupOutput."""
    name = "COMP_SELVA_LOOK001"
    tree = bpy.data.node_groups.get(name) or bpy.data.node_groups.new(name, "CompositorNodeTree")
    tree.nodes.clear()
    for it in list(tree.interface.items_tree):
        tree.interface.remove(it)
    tree.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    scene.compositing_node_group = tree
    if hasattr(scene.render, "use_compositing"):
        scene.render.use_compositing = True
    rl = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    for key, vals in (("Type", (GLARE["type"], "FOG_GLOW")), ("Quality", (GLARE["quality"], "HIGH"))):
        for v in vals:
            try:
                glare.inputs[key].default_value = v
                break
            except Exception:
                continue
    _set(glare, "Threshold", GLARE["threshold"])
    _set(glare, "Smoothness", GLARE["smoothness"])
    _set(glare, "Strength", GLARE["strength"])
    _set(glare, "Size", GLARE["size"])       # Blender 5: 0–1
    _set(glare, "Saturation", GLARE["saturation"])
    bal = tree.nodes.new("CompositorNodeColorBalance")
    for ident, key in (("Color Lift", "lift"), ("Color Gamma", "gamma"), ("Color Gain", "gain")):
        for s in bal.inputs:
            if s.identifier == ident:
                s.default_value = GRADE[key]
    out = tree.nodes.new("NodeGroupOutput")
    tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], bal.inputs["Image"])
    tree.links.new(bal.outputs["Image"], out.inputs[0])
    return {"tree": name, "glare": GLARE, "color_balance": {k: list(v[:3]) for k, v in GRADE.items()},
            "glare_type_set": str(glare.inputs["Type"].default_value)}


VIEW = {"view_transform": "AgX", "look": "None", "exposure": 0.75, "gamma": 1.0}


def setup_render(scene, args):
    w, h = (int(v) for v in args.res.lower().split("x"))
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    notes = []
    ee.taa_render_samples = args.samples
    if hasattr(ee, "use_raytracing"):
        ee.use_raytracing = True
        ee.ray_tracing_method = "SCREEN"
        rt = ee.ray_tracing_options
        rt.resolution_scale = "1"
        rt.screen_trace_quality = 0.9
        rt.screen_trace_thickness = 0.4
        rt.trace_max_roughness = 0.5
        notes.append("EEVEE raytracing ON, method SCREEN (+ planar probe on water for off-screen canopy)")
    else:
        notes.append("EEVEE raytracing NOT available in this build")
    for attr, val in (("use_shadows", True), ("shadow_pool_size", "1024"), ("shadow_ray_count", 2),
                      ("shadow_step_count", 8), ("use_volumetric_shadows", True),
                      ("volumetric_tile_size", "4"), ("volumetric_samples", 64),
                      ("volumetric_sample_distribution", 0.85), ("volumetric_start", 0.2),
                      ("volumetric_end", 110.0), ("volumetric_shadow_samples", 16),
                      ("volumetric_light_clamp", 0.0), ("use_fast_gi", True)):
        if hasattr(ee, attr):
            try:
                setattr(ee, attr, val)
            except Exception as e:
                notes.append(f"could not set eevee.{attr}: {e}")
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = args.percent
    scene.render.use_motion_blur = False
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = VIEW["view_transform"]
    try:
        scene.view_settings.look = VIEW["look"]
    except Exception:
        pass
    scene.view_settings.exposure = VIEW["exposure"]
    scene.view_settings.gamma = VIEW["gamma"]
    return notes


def set_totem_state(state, mats, lights, beam_objs):
    for mname, val in WARP_STRENGTH[state].items():
        b = next(n for n in mats[mname].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Emission Strength"].default_value = val
    lights["totem"].data.energy = LIGHT_RIG["totem"]["power_active" if state == "active" else "power_dim"]
    for o in beam_objs:
        o.hide_render = state != "active"
        o.hide_viewport = state != "active"


# --------------------------------------------------------------------------------------
# Measurements, export, validation
# --------------------------------------------------------------------------------------
def tris_of(obj):
    if obj is None or obj.type != "MESH":
        return 0
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def ensure_triangulated(objs):
    for o in objs:
        if o.type != "MESH":
            continue
        if any(len(p.vertices) != 3 for p in o.data.polygons):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
            bm.to_mesh(o.data)
            bm.free()


def canopy_coverage(cam, objs, scene, nx=96, ny=54):
    """% of rays in the upper part of the frame that hit geometry (sky cover)."""
    bpy.context.view_layer.update()   # camera matrix_world must be current
    verts, polys = [], []
    for o in objs:
        if o is None or o.type != "MESH":
            continue
        mw = o.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    tr, br, bl, tl = [Vector(v) for v in cam.data.view_frame(scene=scene)]
    mw = cam.matrix_world
    origin = mw.translation
    rot = mw.to_3x3()
    hits = {"top_half": [0, 0], "top_third": [0, 0]}
    for j in range(ny):
        v = (j + 0.5) / ny
        if v < 0.5:
            continue
        for i in range(nx):
            u = (i + 0.5) / nx
            p = bl.lerp(br, u).lerp(tl.lerp(tr, u), v)
            hit = bvh.ray_cast(origin, (rot @ p).normalized(), 600.0)[0] is not None
            hits["top_half"][0] += hit
            hits["top_half"][1] += 1
            if v >= 2.0 / 3.0:
                hits["top_third"][0] += hit
                hits["top_third"][1] += 1
    return {k: round(100.0 * a / max(1, b), 1) for k, (a, b) in hits.items()}


def set_lod_layer(view_layer, lod_visible):
    for i in range(3):
        lc = find_layer_collection(view_layer.layer_collection, f"LOOK001_DECOR_LOD{i}")
        lc.exclude = (lod_visible is not None and i != lod_visible)
    view_layer.update()


def export_lod(lod, path, export_objs, view_layer):
    set_lod_layer(view_layer, lod)
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in export_objs if o.type == "MESH"]
    for o in meshes:
        o.hide_set(False)
        o.select_set(True)
    view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in export_objs:
        o.hide_set(False)
        o.select_set(True)
    op_props = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    kw = dict(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
              export_yup=True, export_cameras=False, export_lights=False, export_extras=True,
              export_materials="EXPORT", export_vertex_color="MATERIAL", export_animations=False,
              export_texcoords=True, export_normals=True)
    kw = {k: v for k, v in kw.items() if k == "filepath" or k in op_props}
    bpy.ops.export_scene.gltf(**kw)
    bpy.ops.object.select_all(action="DESELECT")
    return kw


def inspect_glb(path):
    d = Path(path).read_bytes()
    magic, ver, length = struct.unpack("<4sII", d[:12])
    if not (magic == b"glTF" and ver == 2 and length == len(d)):
        raise RuntimeError(f"bad GLB header in {path}")
    jl, jt = struct.unpack("<I4s", d[12:20])
    if jt != b"JSON":
        raise RuntimeError(f"missing JSON chunk in {path}")
    j = json.loads(d[20:20 + jl])
    tris = 0
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            if pr.get("mode", 4) != 4:
                continue
            acc = pr["indices"] if "indices" in pr else pr["attributes"]["POSITION"]
            tris += j["accessors"][acc]["count"] // 3
    # bounds of all POSITION accessors in glTF space (Y-up)
    mn, mx = [1e9] * 3, [-1e9] * 3
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            a = j["accessors"][pr["attributes"]["POSITION"]]
            for k in range(3):
                mn[k] = min(mn[k], a["min"][k])
                mx[k] = max(mx[k], a["max"][k])
    nodes = [n.get("name") for n in j.get("nodes", [])]
    return {"valid_glb_v2": True, "asset_version": j.get("asset", {}).get("version"),
            "generator": j.get("asset", {}).get("generator"), "tris": tris,
            "meshes": len(j.get("meshes", [])), "nodes": nodes,
            "materials": [m.get("name") for m in j.get("materials", [])],
            "extensionsUsed": j.get("extensionsUsed", []),
            "bounds_gltf_yup_min": [round(v, 3) for v in mn], "bounds_gltf_yup_max": [round(v, 3) for v in mx],
            "has_cameras": bool(j.get("cameras")),
            "has_lights": "KHR_lights_punctual" in j.get("extensionsUsed", [])}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def bl2gd(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def cam_info(name):
    c = CAMERAS[name]
    lens = c["lens"]
    hfov = 2 * math.degrees(math.atan(18.0 / lens))
    vfov = 2 * math.degrees(math.atan(math.tan(math.radians(hfov / 2)) * 9.0 / 16.0))
    return {"blender_location": [round(x, 3) for x in c["pos"]], "blender_aim": [round(x, 3) for x in c["aim"]],
            "lens_mm": lens, "sensor_width_mm": 36.0, "hfov_deg": round(hfov, 2), "vfov_deg_16x9": round(vfov, 2),
            "godot_position": bl2gd(c["pos"]), "godot_look_at": bl2gd(c["aim"]),
            "godot_fov_keep_height": round(vfov, 2), "dof": False, "motion_blur": False}


# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------
DELIVERABLES = ["world_selva_look001.py", "selva_look001.blend", "selva_look001_LOD0.glb",
                "selva_look001_LOD1.glb", "selva_look001_LOD2.glb", "LOOK-001_laguna.png",
                "LOOK-001_dosel.png", "LOOK-001_manifest.json"]


def main():
    t0 = time.time()
    args = parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    warnings = []

    bv, bv_str = bpy.app.version, bpy.app.version_string
    if tuple(bv[:3]) != REQUIRED_BLENDER:
        msg = f"Blender {bv_str} != required 5.2.1 — results may differ"
        print("[WARN]", msg)
        warnings.append(msg)

    scene, fresh, removed = prepare_scene()
    print(f"[INFO] {LOOK_ID} {DISPLAY_NAME} (id {WORLD_ID}) Blender {bv_str} fresh={fresh} removed_look_objs={removed}")
    mats = make_materials()

    gp = bpy.data.collections.get(GAMEPLAY_COLL)
    if gp is not None and len(gp.all_objects) > 0:
        gp_objs = list(gp.all_objects)
        gp_status = "kept_existing (intact)"
    else:
        if gp is None:
            gp = new_coll(GAMEPLAY_COLL)
        gp_objs = build_gameplay(gp, mats)
        gp_status = "built_from_greybox_patterns@" + GREYBOX_REF

    c_markers = new_coll("LOOK001_MARKERS")
    c_decor = new_coll("LOOK001_DECOR")
    c_lods = [new_coll(f"LOOK001_DECOR_LOD{i}", c_decor) for i in range(3)]
    c_atmos = new_coll("LOOK001_ATMOS")
    c_vfx = new_coll("LOOK001_VFX_PREVIEW")
    c_lights = new_coll("LOOK001_LIGHTS")
    c_cams = new_coll("LOOK001_CAMERAS")
    c_help = new_coll("LOOK001_REVIEW_HELPERS")

    layout = gen_layout(random.Random(SEED))
    markers = build_markers(c_markers)
    lod_objs = {}
    for lod in range(3):
        objs = [build_water(lod, c_lods[lod], mats), build_bank(lod, c_lods[lod], mats)]
        objs += build_totem(lod, c_lods[lod], mats)
        objs += [build_trees(layout, lod, c_lods[lod], mats), build_snags(layout, lod, c_lods[lod], mats),
                 build_canopy(layout, lod, c_lods[lod], mats), build_understory(layout, lod, c_lods[lod], mats),
                 build_backdrop(layout, lod, c_lods[lod], mats)]
        lod_objs[lod] = [o for o in objs if o is not None]
        c_lods[lod].hide_render = lod != 0

    fog_objs = build_fog(layout, c_atmos, mats)
    beam_objs = build_beam_preview(c_vfx, mats)
    maya = build_maya_standin(c_help, mats)
    probes = build_probes(c_help)
    lights = build_lights(c_lights)
    cams = build_cameras(c_cams)
    setup_world()
    comp = setup_compositor(scene)
    render_notes = setup_render(scene, args)
    scene.camera = cams["Cam_Laguna"]
    for k, v in (("world_id", WORLD_ID), ("display_name", DISPLAY_NAME), ("look_id", LOOK_ID),
                 ("seed", SEED), ("ref_2d_tip", REF_2D_TIP), ("high_poly", "HOLD")):
        scene[k] = v

    ensure_triangulated(gp_objs + [o for lst in lod_objs.values() for o in lst])
    gp_tris = {o.name: tris_of(o) for o in gp_objs}
    gp_total = sum(gp_tris.values())
    breakdown = {lod: {o.name: tris_of(o) for o in lod_objs[lod]} for lod in range(3)}
    tris = {lod: gp_total + sum(breakdown[lod].values()) for lod in range(3)}
    print(f"[TRIS] gameplay={gp_total} LOD0={tris[0]} LOD1={tris[1]} LOD2={tris[2]}")
    for lod in range(3):
        print(f"[TRIS] LOD{lod} breakdown {breakdown[lod]}")
    if tris[0] > BUDGET_CONTRACT_LOD0:
        print(f"[FAIL] LOD0 {tris[0]} tris > contractual ceiling {BUDGET_CONTRACT_LOD0}")
        sys.exit(3)
    for lod in range(3):
        if tris[lod] > BUDGET_SUGGESTED[lod]:
            w = (f"LOD{lod} {tris[lod]} tris above suggested {BUDGET_SUGGESTED[lod]} "
                 f"(includes constant gameplay base {gp_total})")
            print("[WARN]", w)
            warnings.append(w)

    cov = {c: canopy_coverage(cams[c], gp_objs + lod_objs[0], scene) for c in ("Cam_Laguna", "Cam_Dosel")}
    print(f"[COVER] {cov}")

    glb_info = {}
    view_layer = bpy.context.view_layer
    if not args.no_export:
        for lod in range(3):
            path = out / f"selva_look001_LOD{lod}.glb"
            kw = export_lod(lod, path, gp_objs + markers + lod_objs[lod], view_layer)
            info = inspect_glb(path)
            leak = [n for n in info["nodes"] if n and ("Fog" in n or "VFX_Beam" in n or n.startswith("Cam_")
                                                        or "Maya" in n or "_LP_" in n or "KEY_" in n)]
            if leak:
                raise RuntimeError(f"look-only objects leaked into {path.name}: {leak}")
            other = [n for n in info["nodes"] if n and any(f"_LOD{k}" in n for k in range(3) if k != lod)]
            if other:
                raise RuntimeError(f"other LOD objects leaked into {path.name}: {other}")
            if info["has_cameras"] or info["has_lights"]:
                raise RuntimeError(f"cameras/lights leaked into {path.name}")
            info["export_kwargs"] = {k: v for k, v in kw.items() if k != "filepath"}
            glb_info[lod] = info
            print(f"[GLB] {path.name} tris={info['tris']} nodes={info['nodes']}")
            if info["tris"] != tris[lod]:
                warnings.append(f"GLB LOD{lod} tri count {info['tris']} != scene count {tris[lod]}")
        set_lod_layer(view_layer, None)
        for i in range(3):
            c_lods[i].hide_render = i != 0
            for o in lod_objs[i]:
                o.hide_set(i != 0)

    stills = {}
    if not args.no_render:
        for shot, cam, state in (("laguna", "Cam_Laguna", "active"), ("dosel", "Cam_Dosel", "dim")):
            if args.only and args.only != shot:
                continue
            set_totem_state(state, mats, lights, beam_objs)
            scene.camera = cams[cam]
            path = out / f"LOOK-001_{shot}.png"
            scene.render.filepath = str(path)
            ts = time.time()
            bpy.ops.render.render(write_still=True)
            stills[shot] = {"file": path.name, "camera": cam, "totem_state": state,
                            "warp_emission": WARP_STRENGTH[state],
                            "totem_light_w": LIGHT_RIG["totem"]["power_active" if state == "active" else "power_dim"],
                            "beam_preview_visible": state == "active",
                            "resolution": [scene.render.resolution_x * args.percent // 100,
                                           scene.render.resolution_y * args.percent // 100],
                            "render_seconds": round(time.time() - ts, 1)}
            print(f"[RENDER] {path.name} {stills[shot]['render_seconds']}s")
        set_totem_state("active", mats, lights, beam_objs)
        scene.camera = cams["Cam_Laguna"]

    blend_path = out / "selva_look001.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
    print(f"[OK] saved {blend_path}")
    try:
        me = Path(__file__).resolve()
        if me.parent != out:
            shutil.copy2(me, out / SCRIPT_ID)
    except Exception:
        pass

    ctx = dict(out=out, bv=bv, bv_str=bv_str, scene=scene, args=args, gp_status=gp_status, gp_objs=gp_objs,
               gp_tris=gp_tris, markers=markers, lod_objs=lod_objs, fog_objs=fog_objs, beam_objs=beam_objs,
               lights=lights, cams=cams, maya=maya, probes=probes, tris=tris, breakdown=breakdown,
               glb_info=glb_info, stills=stills, comp=comp, render_notes=render_notes, cov=cov,
               warnings=warnings, t0=t0, layout=layout)
    manifest = build_manifest(ctx)
    (out / "LOOK-001_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    lines = [f"{sha256(out / n)}  {n}" for n in DELIVERABLES if (out / n).exists()]
    (out / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n")
    print("[SHA256SUMS]\n" + "\n".join(lines))
    print(f"[DONE] {LOOK_ID} {DISPLAY_NAME} tris LOD0={tris[0]} LOD1={tris[1]} LOD2={tris[2]} "
          f"in {time.time() - t0:.1f}s")


def build_manifest(c):
    out, scene, args = c["out"], c["scene"], c["args"]
    tris, glb_info = c["tris"], c["glb_info"]
    sd = sun_dir()
    travel = bl2gd(-sd)
    yaw = math.degrees(math.atan2(-travel[0], -travel[2]))
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, travel[1]))))
    files = {}
    for fn in DELIVERABLES[:-1]:
        p = out / fn
        if p.exists():
            files[fn] = {"sha256": sha256(p), "bytes": p.stat().st_size}
    bh = bpy.app.build_hash
    return {
        "look_id": LOOK_ID, "world": "WORLD-001", "world_id": WORLD_ID, "display_name": DISPLAY_NAME,
        "generated_by": SCRIPT_ID, "generated_local_time": time.strftime("%Y-%m-%d %H:%M:%S %z"),
        "blender": {"version_string": c["bv_str"], "version": list(c["bv"][:3]), "required": "5.2.1 LTS",
                    "binary": "/usr/local/bin/blender -> /opt/blender-5.2.1-linux-x64/blender",
                    "build_hash": bh.decode() if isinstance(bh, bytes) else str(bh), "engine": scene.render.engine},
        "refs": {
            "ref_2d_tip": REF_2D_TIP, "ref_2d_tip_full": REF_2D_TIP_FULL,
            "ref_2d_repo": "NadiaCoelloO/sand-vivid-dawn-sail (read only)",
            "greybox_bpy_patterns": {"repo": GREYBOX_REPO, "ref": GREYBOX_REF, "path": "assets/scripts/bpy/",
                                     "files": ["_common.py", "chunk_selva_floor.py", "chunk_selva_platform_solid.py",
                                               "chunk_selva_oneway.py", "totem_warp_cuyabeno.py", "hero_maya_grey.py"],
                                     "fetched_via": "raw.githubusercontent.com (no clone)"},
            "pilot_layout": f"runtime/scenes/pilot_cuyabeno.tscn@{GREYBOX_REF}",
            "paint_v03_identity_lock": PAINT_V03,
            "brief": "/home/box/workspace/world-001/BRIEF_CUYABENO_LOOK001.md (== ASTRA_WORLD001_REPLY.md section B)",
            "reference_paint_scripts_read_only": [
                "/home/box/workspace/cine/CIN-001/render_cin001_warp_sting_paint_v03.py",
                "/home/box/workspace/cine/CIN-003/render_cin003_intro_cuyabeno_paint_v03.py"],
        },
        "units": {"scale": "1u = 1m", "blender_up": "+Z",
                  "gltf_up": "+Y via exporter export_yup=True (no manual rotation of the set)",
                  "axis_conversion_godot": "Godot(x, y, z) = Blender(x, z, -y)",
                  "gameplay_axis": "Blender X at y=0 == Godot X at z=0"},
        "seed": SEED, "high_poly": "HOLD",
        "timings_untouched": {"coyote": 0.10, "buffer": 0.12, "cut": 0.48, "note": "LOOK-001 does not modify simulation"},
        "collections": {
            GAMEPLAY_COLL: {"status": c["gp_status"], "exported": "every LOD (identical)", "objects": list(c["gp_tris"].keys())},
            "LOOK001_MARKERS": {"exported": "every LOD", "objects": [m.name for m in c["markers"]]},
            "LOOK001_DECOR_LOD0/1/2": {"exported": "only in its own GLB",
                                       "objects": {f"LOD{l}": [o.name for o in c["lod_objs"][l]] for l in range(3)}},
            "LOOK001_ATMOS": {"exported": False, "objects": [o.name for o in c["fog_objs"]]},
            "LOOK001_VFX_PREVIEW": {"exported": False, "objects": [o.name for o in c["beam_objs"]]},
            "LOOK001_LIGHTS": {"exported": False, "objects": [o.name for o in c["lights"].values()]},
            "LOOK001_CAMERAS": {"exported": False, "objects": list(c["cams"].keys())},
            "LOOK001_REVIEW_HELPERS": {"exported": False, "objects": [c["maya"].name] + [p.name for p in c["probes"]]},
        },
        "layout_notes": [
            "Floor chunk (18x18 m slab, Platforms A/B/C, root stubs, hojarasca, rocks) rebuilt with the exact positions/sizes of chunk_selva_floor.py@f9a879d.",
            "Solid module (3x2x1 m, bevel 0.06/2 + top plate) placed at Blender (6,0,0) = pilot CSGPlatform (Godot x=6, top y=1.0).",
            "Oneway module (4x2x0.18 m + underside cue) placed at Blender (1.0,0,1.8): REVIEW PLACEMENT — pilot_cuyabeno.tscn has no oneway; verify against the selva layout in levels.ts (tip 5fd45031) before shipping. No other new surfaces/routes.",
            "Totem at TotemWarpAnchor Blender (7.5,0,0); VFX_WarpBeam_Spawn at z=3.03 (matches pilot Marker3D). If the LOOK GLB is used, do not also instance totem_warp_cuyabeno.glb.",
            f"Decor keep-out: corridor |y| < {CORRIDOR_HALF_DEPTH} m for x in [-12.5,12.5] below z {JUMP_CLEAR_Z} m, platform footprints + 0.6 m, root stubs, totem. Trees only behind the corridor (y >= 10) or behind the gameplay camera (y <= -10.5). Front floor plants <= 0.75 m.",
            "Blackwater plane at z=-0.12 is visual only (cr_walkable=false, no collision); it does not change swim/damage/fall zones.",
            "Bank skirt only on front/back floor edges; X edges left open for chunk tiling. Chunk visual width 18 m vs pilot CSGFloor 24 m — verify in Godot.",
            "No collision meshes exported: gameplay collisions stay as in the existing port. Maya is a review stand-in only (not in GLB).",
        ],
        "tris": {
            "contract_ceiling_lod0": BUDGET_CONTRACT_LOD0, "suggested": {f"LOD{k}": v for k, v in BUDGET_SUGGESTED.items()},
            "per_lod": {f"LOD{l}": tris[l] for l in range(3)},
            "per_lod_glb_parsed": {f"LOD{l}": glb_info[l]["tris"] for l in glb_info},
            "gameplay_base_constant": sum(c["gp_tris"].values()), "gameplay_breakdown": c["gp_tris"],
            "decor_breakdown": {f"LOD{l}": c["breakdown"][l] for l in range(3)},
            "note": "Gameplay surfaces are identical in all LODs (brief §8); LOD totals include them.",
        },
        "draw_calls_estimate": {f"LOD{l}": sum(len(o.data.materials) for o in c["gp_objs"] + c["lod_objs"][l]) for l in range(3)},
        "glb": {f"selva_look001_LOD{l}.glb": glb_info[l] for l in glb_info},
        "materials": {
            "M_SELVA_OPAQUE": {"type": "lit Principled; base colour = vertex colour COLOR_0 ('Col')", "roughness": 0.78,
                               "metallic": 0.0, "godot": "StandardMaterial3D, vertex_color_use_as_albedo=true, roughness 0.78"},
            "M_SELVA_BACKDROP": {"type": "unlit (Background shader -> KHR_materials_unlit); colour = COLOR_0",
                                 "godot": "StandardMaterial3D shading_mode=UNSHADED, vertex_color_use_as_albedo=true (fog still applies)"},
            "M_BLACKWATER": {"type": "Principled", "base_srgb": PAL_HEX["water"], "metallic": 0.0, "roughness": WATER_ROUGHNESS,
                             "ior": 1.333, "ripples": f"broad noise bump (scales 0.22 + 0.9, strength {WATER_BUMP}) — Blender only, not in GLB",
                             "transparency_or_refraction": False},
            "M_MAYA_GREY": {"type": "Principled", "base_srgb": PAL_HEX["maya"], "roughness": 0.72,
                            "note": "review stand-in only; not in chunk GLB (hero_grey.glb stays the hero asset)"},
            "M_WARP_GOLD": {"type": "Principled + emission", "srgb": PAL_HEX["warp_gold"], "emission_strength": WARP_STRENGTH,
                            "exported_state": "active"},
            "M_WARP_CYAN": {"type": "Principled + emission", "srgb": PAL_HEX["warp_cyan"], "emission_strength": WARP_STRENGTH,
                            "exported_state": "active", "note": "restricted to the totem tip (secondary accent)"},
            "look_only_not_exported": ["LOOKONLY_VFX_BeamGold", "LOOKONLY_VFX_BeamCyan", "LOOKONLY_FogBank", "LOOKONLY_Haze"],
        },
        "palette_srgb": PAL_HEX,
        "lights": {
            "key": {"name": "LOOK001_KEY_SunDawn_Filtered", "type": "SUN", "color_linear": LIGHT_RIG["key"]["color"],
                    "strength_w_m2": LIGHT_RIG["key"]["strength"], "angle_deg": LIGHT_RIG["key"]["angle_deg"],
                    "azimuth_deg": SUN_AZ_DEG, "azimuth_convention": "from +X toward +Y (negative = toward -Y)",
                    "elevation_deg": SUN_EL_DEG, "direction_to_sun_blender": [round(x, 4) for x in sd],
                    "canopy_light_zones": [{"name": n, "blender_target": list(p), "gap_radius_m": r} for n, p, r in LIGHT_ZONES],
                    "godot": {"node": "DirectionalLight3D", "rotation_degrees": [round(pitch, 2), round(yaw, 2), 0.0],
                              "light_color": list(LIGHT_RIG["key"]["color"]), "light_energy_start": 1.6,
                              "shadow_enabled": True, "shadow_blur": 1.5, "volumetric_fog_energy": 1.0}},
            "key_soft_lateral": {"name": "LOOK001_KEY_Soft_Lateral", **{k: v for k, v in LIGHT_RIG["key_soft"].items()},
                                 "role": "soft lateral dawn key under the canopy (sun above only makes the shafts/spots)",
                                 "godot": {"node": "SpotLight3D or large OmniLight3D at lagoon edge (+X,-Z)", "light_color": "#FFCC94",
                                           "light_energy_start": 1.2, "light_specular": 0.0, "light_volumetric_fog_energy": 0.4,
                                           "alt": "bake into LightmapGI if static"}},
            "fill_soft_cool": {"name": "LOOK001_FILL_Cool", **{k: v for k, v in LIGHT_RIG["fill_soft"].items()},
                               "godot": {"node": "DirectionalLight3D (no shadow) or OmniLight3D, cool #9EE6EC-ish, energy ~0.35, specular 0"}},
            "fill": {"type": "world ambient (cool humid sky gradient)", "world_strength": LIGHT_RIG["fill_world"]["strength"],
                     "sky_linear": SKY, "target_key_to_fill": "~3:1",
                     "godot": {"ambient_light_source": "Sky", "ambient_light_color": "#6F8C8A", "ambient_light_energy": 0.45}},
            "totem_local": {"name": "LOOK001_TOTEM_Local_Gold", "type": "POINT", "color_linear": LIGHT_RIG["totem"]["color"],
                            "power_w_active": LIGHT_RIG["totem"]["power_active"], "power_w_dim": LIGHT_RIG["totem"]["power_dim"],
                            "radius_m": LIGHT_RIG["totem"]["radius"], "blender_location": list(LIGHT_RIG["totem"]["loc"]),
                            "godot": {"node": "OmniLight3D child of TotemWarpAnchor", "position_local": [0.0, 3.15, 0.0],
                                      "light_color": "#FFC77A", "light_energy_active": 2.0, "light_energy_dim": 0.15,
                                      "omni_range": 6.0}},
        },
        "cameras": {"Cam_Laguna": cam_info("Cam_Laguna"), "Cam_Dosel": cam_info("Cam_Dosel"),
                    "Cam_Gameplay_Ref": dict(cam_info("Cam_Gameplay_Ref"),
                                             note="reference of pilot Camera3D (player at x=0); not rendered; gameplay camera unchanged")},
        "stills": c["stills"],
        "color_management": {"view_transform": VIEW["view_transform"], "look": VIEW["look"], "exposure": VIEW["exposure"],
                             "gamma": VIEW["gamma"], "identical_for_both_stills": True, "compositor": c["comp"]},
        "render": {"engine": "BLENDER_EEVEE", "samples": args.samples, "resolution": args.res, "percentage": args.percent,
                   "raytracing": bool(getattr(scene.eevee, "use_raytracing", False)),
                   "ray_tracing_method": getattr(scene.eevee, "ray_tracing_method", None),
                   "volumetrics": {"tile_size": "4", "samples": 64, "shadows": True, "end_m": 110.0},
                   "probes": [p.name for p in c["probes"]], "notes": c["render_notes"]},
        "canopy_cover_percent_raycast": c["cov"],
        "fog": {"world_haze": {"density": WORLD_HAZE_DENSITY, "color_linear": [0.80, 0.84, 0.88], "anisotropy": 0.3,
                               "blender_impl": "bounded volume box LOOK001_AerialHaze (look-only), not a world volume (EEVEE 5 world volume is infinite and hides the sky)",
                               "box_blender_xyz_minmax": list(HAZE_BOX)},
                "bank_material": f"Principled Volume colour (0.78,0.82,0.86), density {FOG_BANK_DENSITY} x edge smoothstep x noise(1.6) x bottom-heavy gradient, anisotropy 0.35",
                "banks": [{"name": o.name, "blender_center": [round(x, 3) for x in o.location],
                           "blender_half_extents": [round(x, 3) for x in o.scale],
                           "rot_z_deg": round(math.degrees(o.rotation_euler.z), 1),
                           "godot_position": bl2gd(o.location),
                           "godot_size": [round(o.scale[0] * 2, 3), round(o.scale[2] * 2, 3), round(o.scale[1] * 2, 3)]}
                          for o in c["fog_objs"]]},
        "warp_beam_preview": {"gold": BEAM_GEOM["gold"], "cyan": BEAM_GEOM["cyan"], "strength": BEAM_STRENGTH,
                              "geometry_note": "(radius_base, radius_top, height) m from VFX_WarpBeam_Spawn; fades with height and at grazing angles"},
        "godot_rebuild_notes": {
            "summary": "The GLB carries geometry, vertex colours and simple PBR/unlit/emissive materials only. It is NOT a full look transfer: water ripples/reflection, fog, sky, probes, the warp beam and post must be rebuilt in Godot (project is Forward+).",
            "water": [
                "M_BLACKWATER -> StandardMaterial3D: albedo #10191A, metallic 0, roughness 0.15, specular 0.5; optional slow-scrolling normal map (2 layers ~4 m and ~1 m, strength 0.1) for broad ripples — no foam, no fine noise, no transparency.",
                "Environment: ssr_enabled=true (max_steps 64, fade_in 0.15, fade_out 2.0, depth_tolerance 0.2) for on-screen reflections.",
                "Off-screen canopy/sky reflections: ReflectionProbe box ~60x8x50 m over the lagoon, update_mode ONCE — base ambient reflection.",
                "Dynamic warp-beam reflection is NOT guaranteed by SSR (often off-screen): mirrored additive beam mesh under the plane or a planar-reflection SubViewport if needed.",
                "Water is visual only: no collision; keep the existing swim/damage/fall zones."],
            "fog": [
                f"Forward+: Environment.volumetric_fog_enabled=true, density {WORLD_HAZE_DENSITY}, albedo (0.80,0.84,0.88), anisotropy 0.3, length 64, detail_spread 2; DirectionalLight3D volumetric_fog_energy 1.0 for shafts through the canopy gaps.",
                "Low banks: one FogVolume (shape ELLIPSOID) per fog.banks entry using godot_position/godot_size; FogMaterial density 0.5, albedo (0.78,0.82,0.86), height_falloff 0.8, edge_fade 0.6, density_texture NoiseTexture3D (frequency ~0.25).",
                "Never place FogVolumes over landing zones / platform tops (kept off in this layout).",
                "Mobile/Compatibility fallback (do not change the project renderer): Environment depth fog (density 0.012, light colour (0.55,0.60,0.66), aerial_perspective 0.3) + 6-10 soft unshaded alpha cards (alpha 0.15-0.3) at the bank positions."],
            "sky": [
                "ProceduralSkyMaterial: sky_top_color #5C6B7C, sky_horizon_color #6E6A63, faint warm band toward the sun azimuth (or a PanoramaSkyMaterial baked from W_SELVA_LOOK001), ground_bottom_color #10191A, energy ~0.5.",
                "Residual sky only reads through the irregular canopy openings (75-90% cover target)."],
            "post": [
                f"Tonemap AgX (Godot 4.4+) or Filmic on 4.2; exposure tuned once (Blender exposure {VIEW['exposure']}) and identical across shots.",
                "Glow minimal: intensity 0.25, strength 0.8, bloom 0.0, hdr_threshold 1.2, levels 3-5 only; keep pod contours readable.",
                "Adjustments: contrast 1.03, saturation 0.95; shadows slightly cool, highlights slightly warm (lift (0.985,1,1.025), gain (1.03,1,0.955)).",
                "No DOF, no motion blur, no letterbox, no burnt-in HUD/text."],
            "warp": [
                "Beam is a VFX spawned at VFX_WarpBeam_Spawn (GLB empty); see warp_beam_preview. Gold dominant, cyan core only.",
                "Toggle M_WARP_GOLD / M_WARP_CYAN emission_energy active (3.0 / 2.4) vs dim (0.35 / 0.25) and the OmniLight energy 2.0 / 0.15 with the totem state."],
            "lod": [
                "LOD switching is NOT automatic from names: import the three GLBs and switch with VisibilityRange (e.g. LOD0 0-35 m, LOD1 30-70 m, LOD2 65 m+) or use Godot auto mesh LOD on LOD0.",
                "SELVA_GP_* gameplay meshes are identical in all three GLBs; collisions remain from the existing port."],
        },
        "files": files,
        "warnings": c["warnings"],
        "elapsed_seconds": round(time.time() - c["t0"], 1),
    }


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(1)
