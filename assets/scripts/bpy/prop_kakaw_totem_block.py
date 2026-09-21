"""
Cacao Rush 3D — Kakaw totem prop block greybox (Phase 1)

Wood/stone stacked silhouette. Accent later: gold OR blue — never red X.

Usage:
  blender --background --python tools/blender/prop_kakaw_totem_block.py -- --out export/prop_kakaw_totem_block.glb
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
    primitive_cylinder,
    set_unit_meters,
    triangulate_object,
)

# Prop budget: 2000 tris; greybox aim ~800–1500; 2 LODs
BUDGET_TRIS = 2000
TARGET_LOD0_MAX = 1500
TARGET_LOD1_MAX = 600


def build_totem_parts(mat_stone, mat_wood, mat_accent):
    """Stacked cylinder/box totem silhouette (~2.2 m tall)."""
    parts = []

    base = primitive_cube("Totem_Base", (0.0, 0.0, 0.15), (0.70, 0.70, 0.30), mat_stone)
    parts.append(base)

    plinth = primitive_cylinder(
        "Totem_Plinth", (0.0, 0.0, 0.45), radius=0.32, depth=0.30, mat=mat_stone, vertices=12
    )
    parts.append(plinth)

    mid = primitive_cube("Totem_MidBlock", (0.0, 0.0, 0.95), (0.50, 0.40, 0.70), mat_wood)
    parts.append(mid)

    upper = primitive_cylinder(
        "Totem_Upper", (0.0, 0.0, 1.50), radius=0.28, depth=0.45, mat=mat_wood, vertices=12
    )
    parts.append(upper)

    # Accent band (greybox placeholder for future gold OR blue — never red)
    band = primitive_cylinder(
        "Totem_AccentBand", (0.0, 0.0, 1.72), radius=0.30, depth=0.08, mat=mat_accent, vertices=12
    )
    parts.append(band)

    cap = primitive_cube("Totem_Cap", (0.0, 0.0, 1.95), (0.45, 0.45, 0.25), mat_stone)
    parts.append(cap)

    # Side fin / kakaw glyph block hint
    fin = primitive_cube("Totem_Fin", (0.28, 0.0, 1.10), (0.12, 0.08, 0.35), mat_accent)
    parts.append(fin)

    return parts


def main():
    args = parse_args("Export Kakaw totem prop greybox GLB with 2 LODs")
    set_unit_meters()
    clear_scene()

    mat_stone = make_grey_material("Totem_Stone_Grey", 0.50)
    mat_wood = make_grey_material("Totem_Wood_Grey", 0.38)
    mat_accent = make_grey_material("Totem_Accent_Grey", 0.55)

    parts = build_totem_parts(mat_stone, mat_wood, mat_accent)

    lod0 = join_meshes(parts, "Totem_Kakaw_Block")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    assign_material(lod0, mat_stone)

    # Rename clearly for LOD0 export node
    lod0.name = "Totem_Kakaw_Block_LOD0"
    if lod0.data:
        lod0.data.name = "Totem_Kakaw_Block_LOD0"

    tris0 = count_tris(lod0)
    print(f"[INFO] Totem_Kakaw_Block_LOD0 tris={tris0} (soft ≤{TARGET_LOD0_MAX})")

    ratio1 = min(0.40, TARGET_LOD1_MAX / max(tris0, 1))
    lod1 = decimate_lod(lod0, "Totem_Kakaw_Block_LOD1", ratio=ratio1, mat=mat_stone)
    tris1 = count_tris(lod1)
    print(f"[INFO] Totem_Kakaw_Block_LOD1 tris={tris1}")

    root = ensure_parent_empty("Totem_Kakaw_Block", (0.0, 0.0, 0.0))
    lod0.parent = root
    lod1.parent = root

    fail_if_over_budget(tris0, BUDGET_TRIS, "Totem_Kakaw_Block_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1])
    print(f"[DONE] prop_kakaw_totem_block → {args.out} | LOD0={tris0} LOD1={tris1}")


if __name__ == "__main__":
    main()
