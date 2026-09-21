"""
Cacao Rush 3D — Maya hero greybox (Phase 1)
Arcade-readable contemporary Andean mestiza explorer blockout.

Usage:
  blender --background --python tools/blender/hero_maya_grey.py -- --out export/hero_grey.glb
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
    primitive_uv_sphere,
    set_unit_meters,
    triangulate_object,
)

# Héroe budget: 25k LOD0 max; greybox aim ~8–12k
BUDGET_TRIS = 25000
TARGET_LOD0_MAX = 12000
TARGET_LOD1_MAX = 12000
TARGET_LOD2_MAX = 5000

# Idle arcade height target: 1.8–2.0 m (Blender meters, 1u=1m)
TARGET_HEIGHT_M = 1.90


def build_maya_parts(mat_body, mat_hair, mat_pack):
    """Procedural humanoid ~1.9m tall from primitives; arcade chunky silhouette."""
    # Scale factor so crown sits near TARGET_HEIGHT_M
    # Layout designed around crown ≈ 1.90 m
    parts = []

    hips = primitive_cube("Maya_Hips", (0.0, 0.0, 1.02), (0.36, 0.22, 0.20), mat_body)
    parts.append(hips)

    torso = primitive_cube("Maya_Torso", (0.0, 0.0, 1.36), (0.38, 0.24, 0.46), mat_body)
    parts.append(torso)

    chest = primitive_cube("Maya_Chest", (0.0, 0.0, 1.58), (0.44, 0.26, 0.18), mat_body)
    parts.append(chest)

    neck = primitive_cylinder(
        "Maya_Neck", (0.0, 0.0, 1.74), radius=0.075, depth=0.11, mat=mat_body, vertices=12
    )
    parts.append(neck)

    head = primitive_uv_sphere(
        "Maya_Head", (0.0, 0.0, 1.90), radius=0.14, mat=mat_body, segments=16, ring_count=10
    )
    parts.append(head)

    # Short hair volume — mid/dark grey, NEVER white (Nix indigo rule is for Nix only)
    hair = primitive_uv_sphere(
        "Maya_Hair", (0.0, -0.02, 1.94), radius=0.15, mat=mat_hair, segments=12, ring_count=8
    )
    hair.scale = (1.05, 1.1, 0.85)
    apply_all_transforms(hair)
    assign_material(hair, mat_hair)
    parts.append(hair)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        upper = primitive_cylinder(
            f"Maya_ArmUpper_{side}",
            (sx * 0.30, 0.0, 1.42),
            radius=0.075,
            depth=0.40,
            mat=mat_body,
            vertices=10,
        )
        upper.rotation_euler = (0.0, 0.35 * sx, 0.0)
        apply_all_transforms(upper)
        assign_material(upper, mat_body)
        parts.append(upper)

        lower = primitive_cylinder(
            f"Maya_ArmLower_{side}",
            (sx * 0.42, 0.0, 1.08),
            radius=0.065,
            depth=0.36,
            mat=mat_body,
            vertices=10,
        )
        lower.rotation_euler = (0.0, 0.15 * sx, 0.0)
        apply_all_transforms(lower)
        assign_material(lower, mat_body)
        parts.append(lower)

        hand = primitive_cube(
            f"Maya_Hand_{side}", (sx * 0.46, 0.0, 0.86), (0.09, 0.07, 0.11), mat_body
        )
        parts.append(hand)

    for side, sx in (("L", 1.0), ("R", -1.0)):
        thigh = primitive_cylinder(
            f"Maya_Thigh_{side}",
            (sx * 0.13, 0.0, 0.68),
            radius=0.095,
            depth=0.48,
            mat=mat_body,
            vertices=10,
        )
        parts.append(thigh)

        shin = primitive_cylinder(
            f"Maya_Shin_{side}",
            (sx * 0.13, 0.0, 0.30),
            radius=0.075,
            depth=0.40,
            mat=mat_body,
            vertices=10,
        )
        parts.append(shin)

        boot = primitive_cube(
            f"Maya_Boot_{side}", (sx * 0.13, 0.07, 0.065), (0.13, 0.24, 0.11), mat_body
        )
        parts.append(boot)

    # Explorer satchel / backpack hint
    pack = primitive_cube("Maya_Satchel", (0.0, -0.20, 1.34), (0.30, 0.13, 0.34), mat_pack)
    parts.append(pack)
    strap = primitive_cube("Maya_Strap", (0.19, -0.06, 1.50), (0.045, 0.17, 0.045), mat_pack)
    parts.append(strap)

    return parts


def main():
    args = parse_args("Export Maya hero greybox GLB with LOD0/1/2")
    set_unit_meters()
    clear_scene()

    # Grey unlit-style flat mid-grey (Principled dark/rough ≈ unlit greybox look)
    mat_body = make_grey_material("Maya_Body_Grey", 0.45)
    mat_hair = make_grey_material("Maya_Hair_Grey", 0.32)
    mat_pack = make_grey_material("Maya_Pack_Grey", 0.38)

    parts = build_maya_parts(mat_body, mat_hair, mat_pack)

    lod0 = join_meshes(parts, "Maya_LOD0")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    assign_material(lod0, mat_body)

    tris0 = count_tris(lod0)
    print(f"[INFO] Maya_LOD0 tris={tris0} (soft target ≤{TARGET_LOD0_MAX}, height≈{TARGET_HEIGHT_M}m)")

    ratio1 = min(0.40, TARGET_LOD1_MAX / max(tris0, 1))
    ratio2 = min(0.12, TARGET_LOD2_MAX / max(tris0, 1))

    lod1 = decimate_lod(lod0, "Maya_LOD1", ratio=ratio1, mat=mat_body)
    lod2 = decimate_lod(lod0, "Maya_LOD2", ratio=ratio2, mat=mat_body)

    tris1 = count_tris(lod1)
    tris2 = count_tris(lod2)
    print(f"[INFO] Maya_LOD1 tris={tris1} | Maya_LOD2 tris={tris2}")

    root = ensure_parent_empty("Maya", (0.0, 0.0, 0.0))
    for lod in (lod0, lod1, lod2):
        lod.parent = root

    fail_if_over_budget(tris0, BUDGET_TRIS, "Maya_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1, lod2])
    print(f"[DONE] hero_maya_grey → {args.out} | LOD0={tris0} LOD1={tris1} LOD2={tris2}")


if __name__ == "__main__":
    main()
