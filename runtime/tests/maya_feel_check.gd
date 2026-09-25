extends SceneTree
## Headless feel check for player_maya.gd against 2D sim.ts numbers (Maya, 60 Hz).
##   godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd
## Expected values come from a verbatim JS port of applyRun/applyJump/applyGravity
## on a flat floor (Cacao.Game @ 77e55b5 src/game/sim.ts). Exit code 1 on any failure.

const PX := 24.0
const PLAYER_SCRIPT := preload("res://scripts/player_maya.gd")
const PILOT_SCENE := "res://scenes/pilot_cuyabeno.tscn"

var _fails := 0
var _held := false
var _move := 0.0
var _p: CharacterBody3D
var _root: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	_build_flat_world()
	await _settle()

	_expect_arr("run ramp px/s", await _vx_series(1.0, 5), [76.667, 153.333, 230.0, 290.0, 290.0], 0.01)
	_expect_arr("stop px/s", await _vx_series(0.0, 6), [220.0, 150.0, 80.0, 10.0, 0.0, 0.0], 0.01)

	var hold := await _jump_apex(-1)
	_expect("full-hold apex px", hold.x, 118.0, 0.5)
	_expect("full-hold air ticks", hold.y, 38.0, 1.0)
	var hop := await _jump_apex(1)
	_expect("1-tick hold apex px", hop.x, 18.6, 0.5)
	_expect("double-jump apex px", await _double_apex(), 234.89, 1.0)
	_expect("third press denied (jumps used)", await _press_count(3), 2.0, 0.0)

	var land_ticks := await _second_jump_land_ticks()
	for n in [5, 6, 7, 8, 9]:
		_expect("buffer %d ticks early jumps" % n, 1.0 if await _buffer_jumps(n, land_ticks) else 0.0, 1.0 if n <= 8 else 0.0, 0.0)

	_expect("full jump clears 1 m ledge", 1.0 if await _ledge_climb() else 0.0, 1.0, 0.0)
	_expect("fall-kill respawns at spawn", 1.0 if await _falls_and_respawns(Vector3(0, 0.05, 0), 60.0) else 0.0, 1.0, 0.0)

	_root.queue_free()
	await physics_frame
	await _pilot_smoke()

	print("MAYA FEEL CHECK: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


func _build_flat_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 8))
	_add_box(Vector3(-40, 0.5, 0), Vector3(3, 1, 8))
	_p = CharacterBody3D.new()
	_p.floor_stop_on_slope = true
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
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


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	body.position = center
	_root.add_child(body)


## Applies inputs for one physics tick (runs before the player's _physics_process).
func _step(move: float, held: bool) -> void:
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
	await physics_frame


func _settle(x := 0.0) -> void:
	_p.global_position = Vector3(x, 0.05, 0)
	_p.velocity = Vector3.ZERO
	for i in 20:
		await _step(0.0, false)


func _vx_series(move: float, n: int) -> Array:
	var out := []
	for i in n:
		await _step(move, false)
		out.append(_p.velocity.x * PX)
	return out


## hold_ticks < 0 keeps jump held for the whole flight. Returns (apex px, air ticks).
func _jump_apex(hold_ticks: int) -> Vector2:
	await _settle()
	var y0 := _p.global_position.y
	var apex := 0.0
	var t := 0
	await _step(0.0, true)
	t += 1
	while not _p.is_on_floor() and t < 300:
		apex = maxf(apex, _p.global_position.y - y0)
		await _step(0.0, hold_ticks < 0 or t < hold_ticks)
		t += 1
	return Vector2(apex * PX, t)


func _double_apex() -> float:
	await _settle()
	var y0 := _p.global_position.y
	await _step(0.0, true)
	while _p.velocity.y > 0.0:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)
	var apex := 0.0
	var t := 0
	while not _p.is_on_floor() and t < 300:
		apex = maxf(apex, _p.global_position.y - y0)
		await _step(0.0, true)
		t += 1
	return apex * PX


func _press_count(presses: int) -> float:
	await _settle()
	var count := 0
	for i in presses:
		var vy_before := _p.velocity.y
		await _step(0.0, true)
		if _p.velocity.y > vy_before + 1.0:
			count += 1
		for k in 10:
			await _step(0.0, true)
		await _step(0.0, false)
	for k in 120:
		await _step(0.0, false)
	return float(count)


func _use_both_jumps() -> void:
	await _settle()
	await _step(0.0, true)
	for i in 5:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)


func _second_jump_land_ticks() -> int:
	await _use_both_jumps()
	var k := 0
	while not _p.is_on_floor() and k < 300:
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
	for i in n + 2:
		await _step(0.0, true)
		if _p.velocity.y > 20.0:
			jumped = true
	for i in 120:
		await _step(0.0, false)
	return jumped


func _ledge_climb() -> bool:
	await _settle(-46.0)
	await _step(1.0, true)
	for i in 90:
		await _step(1.0, true)
		if _p.is_on_floor() and _p.global_position.y > 0.9:
			await _step(0.0, false)
			return true
	await _step(0.0, false)
	return false


func _falls_and_respawns(spawn: Vector3, run_to_x: float) -> bool:
	await _settle()
	_p.global_position = Vector3(run_to_x + 100.0, 0.05, 0)
	for i in 180:
		await _step(0.0, false)
		if _p.global_position.distance_to(spawn) < 0.5 and _p.velocity.length() < 1.0:
			return true
	return false


func _pilot_smoke() -> void:
	var pilot: Node = (load(PILOT_SCENE) as PackedScene).instantiate()
	root.add_child(pilot)
	_p = pilot.get_node("PlayerMaya")
	var spawn := _p.global_position
	for i in 60:
		await _step(0.0, false)
	_expect("pilot: Maya lands on floor from spawn", 1.0 if _p.is_on_floor() and absf(_p.global_position.y) < 0.1 else 0.0, 1.0, 0.0)
	var on_ledge := false
	await _step(1.0, true)
	for i in 90:
		await _step(1.0, true)
		if _p.is_on_floor() and _p.global_position.y > 0.9:
			on_ledge = true
			break
	for i in 30:
		await _step(0.0, false)
	_expect("pilot: full jump from spawn lands on ledge", 1.0 if on_ledge else 0.0, 1.0, 0.0)
	var respawned := false
	for i in 360:
		await _step(-1.0, false)
		if i > 30 and _p.global_position.distance_to(spawn) < 0.5:
			respawned = true
			break
	await _step(0.0, false)
	_expect("pilot: running off the left edge respawns", 1.0 if respawned else 0.0, 1.0, 0.0)
	pilot.queue_free()


func _expect(label: String, got: float, want: float, tol: float) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s  %-36s got %9.3f  want %9.3f" % ["ok  " if ok else "FAIL", label, got, want])


func _expect_arr(label: String, got: Array, want: Array, tol: float) -> void:
	var ok := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		ok = ok and absf(float(got[i]) - float(want[i])) <= tol
	if not ok:
		_fails += 1
	print("%s  %-36s got %s  want %s" % ["ok  " if ok else "FAIL", label, str(got.map(func(v): return snappedf(v, 0.001))), str(want)])
