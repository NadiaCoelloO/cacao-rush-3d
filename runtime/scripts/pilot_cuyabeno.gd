extends Node3D
## Pilot vertical slice: world id `selva`, display name **Cuyabeno**.
## LOOK-001: instances selva_look001_LOD* (decor + gameplay visuals) and rebuilds
## water / fog / sky / warp beam / film grade in `look001_cuyabeno.gd`.
## HP-001 E1: HP totem + trunk kit replace LOOK equivalents (visual only).
## Collisions: CSGFloor + CSGPlatform (x=6, 3×1×3) + CSGOneway plank at the
## PR#3 anchor Godot (6, 1, 0) size 4×0.18×2 (use_collision=true). The Assets
## oneway baked at Blender (1,0,1.8) is hidden. Tip 5fd45031 selva-1 oneway #0.
## High-poly HOLD. player_maya.gd timings are not touched.
##
## Fallback if LOOK GLBs are missing: original greybox floor + CIN-001 totem.

const LOOK_LOD0 := "res://models/selva_look001_LOD0.glb"
const LOOK_LOD1 := "res://models/selva_look001_LOD1.glb"
const LOOK_LOD2 := "res://models/selva_look001_LOD2.glb"
const FLOOR_GLB := "res://models/chunk_selva_floor.glb"
const TOTEM_GLB := "res://models/totem_warp_cuyabeno.glb"
const ONEWAY_GLB := "res://models/chunk_selva_oneway.glb"
const WORLD_ID := "selva"
const DISPLAY_NAME := "Cuyabeno"

const LOD_BEGIN := [0.0, 30.0, 65.0]
const LOD_END := [35.0, 70.0, 0.0]
const ONEWAY_BOX := Vector3(4.0, 0.18, 2.0)

@onready var _world_root: Node3D = $WorldRoot
@onready var _floor_placeholder: Node3D = $WorldRoot/FloorPlaceholder
@onready var _totem_anchor: Node3D = $WorldRoot/TotemWarpAnchor
@onready var _totem_placeholder: Node3D = $WorldRoot/TotemWarpAnchor/TotemPlaceholder
@onready var _oneway_anchor: Node3D = $WorldRoot/PlatformOnewayAnchor
@onready var _oneway_placeholder: Node3D = $WorldRoot/PlatformOnewayAnchor/PlatformOnewayPlaceholder
@onready var _look: Node3D = $Look001
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	var using_look := _try_load_look()
	if using_look:
		if _hud_label:
			_hud_label.text = "%s  ·  id %s  ·  LOOK-001" % [DISPLAY_NAME, WORLD_ID]
		_hide_csg_visuals()
		_try_load_oneway()
		var lods: Array = []
		for child in _world_root.get_children():
			if String(child.name).begins_with("SELVA_LOOK001"):
				lods.append(child)
		if _look and _look.has_method("apply"):
			_look.apply(self, lods)
		if using_look and _hud_label and _look and _look.get("_hp_ok"):
			_hud_label.text = "%s  ·  id %s  ·  LOOK-001 + HP-001" % [DISPLAY_NAME, WORLD_ID]
		if _wants_capture():
			call_deferred("_run_capture")
	else:
		if _hud_label:
			_hud_label.text = "%s  ·  id %s  ·  greybox" % [DISPLAY_NAME, WORLD_ID]
		_try_load_floor()
		_try_load_totem()
		_try_load_oneway()


func _try_load_look() -> bool:
	# LOD0 is required. If it is missing, keep CSG placeholders visible.
	if not ResourceLoader.exists(LOOK_LOD0):
		return false
	var packed0: Resource = load(LOOK_LOD0)
	if not (packed0 is PackedScene):
		return false
	var paths := [LOOK_LOD0, LOOK_LOD1, LOOK_LOD2]
	for i in paths.size():
		if not ResourceLoader.exists(paths[i]):
			continue
		var packed: Resource = load(paths[i])
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			inst.name = "SELVA_LOOK001_LOD%d" % i
			_world_root.add_child(inst)
			_apply_lod_range(inst, LOD_BEGIN[i], LOD_END[i])
	return true


func _apply_lod_range(n: Node, begin: float, end: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.visibility_range_begin = begin
		mi.visibility_range_end = end
		mi.visibility_range_begin_margin = 4.0
		mi.visibility_range_end_margin = 4.0
	for c in n.get_children():
		_apply_lod_range(c, begin, end)


func _hide_csg_visuals() -> void:
	# Keep CSG collision (visibility does not disable use_collision).
	if _floor_placeholder:
		_floor_placeholder.visible = false
	if _totem_placeholder:
		_totem_placeholder.visible = false


func _try_load_floor() -> void:
	if ResourceLoader.exists(FLOOR_GLB):
		var packed: Resource = load(FLOOR_GLB)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			_world_root.add_child(inst)
			if _floor_placeholder:
				_floor_placeholder.visible = false


func _try_load_totem() -> void:
	# CIN-001 greybox warp post; only when LOOK-001 GLBs are absent.
	if not ResourceLoader.exists(TOTEM_GLB):
		return
	var packed: Resource = load(TOTEM_GLB)
	if packed is PackedScene and _totem_anchor:
		var inst: Node = (packed as PackedScene).instantiate()
		_totem_anchor.add_child(inst)
		if _totem_placeholder:
			_totem_placeholder.visible = false


func _try_load_oneway() -> void:
	# PR#3 / tip 5fd45031 oneway #0: Godot (6, 1, 0), box 4×0.18×2.
	# CSGOneway keeps use_collision=true even when the placeholder is hidden
	# (visibility does not disable CSG collision). 3D oneway is not a true
	# one-way collider yet (same risk as PR#3).
	if _oneway_placeholder:
		_oneway_placeholder.visible = false
	if not ResourceLoader.exists(ONEWAY_GLB) or _oneway_anchor == null:
		return
	var packed: Resource = load(ONEWAY_GLB)
	if packed is PackedScene:
		var inst: Node = (packed as PackedScene).instantiate()
		_oneway_anchor.add_child(inst)


func _wants_capture() -> bool:
	if OS.get_environment("LOOK001_CAPTURE") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look001-capture="):
			return true
	return false


func _run_capture() -> void:
	var shot := OS.get_environment("LOOK001_CAPTURE")
	var out_dir := OS.get_environment("LOOK001_OUT")
	if out_dir == "":
		out_dir = "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look001-capture="):
			shot = a.substr("--look001-capture=".length())
		elif a.begins_with("--look001-out="):
			out_dir = a.substr("--look001-out=".length())
	if shot == "":
		return
	if not out_dir.ends_with("/"):
		out_dir += "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots: PackedStringArray
	if shot == "both" or shot == "notes":
		shots = PackedStringArray(["laguna", "dosel", "pods"])
	else:
		shots = PackedStringArray([shot])
	if _look and _look.has_method("capture_still"):
		var hp := false
		if _look.get("_hp_ok"):
			hp = true
		for s in shots:
			var tag := "totem_pods" if s == "pods" else s
			if s == "pods" and hp:
				tag = "totem_pods_v2"
			if s == "gameplay":
				tag = "gameplay" if hp else "gameplay_final"
			var stem := "HP001_E1_engine_%s.png" if hp else "LOOK-001_engine_%s.png"
			await _look.capture_still(s, "%s%s" % [out_dir, stem % tag])
	get_tree().quit()
