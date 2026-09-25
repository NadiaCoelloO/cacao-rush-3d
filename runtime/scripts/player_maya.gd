extends CharacterBody3D
## Maya controller for the Fase 2 vertical slice — movement feel ported 1:1
## from the 2D sim (src/game/sim.ts + characters.ts, id "maya").
## 2D truth: sand-vivid-dawn-sail @ 5fd450312c8e6ad0a214f35b68fd81ec2857fec3
## (oleada 3+4: T-019 mantle, T-018 proneClearsLip; run/jump numbers unchanged
## since 8e7ce7ad).
## Step order per tick, same as sim.ts updateGame(): applyRun → applyJump →
## applyGravity → resolve → (hanging ? tickMantle : ledgeGrab) → updateCrouch →
## kill (80 px below level) → followCam.
##
## Units: 2D px → metres at PX_TO_M. Scale is set by the collision box, not the
## sprite: PH=42 px ≈ Maya 1.75 m (capsule 1.8 m) → 24 px/m, T=32 px = 1.333 m,
## same scale as assets/budgets/ASSET_chunk_selva_*.md. 2D y grows downward;
## here +Y is up, so every 2D vy sign is flipped and every 2D "top" is a "feet + h".
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
## sim.ts PH_CROUCH / PH_PRONE (T-018). The standing height is read from the
## capsule (1.8 m) so the existing run/jump checks stay byte-identical.
const PH_CROUCH := 24.0 * PX_TO_M
const PH_PRONE := 14.0 * PX_TO_M
## updateCrouch: |vx| above this (18 px/s) turns a crouch into a crawl.
const CRAWL_VX := 18.0 * PX_TO_M
## proneClearsLip: probe the lip 8 px ahead of the hitbox in the held direction.
const LIP_PROBE := 8.0 * PX_TO_M
## applyRun crouchMul: dragging 0.42, crouching 0.55.
const CROUCH_MUL := 0.55
const DRAG_MUL := 0.42
## applyJump: down + jump on the ground arms a one-way drop for 0.18 s (no jump).
const DROP_T := 0.18

## sim.ts MANTLE_T (T-019): hang → pull-up → stand, smoothstep, all heroes.
const MANTLE_T := 0.28
## findLedge / ledgeSide / ledgeGrab / standOnLedge geometry (2D px).
const HAND_BELOW_TOP := 8.0 * PX_TO_M      # hand = p.y + 8
const LEDGE_DY := 26.0 * PX_TO_M           # |plat.top - hand| <= 26
const LEDGE_BEST := 28.0 * PX_TO_M         # initial bestDist
const LEDGE_IN := 22.0 * PX_TO_M           # p.x < s.x + 22 (edge up to 22 px inside)
const LEDGE_OUT := 18.0 * PX_TO_M          # p.x + p.w > s.x - 18 (edge up to 18 px away)
const HANG_OVERLAP := 6.0 * PX_TO_M        # hang x = plat.x - p.w + 6
const HANG_TOP := 8.0 * PX_TO_M            # hang y = plat.y - 8 (head 8 px above the lip)
const STAND_INSET := 2.0 * PX_TO_M         # stand x = plat.x + 2
const GRAB_MAX_RISE := 40.0 * PX_TO_M      # ledgeGrab bails while rising faster than 40 px/s
## applyJump wall kick used when leaving a hang (resolveX sets wallDir = hangDir
## every hang tick): vx = -wallDir * runSpeed * 0.95, facing flips.
const HANG_KICK_MUL := 0.95
## Probe boxes are inset so a face touching the floor/ceiling is not "blocked"
## (2D overlaps() is strict).
const PROBE_EPS := 0.01

## sim.ts followCam: look-ahead facing*48 px (lerp 4.2/s), focus 28 px above the
## hitbox centre (p.h/2, so it drops with the crouch), follow k = 1 - exp(-16 dt).
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
var _drop_timer := 0.0
var _jumps_left := 0
var _facing := 1.0
var _cam_look := 0.0
var _cam_focus := Vector3.ZERO
var _spawn: Transform3D

## Hitbox (2D p.w / p.h). Width comes from the capsule radius; heights swap
## between standing / PH_CROUCH / PH_PRONE via tryHeight.
var _pw := 0.7
var _stand_h := 1.8
var _h := 1.8
var _crouching := false
var _dragging := false

## T-019 hang/mantle state (2D hanging / hangPlat / hangDir / mantleT).
var _hanging := false
var _hang_plat := AABB()
var _hang_dir := 1
var _mantle_t := 0.0

