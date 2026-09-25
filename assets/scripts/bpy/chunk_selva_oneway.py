"""
Cacao Rush 3D — Cuyabeno (world id selva) one-way platform greybox (Phase 1).

Thin top-collision slab + underside notch/arrow cue (mesh ONLY — no gameplay logic).
Distinct silhouette from chunk_selva_platform_solid. Display: Cuyabeno.
Do NOT label UI/docs «Selva Dulce» or Yasuní.

2D truth (READ ONLY) sand-vivid-dawn-sail tip f278dd9730cb335590d50287303907e57f8f3461:
  T=32px, player PH=42px → Maya ~1.75 m → 0.041667 m/px (24 px/m).
  Oneway median ~T*4 × 18 px = 5.333 × 0.75 m; common small T*3 × 16 px = 4.0 × 0.667 m.
  Visual in 2D is a thin highlight strip (~4–14 px). Greybox uses modular T*3 width.
  Dims used: 4.0 m (W) × 2.0 m (D) × 0.18 m (slab) + underside chevron cue.

Usage:
  blender --background --python assets/scripts/bpy/chunk_selva_oneway.py -- --out export/chunk_selva_oneway.glb
"""
from __future__ import annotations

import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import bpy  # noqa: E402
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
    primitive_cube,
    set_unit_meters,
    triangulate_object,
)

BUDGET_TRIS = 2000
TARGET_LOD0_MAX = 200
TARGET_LOD1_MAX = 80

# Meters — modular common small oneway (T*3). Origin bottom of slab.
WIDTH = 4.0
DEPTH = 2.0
SLAB_H = 0.18


def build_oneway_parts(mat_slab, mat_cue):
    """
    Thin top slab + underside chevron/arrow cue so artists can tell it apart from solid.
    Cue is greybox mesh only (no collision / gameplay meaning in this asset).
    """
    parts = []

    # Main thin slab — top face at z=SLAB_H
    slab = primitive_cube(
        "Selva_Oneway_Slab",
        (0.0, 0.0, SLAB_H * 0.5),
        (WIDTH, DEPTH, SLAB_H),
        mat_slab,
    )
    parts.append(slab)

    # Slightly inset top highlight strip (lighter grey) — reads like 2D 4px top bar
    highlight = primitive_cube(
        "Selva_Oneway_TopStrip",
        (0.0, 0.0, SLAB_H + 0.015),
        (WIDTH * 0.94, DEPTH * 0.70, 0.03),
        mat_cue,
    )
    parts.append(highlight)

    # Underside notch / chevron pointing down-forward (silhouette cue)
    # Two diagonal bars forming a shallow V under the slab
    cue_z = -0.06
    cue_h = 0.10
    cue_d = 0.12
    left = primitive_cube(
        "Selva_Oneway_Chevron_L",
        (-0.45, 0.0, cue_z),
        (1.1, cue_d, cue_h),
        mat_cue,
    )
    left.rotation_euler = (0.0, 0.45, 0.0)  # ~25 deg
    apply_all_transforms(left)
    parts.append(left)

    right = primitive_cube(
        "Selva_Oneway_Chevron_R",
        (0.45, 0.0, cue_z),
        (1.1, cue_d, cue_h),
        mat_cue,
    )
    right.rotation_euler = (0.0, -0.45, 0.0)
    apply_all_transforms(right)
    parts.append(right)

    # Center drop nub under slab (one-way "through from below" read)
    nub = primitive_cube(
        "Selva_Oneway_Underside_Nub",
        (0.0, 0.0, -0.08),
        (0.35, 0.35, 0.12),
        mat_cue,
    )
    parts.append(nub)

    return parts


def main():
    args = parse_args("Export chunk_selva_oneway greybox GLB with 2 LODs (Cuyabeno)")
    set_unit_meters()
    clear_scene()

    mat_slab = make_grey_material("Selva_Oneway_Slab_Grey", 0.50)
    mat_cue = make_grey_material("Selva_Oneway_Cue_Grey", 0.38)

    parts = build_oneway_parts(mat_slab, mat_cue)
    lod0 = join_meshes(parts, "Selva_Oneway_LOD0")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    assign_material(lod0, mat_slab)
    lod0.name = "Selva_Oneway_LOD0"
    if lod0.data:
        lod0.data.name = "Selva_Oneway_LOD0"

    tris0 = count_tris(lod0)
    print(
        f"[INFO] Selva_Oneway_LOD0 tris={tris0} "
        f"(soft ≤{TARGET_LOD0_MAX}, hard ≤{BUDGET_TRIS}) "
        f"slab={WIDTH}x{DEPTH}x{SLAB_H}m"
    )

    ratio1 = min(0.40, TARGET_LOD1_MAX / max(tris0, 1))
    lod1 = decimate_lod(lod0, "Selva_Oneway_LOD1", ratio=ratio1, mat=mat_slab)
    tris1 = count_tris(lod1)
    print(f"[INFO] Selva_Oneway_LOD1 tris={tris1}")

    root = ensure_parent_empty("Selva_Oneway", (0.0, 0.0, 0.0))
    lod0.parent = root
    lod1.parent = root

    fail_if_over_budget(tris0, BUDGET_TRIS, "Selva_Oneway_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1])

    out = Path(args.out)
    blend_path = out.with_suffix(".blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path.resolve()))
    print(f"[OK] Saved blend → {blend_path.resolve()}")
    print(
        f"[DONE] chunk_selva_oneway → {args.out} | LOD0={tris0} LOD1={tris1} | "
        f"display=Cuyabeno world=selva dims={WIDTH}x{DEPTH}x{SLAB_H}m+cue"
    )


if __name__ == "__main__":
    main()
