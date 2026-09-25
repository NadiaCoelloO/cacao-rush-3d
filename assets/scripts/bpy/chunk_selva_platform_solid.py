"""
Cacao Rush 3D — Cuyabeno (world id selva) solid platform greybox (Phase 1).

Modular solid walkable block (full collision volume). Display: Cuyabeno.
Do NOT label UI/docs «Selva Dulce» or Yasuní.

2D truth (READ ONLY) sand-vivid-dawn-sail tip f278dd9730cb335590d50287303907e57f8f3461:
  T=32px, player PH=42px → Maya ~1.75 m → 0.041667 m/px (24 px/m).
  Solid platforms vary widely; modular prop piece sized ~1–3 m wide (brief).
  Dims used: 3.0 m (W) × 2.0 m (D) × 1.0 m (H) — solid block, origin bottom-center.

Usage:
  blender --background --python assets/scripts/bpy/chunk_selva_platform_solid.py -- --out export/chunk_selva_platform_solid.glb
"""
from __future__ import annotations

import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from _common import (  # noqa: E402
    apply_all_transforms,
    assign_material,
    clear_scene,
    count_tris,
    decimate_lod,
    ensure_parent_empty,
    export_glb_yup,
    fail_if_over_budget,
    join_meshes,
    make_grey_material,
    parse_args,
    set_unit_meters,
    triangulate_object,
)

# Prop budget (TECH_BUDGET Prop / pickup ≤ 2k, 2 LODs)
BUDGET_TRIS = 2000
TARGET_LOD0_MAX = 400
TARGET_LOD1_MAX = 120

# Meters — 1u = 1m. Origin at bottom center (walkable top at z=HEIGHT).
WIDTH = 3.0
DEPTH = 2.0
HEIGHT = 1.0
BEVEL_OFFSET = 0.06
BEVEL_SEGMENTS = 2


def _bevel_cube(name: str, size_xyz, mat, bevel_offset: float, segments: int):
    """Unit cube scaled to size, lightly beveled, origin at geometric center then shifted."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    if obj.data:
        obj.data.name = name
    sx, sy, sz = size_xyz
    obj.scale = (sx, sy, sz)
    apply_all_transforms(obj)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(obj.data)
    bmesh.ops.bevel(
        bm,
        geom=list(bm.edges),
        offset=bevel_offset,
        segments=segments,
        profile=0.5,
        affect="EDGES",
    )
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Shift so bottom sits on z=0
    obj.location = (0.0, 0.0, sz * 0.5)
    apply_all_transforms(obj)
    assign_material(obj, mat)
    return obj


def build_solid_parts(mat_body, mat_top):
    """Full collision solid block + slightly raised top plate for readable silhouette."""
    parts = []
    body = _bevel_cube(
        "Selva_Platform_Solid_Body",
        (WIDTH, DEPTH, HEIGHT),
        mat_body,
        bevel_offset=BEVEL_OFFSET,
        segments=BEVEL_SEGMENTS,
    )
    parts.append(body)

    # Thin top plate (lighter grey) for top-face read — still part of solid volume visual
    top_h = 0.06
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, HEIGHT - top_h * 0.5 + 0.005))
    top = bpy.context.active_object
    top.name = "Selva_Platform_Solid_Top"
    if top.data:
        top.data.name = "Selva_Platform_Solid_Top"
    top.scale = (WIDTH * 0.92, DEPTH * 0.92, top_h)
    apply_all_transforms(top)
    assign_material(top, mat_top)
    parts.append(top)
    return parts


def main():
    args = parse_args("Export chunk_selva_platform_solid greybox GLB with 2 LODs (Cuyabeno)")
    set_unit_meters()
    clear_scene()

    mat_body = make_grey_material("Selva_Platform_Solid_Grey", 0.46)
    mat_top = make_grey_material("Selva_Platform_Solid_Top_Grey", 0.55)

    parts = build_solid_parts(mat_body, mat_top)
    lod0 = join_meshes(parts, "Selva_Platform_Solid_LOD0")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    assign_material(lod0, mat_body)
    lod0.name = "Selva_Platform_Solid_LOD0"
    if lod0.data:
        lod0.data.name = "Selva_Platform_Solid_LOD0"

    tris0 = count_tris(lod0)
    print(
        f"[INFO] Selva_Platform_Solid_LOD0 tris={tris0} "
        f"(soft ≤{TARGET_LOD0_MAX}, hard ≤{BUDGET_TRIS}) "
        f"size={WIDTH}x{DEPTH}x{HEIGHT}m"
    )

    ratio1 = min(0.35, TARGET_LOD1_MAX / max(tris0, 1))
    lod1 = decimate_lod(lod0, "Selva_Platform_Solid_LOD1", ratio=ratio1, mat=mat_body)
    tris1 = count_tris(lod1)
    print(f"[INFO] Selva_Platform_Solid_LOD1 tris={tris1}")

    root = ensure_parent_empty("Selva_Platform_Solid", (0.0, 0.0, 0.0))
    lod0.parent = root
    lod1.parent = root

    fail_if_over_budget(tris0, BUDGET_TRIS, "Selva_Platform_Solid_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1])

    # Save .blend beside export if --out suggests a path
    out = Path(args.out)
    blend_path = out.with_suffix(".blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path.resolve()))
    print(f"[OK] Saved blend → {blend_path.resolve()}")
    print(
        f"[DONE] chunk_selva_platform_solid → {args.out} | LOD0={tris0} LOD1={tris1} | "
        f"display=Cuyabeno world=selva dims={WIDTH}x{DEPTH}x{HEIGHT}m"
    )


if __name__ == "__main__":
    main()
