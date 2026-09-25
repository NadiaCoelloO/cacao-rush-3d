extends CharacterBody3D
## Maya controller for the Fase 2 vertical slice — movement feel ported 1:1
## from the 2D sim (src/game/sim.ts + characters.ts, id "maya").
## Truth pin: sand-vivid-dawn-sail @ f278dd9 (not readable by the cloud agent);
## values transcribed from NadiaCoelloO/Cacao.Game @ 77e55b5 src/game — re-diff
## against the pin when it is reachable.
##
## Units: 2D px → metres at PX_TO_M. Scale is set by the collision box, not the
## sprite: PH=42 px ≈ Maya 1.75 m (capsule 1.8 m) → 24 px/m, T=32 px = 1.333 m,
## same scale as assets/budgets/ASSET_chunk_selva_*.md. 2D y grows downward;
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

## sim.ts PH (player hitbox height); Maya's feet are at the body origin.
const PH := 42.0 * PX_TO_M

## sim.ts followCam: look-ahead facing*48 px (lerp 4.2/s), focus 28 px above the
## hitbox centre, follow k = 1 - exp(-16 dt).
const CAM_LOOK_AHEAD := 48.0 * PX_TO_M
const CAM_LOOK_RATE := 4.2
const CAM_FOCUS_HEIGHT := PH * 0.5 + 28.0 * PX_TO_M
const CAM_FOLLOW_RATE := 16.0

## Camera position relative to the followCam focus. 2D shows 540 px (22.5 m) of
## height; at fov 50 a 12 m dolly frames ~11.2 m, i.e. a full jump plus headroom.
@export var camera_offset: Vector3 = Vector3(0.0, 1.0, 12.0)
## sim.ts kills when the player drops 80 px below the level; greybox floor top is y=0.
@export var kill_y := -80.0 * PX_TO_M

var _grounded := false
var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _jumps_left := 0
var _facing := 1.0
var _cam_look := 0.0
var _cam_focus := Vector3.ZERO
var _spawn: Transform3D

@onready var _camera: Camera3D = $Camera3D
@onready var _mesh_placeholder: Node3D = $MeshPlaceholder


func _ready() -> void:
	# Try to instance greybox glTF if present under res://models/.
	_try_attach_hero_mesh()
	_spawn = global_transform
	_snap_camera()


func _physics_process(delta: float) -> void:
	# Same order as sim.ts step(): applyRun → applyJump → applyGravity → move → ground.
	_apply_run(delta)
	_apply_jump(delta)
	_apply_gravity(delta)

	# Greybox lane: Z lightly locked toward 0.
	velocity.z = move_toward(velocity.z, 0.0, RUN_SPEED * delta)

	move_and_slide()
	_update_ground(delta)
	if global_position.y < kill_y:
		_respawn()
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
		_facing = signf(target)
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


func _respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	_grounded = false
	_coyote_timer = 0.0
	_buffer_timer = 0.0
	_jumps_left = 0
	_snap_camera()


func _cam_target() -> Vector3:
	return global_position + Vector3(_cam_look, CAM_FOCUS_HEIGHT, 0.0)


func _snap_camera() -> void:
	_cam_look = _facing * CAM_LOOK_AHEAD
	_cam_focus = _cam_target()
	if _camera:
		_camera.global_position = _cam_focus + camera_offset
		_camera.look_at(_cam_focus, Vector3.UP)


func _follow_camera(delta: float) -> void:
	if _camera == null:
		return
	_cam_look += (_facing * CAM_LOOK_AHEAD - _cam_look) * minf(1.0, CAM_LOOK_RATE * delta)
	_cam_focus = _cam_focus.lerp(_cam_target(), 1.0 - exp(-CAM_FOLLOW_RATE * delta))
	_camera.global_position = _cam_focus + camera_offset
	_camera.look_at(_cam_focus, Vector3.UP)


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
