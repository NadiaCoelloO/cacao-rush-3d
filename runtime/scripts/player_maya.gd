extends CharacterBody3D
## Maya controller for the Fase 2 vertical slice — movement feel ported 1:1
## from the 2D sim (sand-vivid-dawn-sail src/game/sim.ts + characters.ts, id "maya").
##
## Units: 2D px → metres at PX_TO_M (T=32 px, PH=42 px ≈ Maya 1.75 m → 24 px/m,
## same scale as assets/budgets/ASSET_chunk_selva_*.md). 2D y grows downward;
## here +Y is up, so every 2D vy sign is flipped.
## Do not "improve" these without updating PORT_CONTRACT / 2D truth.

const PX_TO_M := 1.0 / 24.0
## 2D FIXED_DT (types.ts). CUT is applied per sim tick, so it is rescaled to delta.
const FIXED_DT := 1.0 / 60.0

## characters.ts maya
const RUN_SPEED := 290.0 * PX_TO_M
const JUMP_VELOCITY := 720.0 * PX_TO_M
const JUMPS := 2
const GRAVITY_MUL := 1.0

## sim.ts
const GRAV_UP := 2100.0 * PX_TO_M
const GRAV_DOWN := 3400.0 * PX_TO_M
const GRAV_APEX := 1200.0 * PX_TO_M
const APEX := 80.0 * PX_TO_M
const MAX_FALL := 1100.0 * PX_TO_M
const ACCEL_G := 4600.0 * PX_TO_M
const ACCEL_A := 2800.0 * PX_TO_M
const FRICTION := 4200.0 * PX_TO_M
const COYOTE := 0.1
const BUFFER := 0.12
const CUT := 0.48
## applyRun: input below this target speed counts as "no input" (8 px/s).
const RUN_DEADZONE := 8.0 * PX_TO_M

## Cinematic-ish follow offset (behind / above Maya).
@export var camera_offset: Vector3 = Vector3(0.0, 3.2, 6.5)
@export var camera_lerp := 8.0

var _grounded := false
var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _jumps_left := 0

@onready var _camera: Camera3D = $Camera3D
@onready var _mesh_placeholder: Node3D = $MeshPlaceholder


func _ready() -> void:
	# Try to instance greybox glTF if present under res://models/.
	_try_attach_hero_mesh()


func _physics_process(delta: float) -> void:
	# Same order as sim.ts step(): applyRun → applyJump → applyGravity → move → ground.
	_apply_run(delta)
	_apply_jump(delta)
	_apply_gravity(delta)

	# Greybox lane: Z lightly locked toward 0.
	velocity.z = move_toward(velocity.z, 0.0, RUN_SPEED * delta)

	move_and_slide()
	_update_ground(delta)
	_follow_camera(delta)

	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


func _apply_run(delta: float) -> void:
	var target := Input.get_axis("move_left", "move_right") * RUN_SPEED
	var accel := ACCEL_G if _grounded else ACCEL_A
	if absf(target) > RUN_DEADZONE:
		velocity.x += signf(target - velocity.x) * accel * delta
		if absf(velocity.x) > absf(target) and signf(velocity.x) == signf(target):
			velocity.x = target
	elif _grounded:
		if absf(velocity.x) < FRICTION * delta:
			velocity.x = 0.0
		else:
			velocity.x -= signf(velocity.x) * FRICTION * delta


func _apply_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_buffer_timer = BUFFER
	else:
		_buffer_timer = maxf(0.0, _buffer_timer - delta)

	var can_jump := (_grounded or _coyote_timer > 0.0 or _jumps_left > 0) and _buffer_timer > 0.0
	if can_jump:
		_buffer_timer = 0.0
		_grounded = false
		velocity.y = JUMP_VELOCITY
		_jumps_left = maxi(0, _jumps_left - 1)

	if not Input.is_action_pressed("jump") and velocity.y > 0.0:
		velocity.y *= pow(CUT, delta / FIXED_DT)


func _apply_gravity(delta: float) -> void:
	var grav := GRAV_DOWN
	if velocity.y > 0.0:
		grav = GRAV_APEX if velocity.y < APEX else GRAV_UP
	velocity.y -= grav * GRAVITY_MUL * delta
	velocity.y = maxf(velocity.y, -MAX_FALL)


func _update_ground(delta: float) -> void:
	_grounded = is_on_floor()
	if _grounded:
		_jumps_left = JUMPS
		_coyote_timer = COYOTE
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)


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