var _stand_shape: Shape3D
var _height_shapes := {}
var _visual: Node3D

@onready var _camera: Camera3D = $Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh_placeholder: Node3D = $MeshPlaceholder


func _ready() -> void:
	_visual = _mesh_placeholder
	# Try to instance greybox glTF if present under res://models/.
	_try_attach_hero_mesh()
	_read_hitbox()
	_spawn = global_transform
	_snap_camera()


func _physics_process(delta: float) -> void:
	# Same order as sim.ts updateGame(): applyRun → applyJump → applyGravity →
	# resolveX/Y → tickMantle | ledgeGrab → updateCrouch → kill → followCam.
	_apply_run(delta)
	_apply_jump(delta)
	_apply_gravity(delta)

	if _hanging:
		# 2D: vx = vy = 0 during the hang; tickMantle owns x/y until it lands.
		_grounded = false
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		_tick_mantle(delta)
	else:
		# Greybox lane: Z lightly locked toward 0.
		velocity.z = move_toward(velocity.z, 0.0, RUN_SPEED * delta)
		move_and_slide()
		_update_ground(delta)
		if not _grounded and Input.is_action_pressed("jump") and velocity.y < 0.0:
			_ledge_grab()
	_update_crouch()

	if global_position.y < kill_y:
		_respawn()
	_follow_camera(delta)

	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


func _apply_run(delta: float) -> void:
	if _hanging:
		velocity.x = 0.0
		velocity.y = 0.0
		if Input.is_action_pressed("move_down"):
			_release_hang()
		return
	var crouch_mul := DRAG_MUL if _dragging else (CROUCH_MUL if _crouching else 1.0)
	var target := Input.get_axis("move_left", "move_right") * RUN_SPEED * crouch_mul
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
	var down := Input.is_action_pressed("move_down")
	var pressed := Input.is_action_just_pressed("jump")
	if pressed:
		_buffer_timer = BUFFER
	else:
		_buffer_timer = maxf(0.0, _buffer_timer - delta)
	_drop_timer = maxf(0.0, _drop_timer - delta)
	if down and pressed and _grounded:
		# 2D dropT: down + jump on the ground tries to fall through a one-way
		# instead of jumping. Pass-through itself belongs to the oneway wiring.
		_drop_timer = DROP_T
		_grounded = false
		_buffer_timer = 0.0

	var can_jump := (_grounded or _coyote_timer > 0.0 or _jumps_left > 0 or _hanging) and _buffer_timer > 0.0
	if can_jump:
		_buffer_timer = 0.0
		_grounded = false
		if _hanging:
			# Leaving a hang is a wall kick in 2D (resolveX flags the lip as wallDir).
			velocity.x = -_hang_dir * RUN_SPEED * HANG_KICK_MUL
			_facing = -_hang_dir
			_release_hang()
		velocity.y = JUMP_VELOCITY
		_jumps_left = maxi(0, _jumps_left - 1)

	if not Input.is_action_pressed("jump") and velocity.y > 0.0:
		velocity.y *= pow(CUT, delta / FIXED_DT)


func _apply_gravity(delta: float) -> void:
	if _hanging:
		return
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
	_drop_timer = 0.0
	_jumps_left = 0
	_release_hang()
	_crouching = false
	_dragging = false
	_set_height(_stand_h)
	_snap_camera()


# --- T-019 ledge grab + mantle (sim.ts ledgeSide / findLedge / standOnLedge /
# --- ledgeGrab / tickMantle). Solids are handled as XY AABBs like the 2D.

func _left() -> float:
	return global_position.x - _pw * 0.5


func _ledge_side(s: AABB) -> int:
	var px := _left()
	var sx := s.position.x
	var sw := s.size.x
	var near_left := px < sx + LEDGE_IN and px + _pw > sx - LEDGE_OUT
	var near_right := px + _pw > sx + sw - LEDGE_IN and px < sx + sw + LEDGE_OUT
	if near_left and near_right:
		return 1 if px + _pw * 0.5 <= sx + sw * 0.5 else -1
	if near_left:
		return 1
	if near_right:
		return -1
	return 0


