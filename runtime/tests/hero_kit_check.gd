extends SceneTree
## Shared-kit check: wall-jump, zigzag, ledge, mantle, crouch, prone/crawl,
## coyote, jump buffer, raft leave and wind — one case per hero. Expected
## numbers are the 2D sim (sand-vivid-dawn-sail @ 5fd45031 characters.ts +
## sim.ts), scaled 24 px = 1 m. Maya's own 54 expectations stay in
## maya_feel_check.gd and are not edited here.
## Raft leave: qa/t-pr8/raft_leave.gd is not in this repo (404 on every
## branch). The case is the contract that file was meant to lock — sim.ts
## resolveX:395 adds riding.dx to position only, resolveY:441-442 clears
## riding the same tick — so a no-steer jump keeps the body's own vx.
##   godot --headless --fixed-fps 60 --path runtime -s res://tests/hero_kit_check.gd

const PX := 24.0
const PLAYER_SCRIPT := preload("res://scripts/player_maya.gd")
const DT := 1.0 / 60.0
const GRAV_UP := 2100.0
const BODY_R := 0.35

## 2D characters.ts run / jump / gravity. Kit jumps stay 2 (Teko's third is latent).
const HEROES := {
	"maya": {"run": 290.0, "jump": 720.0, "grav": 1.0},
	"teko": {"run": 300.0, "jump": 860.0, "grav": 0.96},
	"luma": {"run": 280.0, "jump": 700.0, "grav": 0.9},
	"rok": {"run": 250.0, "jump": 680.0, "grav": 1.15},
	"nix": {"run": 295.0, "jump": 740.0, "grav": 1.0},
}

## Last airborne frame index (0 = the frame that leaves the floor) whose applyJump
## still sees coyote > 0. coyote starts at 0.1 and is decremented by 1/60 at the
## end of each air frame. In IEEE-754, 0.1 - 6/60 is ~2e-17, so `coyote > 0`
## (the 2D test) still passes on index 6 and fails on index 7.
const COYOTE_LAST := 6.0
## sim.ts BUFFER 0.12. maya_feel_check already locks Maya at "8 early works, 9 does not".
const BUFFER_TICKS := 8.0
## Raft travels +3 m/s (72 px/s). Inheriting that on leave fails the 0.5 px band.
const RAFT_SPEED := 3.0
const RAFT_X := 160.0
## applyWind sample. vx is px/s; mass = max(0.72, gravityMul). Two airborne
## ticks so the position delta is the second tick's velocity times dt, not
## that plus another copy of the impulse (the Río position push).
const WIND_VX := 240.0
const WIND_X := 200.0

const TALL_X := -61.5
const TALL_TOP := 5.5
const LIP_X := -78.5
const ONEWAY_X := 40.0
const ONEWAY_TOP := 3.2

