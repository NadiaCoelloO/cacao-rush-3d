extends Node3D
## Pilot vertical slice: world id `selva`, display name **Cuyabeno**.
## Loads greybox glTF from res://models/ when present; otherwise CSG placeholders.
## Repo source of truth: assets/greybox/ (see runtime/models/README.md).
##
## CIN-001 totem warp Cuyabeno, ASSET OK @ d93f777 (runtime/models/totem_warp_cuyabeno.glb).
## If GLB missing locally: `git checkout main -- runtime/models/totem_warp_cuyabeno.glb`
##
## Platforms ASSET OK: chunk_selva_platform_solid (3×2×1) + chunk_selva_oneway (4×2×0.18).
## High-poly HOLD. GLBs already on main — do not rewrite via MCP.

const FLOOR_GLB := "res://models/chunk_selva_floor.glb"
const TOTEM_GLB := "res://models/totem_warp_cuyabeno.glb"
const SOLID_GLB := "res://models/chunk_selva_platform_solid.glb"
const ONEWAY_GLB := "res://models/chunk_selva_oneway.glb"
const WORLD_ID := "selva"
const DISPLAY_NAME := "Cuyabeno"

## BoxShape sizes (W×H×D) matching asset dims W×D×H with Y-up.
const SOLID_BOX := Vector3(3.0, 1.0, 2.0)
const ONEWAY_BOX := Vector3(4.0, 0.18, 2.0)

@onready var _world_root: Node3D = $WorldRoot
@onready var _floor_placeholder: Node3D = $WorldRoot/FloorPlaceholder
@onready var _totem_anchor: Node3D = $WorldRoot/TotemWarpAnchor
@onready var _totem_placeholder: Node3D = $WorldRoot/TotemWarpAnchor/TotemPlaceholder
@onready var _solid_anchor: Node3D = $WorldRoot/PlatformSolidAnchor
@onready var _solid_placeholder: Node3D = $WorldRoot/PlatformSolidAnchor/PlatformSolidPlaceholder
@onready var _oneway_anchor: Node3D = $WorldRoot/PlatformOnewayAnchor
@onready var _oneway_placeholder: Node3D = $WorldRoot/PlatformOnewayAnchor/PlatformOnewayPlaceholder
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	if _hud_label:
		_hud_label.text = "%s  ·  id %s  ·  greybox" % [DISPLAY_NAME, WORLD_ID]
	_try_load_floor()
	_try_load_totem()
	_try_load_solid()
	_try_load_oneway()


func _try_load_floor() -> void:
	if ResourceLoader.exists(FLOOR_GLB):
		var packed: Resource = load(FLOOR_GLB)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			_world_root.add_child(inst)
			if _floor_placeholder:
				_floor_placeholder.visible = false


func _try_load_totem() -> void:
	# CIN-001 greybox warp post; GLB includes Empty VFX_WarpBeam_Spawn (no beam mesh).
	if not ResourceLoader.exists(TOTEM_GLB):
		return
	var packed: Resource = load(TOTEM_GLB)
	if packed is PackedScene and _totem_anchor:
		var inst: Node = (packed as PackedScene).instantiate()
		_totem_anchor.add_child(inst)
		if _totem_placeholder:
			_totem_placeholder.visible = false


func _try_load_solid() -> void:
	# Mid platform ~x=3.5; GLB origin bottom-center, top at y=1.0.
	if not ResourceLoader.exists(SOLID_GLB):
		return
	var packed: Resource = load(SOLID_GLB)
	if packed is PackedScene and _solid_anchor:
		var inst: Node = (packed as PackedScene).instantiate()
		_solid_anchor.add_child(inst)
		if _solid_placeholder:
			_solid_placeholder.visible = false
		if not _node_has_collision(inst):
			_ensure_box_collision(_solid_anchor, SOLID_BOX)


func _try_load_oneway() -> void:
	# Thin hop toward totem (~x=6); GLB origin slab bottom; visual + greybox collision.
	if not ResourceLoader.exists(ONEWAY_GLB):
		return
	var packed: Resource = load(ONEWAY_GLB)
	if packed is PackedScene and _oneway_anchor:
		var inst: Node = (packed as PackedScene).instantiate()
		_oneway_anchor.add_child(inst)
		if _oneway_placeholder:
			_oneway_placeholder.visible = false
		if not _node_has_collision(inst):
			_ensure_box_collision(_oneway_anchor, ONEWAY_BOX)


func _node_has_collision(n: Node) -> bool:
	if n is CollisionObject3D:
		return true
	for c in n.get_children():
		if _node_has_collision(c):
			return true
	return false


func _ensure_box_collision(parent: Node3D, box_size: Vector3) -> void:
	# Mesh origin is bottom-center; BoxShape is center-origin → lift by half height.
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = Vector3(0.0, box_size.y * 0.5, 0.0)
	body.add_child(col)
	parent.add_child(body)
