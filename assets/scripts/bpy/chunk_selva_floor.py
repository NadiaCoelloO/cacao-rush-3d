"""
Cacao Rush 3D — Cuyabeno pilot (path id: selva) floor chunk greybox (Phase 1)

Cuyabeno (EC rainforest) identity: leaf litter (hojarasca) + cacao root stubs.
NO Asian jungle, NO bamboo.

Usage:
  blender --background --python tools/blender/chunk_selva_floor.py -- --out export/chunk_selva_floor.glb
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

# Chunk budget: 80k LOD0 max; greybox aim ~5–15k
BUDGET_TRIS = 80000
TARGET_LOD0_MAX = 15000
TARGET_LOD1_MAX = 6000
TARGET_LOD2_MAX = 2000

# Walkable footprint ~16–20 m
CHUNK_SIZE_M = 18.0


def _subdivide_plane(obj, cuts: int = 4) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.subdivide(number_cuts=cuts)
    bpy.ops.object.mode_set(mode="OBJECT")


def build_selva_parts(mat_floor, mat_platform, mat_root, mat_litter):
    """
    Flat / lightly subdivided floor slab ~18x18m with raised platforms
    and cacao-root stubs + hojarasca blocks (Cuyabeno — not Asia/bamboo).
    """
    parts = []
    half = CHUNK_SIZE_M * 0.5

    # Main walkable slab
    bpy.ops.mesh.primitive_plane_add(size=CHUNK_SIZE_M, location=(0.0, 0.0, 0.0))
    floor = bpy.context.active_object
    floor.name = "Selva_Floor_Base"
    _subdivide_plane(floor, cuts=3)
    apply_all_transforms(floor)
    assign_material(floor, mat_floor)
    parts.append(floor)

    # 2–3 raised platforms (arcade feel) — low boxes, not solid walls
    platforms = [
        ("Selva_Platform_A", (4.0, 3.0, 0.25), (3.5, 2.5, 0.5)),
        ("Selva_Platform_B", (-5.0, -2.5, 0.35), (2.8, 3.0, 0.7)),
        ("Selva_Platform_C", (1.5, -6.0, 0.20), (4.0, 2.0, 0.4)),
    ]
    for name, loc, scale in platforms:
        p = primitive_cube(name, loc, scale, mat_platform)
        parts.append(p)

    # Cacao root stubs (short trunk/root blocks — Ecuador cacao, not bamboo)
    roots = [
        ("Selva_CacaoRoot_01", (-3.5, 5.0, 0.35), 0.35, 0.70),
        ("Selva_CacaoRoot_02", (6.0, -4.0, 0.25), 0.28, 0.50),
        ("Selva_CacaoRoot_03", (-6.5, -5.5, 0.30), 0.32, 0.60),
        ("Selva_CacaoRoot_04", (2.0, 6.5, 0.22), 0.25, 0.44),
    ]
    for name, loc, radius, depth in roots:
        r = primitive_cylinder(name, loc, radius=radius, depth=depth, mat=mat_root, vertices=10)
        parts.append(r)
        # Lateral root nubs
        nub = primitive_cube(
            name.replace("Root", "RootNub"),
            (loc[0] + radius * 0.9, loc[1], 0.08),
            (radius * 1.6, radius * 0.5, 0.12),
            mat_root,
        )
        parts.append(nub)

    # Hojarasca (leaf-litter) low irregular blocks scattered on floor
    litter_spots = [
        (-2.0, 2.0, 0.04),
        (3.5, -1.5, 0.03),
        (-4.0, -3.0, 0.05),
        (5.5, 4.5, 0.04),
        (0.5, 1.0, 0.03),
        (-7.0, 1.5, 0.04),
        (7.0, -6.0, 0.03),
        (-1.0, -7.0, 0.04),
    ]
    for i, (x, y, z) in enumerate(litter_spots, start=1):
        lit = primitive_cube(
            f"Selva_Hojarasca_{i:02d}",
            (x, y, z),
            (0.8 + (i % 3) * 0.15, 0.5 + (i % 2) * 0.2, 0.06),
            mat_litter,
        )
        parts.append(lit)

    # A few rock blocks (optional biome clutter)
    rocks = [
        ("Selva_Rock_01", (7.5, 2.0, 0.25), (0.7, 0.5, 0.5)),
        ("Selva_Rock_02", (-7.0, 6.0, 0.20), (0.5, 0.6, 0.4)),
    ]
    for name, loc, scale in rocks:
        parts.append(primitive_cube(name, loc, scale, mat_platform))

    # Keep within ±half for walkable bounds (sanity)
    _ = half
    return parts


def main():
    args = parse_args("Export selva floor chunk greybox GLB (display: Cuyabeno)")
    set_unit_meters()
    clear_scene()

    mat_floor = make_grey_material("Selva_Floor_Grey", 0.42)
    mat_platform = make_grey_material("Selva_Platform_Grey", 0.48)
    mat_root = make_grey_material("Selva_CacaoRoot_Grey", 0.35)
    mat_litter = make_grey_material("Selva_Hojarasca_Grey", 0.40)

    parts = build_selva_parts(mat_floor, mat_platform, mat_root, mat_litter)

    lod0 = join_meshes(parts, "Selva_Chunk_Floor_LOD0")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    assign_material(lod0, mat_floor)

    tris0 = count_tris(lod0)
    print(f"[INFO] Selva_Chunk_Floor_LOD0 tris={tris0} (soft ≤{TARGET_LOD0_MAX}, size≈{CHUNK_SIZE_M}m)")

    ratio1 = min(0.40, TARGET_LOD1_MAX / max(tris0, 1))
    ratio2 = min(0.15, TARGET_LOD2_MAX / max(tris0, 1))

    lod1 = decimate_lod(lod0, "Selva_Chunk_Floor_LOD1", ratio=ratio1, mat=mat_floor)
    lod2 = decimate_lod(lod0, "Selva_Chunk_Floor_LOD2", ratio=ratio2, mat=mat_floor)

    tris1 = count_tris(lod1)
    tris2 = count_tris(lod2)
    print(f"[INFO] LOD1={tris1} | LOD2={tris2}")

    root = ensure_parent_empty("Selva_Chunk", (0.0, 0.0, 0.0))
    for lod in (lod0, lod1, lod2):
        lod.parent = root

    fail_if_over_budget(tris0, BUDGET_TRIS, "Selva_Chunk_Floor_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1, lod2])
    print(f"[DONE] chunk_selva_floor → {args.out} | LOD0={tris0} LOD1={tris1} LOD2={tris2}")


if __name__ == "__main__":
    main()
