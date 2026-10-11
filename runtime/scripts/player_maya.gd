extends CharacterBody3D
## Shared kit for Maya, Teko, Luma, Rok and Nix. Maya is the default preset
## (`hero_id = "maya"`); there is no per-hero movement branch.
## 2D truth: sand-vivid-dawn-sail @ 5fd45031 src/game/sim.ts + characters.ts
## (READ ONLY). coyote 0.1, buffer 0.12, cut 0.48, probeWall, wallDir,
## wallLock 0.14 and vx = -wallDir * runSpeed * 0.95 match that pin.
## `wallCoyote` is initialised to 0 and never read or written there, so it
## stays 0 — no grace period was invented. Mantle / proneClearsLip are the
## oleada-4 port already in this file. Nix climb
## (`character.id == "nix" && jumpHeld`, sim.ts ~1592) is NOT implemented.
## Hero powers (dash, Teko's third jump, glide, pound, climb) are latent data
## plus `power_*` slots. `_tick_powers` is the only place a later phase hangs
## them; the kit leaves every slot off.
##
## Step order per tick, same as sim.ts updateGame(): wallLock tick → applyRun →
## applyJump → _tick_powers → applyGravity → applyWind → resolve → wall sense →
## (hanging ? tickMantle : ledgeGrab) → updateCrouch → kill → followCam.
## Leaving a mover (sim.ts resolveX:395 adds riding.dx to position only;
## resolveY:441-442 clears riding the same tick) does not copy its velocity.
## applyWind adds vx/vy only — it never writes position.
##
## Units: 2D px → metres at PX_TO_M. Scale is set by the collision box, not the
## sprite: PH=42 px ≈ Maya 1.75 m (capsule 1.8 m) → 24 px/m, T=32 px = 1.333 m,
## same scale as assets/budgets/ASSET_chunk_selva_*.md. 2D y grows downward;
## here +Y is up, so every 2D vy sign is flipped and every 2D "top" is a "feet + h".
## Do not "improve" these without updating PORT_CONTRACT / 2D truth.

const PX_TO_M := 1.0 / 24.0
## 2D FIXED_DT (types.ts). CUT is applied per sim tick, so it is rescaled to delta.
const FIXED_DT := 1.0 / 60.0

## characters.ts shared kit. `jumps` is the kit pool (2). Teko's third jump is
## `latent_extra_jumps` and is not added until a later phase sets power_extra_jumps.
## latent_climb / latent_glide / latent_dash / latent_pound are the same kind of slot.
const HERO_KIT := {
	"maya": {"run_px": 290.0, "jump_px": 720.0, "grav": 1.0, "jumps": 2, "latent_extra_jumps": 0, "latent_dash": true, "latent_glide": false, "latent_pound": false, "latent_climb": false, "color": Color("3d8a72")},
	"teko": {"run_px": 300.0, "jump_px": 860.0, "grav": 0.96, "jumps": 2, "latent_extra_jumps": 1, "latent_dash": false, "latent_glide": false, "latent_pound": false, "latent_climb": false, "color": Color("c45c26")},
	"luma": {"run_px": 280.0, "jump_px": 700.0, "grav": 0.9, "jumps": 2, "latent_extra_jumps": 0, "latent_dash": false, "latent_glide": true, "latent_pound": false, "latent_climb": false, "color": Color("2f7d62")},
	"rok": {"run_px": 250.0, "jump_px": 680.0, "grav": 1.15, "jumps": 2, "latent_extra_jumps": 0, "latent_dash": false, "latent_glide": false, "latent_pound": true, "latent_climb": false, "color": Color("8a5a3c")},
	"nix": {"run_px": 295.0, "jump_px": 740.0, "grav": 1.0, "jumps": 2, "latent_extra_jumps": 0, "latent_dash": false, "latent_glide": false, "latent_pound": false, "latent_climb": true, "color": Color("5a3488")},
}
@export var hero_id := "maya"
## Active stats. Initialisers are Maya so a tick before _ready still matches the 54 checks.
var _run_speed := 290.0 * PX_TO_M
var _jump_velocity := 720.0 * PX_TO_M
var _jumps := 2
var _gravity_mul := 1.0
var _hero_color := Color("3d8a72")
var _latent_extra_jumps := 0
## Later phase turns these on. The kit never does.
var power_extra_jumps := 0
var power_climb := false
var power_glide := false
var power_dash := false
var power_pound := false

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
## applyJump wall kick (sim.ts): vx = -wallDir * runSpeed * 0.95, facing flips,
## wallLock = 0.14. The same mul is the hang-leave kick already covered by the
## 54 checks (resolveX used to flag the lip as wallDir during a hang).
const HANG_KICK_MUL := 0.95
const WALL_LOCK := 0.14
## probeWall (sim.ts): dir>0 probes x = right+1, w=4; dir<0 probes x = left-5, w=4;
## vertical span is feet+8 px .. head-10 px (h-18). |moveX| > 0.2 to arm it.
const PROBE_AHEAD := 1.0 * PX_TO_M
const PROBE_BACK := 5.0 * PX_TO_M
const PROBE_W := 4.0 * PX_TO_M
const PROBE_FEET := 8.0 * PX_TO_M
const PROBE_SHRINK := 18.0 * PX_TO_M
const WALL_INPUT := 0.2
## Probe boxes are inset so a face touching the floor/ceiling is not "blocked"
## (2D overlaps() is strict).
const PROBE_EPS := 0.01

