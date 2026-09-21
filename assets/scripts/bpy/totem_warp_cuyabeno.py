"""CIN-001 totem_warp_cuyabeno greybox."""
from __future__ import annotations

import math
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import bpy  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402
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
    primitive_cone,
    primitive_cube,
    primitive_cylinder,
    primitive_uv_sphere,
    set_unit_meters,
    triangulate_object,
)

BUDGET_TRIS = 2000
TARGET_LOD0_MAX = 1600
TARGET_LOD1_MAX = 700

TOTEM_TIP_Z = 2.95
MAYA_HEIGHT = 1.70

def make_tint_material(
    name: str,
    color: tuple[float, float, float],
    *,
    metallic: float = 0.0,
    roughness: float = 0.55,
    unlit: bool = False,
) -> bpy.types.Material:
    """Simple tinted PBR/emission material for greybox accent read (gold/cyan/liana)."""
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    r, g, b = color
    if unlit:
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (r, g, b, 1.0)
        emit.inputs["Strength"].default_value = 1.0
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
    else:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat

def _rotate_obj(obj: bpy.types.Object, euler_xyz: tuple[float, float, float]) -> None:
    obj.rotation_euler = Euler(euler_xyz, "XYZ")
    apply_all_transforms(obj)

def build_totem_parts(mat_stone, mat_gold, mat_cyan, mat_liana):
    parts = []
    parts.append(primitive_cube("Totem_Base_Step0", (0.0, 0.0, 0.10), (0.95, 0.95, 0.20), mat_stone))
    parts.append(primitive_cube("Totem_Base_Step1", (0.0, 0.0, 0.28), (0.72, 0.72, 0.18), mat_stone))
    parts.append(primitive_cube("Totem_Shaft_Lower", (0.0, 0.0, 0.95), (0.48, 0.48, 1.10), mat_stone))
    parts.append(primitive_cube("Totem_Ledge_Mid", (0.0, 0.0, 1.55), (0.58, 0.58, 0.12), mat_stone))
    parts.append(primitive_cube("Totem_Shaft_Upper", (0.0, 0.0, 2.05), (0.40, 0.40, 0.90), mat_stone))
    parts.append(primitive_cube("Totem_Crown_Plate", (0.0, 0.0, 2.55), (0.50, 0.50, 0.12), mat_stone))
    spike_h = 0.14
    spike_s = 0.08
    for i, (sx, sy) in enumerate(((0.18, 0.18), (0.18, -0.18), (-0.18, 0.18), (-0.18, -0.18))):
        parts.append(primitive_cube(f"Totem_Crown_Spike_{i}", (sx, sy, 2.55 + spike_h * 0.5 + 0.06), (spike_s, spike_s, spike_h), mat_stone))
    parts.append(primitive_cylinder("Totem_GoldBand_Lower", (0.0, 0.0, 0.55), radius=0.26, depth=0.06, mat=mat_gold, vertices=10))
    parts.append(primitive_cylinder("Totem_GoldBand_Upper", (0.0, 0.0, 2.20), radius=0.22, depth=0.05, mat=mat_gold, vertices=10))
    plate_z_pairs = ((1.05, 0.25), (2.00, 0.21))
    for zi, (pz, pr) in enumerate(plate_z_pairs):
        for fi, (px, py, rot_z) in enumerate(((0.25, 0.0, math.radians(90)), (-0.25, 0.0, math.radians(90)), (0.0, 0.25, 0.0), (0.0, -0.25, 0.0))):
            if zi == 0 and fi >= 2:
                continue
            if zi == 1 and fi >= 2:
                continue
            plate = primitive_cylinder(f"Totem_GoldOval_{zi}_{fi}", (px if zi == 0 else px * 0.85, py if zi == 0 else py * 0.85, pz), radius=pr, depth=0.035, mat=mat_gold, vertices=10)
            if abs(px) > abs(py):
                _rotate_obj(plate, (0.0, math.radians(90), 0.0))
            else:
                _rotate_obj(plate, (math.radians(90), 0.0, 0.0))
            plate.scale = (0.55, 1.0, 1.15)
            apply_all_transforms(plate)
            parts.append(plate)
    liana_specs = [
        ("Totem_Liana_0", (0.28, 0.05, 0.90), 0.035, 1.40, (0.15, 0.0, 0.2)),
        ("Totem_Liana_1", (-0.26, -0.08, 1.20), 0.030, 1.10, (-0.12, 0.05, -0.25)),
        ("Totem_Liana_2", (0.08, 0.27, 1.70), 0.028, 0.90, (0.0, 0.18, 0.4)),
    ]
    for name, loc, rad, depth, rot in liana_specs:
        vine = primitive_cylinder(name, loc, radius=rad, depth=depth, mat=mat_liana, vertices=8)
        _rotate_obj(vine, rot)
        parts.append(vine)
    parts.append(primitive_cube("Totem_Liana_Ribbon_A", (0.30, 0.0, 1.40), (0.04, 0.12, 0.55), mat_liana))
    parts.append(primitive_cube("Totem_Liana_Ribbon_B", (-0.12, 0.28, 0.75), (0.35, 0.04, 0.05), mat_liana))
    cacao_offsets = [
        (0.00, 0.00, 2.72, 0.11, 0.18),
        (0.12, 0.05, 2.68, 0.09, 0.15),
        (-0.10, -0.06, 2.70, 0.09, 0.14),
        (0.05, -0.11, 2.66, 0.08, 0.13),
        (-0.06, 0.10, 2.67, 0.08, 0.13),
    ]
    for i, (cx, cy, cz, rx, rz) in enumerate(cacao_offsets):
        pod = primitive_uv_sphere(f"Totem_CacaoOro_{i}", (cx, cy, cz), radius=rx, mat=mat_gold, segments=8, ring_count=6)
        pod.scale = (1.0, 0.85, rz / max(rx, 1e-6))
        apply_all_transforms(pod)
        parts.append(pod)
    tip = primitive_cone("Totem_CyanTip", (0.0, 0.0, TOTEM_TIP_Z), radius1=0.07, depth=0.16, mat=mat_cyan, vertices=8)
    parts.append(tip)
    return parts