## Returns {plat: AABB, dir: int} or an empty Dictionary.
func _find_ledge() -> Dictionary:
	var hand := global_position.y + _h - HAND_BELOW_TOP
	var best := AABB()
	var found := false
	var best_dir := 1
	var best_dist := LEDGE_BEST
	for s in _nearby_solids():
		var dir := _ledge_side(s)
		if dir == 0:
			continue
		var dy := absf(s.end.y - hand)
		if dy > LEDGE_DY or dy >= best_dist:
			continue
		best = s
		found = true
		best_dist = dy
		best_dir = dir
	if not found:
		return {}
	return {"plat": best, "dir": best_dir}


## Feet-origin stand position on top of the lip (2D standOnLedge).
func _stand_on_ledge(s: AABB, dir: int) -> Vector2:
	var left := s.position.x + STAND_INSET if dir > 0 else s.end.x - _pw - STAND_INSET
	return Vector2(left + _pw * 0.5, s.end.y)


## Feet-origin hang position (2D ledgeGrab: x = plat.x - p.w + 6, y = plat.y - 8).
func _hang_pos(s: AABB, dir: int) -> Vector2:
	var left := s.position.x - _pw + HANG_OVERLAP if dir > 0 else s.end.x - HANG_OVERLAP
	return Vector2(left + _pw * 0.5, s.end.y + HANG_TOP - _h)


func _ledge_grab() -> void:
	if _grounded or _hanging or velocity.y > GRAB_MAX_RISE:
		return
	var hit := _find_ledge()
	if hit.is_empty():
		return
	var plat: AABB = hit["plat"]
	var dir: int = hit["dir"]
	var stand := _stand_on_ledge(plat, dir)
	# blockedAt(stand.x + 1, stand.y, p.w - 2, p.h - 1): room to stand on the lip.
	if _blocked_rect(stand.x - _pw * 0.5 + PX_TO_M, stand.y + PX_TO_M, _pw - 2.0 * PX_TO_M, _h - PX_TO_M):
		return
	_hanging = true
	_hang_plat = plat
	_hang_dir = dir
	_facing = float(dir)
	velocity.x = 0.0
	velocity.y = 0.0
	_mantle_t = MANTLE_T
	_buffer_timer = 0.0
	var hang := _hang_pos(plat, dir)
	global_position.x = hang.x
	global_position.y = hang.y


func _tick_mantle(delta: float) -> void:
	_mantle_t -= delta
	var u := 1.0 - maxf(0.0, _mantle_t) / MANTLE_T
	var e := u * u * (3.0 - 2.0 * u)
	var hang := _hang_pos(_hang_plat, _hang_dir)
	var stand := _stand_on_ledge(_hang_plat, _hang_dir)
	global_position.x = hang.x + (stand.x - hang.x) * e
	global_position.y = hang.y + (stand.y - hang.y) * e
	velocity.x = 0.0
	velocity.y = 0.0
	if _mantle_t > 0.0:
		return
	global_position.x = stand.x
	global_position.y = stand.y
	_release_hang()
	_grounded = true
	_jumps_left = JUMPS
	_coyote_timer = COYOTE


func _release_hang() -> void:
	_hanging = false
	_hang_plat = AABB()
	_mantle_t = 0.0


# --- T-018 crouch / prone (sim.ts updateCrouch / proneClearsLip / tryHeight).

func _prone_clears_lip(dir: float) -> bool:
	if dir == 0.0:
		return false
	var feet := global_position.y
	var x := _left() + dir * LIP_PROBE
	# blockedAt(x, feet - PH_CROUCH, p.w, PH_CROUCH - 1) → lip inside the crouch box
	if not _blocked_rect(x, feet + PX_TO_M, _pw, PH_CROUCH - PX_TO_M):
		return false
	# !blockedAt(x, feet - PH_PRONE, p.w, PH_PRONE - 1) → but not the prone box
	return not _blocked_rect(x, feet + PX_TO_M, _pw, PH_PRONE - PX_TO_M)


func _update_crouch() -> void:
	var want := Input.is_action_pressed("move_down") and not Input.is_action_pressed("jump") and (_grounded or _dragging)
	if want:
		_crouching = true
		var feet := global_position.y
		var move_dir := signf(Input.get_axis("move_left", "move_right"))
		var crawl := absf(velocity.x) > CRAWL_VX \
			or _blocked_rect(_left() + PX_TO_M, feet, _pw - 2.0 * PX_TO_M, _stand_h) \
			or _prone_clears_lip(move_dir)
		_dragging = crawl
		_try_height(PH_PRONE if crawl else PH_CROUCH)
		return
	if _try_height(_stand_h):
		_crouching = false
		_dragging = false
		return
	_crouching = true
	_dragging = true
	_try_height(PH_PRONE)