## T-020 (2D PR #12, recolor only): Maya's crouch-1..6 / crawl-1..6 outfit is
## cream/tan, not olive. Greybox equivalent: while crouching / crawling the
## hero_grey outfit colour is overridden with the average opaque outfit colour
## sampled from the 2D crouch-1 / crawl-1 PNGs; standing restores the untouched
## greybox materials. Runtime override only — no crouch mesh, high-poly HOLD.
## hero_grey.glb (assets 402121f, ASSET OK) exposes stable slots Maya_Body /
## Maya_Hair / Maya_Pack: only the outfit slots are tinted (hair unchanged, as
## in 2D). Maya_Pack (satchel) is an accessory, not outfit, in the 2D recolor —
## add it to TINT_OUTFIT_SLOTS if Identidad reclassifies it. A hero instance
## without named slots (older glb, CSG fallback) is tinted whole.
## Identidad PASA (greybox T-020, 2026-09-26): both tints sit in the ~28° hue
## band (crouch 27.9°, crawl 28.3°) — never olive (≈60–90°). Retune only with
## a new 2D sample and Identidad re-check.
enum PoseTint { STAND, CROUCH, CRAWL }
const TINT_CROUCH := Color(138.0 / 255.0, 99.0 / 255.0, 65.0 / 255.0)
const TINT_CRAWL := Color(148.0 / 255.0, 110.0 / 255.0, 76.0 / 255.0)
const TINT_HUE_DEG := 28.0
const TINT_HUE_BAND_DEG := 4.0
const TINT_OUTFIT_SLOTS: Array[String] = ["Maya_Body"]

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
## sim.ts player.wallDir / wallLock (sand-vivid-dawn-sail @ 5fd45031).
## wallCoyote exists on the 2D struct and is never updated, so it stays 0.
var _wall_dir := 0
var _wall_lock := 0.0
var _wall_coyote := 0.0
## Greybox pose id: stand / wall / bounce / hang / crouch / drag.
var pose_id := "stand"
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

## T-020 tint state: every material slot under _visual (MeshInstance3D surface
## or CSG primitive) with the material it had at _ready, plus the tinted
## duplicates keyed by pose → source material.
var _pose_tint := PoseTint.STAND
var _tint_slots: Array[Dictionary] = []
var _tint_cache := {}

@onready var _camera: Camera3D = $Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh_placeholder: Node3D = $MeshPlaceholder


func _ready() -> void:
	# Godot's default ADD_VELOCITY copies the platform into velocity on jump.
	# 2D riding is a position delta only, dropped the frame you leave.
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	_visual = _mesh_placeholder
	# Try to instance greybox glTF if present under res://models/.
	_try_attach_hero_mesh()
	_collect_tint_slots(_visual)
	_read_hitbox()
	_build_pose_rig()
	_apply_hero_stats()
	_spawn = global_transform
	_snap_camera()


