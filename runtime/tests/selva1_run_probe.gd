extends SceneTree
## Headless scripted run of selva-1 from spawn to G00 using inputs only.
##   SELVA_RUN=1 godot --headless --fixed-fps 60 --path runtime -s res://tests/selva1_run_probe.gd
## Does not modify player_maya.gd. Exit 0 if the goal is taken.

const PILOT := "res://scenes/pilot_cuyabeno.tscn"
const MAX_TICKS := 60 * 180
const GOAL_X := 195.0
const PX := 1.0 / 24.0

var _p: CharacterBody3D
var _play: Node
var _plats: Array = []
var _hazards: Array = []
var _movers: Array = []
var _move := 0.0
var _held := false
var _down := false
var _far_x := 0.0
var _stuck := 0
var _last_x := 0.0
var _air_hold := 0
var _tap_off := 0
var _deaths := 0
var _last_lives := 5


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
		var lay: Dictionary = _play.get("_layout")
		_plats = lay.get("platforms", [])
		_hazards = lay.get("hazards", [])
	if _play:
		_movers = _play.get("_movers")
		_last_lives = int(_play.get("_lives"))
	for i in 50:
		await _step(0.0, false, false)
	_far_x = _p.global_position.x
	_last_x = _far_x
	print("SELVA_RUN start feet=", _p.global_position, " plats=", _plats.size(), \
			" feel=", _play.get("_feel") if _play else "?", \
			" kill_y=", _p.kill_y, " pit=", _play.get("PIT_KILL_Y") if _play else "?")
	for tick in MAX_TICKS:
		if _play:
			var lives := int(_play.get("_lives"))
			if lives < _last_lives:
				_deaths += _last_lives - lives
				_last_lives = lives
				print("SELVA_RUN death n=%d lives=%d feet=%s" % [_deaths, lives, _p.global_position])
		var plan := _plan()
		await _step(plan.x, plan.y > 0.5, plan.z > 0.5)
		var x := _p.global_position.x
		if x > _far_x:
			_far_x = x
		if absf(x - _last_x) < 0.03:
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
		if tick % 600 == 599:
			print("SELVA_RUN progress t=%.1f x=%.2f y=%.2f far=%.2f stuck=%d lives=%s" % [
				tick / 60.0, x, _p.global_position.y, _far_x, _stuck,
				str(_play.get("_lives")) if _play else "?"
			])
	print("SELVA_RUN FAIL ticks=%d far_x=%.2f feet=%s deaths=%d goal=0" % [
		MAX_TICKS, _far_x, _p.global_position, _deaths
	])
	quit(1)


func _plan() -> Vector3:
	# x = move, y = jump, z = crouch/prone
	if _p == null:
		return Vector3(1.0, 0.0, 0.0)
	var feet := _p.global_position
	var crouch := _under_ceiling(feet.x, feet.y)
	var jump := false
	var move := 1.0
	if _should_wait_mover(feet.x, feet.y):
		move = 0.0
	if _gap_ahead(feet.x, feet.y) or _hazard_ahead(feet.x, feet.y):
		jump = true
		crouch = false
	if not _p.is_on_floor():
		_air_hold += 1
		# Full-hold for height, then tap a second jump (just_pressed).
		jump = true
		if _air_hold > 10 and (_gap_ahead(feet.x, feet.y) or feet.y < _best_top(feet.x + 3.0, feet.y + 8.0) - 0.4):
			if _tap_off > 0:
				_tap_off -= 1
				jump = false
			elif _held:
				_tap_off = 2
				jump = false
		crouch = false
	else:
		_air_hold = 0
		_tap_off = 0
	if _stuck > 25:
		jump = true
		crouch = false
	if _stuck > 90 and _stuck < 130:
		move = -1.0
	if _stuck > 160:
		crouch = true
	return Vector3(move, 1.0 if jump else 0.0, 1.0 if crouch else 0.0)


func _under_ceiling(x: float, y: float) -> bool:
	for raw in _plats:
		var p: Dictionary = raw
		if String(p.get("kind", "")) == "oneway":
			continue
		var c: Array = p["center_m"]
		var s: Array = p["size_m"]
		var x0 := float(c[0]) - float(s[0]) * 0.5
		var x1 := float(c[0]) + float(s[0]) * 0.5
		if x < x0 - 0.15 or x > x1 + 0.15:
			continue
		var bottom := float(c[1]) - float(s[1]) * 0.5
		var gap := bottom - y
		if gap > 0.12 and gap < 1.72:
			return true
	return false


func _gap_ahead(x: float, y: float) -> bool:
	var here := _best_top(x, y)
	var land := _best_top(x + 2.5, y)
	if here < -90.0:
		return true
	if land < -90.0:
		return true
	if land < here - 0.45:
		return true
	return false


func _hazard_ahead(x: float, y: float) -> bool:
	var probe := AABB(Vector3(x + 0.2, y, -2.0), Vector3(2.1, 1.8, 4.0))
	for raw in _hazards:
		var h: Dictionary = raw
		var kind := String(h.get("kind", ""))
		if kind == "wind":
			continue
		var c: Array = h.get("center_m", [0, 0, 0])
		var s: Array = h.get("size_m", [1, 1, 1])
		var box := AABB(
			Vector3(float(c[0]) - float(s[0]) * 0.5, float(c[1]) - float(s[1]) * 0.5, -2.0),
			Vector3(float(s[0]), float(s[1]), 4.0)
		)
		# Live AABB from the play layer beats the rest pose (rocks move).
		if _play:
			for rec in _play.get("_hazards"):
				if rec is Dictionary and String(rec.get("id", "")) == String(h.get("id", "")):
					if rec.get("aabb") is AABB:
						box = rec["aabb"]
					break
		if probe.position.x < box.end.x and probe.end.x > box.position.x \
				and probe.position.y < box.end.y and probe.end.y > box.position.y:
			return true
	return false


func _should_wait_mover(x: float, y: float) -> bool:
	if _movers.is_empty() or not _p.is_on_floor():
		return false
	var next_static := _best_top(x + 3.2, y)
	if next_static > -90.0 and next_static >= y - 0.6:
		return false
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var half := (mesh.mesh as BoxMesh).size.x * 0.5
		var left := pos.x - half
		var right := pos.x + half
		var top := pos.y + (mesh.mesh as BoxMesh).size.y * 0.5
		if top < y - 1.0 or top > y + 6.5:
			continue
		if left > x + 0.4 and left < x + 8.5:
			# Platform is in jump range — go. If still far, wait.
			return left > x + 4.8
	return false


func _best_top(x: float, y: float) -> float:
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
		if top <= y + 3.4 and top > best:
			best = top
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var x0 := pos.x - sz.x * 0.5
		var x1 := pos.x + sz.x * 0.5
		if x < x0 or x > x1:
			continue
		var top := pos.y + sz.y * 0.5
		if top <= y + 3.4 and top > best:
			best = top
	return best


func _step(move: float, held: bool, down := false) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right")
		elif move < 0.0:
			Input.action_press("move_left")
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