## 2D tryHeight: shrinking always succeeds; growing needs headroom.
func _try_height(h: float) -> bool:
	if h > _h and _blocked_rect(_left() + PX_TO_M, global_position.y, _pw - 2.0 * PX_TO_M, h):
		return false
	_set_height(h)
	return true


func _read_hitbox() -> void:
	if _collision and _collision.shape:
		_stand_shape = _collision.shape
		if _stand_shape is CapsuleShape3D:
			_pw = (_stand_shape as CapsuleShape3D).radius * 2.0
			_stand_h = (_stand_shape as CapsuleShape3D).height
		elif _stand_shape is BoxShape3D:
			_pw = (_stand_shape as BoxShape3D).size.x
			_stand_h = (_stand_shape as BoxShape3D).size.y
	_h = _stand_h


func _set_height(h: float) -> void:
	_h = h
	if _collision:
		if is_equal_approx(h, _stand_h) and _stand_shape:
			_collision.shape = _stand_shape
		else:
			if not _height_shapes.has(h):
				var cap := CapsuleShape3D.new()
				cap.radius = minf(_pw * 0.5, h * 0.5)
				cap.height = h
				_height_shapes[h] = cap
			_collision.shape = _height_shapes[h]
		_collision.position.y = h * 0.5
	# Greybox pose: squash the placeholder to the hitbox height (held while still;
	# no crouch mesh/material yet — T-020 high-poly HOLD).
	if _visual:
		_visual.scale.y = h / _stand_h


# --- Solid queries (2D blockedAt / solids()) against the physics world.

## 2D blockedAt on a feet-up rectangle: left x, bottom y, width, height.
func _blocked_rect(left: float, bottom: float, w: float, h: float) -> bool:
	var size := Vector3(w - 2.0 * PROBE_EPS, h - 2.0 * PROBE_EPS, _pw - 2.0 * PROBE_EPS)
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var box := BoxShape3D.new()
	box.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(), Vector3(left + w * 0.5, bottom + h * 0.5, global_position.z))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## World-space AABBs of solids within ledge reach (2D solids() list, local slice).
func _nearby_solids() -> Array[AABB]:
	var reach := _pw + LEDGE_OUT + LEDGE_IN + 1.0
	var box := BoxShape3D.new()
	box.size = Vector3(_pw + 2.0 * reach, _h + 2.0 * (LEDGE_DY + HAND_BELOW_TOP) + 1.0, _pw)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(), global_position + Vector3(0.0, _h * 0.5, 0.0))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	var out: Array[AABB] = []
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var aabb := _collider_aabb(hit["collider"], int(hit["shape"]))
		if aabb.size.x > 0.0 and aabb.size.y > 0.0:
			out.append(aabb)
	return out


func _collider_aabb(collider: Object, shape_idx: int) -> AABB:
	if collider is CSGBox3D:
		var csg := collider as CSGBox3D
		return csg.global_transform * AABB(-csg.size * 0.5, csg.size)
	if collider is CSGShape3D:
		var csg := collider as CSGShape3D
		return csg.global_transform * csg.get_aabb()
	if collider is CollisionObject3D:
		var co := collider as CollisionObject3D
		var owner := co.shape_find_owner(shape_idx)
		var xf := co.global_transform * co.shape_owner_get_transform(owner)
		for i in co.shape_owner_get_shape_count(owner):
			if co.shape_owner_get_shape_index(owner, i) == shape_idx:
				return xf * _shape_aabb(co.shape_owner_get_shape(owner, i))
	return AABB()


func _shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s := (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	var pts := PackedVector3Array()
	if shape is ConcavePolygonShape3D:
		pts = (shape as ConcavePolygonShape3D).get_faces()
	elif shape is ConvexPolygonShape3D:
		pts = (shape as ConvexPolygonShape3D).points
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		aabb = aabb.expand(p)
	return aabb


# --- followCam

func _cam_target() -> Vector3:
	# 2D focus is p.h/2 - 28 px above the hitbox: standing focus unchanged, crouch lowers it.
	return global_position + Vector3(_cam_look, CAM_FOCUS_HEIGHT - (_stand_h - _h) * 0.5, 0.0)


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
			if inst is Node3D:
				_visual = inst
			if _mesh_placeholder:
				_mesh_placeholder.visible = false
			return
	# Else keep CSG/capsule placeholder (comments: replace with hero_grey.glb).
