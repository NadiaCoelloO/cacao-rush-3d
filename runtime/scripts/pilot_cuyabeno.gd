extends Node3D
## Pilot vertical slice: world id `selva`, display name **Cuyabeno**.
## Loads greybox glTF from res://models/ when present; otherwise CSG placeholders.
## Repo source of truth: assets/greybox/ (see runtime/models/README.md).
##
## CIN-001 totem warp Cuyabeno, ASSET OK @ d93f777 (runtime/models/totem_warp_cuyabeno.glb).
## If GLB missing locally: `git checkout main -- runtime/models/totem_warp_cuyabeno.glb`

const FLOOR_GLB := "res://models/chunk_selva_floor.glb"
const TOTEM_GLB := "res://models/totem_warp_cuyabeno.glb"
const WORLD_ID := "selva"
const DISPLAY_NAME := "Cuyabeno"

@onready var _world_root: Node3D = $WorldRoot
@onready var _floor_placeholder: Node3D = $WorldRoot/FloorPlaceholder
@onready var _totem_anchor: Node3D = $WorldRoot/TotemWarpAnchor
@onready var _totem_placeholder: Node3D = $WorldRoot/TotemWarpAnchor/TotemPlaceholder
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	if _hud_label:
		_hud_label.text = "%s  ·  id %s  ·  greybox" % [DISPLAY_NAME, WORLD_ID]
	_try_load_floor()
	_try_load_totem()


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
