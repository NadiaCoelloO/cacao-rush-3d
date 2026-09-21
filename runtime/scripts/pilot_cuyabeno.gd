extends Node3D
## Pilot vertical slice: world id `selva`, display name **Cuyabeno**.
## Loads greybox glTF from res://models/ when present; otherwise CSG placeholders.
## Repo source of truth: assets/greybox/ (see runtime/models/README.md).

const FLOOR_GLB := "res://models/chunk_selva_floor.glb"
const WORLD_ID := "selva"
const DISPLAY_NAME := "Cuyabeno"

@onready var _world_root: Node3D = $WorldRoot
@onready var _floor_placeholder: Node3D = $WorldRoot/FloorPlaceholder
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	if _hud_label:
		_hud_label.text = "%s  ·  id %s  ·  greybox" % [DISPLAY_NAME, WORLD_ID]
	_try_load_floor()


func _try_load_floor() -> void:
	# Preferred: import assets/greybox/worlds/selva/chunk_selva_floor.glb → res://models/
	if ResourceLoader.exists(FLOOR_GLB):
		var packed: Resource = load(FLOOR_GLB)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			_world_root.add_child(inst)
			if _floor_placeholder:
				_floor_placeholder.visible = false
			return
	# Placeholder CSGBox3D remains — replace with chunk_selva_floor.glb after import.