var _fails := 0
var _held := false
var _down := false
var _move := 0.0
var _p: CharacterBody3D
var _root: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _tick()
	_build_world()
	var pf0 := Engine.get_physics_frames()
	for i in 10:
		await _tick()
	_expect("harness: 1 physics tick per frame", float(Engine.get_physics_frames() - pf0), 10.0, 0.0)

	for hero in ["maya", "teko", "luma", "rok", "nix"]:
		_p.hero_id = hero
		_p._apply_hero_stats()
		var spec: Dictionary = HEROES[hero]
		var run := float(spec["run"])
		var jump := float(spec["jump"])
		var grav := float(spec["grav"])
		var kick := run * 0.95
		var vy := jump - GRAV_UP * grav * DT
		print("-- %s  run %.0f  jump %.0f  grav %.2f" % [hero, run, jump, grav])

		var wall := await _wall_jump()
		_expect("%s wall-jump vx = -wallDir*run*0.95" % hero, wall.x, kick, 0.5)
		_expect("%s wall-jump vy = jump - gravUp tick" % hero, wall.y, vy, 0.5)
		_expect("%s wall-jump pose bounce + lock 0.14" % hero, wall.z, 1.0, 0.0)

		var zig := await _zigzag()
		_expect("%s zigzag second kick reverses vx" % hero, zig.x, kick, 0.5)
		_expect("%s zigzag climbs (dy px)" % hero, zig.y, 1.0, 0.0)

		var ledge := await _ledge_grab_metrics()
		_expect("%s ledge hang head 8 px above lip" % hero, ledge.x, 8.0, 0.05)
		_expect("%s ledge pose hang" % hero, ledge.y, 1.0, 0.0)

		var mantle := await _mantle_metrics()
		_expect("%s mantle 17 ticks, stand +2 px, skips oneway" % hero, mantle, 2.0, 0.05)

		_expect("%s crouch still → 24 px" % hero, await _crouch_height(), 24.0, 0.01)
		var crawl := await _crawl_speed()
		_expect("%s prone/crawl speed 0.42*run" % hero, crawl.x, run * 0.42, 0.05)
		_expect("%s prone under 18 px lip + drag pose" % hero, crawl.y, 1.0, 0.0)

		_expect("%s coyote last air tick" % hero, await _coyote_last(), COYOTE_LAST, 0.0)
		_expect("%s jump buffer ticks" % hero, await _buffer_window(), BUFFER_TICKS, 0.0)

		var raft := await _raft_leave()
		_expect("%s raft leave vx stays 0" % hero, raft.x, 0.0, 0.5)
		_expect("%s raft leave vy = jump - gravUp tick" % hero, raft.y, vy, 0.5)

		var wind := await _wind_velocity()
		var wind_vx := 2.0 * (WIND_VX / grav) * DT
		_expect("%s wind vx = 2*(vx/mass)*dt" % hero, wind.x, wind_vx, 0.02)
		_expect("%s wind moves by velocity, not twice" % hero, wind.y, wind_vx * DT, 0.002)

	_root.queue_free()
	print("HERO KIT CHECK: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


func _build_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_add_box(Vector3(0, -0.5, 0), Vector3(240, 1, 8), false)
	# Wall A right face at x=0. Wall B left face at x=1.7. Shaft for the zigzag.
	_add_box(Vector3(-0.5, 15.0, 0), Vector3(1, 30, 6), false)
	_add_box(Vector3(2.2, 15.0, 0), Vector3(1, 30, 6), false)
	_add_box(Vector3(TALL_X + 1.5, TALL_TOP * 0.5, 0), Vector3(3, TALL_TOP, 8), false)
	_add_box(Vector3(LIP_X - 1.5, 0.75 + 0.5, 0), Vector3(3, 1, 8), false)
	# One-way lip the mantle must ignore. Top at ONEWAY_TOP, left face at ONEWAY_X.
	_add_box(Vector3(ONEWAY_X + 1.0, ONEWAY_TOP - 1.0, 0), Vector3(2, 2, 6), true)
	_p = CharacterBody3D.new()
	_p.floor_stop_on_slope = true
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = BODY_R
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	_p.add_child(col)
	var mesh := Node3D.new()
	mesh.name = "MeshPlaceholder"
	_p.add_child(mesh)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_p.add_child(cam)
	_p.set_script(PLAYER_SCRIPT)
	_p.position = Vector3(0, 0.05, 0)
	_root.add_child(_p)


func _add_box(center: Vector3, size: Vector3, oneway: bool) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	body.position = center
	if oneway:
		body.add_to_group("oneway")
		body.set_meta("kind", "oneway")
	_root.add_child(body)


func _tick() -> void:
	await process_frame


func _step(move: float, held: bool, down := false) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right", move)
		elif move < 0.0:
			Input.action_press("move_left", -move)
		_move = move
	if held != _held:
		if held:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		_held = held
	if down != _down:
		if down:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")
		_down = down
	await _tick()


func _reset_body() -> void:
	_p._release_hang()
	_p._crouching = false
	_p._dragging = false
	_p._set_height(_p._stand_h)
	_p._wall_dir = 0
	_p._wall_lock = 0.0
	_p._wall_coyote = 0.0
	_p._buffer_timer = 0.0
	_p._drop_timer = 0.0
	_p.velocity = Vector3.ZERO
	_p._apply_pose()


func _settle(x := 2.0) -> void:
	_reset_body()
	_p.global_position = Vector3(x, 0.05, 0)
	for i in 15:
		await _step(0.0, false)


## Airborne, jumps exhausted, pressed into wall A's right face. Returns (vx, vy, pose_ok).
func _wall_jump() -> Vector3:
	_reset_body()
	_p.global_position = Vector3(0.55, 6.0, 0)
	_p.velocity = Vector3(-1.0, 0.0, 0)
	_p._jumps_left = 0
	_p._coyote_timer = 0.0
	_p._grounded = false
	var saw_wall := false
	for i in 25:
		await _step(-1.0, false)
		if _p._wall_dir == -1 and _p.pose_id == "wall":
			saw_wall = true
			break
	if not saw_wall:
		print("    wall miss dir %s pose %s pos %s" % [str(_p._wall_dir), _p.pose_id, str(_p.global_position)])
		return Vector3(-999, -999, 0)
	await _step(-1.0, true)
	var vx := _p.velocity.x * PX
	var vy := _p.velocity.y * PX
	var pose_ok := 1.0 if _p.pose_id == "bounce" and absf(_p._wall_lock - 0.14) < 0.002 else 0.0
	for i in 40:
		await _step(0.0, false)
	return Vector3(vx, vy, pose_ok)


## Kick off wall A, hold into wall B, kick back. Second |vx| should match the kick,
## and the second kick happens higher than the first.
func _zigzag() -> Vector2:
	_reset_body()
	_p.global_position = Vector3(0.55, 4.0, 0)
	_p.velocity = Vector3(-1.0, 0.0, 0)
	_p._jumps_left = 0
	_p._coyote_timer = 0.0
	_p._grounded = false
	if not await _wait_wall(-1.0, -1):
		print("    zig no first wall %s %s" % [str(_p.global_position), str(_p._wall_dir)])
		return Vector2(-999, 0)
	await _step(-1.0, true)
	var y0 := _p.global_position.y
	# Hold jump across the gap. 2D cuts vy by 0.48 every tick the button is up,
	# which kills the hop before the other wall. A real zigzag holds jump.
	if not await _wait_wall(1.0, 1, true):
		print("    zig no second wall y %.2f dir %s lock %.3f pos %s" % [_p.global_position.y, str(_p._wall_dir), _p._wall_lock, str(_p.global_position)])
		return Vector2(-999, 0)
	var climbed := _p.global_position.y > y0 + 1.0
	await _step(1.0, false)
	await _step(1.0, true)
	var vx := absf(_p.velocity.x) * PX
	for i in 30:
		await _step(0.0, false)
	return Vector2(vx, 1.0 if climbed else 0.0)


func _wait_wall(move: float, dir: int, held := false) -> bool:
	for i in 90:
		await _step(move, held)
		if _p._wall_dir == dir and _p._wall_lock <= 0.0:
			return true
		if _p.global_position.y < 0.2:
			return false
	return false


func _ledge_grab_metrics() -> Vector2:
	await _settle(TALL_X - BODY_R - 0.1)
	for t in 200:
		await _step(0.0, true)
		if _p._hanging:
			var head: float = (_p.global_position.y + float(_p._stand_h) - TALL_TOP) * PX
			var pose := 1.0 if String(_p.pose_id) == "hang" else 0.0
			for k in 40:
				await _step(0.0, false)
			return Vector2(head, pose)
	await _step(0.0, false)
	return Vector2(-999, 0)


## Stand inset in px (want 2) when the solid lip is mantled and the oneway was not.
func _mantle_metrics() -> float:
	if await _grabbed_oneway():
		print("    mantle grabbed the oneway")
		return -1.0
	await _settle(TALL_X - BODY_R - 0.1)
	var grab := -1
	var inset := -1.0
	for t in 220:
		await _step(0.0, true)
		if _p._hanging and grab < 0:
			grab = t
		elif grab >= 0 and not _p._hanging:
			if absf(float(t - grab) - 17.0) > 0.0:
				inset = -2.0
			else:
				inset = (_p.global_position.x - BODY_R - TALL_X) * PX
			break
	await _step(0.0, false)
	return inset


func _grabbed_oneway() -> bool:
	_reset_body()
	# 0.1 m off the oneway's left face, above the floor, jump held, no steer.
	_p.global_position = Vector3(ONEWAY_X - BODY_R - 0.1, ONEWAY_TOP - 0.4, 0)
	_p.velocity = Vector3.ZERO
	_p._jumps_left = 0
	_p._coyote_timer = 0.0
	for t in 50:
		await _step(0.0, true)
		if _p._hanging:
			await _step(0.0, false)
			return true
	await _step(0.0, false)
	return false


func _crouch_height() -> float:
	await _settle(4.0)
	await _step(0.0, false, true)
	var h: float = float(_p._h) * PX
	await _step(0.0, false, false)
	return h


## Returns (crawl px/s, passed_and_pose).
func _crawl_speed() -> Vector2:
	await _settle(4.0)
	var speed := 0.0
	for i in 4:
		await _step(1.0, false, true)
		speed = _p.velocity.x * PX
	var pose: bool = String(_p.pose_id) == "drag" and is_equal_approx(float(_p._h) * PX, 14.0)
	await _settle(LIP_X + BODY_R + 0.6)
	var passed := false
	for i in 30:
		await _step(-1.0, false, false)
	for i in 160:
		await _step(-1.0, false, true)
		if _p.global_position.x < LIP_X - 1.5:
			passed = true
			break
	await _step(0.0, false, false)
	return Vector2(speed, 1.0 if pose and passed else 0.0)


func _coyote_last() -> float:
	var last := -1.0
	for at in [6, 7]:
		if await _third_jump_at(at):
			last = float(at)
	return last


func _third_jump_at(at: int) -> bool:
	await _settle(4.0)
	await _step(0.0, true)   # frame 0, ground jump
	await _step(0.0, false)  # frame 1
	await _step(0.0, true)   # frame 2, second jump → jumps left = 0
	await _step(0.0, false)  # frame 3
	var f := 4
	while f < at:
		await _step(0.0, false)
		f += 1
	if _p._jumps_left != 0 or _p.is_on_floor():
		await _step(0.0, false)
		return false
	var vy := _p.velocity.y
	await _step(0.0, true)
	var jumped := _p.velocity.y > vy + 1.0
	for i in 90:
		await _step(0.0, false)
	return jumped


func _use_both_jumps() -> void:
	await _settle(4.0)
	await _step(0.0, true)
	for i in 8:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)