def build_maya_scale_stub(mat) -> bpy.types.Object:
    stub = primitive_cube("Maya_Scale_Stub", (1.20, 0.0, MAYA_HEIGHT * 0.5), (0.18, 0.18, MAYA_HEIGHT), mat)
    if stub.data:
        stub.data.name = "Maya_Scale_Stub"
    return stub

def main():
    args = parse_args("Export totem_warp_cuyabeno greybox GLB with 2 LODs (CIN-001)")
    set_unit_meters()
    clear_scene()
    mat_stone = make_grey_material("Totem_Stone", 0.42)
    mat_gold = make_tint_material("Totem_GoldAccent", (0.72, 0.58, 0.22), metallic=0.65, roughness=0.35, unlit=False)
    mat_cyan = make_tint_material("Totem_CyanTip", (0.25, 0.65, 0.85), metallic=0.05, roughness=0.4, unlit=True)
    mat_liana = make_grey_material("Totem_Liana", 0.28)
    mat_maya = make_grey_material("Maya_Stub_Grey", 0.55)
    parts = build_totem_parts(mat_stone, mat_gold, mat_cyan, mat_liana)
    lod0 = join_meshes(parts, "Totem_Warp_Cuyabeno_LOD0")
    apply_all_transforms(lod0)
    triangulate_object(lod0)
    lod0.name = "Totem_Warp_Cuyabeno_LOD0"
    if lod0.data:
        lod0.data.name = "Totem_Warp_Cuyabeno_LOD0"
    tris0 = count_tris(lod0)
    print(f"[INFO] Totem_Warp_Cuyabeno_LOD0 tris={tris0}")
    ratio1 = min(0.42, TARGET_LOD1_MAX / max(tris0, 1))
    lod1 = decimate_lod(lod0, "Totem_Warp_Cuyabeno_LOD1", ratio=ratio1, mat=None)
    tris1 = count_tris(lod1)
    print(f"[INFO] Totem_Warp_Cuyabeno_LOD1 tris={tris1}")
    root = ensure_parent_empty("Totem_Warp_Cuyabeno", (0.0, 0.0, 0.0))
    lod0.parent = root
    lod1.parent = root
    vfx = ensure_parent_empty("VFX_WarpBeam_Spawn", (0.0, 0.0, TOTEM_TIP_Z + 0.08))
    vfx.parent = root
    maya = build_maya_scale_stub(mat_maya)
    maya.parent = root
    fail_if_over_budget(tris0, BUDGET_TRIS, "Totem_Warp_Cuyabeno_LOD0")
    export_glb_yup(args.out, objects=[root, lod0, lod1, vfx, maya])
    print(f"[DONE] totem_warp_cuyabeno → {args.out} | LOD0={tris0} LOD1={tris1}")

if __name__ == "__main__":
    main()