func _apply_hero_stats() -> void:
	var id := hero_id if HERO_KIT.has(hero_id) else "maya"
	hero_id = id
	var s: Dictionary = HERO_KIT[id]
	_run_speed = float(s["run_px"]) * PX_TO_M
	_jump_velocity = float(s["jump_px"]) * PX_TO_M
	_gravity_mul = float(s["grav"])
	# power_extra_jumps is the later-phase latch (Teko's third jump). Default 0.
	_jumps = int(s["jumps"]) + power_extra_jumps
	_latent_extra_jumps = int(s["latent_extra_jumps"])
	_hero_color = s["color"]
	_tint_pose_arms()


func _physics_process(delta: float) -> void:
	# sim.ts tickDash decrements wallLock before applyRun. A lock set by the
	# jump later this tick is not consumed until the next tick.
	_wall_lock = maxf(0.0, _wall_lock - delta)
	# Same order as sim.ts updateGame(): applyRun → applyJump → (powers) →
	# applyGravity → applyWind → resolve → wall sense → tickMantle | ledgeGrab → updateCrouch.
	_apply_run(delta)
	_apply_jump(delta)
	_tick_powers(delta)
	_apply_gravity(delta)
	_apply_wind(delta)

	if _hanging:
		# 2D: vx = vy = 0 during the hang; tickMantle owns x/y until it lands.
		_grounded = false
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		_wall_dir = 0
		_tick_mantle(delta)
	else:
		# Greybox lane: Z lightly locked toward 0.
		velocity.z = move_toward(velocity.z, 0.0, _run_speed * delta)
		move_and_slide()
		_update_ground(delta)
		_sense_wall()
		if not _grounded and Input.is_action_pressed("jump") and velocity.y < 0.0:
			_ledge_grab()
	_update_crouch()
	_apply_pose()

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
	var target := Input.get_axis("move_left", "move_right") * _run_speed * crouch_mul
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

	# wallDir joins the 2D canJump set. Climbing is a Nix power and is not in the kit.
	var can_jump := (_grounded or _coyote_timer > 0.0 or _jumps_left > 0 or _wall_dir != 0 or _hanging) and _buffer_timer > 0.0
	if can_jump:
		_buffer_timer = 0.0
		_grounded = false
		if _hanging:
			# Leaving a hang is a wall kick in 2D (resolveX flags the lip as wallDir).
			velocity.x = -_hang_dir * _run_speed * HANG_KICK_MUL
			_facing = -_hang_dir
			_release_hang()
		elif _wall_dir != 0:
			# sim.ts applyJump: airborne + wallDir → kick, then wallLock 0.14.
			velocity.x = -float(_wall_dir) * _run_speed * HANG_KICK_MUL
			_facing = -float(_wall_dir)
			_wall_lock = WALL_LOCK
			_wall_dir = 0
		velocity.y = _jump_velocity
		_jumps_left = maxi(0, _jumps_left - 1)

	if not Input.is_action_pressed("jump") and velocity.y > 0.0:
		velocity.y *= pow(CUT, delta / FIXED_DT)


func _apply_gravity(delta: float) -> void:
	if _hanging:
		return
	var grav := GRAV_DOWN
	if velocity.y > 0.0:
		grav = GRAV_APEX if velocity.y < APEX else GRAV_UP
	velocity.y -= grav * _gravity_mul * delta
	velocity.y = maxf(velocity.y, -MAX_FALL)


## sim.ts applyWind (after gravity, before resolve). vx/ay are px/s, ay downward.
## mass = max(0.72, gravityMul). Velocity only: llamaShove is what writes x.
## Zones are group "wind" with meta vx, ay and either meta aabb or a BoxShape.
func _apply_wind(delta: float) -> void:
	var mass := maxf(0.72, _gravity_mul)
	var body := _body_rect()
	for node in get_tree().get_nodes_in_group("wind"):
		if not _wind_hits(body, node):
			continue
		var vx_px := float(node.get_meta("vx", 0.0))
		var ay_px := float(node.get_meta("ay", 0.0))
		velocity.x += (vx_px / mass) * PX_TO_M * delta
		velocity.y -= (ay_px / mass) * PX_TO_M * delta


func _body_rect() -> Rect2:
	return Rect2(global_position.x - _pw * 0.5, global_position.y, _pw, _h)


