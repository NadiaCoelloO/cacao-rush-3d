"""
Shared helpers for Cacao Rush 3D Blender greybox export scripts.
Compatible with Blender 5.2 (bpy) — Phase 1 greybox pipeline.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


def parse_args(description: str = "Cacao Rush 3D greybox exporter"):
    """Parse CLI args after '--' for Blender background scripts."""
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "--out",
        required=True,
        help="Output .glb path (e.g. export/hero_grey.glb)",
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    """Remove all objects, meshes, materials, and orphan data from the scene."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.curves):
        for item in list(block):
            block.remove(item, do_unlink=True)


def make_grey_material(
    name: str = "Greybox_MidGrey",
    value: float = 0.45,
    unlit: bool = True,
) -> bpy.types.Material:
    """
    Flat mid-grey material for Phase-1 greybox (no textures).
    When unlit=True, uses Background/Emission so shading is flat grey (arcade greybox).
    """
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    if unlit:
        # Emission ≈ unlit grey for glTF / greybox view
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (value, value, value, 1.0)
        emit.inputs["Strength"].default_value = 1.0
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
    else:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = (value, value, value, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.7
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat



def make_rgb_material(
    name: str,
    r: float,
    g: float,
    b: float,
    unlit: bool = True,
) -> bpy.types.Material:
    """
    Flat RGB material for greybox / feel-parity tints (sRGB 0–1).
    When unlit=True, uses Emission so shading is flat (arcade look), matching make_grey_material.
    Does not replace make_grey_material — grey scripts keep working.
    """
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    color = (float(r), float(g), float(b), 1.0)
    if unlit:
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = color
        emit.inputs["Strength"].default_value = 1.0
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
    else:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.7
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def assign_material(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.type != "MESH":
        return
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def apply_all_transforms(obj: bpy.types.Object) -> None:
    """Apply location, rotation, and scale; freeze scale to (1,1,1)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def triangulate_object(obj: bpy.types.Object) -> None:
    """Ensure mesh is fully triangulated (glTF requirement)."""
    if obj.type != "MESH":
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")


def count_tris(obj: bpy.types.Object) -> int:
    """Count triangles in a mesh object (after triangulation)."""
    if obj.type != "MESH" or obj.data is None:
        return 0
    mesh = obj.data
    if hasattr(mesh, "loop_triangles") and len(mesh.loop_triangles) > 0:
        # Ensure loop_triangles are calculated
        mesh.calc_loop_triangles()
        return len(mesh.loop_triangles)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    n = len(bm.faces)
    bm.free()
    return n


def count_tris_objects(objects) -> int:
    return sum(count_tris(o) for o in objects if o.type == "MESH")


def fail_if_over_budget(tri_count: int, budget: int, label: str = "asset") -> None:
    """Exit 1 if triangle count exceeds BUDGET_TRIS."""
    print(f"[BUDGET] {label}: {tri_count} tris (budget={budget})")
    if tri_count > budget:
        print(f"[FAIL] {label} exceeds BUDGET_TRIS ({tri_count} > {budget})")
        sys.exit(1)


def decimate_lod(
    src: bpy.types.Object,
    name: str,
    ratio: float,
    mat: bpy.types.Material | None = None,
) -> bpy.types.Object:
    """Duplicate src, apply Decimate at `ratio`, rename to `name`."""
    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    lod = bpy.context.active_object
    lod.name = name
    if lod.data:
        lod.data.name = name

    mod = lod.modifiers.new(name="Decimate_LOD", type="DECIMATE")
    mod.ratio = max(0.01, min(1.0, ratio))
    bpy.ops.object.modifier_apply(modifier=mod.name)

    apply_all_transforms(lod)
    triangulate_object(lod)
    if mat is not None:
        assign_material(lod, mat)
    return lod


def join_meshes(objects, name: str) -> bpy.types.Object:
    """Join a list of mesh objects into one named mesh."""
    meshes = [o for o in objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("join_meshes: no mesh objects")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    if joined.data:
        joined.data.name = name
    return joined


def ensure_parent_empty(name: str, location=(0.0, 0.0, 0.0)) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.location = Vector(location)
    bpy.context.collection.objects.link(empty)
    return empty


def export_glb_yup(filepath: str, objects=None) -> None:
    """
    Export selected (or given) objects as Y-up glTF binary (.glb).
    No packed unused images; units meters assumed.
    """
    out = Path(filepath)
    out.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    if objects is None:
        for obj in bpy.context.scene.objects:
            obj.select_set(True)
    else:
        for obj in objects:
            if obj is not None:
                obj.select_set(True)

    export_kwargs = dict(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.gltf(**export_kwargs)
    except TypeError:
        export_kwargs.pop("export_image_format", None)
        export_kwargs.pop("export_yup", None)
        try:
            bpy.ops.export_scene.gltf(**export_kwargs)
        except TypeError as e:
            bpy.ops.export_scene.gltf(
                filepath=str(out),
                export_format="GLB",
                use_selection=True,
            )
            print(f"[WARN] export used minimal kwargs due to: {e}")

    print(f"[OK] Exported Y-up GLB → {out.resolve()}")


def set_unit_meters() -> None:
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def primitive_cube(name, loc, scale, mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    apply_all_transforms(obj)
    if mat:
        assign_material(obj, mat)
    return obj


def primitive_cylinder(name, loc, radius, depth, mat=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=loc
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_all_transforms(obj)
    if mat:
        assign_material(obj, mat)
    return obj


def primitive_uv_sphere(name, loc, radius, mat=None, segments=16, ring_count=8):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=ring_count, radius=radius, location=loc
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_all_transforms(obj)
    if mat:
        assign_material(obj, mat)
    return obj


def primitive_cone(name, loc, radius1, depth, mat=None, vertices=12):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=0.0, depth=depth, location=loc
    )
    obj = bpy.context.active_object
    obj.name = name
    apply_all_transforms(obj)
    if mat:
        assign_material(obj, mat)
    return obj