func _second_land_ticks() -> int:
	await _use_both_jumps()
	var k := 0
	while not _p.is_on_floor() and k < 400:
		await _step(0.0, true)
		k += 1
	return k


func _buffer_jumps(n: int, land_ticks: int) -> bool:
	await _use_both_jumps()
	for i in land_ticks - n:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)
	var jumped := false
	for i in n + 3:
		await _step(0.0, true)
		if _p.velocity.y > 20.0:
			jumped = true
	for i in 140:
		await _step(0.0, false)
	return jumped


func _buffer_window() -> float:
	var land := await _second_land_ticks()
	if land < 12:
		print("    buffer flight too short: %d" % land)
		return -1.0
	var win := -1.0
	if await _buffer_jumps(8, land):
		win = 8.0
	if await _buffer_jumps(9, land):
		win = 9.0
	return win


## No-steer jump off a raft moving at RAFT_SPEED. Returns (vx px/s, vy px/s)
## measured on the leave frame. ADD_VELOCITY would report vx ≈ 72.
func _raft_leave() -> Vector2:
	var raft := AnimatableBody3D.new()
	raft.sync_to_physics = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 0.4, 4)
	col.shape = box
	raft.add_child(col)
	raft.position = Vector3(RAFT_X, 2.2, 0)
	var scr := GDScript.new()
	scr.source_code = "extends AnimatableBody3D\nfunc _physics_process(delta: float) -> void:\n\tglobal_position.x += %s * delta\n" % RAFT_SPEED
	scr.reload()
	raft.set_script(scr)
	_root.add_child(raft)
	_reset_body()
	_p.global_position = Vector3(RAFT_X, 2.45, 0)
	_p.velocity = Vector3.ZERO
	for i in 30:
		await _step(0.0, false)
	if not _p.is_on_floor():
		print("    raft miss pos %s" % str(_p.global_position))
		raft.queue_free()
		return Vector2(-999, -999)
	await _step(0.0, true)
	var out := Vector2(_p.velocity.x * PX, _p.velocity.y * PX)
	for i in 10:
		await _step(0.0, false)
	raft.queue_free()
	return out


## Two airborne ticks inside a wind zone. Returns (vx px/s, dx px) of the
## second tick. dx must equal vx*dt: wind writes velocity before move_and_slide
## and does not add the same impulse to position.
func _wind_velocity() -> Vector2:
	var zone := Node3D.new()
	zone.add_to_group("wind")
	zone.set_meta("vx", WIND_VX)
	zone.set_meta("ay", 0.0)
	zone.set_meta("aabb", AABB(Vector3(WIND_X - 15.0, 8.0, -4.0), Vector3(30.0, 30.0, 8.0)))
	_root.add_child(zone)
	_reset_body()
	_p.global_position = Vector3(WIND_X, 18.0, 0)
	_p.velocity = Vector3.ZERO
	_p._grounded = false
	_p._jumps_left = 0
	_p._coyote_timer = 0.0
	await _step(0.0, false)
	var x0 := _p.global_position.x
	await _step(0.0, false)
	var out := Vector2(_p.velocity.x * PX, (_p.global_position.x - x0) * PX)
	zone.queue_free()
	for i in 5:
		await _step(0.0, false)
	return out


func _expect(label: String, got: float, want: float, tol: float) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s  %-44s got %9.3f  want %9.3f" % ["ok  " if ok else "FAIL", label, got, want])