func _wind_hits(body: Rect2, node: Node) -> bool:
	var zone := Rect2()
	var have := false
	if node.has_meta("aabb"):
		var box: AABB = node.get_meta("aabb")
		zone = Rect2(box.position.x, box.position.y, box.size.x, box.size.y)
		have = true
	else:
		var shape_node := node.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node and shape_node.shape is BoxShape3D:
			var box_shape := shape_node.shape as BoxShape3D
			var origin: Vector3 = shape_node.global_position
			var size := box_shape.size
			zone = Rect2(origin.x - size.x * 0.5, origin.y - size.y * 0.5, size.x, size.y)
			have = true
	if not have or zone.size.x <= 0.0 or zone.size.y <= 0.0:
		return false
	return body.intersects(zone)


func _update_ground(delta: float) -> void:
	_grounded = is_on_floor()
	if _grounded:
		_jumps_left = _jumps
		_coyote_timer = COYOTE
		_wall_dir = 0
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)


## Later phase writes the body. Call site is the 2D nix-climb slot (after jump,
## before gravity). power_climb / power_glide / power_dash / power_pound /
## power_extra_jumps stay false/0, so this is a no-op.
func _tick_powers(_delta: float) -> void:
	pass


## resolveX wallDir, then probeWall, then wallLock forces wallDir back to 0.
## One-ways are not solids (sim.ts solids() skips kind == "oneway").
func _sense_wall() -> void:
	if _grounded or _wall_lock > 0.0 or _hanging:
		_wall_dir = 0
		return
	_wall_dir = _wall_dir_from_slides()
	if _wall_dir == 0:
		var move := Input.get_axis("move_left", "move_right")
		if absf(move) > WALL_INPUT:
			_wall_dir = _probe_wall(signf(move))


func _wall_dir_from_slides() -> int:
	var best := 0
	var best_pen := 0.0
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if _collider_is_oneway(hit.get_collider()):
			continue
		var n := hit.get_normal()
		if absf(n.x) < 0.6 or absf(n.y) > 0.45:
			continue
		var dir := 1 if n.x < 0.0 else -1
		if absf(n.x) > best_pen:
			best_pen = absf(n.x)
			best = dir
	return best


## Returns 1, -1, or 0. Skips a solid the feet are already standing on (onTopOf).
func _probe_wall(dir: float) -> int:
	if dir == 0.0:
		return 0
	var left := global_position.x + _pw * 0.5 + PROBE_AHEAD if dir > 0.0 else global_position.x - _pw * 0.5 - PROBE_BACK
	var bottom := global_position.y + PROBE_FEET
	var height := _h - PROBE_SHRINK
	if height <= PROBE_EPS:
		return 0
	for s in _solids_in_rect(left, bottom, PROBE_W, height):
		if _on_top_of(s):
			continue
		return 1 if dir > 0.0 else -1
	return 0


func _on_top_of(s: AABB) -> bool:
	var feet := global_position.y
	var top := s.end.y
	var slop := 5.0 * PX_TO_M
	if feet > top + slop or feet < top - 2.0 * PX_TO_M:
		return false
	var inset := PX_TO_M
	return _left() + _pw > s.position.x + inset and _left() < s.end.x - inset


func _respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	_grounded = false
	_coyote_timer = 0.0
	_buffer_timer = 0.0
	_drop_timer = 0.0
	_jumps_left = 0
	_wall_dir = 0
	_wall_lock = 0.0
	_wall_coyote = 0.0
	_release_hang()
	_crouching = false
	_dragging = false
	_set_height(_stand_h)
	_refresh_pose_tint()
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
	_jumps_left = _jumps
	_coyote_timer = COYOTE
	_wall_dir = 0


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
		_refresh_pose_tint()
		return
	if _try_height(_stand_h):
		_crouching = false
		_dragging = false
		_refresh_pose_tint()
		return
	_crouching = true
	_dragging = true
	_try_height(PH_PRONE)
	_refresh_pose_tint()


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
	# no crouch mesh — high-poly HOLD). The T-020 cream/tan tint is applied by
	# _refresh_pose_tint once updateCrouch has settled the crouch/drag flags.
	if _visual:
		_visual.scale.y = h / _stand_h


# --- T-020 crouch / crawl cream-tan greybox tint (2D PR #12, recolor only).

## Pose the tint should show for the current updateCrouch flags.
func _refresh_pose_tint() -> void:
	var pose := PoseTint.STAND
	if _dragging:
		pose = PoseTint.CRAWL
	elif _crouching:
		pose = PoseTint.CROUCH
	_set_pose_tint(pose)


