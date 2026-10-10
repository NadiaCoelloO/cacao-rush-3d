extends SceneTree
## Headless scripted run of selva-1 from spawn to G00 using inputs only.
##   SELVA_RUN=1 godot --headless --fixed-fps 60 --path runtime -s res://tests/selva1_run_probe.gd
## Does not modify player_maya.gd. Exit 0 if the goal is taken.

const PILOT := "res://scenes/pilot_cuyabeno.tscn"
const MAX_TICKS := 60 * 180
const GOAL_X := 195.0

var _p: CharacterBody3D
var _play: Node
var _plats: Array = []
var _movers: Array = []
var _move := 0.0
var _held := false
var _down := false
var _far_x := 0.0
var _stuck := 0
var _last_x := 0.0
var _deaths := 0
var _last_lives := 5
var _air := 0
var _jump_armed := false


func _initialize() -> void:
	OS.set_environment("SELVA_RUN", "1")
	_run.call_deferred()


func _run() -> void:
	var pilot: Node = (load(PILOT) as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	_p = pilot.get_node("PlayerMaya")
	_play = pilot.get_node_or_null("Selva1Play")
	if _play == null:
		for c in pilot.get_children():
			if String(c.name).begins_with("Selva") or c.has_method("_tick_play"):
				_play = c
				break
	if _play and _play.get("_layout"):
		_plats = (_play.get("_layout") as Dictionary).get("platforms", [])
	if _play:
		_movers = _play.get("_movers")
		_last_lives = int(_play.get("_lives"))
	for i in 50:
		await _step(0.0, false, false)
	_far_x = _p.global_position.x
	_last_x = _far_x
	print("SELVA_RUN start feet=", _p.global_position, " plats=", _plats.size(), \
			" movers=", _movers.size(), \
			" feel=", _play.get("_feel") if _play else "?", \
			" kill_y=", _p.kill_y, " pit=", _play.get("PIT_KILL_Y") if _play else "?")
	for tick in MAX_TICKS:
		if _play:
			var lives := int(_play.get("_lives"))
			if lives < _last_lives:
				_deaths += _last_lives - lives
				_last_lives = lives
				print("SELVA_RUN death n=%d lives=%d feet=%s" % [_deaths, lives, _p.global_position])
			if lives <= 0 and String(_play.get("_status")) == "over":
				print("SELVA_RUN FAIL game_over ticks=%d far_x=%.2f feet=%s deaths=%d goal=0" % [
					tick, _far_x, _p.global_position, _deaths
				])
				quit(1)
				return
		var plan := _plan()
		await _step(plan.x, plan.y > 0.5, plan.z > 0.5)
		var x := _p.global_position.x
		if x > _far_x:
			_far_x = x
		if absf(x - _last_x) < 0.04:
			_stuck += 1
		else:
			_stuck = 0
			_last_x = x
		var won := false
		if _play:
			won = bool(_play.get("_goal_taken")) or String(_play.get("_status")) == "win"
		if won or x >= GOAL_X:
			print("SELVA_RUN PASS ticks=%d far_x=%.2f feet=%s deaths=%d goal=1" % [
				tick, _far_x, _p.global_position, _deaths
			])
			quit(0)
			return
		if (tick < 1800 and tick % 120 == 119) or tick % 600 == 599:
			print("SELVA_RUN progress t=%.1f x=%.2f y=%.2f far=%.2f stuck=%d hang=%s lives=%s" % [
				tick / 60.0, x, _p.global_position.y, _far_x, _stuck,
				str(_p.get("_hanging")), str(_play.get("_lives")) if _play else "?"
			])
	print("SELVA_RUN FAIL ticks=%d far_x=%.2f feet=%s deaths=%d goal=0" % [
		MAX_TICKS, _far_x, _p.global_position, _deaths
	])
	quit(1)


func _plan() -> Vector3:
	var feet := _p.global_position
	var x := feet.x
	var y := feet.y
	var on := _p.is_on_floor()
	var hanging: bool = bool(_p.get("_hanging"))
	if on:
		_air = 0
	else:
		_air += 1

	# Mantle: let the 0.28 s pull-up finish. Jump-from-hang kicks backward.
	if hanging:
		_jump_armed = false
		return Vector3(0.0, 0.0, 0.0)

	# P04 (moving, top ≈ 4): walk to P02's lip, hop when the deck overlaps,
	# ride it right, then jump to P05 (50.67).
	if x > 24.0 and x < 52.5 and y < 8.5:
		var m := _nearest_mover(x, y)
		if not on and x > 34.0:
			_jump_armed = true
			return Vector3(1.0, 1.0, 0.0)
		if y < 3.15:
			var under := m.x < 0.8 and m.y > x + 0.5
			if under:
				_jump_armed = true
				return Vector3(0.0, 1.0, 0.0)
			_jump_armed = false
			if x < 27.6:
				return Vector3(1.0, 0.0, 0.0)
			return Vector3(0.0, 0.0, 0.0)
		if x > 43.6:
			_jump_armed = true
			return Vector3(1.0, 1.0, 0.0)
		return Vector3(1.0, 0.0, 0.0)

	# After the crawl, stay ducked until the body clears P06 (right 62.67 + 0.54).
	# Double-jump the spikes, then release so we land on P09 past frog H01 (84.4).
	if x > 61.8 and x < 96.0 and y < 16.0:
		var duck := x < 63.35 and y < 4.0
		if duck:
			return Vector3(1.0, 0.0, 1.0)
		var hop := x > 63.95 or not on
		if (not on) and _air > 18 and _p.velocity.y < 0.0 and x < 82.0 and _held:
			hop = false
		if x > 84.0:
			hop = false
		return Vector3(1.0, 1.0 if hop else 0.0, 0.0)

	var crouch := _in_low_cover(x)
	var jump := false
	var move := 1.0

	if on:
		var mount := _higher_ahead(x, y)
		var wait := _mover_too_far(x, y)
		if wait and mount < 0.0:
			move = 0.0
			_jump_armed = false
		elif mount >= 0.0 and mount < 3.2:
			# Walk under a higher deck (P04) and hop up — a running 8 m jump overshoots.
			move = 0.0 if mount < 1.4 else 1.0
			_jump_armed = mount < 2.0
		else:
			_jump_armed = (not crouch) and (_gap_ahead(x, y) or _hazard_hop(x, y) or _stuck > 40)
		jump = _jump_armed
	else:
		# Hold the whole airtime. Releasing cuts vy and shortens the jump.
		jump = _jump_armed

	if _stuck > 90 and _stuck < 120:
		move = -1.0
	if crouch:
		jump = false
		_jump_armed = false
	return Vector3(move, 1.0 if jump else 0.0, 1.0 if crouch else 0.0)


func _in_low_cover(x: float) -> bool:
	# P06 crawl 53.33–62.67. P13 squeeze 104–112.
	return (x > 52.4 and x < 63.4) or (x > 103.2 and x < 113.2)


func _gap_ahead(x: float, y: float) -> bool:
	var here := _support_top(x, y + 0.4)
	var land := _support_top(x + 2.3, y + 0.4)
	if here < -90.0:
		return false
	if land < -90.0:
		return true
	if land < here - 0.5:
		return true
	return false


func _hazard_hop(x: float, y: float) -> bool:
	if x > 63.6 and x < 69.8 and y < 4.2:
		return true
	# H01 (84.4, 8.33) H02 (151.0, 13.67)
	if absf(x - 84.4) < 1.6 and absf(y - 8.33) < 1.4:
		return true
	if absf(x - 151.0) < 1.6 and absf(y - 13.67) < 1.4:
		return true
	return false


func _nearest_mover(x: float, y: float) -> Vector3:
	# x = dist to left face (>=0 if ahead), y = right face, z = right face (copy)
	var best := Vector3(-1.0, -1.0, -1.0)
	var best_dist := 99.0
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var top := pos.y + sz.y * 0.5
		if top < y - 0.5 or top > y + 5.5:
			continue
		var left := pos.x - sz.x * 0.5
		var right := pos.x + sz.x * 0.5
		var dist := left - x
		if absf(dist) < best_dist:
			best_dist = absf(dist)
			best = Vector3(dist, right, right)
	return best


func _higher_ahead(x: float, y: float) -> float:
	var best := -1.0
	# Only moving decks are mount targets. Static crates/oneways (P03/P07)
	# sit too high and steal the running jump.
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var x0 := pos.x - sz.x * 0.5
		var x1 := pos.x + sz.x * 0.5
		var top := pos.y + sz.y * 0.5
		if top < y + 0.7 or top > y + 4.6:
			continue
		if x1 < x - 0.2 or x0 > x + 6.0:
			continue
		var dist := maxf(0.0, x0 - x)
		if best < 0.0 or dist < best:
			best = dist
	return best


func _mover_too_far(x: float, y: float) -> bool:
	var nxt := _support_top(x + 3.0, y + 2.0)
	if nxt > -90.0 and nxt >= y - 0.7:
		return false
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var left := pos.x - sz.x * 0.5
		var top := pos.y + sz.y * 0.5
		if top < y - 1.2 or top > y + 7.0:
			continue
		if left > x + 0.3 and left < x + 9.0:
			return left > x + 4.6
	return false


func _support_top(x: float, y: float) -> float:
	var best := -999.0
	for raw in _plats:
		var p: Dictionary = raw
		if String(p.get("kind", "")) == "moving":
			continue
		var c: Array = p["center_m"]
		var s: Array = p["size_m"]
		var x0 := float(c[0]) - float(s[0]) * 0.5
		var x1 := float(c[0]) + float(s[0]) * 0.5
		if x < x0 or x > x1:
			continue
		var top := float(p["top_m"])
		if top <= y + 0.5 and top > best:
			best = top
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		if x < pos.x - sz.x * 0.5 or x > pos.x + sz.x * 0.5:
			continue
		var top := pos.y + sz.y * 0.5
		if top <= y + 0.5 and top > best:
			best = top
	return best


func _step(move: float, held: bool, down := false) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right", 1.0)
		elif move < 0.0:
			Input.action_press("move_left", 1.0)
		_move = move
	if held and not _held:
		Input.action_press("jump")
	elif not held and _held:
		Input.action_release("jump")
	_held = held
	if down and not _down:
		Input.action_press("move_down")
	elif not down and _down:
		Input.action_release("move_down")
	_down = down
	await process_frame
