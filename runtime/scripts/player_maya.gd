extends CharacterBody3D
## Minimal Maya controller stub for the Fase 2 vertical slice.
## Full port from sand-vivid-dawn-sail sim.ts is next; this is feel-stub only.
##
## Feel constants DOCUMENTED as matching 2D tip pin:
##   COYOTE 0.1s · BUFFER 0.12s · CUT 0.48 (jump cut multiplier)
## Do not "improve" these without updating PORT_CONTRACT / 2D truth.

const SPEED := 6.0
const JUMP_VELOCITY := 7.5
const GRAVITY := 18.0

## Match 2D (sim.ts) — coyote time after leaving floor.
const COYOTE := 0.1
## Match 2D — jump input buffer before landing.
const BUFFER := 0.12
## Match 2D — velocity scale when jump is released early.
const CUT := 0.48

## Cinematic-ish follow offset (behind / above Maya).
@export var camera_offset: Vector3 = Vector3(0.0, 3.2, 6.5)
@export var camera_lerp := 8.0

var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _jump_held := false

@onready var _camera: Camera3D = $Camera3D
@onready var _mesh_placeholder: Node3D = $MeshPlaceholder


func _ready() -> void:
	# Try to instance greybox glTF if present under res://models/.
	_try_attach_hero_mesh()


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = COYOTE
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y -= GRAVITY * delta

	# Platformer-style: primarily X; Z lightly locked toward 0 for greybox lane.
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = axis * SPEED
	velocity.z = move_toward(velocity.z, 0.0, SPEED * delta)

	if Input.is_action_just_pressed("jump"):
		_buffer_timer = BUFFER
	else:
		_buffer_timer = maxf(_buffer_timer - delta, 0.0)

	var want_jump := _buffer_timer > 0.0 and _coyote_timer > 0.0
	if want_jump:
		velocity.y = JUMP_VELOCITY
		_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_held = true

	# Jump cut: release early → scale upward velocity (2D CUT 0.48).
	if _jump_held and not Input.is_action_pressed("jump"):
		if velocity.y > 0.0:
			velocity.y *= CUT
		_jump_held = false
	elif not Input.is_action_pressed("jump"):
		_jump_held = false

	move_and_slide()
	_follow_camera(delta)

	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


func _follow_camera(delta: float) -> void:
	if _camera == null:
		return
	var target := global_position + camera_offset
	_camera.global_position = _camera.global_position.lerp(target, clampf(camera_lerp * delta, 0.0, 1.0))
	_camera.look_at(global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)


func _try_attach_hero_mesh() -> void:
	# Preferred: copy/import assets/greybox/heroes/hero_grey.glb → res://models/hero_grey.glb
	var path := "res://models/hero_grey.glb"
	if ResourceLoader.exists(path):
		var packed: Resource = load(path)
		if packed is PackedScene:
			var inst: Node = (packed as PackedScene).instantiate()
			add_child(inst)
			if _mesh_placeholder:
				_mesh_placeholder.visible = false
			return
	# Else keep CSG/capsule placeholder (comments: replace with hero_grey.glb).