func _set_pose_tint(pose: PoseTint) -> void:
	if pose == _pose_tint:
		return
	_pose_tint = pose
	for slot in _tint_slots:
		var node: Node = slot["node"]
		if not is_instance_valid(node):
			continue
		var mat: Material = slot["base"] if pose == PoseTint.STAND else _tinted_material(slot["source"], pose)
		if slot["surface"] >= 0:
			(node as MeshInstance3D).set_surface_override_material(slot["surface"], mat)
		else:
			node.set("material", mat)


## Albedo for a pose, or the untouched greybox when standing.
func pose_tint_color() -> Color:
	match _pose_tint:
		PoseTint.CROUCH:
			return TINT_CROUCH
		PoseTint.CRAWL:
			return TINT_CRAWL
	return Color(1.0, 1.0, 1.0)


## Records the material slots to tint under `visual`: MeshInstance3D surfaces
## keep their override (usually none — the glTF material lives on the mesh) and
## CSG primitives keep their `material`, so STAND puts back exactly what was
## there. If the visual has TINT_OUTFIT_SLOTS materials only those are kept.
func _collect_tint_slots(visual: Node) -> void:
	var found: Array[Dictionary] = []
	_walk_tint_slots(visual, found)
	var outfit := found.filter(func(s: Dictionary) -> bool: return _is_outfit_slot(s["source"]))
	_tint_slots.append_array(outfit if not outfit.is_empty() else found)


func _walk_tint_slots(node: Node, out: Array[Dictionary]) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var count := mi.mesh.get_surface_count() if mi.mesh else 0
		for i in count:
			var base: Material = mi.get_surface_override_material(i)
			var source: Material = base if base else mi.mesh.surface_get_material(i)
			out.append({"node": mi, "surface": i, "base": base, "source": source})
	elif node is CSGPrimitive3D and "material" in node:
		var base: Material = node.get("material")
		out.append({"node": node, "surface": -1, "base": base, "source": base})
	for child in node.get_children():
		_walk_tint_slots(child, out)


func _is_outfit_slot(source: Material) -> bool:
	if source == null:
		return false
	for slot in TINT_OUTFIT_SLOTS:
		if source.resource_name.begins_with(slot):
			return true
	return false


## Duplicate of `source` carrying the pose colour (roughness etc. kept), or a
## fresh StandardMaterial3D when the slot had none. Shared per pose + source.
## The Blender greybox exports "unlit Emission" (albedo black, emission = flat
## colour), so an emissive source is tinted through its emission; anything else
## through albedo.
func _tinted_material(source: Material, pose: PoseTint) -> Material:
	var key := "%d:%d" % [pose, source.get_instance_id() if source else 0]
	if _tint_cache.has(key):
		return _tint_cache[key]
	var tint := TINT_CRAWL if pose == PoseTint.CRAWL else TINT_CROUCH
	var tinted: BaseMaterial3D
	if source is BaseMaterial3D:
		tinted = (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	else:
		tinted = StandardMaterial3D.new()
	if tinted.emission_enabled:
		tinted.emission_texture = null
		tinted.emission = tint
	else:
		tinted.albedo_texture = null
		tinted.albedo_color = tint
	_tint_cache[key] = tinted
	return tinted


## The flat colour a greybox material shows (emission for the unlit export,
## albedo otherwise). Used by the headless check.
static func flat_color(mat: Material) -> Color:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		return bm.emission if bm.emission_enabled else bm.albedo_color
	return Color(0, 0, 0, 0)


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
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if not _collider_is_oneway(hit["collider"]):
			return true
	return false


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
		if _collider_is_oneway(hit["collider"]):
			continue
		var aabb := _collider_aabb(hit["collider"], int(hit["shape"]))
		if aabb.size.x > 0.0 and aabb.size.y > 0.0:
			out.append(aabb)
	return out


func _solids_in_rect(left: float, bottom: float, w: float, h: float) -> Array[AABB]:
	var out: Array[AABB] = []
	var size := Vector3(w - 2.0 * PROBE_EPS, h - 2.0 * PROBE_EPS, _pw - 2.0 * PROBE_EPS)
	if size.x <= 0.0 or size.y <= 0.0:
		return out
	var box := BoxShape3D.new()
	box.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis(), Vector3(left + w * 0.5, bottom + h * 0.5, global_position.z))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if _collider_is_oneway(hit["collider"]):
			continue
		var aabb := _collider_aabb(hit["collider"], int(hit["shape"]))
		if aabb.size.x > 0.0 and aabb.size.y > 0.0:
			out.append(aabb)
	return out


## 2D solids() drops kind == "oneway" (sand-vivid-dawn-sail @ 5fd45031).
## Bodies opt in with group "oneway" or meta kind. The Cuyabeno CSGOneway
## carries both, so mantle skips that plank.
func _collider_is_oneway(collider: Object) -> bool:
	var n := collider as Node
	var hops := 0
	while n != null and hops < 4:
		if n.is_in_group("oneway"):
			return true
		if n.has_meta("kind") and String(n.get_meta("kind")) == "oneway":
			return true
		n = n.get_parent()
		hops += 1
	return false


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


# --- Greybox poses (no high-poly). Side camera looks along Z, so a Z lean
# reads in the gameplay plane: wall stick, bounce, hang, drag.

var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D


func _build_pose_rig() -> void:
	_arm_l = _make_arm("PoseArmL")
	_arm_r = _make_arm("PoseArmR")
	add_child(_arm_l)
	add_child(_arm_r)


func _make_arm(node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.42, 0.12)
	mi.mesh = box
	return mi


func _tint_pose_arms() -> void:
	if _arm_l == null or _arm_r == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _hero_color
	mat.emission_enabled = true
	mat.emission = _hero_color
	mat.emission_energy_multiplier = 0.45
	mat.roughness = 0.85
	_arm_l.material_override = mat
	_arm_r.material_override = mat


func _apply_pose() -> void:
	var id := "stand"
	if _hanging:
		id = "hang"
	elif _dragging:
		id = "drag"
	elif _crouching:
		id = "crouch"
	elif _wall_lock > 0.0:
		id = "bounce"
	elif _wall_dir != 0:
		id = "wall"
	pose_id = id
	if _visual:
		var lean := 0.0
		var yoff := 0.0
		match id:
			"wall":
				lean = -float(_wall_dir) * 24.0
			"bounce":
				lean = _facing * 32.0
			"hang":
				lean = float(_hang_dir) * 10.0
				yoff = -0.22
			"drag":
				lean = _facing * 76.0
				yoff = 0.12
		_visual.rotation_degrees.z = lean
		_visual.position.y = yoff
	_pose_arms(id)


func _pose_arms(id: String) -> void:
	if _arm_l == null or _arm_r == null:
		return
	var show := id == "wall" or id == "bounce" or id == "hang" or id == "drag"
	_arm_l.visible = show
	_arm_r.visible = show
	if not show:
		return
	var sign_face := 1.0 if _facing >= 0.0 else -1.0
	match id:
		"wall":
			# Both arms into the wall.
			var into := -float(_wall_dir)
			_arm_l.position = Vector3(into * 0.42, _h * 0.72, 0.08)
			_arm_r.position = Vector3(into * 0.42, _h * 0.48, -0.08)
			_arm_l.rotation_degrees = Vector3(0, 0, into * 70.0)
			_arm_r.rotation_degrees = Vector3(0, 0, into * 70.0)
		"bounce":
			_arm_l.position = Vector3(sign_face * 0.28, _h * 0.7, 0.08)
			_arm_r.position = Vector3(-sign_face * 0.22, _h * 0.55, -0.08)
			_arm_l.rotation_degrees = Vector3(0, 0, -sign_face * 50.0)
			_arm_r.rotation_degrees = Vector3(0, 0, sign_face * 30.0)
		"hang":
			var into := float(_hang_dir)
			_arm_l.position = Vector3(into * 0.28, _h + 0.05, 0.06)
			_arm_r.position = Vector3(into * 0.28, _h - 0.02, -0.06)
			_arm_l.rotation_degrees = Vector3(0, 0, into * 80.0)
			_arm_r.rotation_degrees = Vector3(0, 0, into * 80.0)
		"drag":
			_arm_l.position = Vector3(sign_face * 0.48, 0.22, 0.06)
			_arm_r.position = Vector3(sign_face * 0.36, 0.16, -0.06)
			_arm_l.rotation_degrees = Vector3(0, 0, sign_face * 80.0)
			_arm_r.rotation_degrees = Vector3(0, 0, sign_face * 80.0)


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
